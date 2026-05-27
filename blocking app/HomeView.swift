import SwiftUI
import FamilyControls
import CoreData
import UserNotifications
import CloudKit

struct HomeView: View {
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ListEntity.createdAt, ascending: false)],
        animation: .default
    ) private var lists: FetchedResults<ListEntity>

    @State private var showingCreate = false
    // حالة حذف
    @State private var showDeleteConfirm = false
    @State private var listToDelete: ListEntity?
    /// When non-nil, presents NoNetGatekeeperSheet for the given list. Set
    /// from deleteList(_:) when the list's gatekeeperType is "nonet" — the
    /// user must pass the 200-char or 7-day gate before the actual purge runs.
    @State private var gatekeeperSheetList: ListEntity?
    /// Backing for the RequestActionSheet (Hard + Partner). The wrapper
    /// captures listID/name + partnership at the moment delete is tapped so
    /// the sheet has stable references even if Core Data context updates.
    @State private var partnerRequestSheet: PartnerRequestSheetContext?

    /// Stable snapshot of "user asked to delete list X gated by partnership Y."
    /// Used as the .sheet(item:) source so SwiftUI handles dismissal correctly.
    struct PartnerRequestSheetContext: Identifiable {
        let id: UUID            // listID, doubles as the SwiftUI item id
        let listName: String
        let action: GatekeeperAction
        let partnership: Partnership
    }
    // حالة خطأ الحفظ
    @State private var saveErrorMessage: String? = nil
    // عرض/إخفاء "قوائم أخرى" — مطوي افتراضياً (DisclosureGroup)
    @State private var showOtherLists: Bool = false

    // حالة الاشتراك/التجربة
    @AppStorage(AppStorageKeys.isPremium) private var isPremium: Bool = false
    @AppStorage(AppStorageKeys.trialStartTs) private var trialStartTs: Double = 0
    @AppStorage(AppStorageKeys.selectedTab) private var selectedTab: Int = 0
    // Personalization from onboarding
    @AppStorage(AppStorageKeys.obName) private var obName: String = ""
    // Surfaces iCloud-unavailable banners when Hard-Mode lists exist
    @ObservedObject private var partnerStore = CloudKitPartnerStore.shared
    @State private var refreshTick: Int = 0
    @State private var selectedListId: UUID? = nil
    private var isTrialActive: Bool {
        trialStartTs > 0 && Date().timeIntervalSince1970 < trialStartTs + BlockingConstants.trialDurationSeconds
    }
    private var trialRemainingDays: Int {
        guard isTrialActive else { return 0 }
        let remaining = (trialStartTs + BlockingConstants.trialDurationSeconds - Date().timeIntervalSince1970) / BlockingConstants.secondsPerDayInterval
        return max(0, Int(ceil(remaining)))
    }

    // Schedule decoding
    private struct ScheduleSlot: Codable { let id: UUID; let day: Int; let fromMinutes: Int; let toMinutes: Int }

    private var activeLists: [ListEntity] {
        lists
            .filter { isActiveNow($0) }
            .sorted { a, b in
                let ah = (a.protection == "hard")
                let bh = (b.protection == "hard")
                if ah != bh { return ah && !bh }
                let ad = a.createdAt
                let bd = b.createdAt
                return ad > bd
            }
    }
    private var nonActiveLists: [ListEntity] {
        lists
            .filter { !isActiveNow($0) }
            .sorted { a, b in
                let ah = (a.protection == "hard")
                let bh = (b.protection == "hard")
                if ah != bh { return ah && !bh }
                let ad = a.createdAt
                let bd = b.createdAt
                return ad > bd
            }
    }

    /// Delete a list and clean up its UserDefaults-backed companion data (breaks/manual state, family selection, shields).
    ///
    /// Routing for Hard-Mode lists depends on the configured gatekeeper:
    ///   • "nonet" — open NoNetGatekeeperSheet so the user picks the 200-char
    ///     reason path (immediate) or the 7-day wait path (delayed). The
    ///     actual purge runs inside `performHardDelete` once the gate is passed.
    ///   • "partner" — current behavior: refuse + record BreakAttempt. The
    ///     full approval workflow lands in PR 2.
    /// Non-Hard lists delete immediately.
    private func deleteList(_ list: ListEntity) {
        if BlockingEngine.shared.isHardLocked(list: list) {
            if list.gatekeeperType == "nonet" {
                // Defer to NoNetGatekeeperSheet — the user must satisfy one of
                // the two gates before performHardDelete runs.
                gatekeeperSheetList = list
                return
            }
            // gatekeeperType == "partner": route through RequestActionSheet
            // so the partner can approve or deny. If no partnership is yet
            // associated (e.g. the invitation hasn't been accepted), fall back
            // to a refusal — there's no one to approve through.
            if let partnership = CloudKitPartnerStore.shared.partnership(for: list.id),
               partnership.status == .accepted {
                partnerRequestSheet = PartnerRequestSheetContext(
                    id: list.id,
                    listName: list.name,
                    action: .delete,
                    partnership: partnership
                )
                return
            }
            // No accepted partnership yet — refusal + best-effort log.
            saveErrorMessage = lang.isArabicEffective
                ? "هذه القائمة بحماية شريك بشري، لكن لم يقبل أحد الدعوة بعد. أرسل دعوة جديدة أو حوّل الحارس إلى NoNet من تفاصيل القائمة."
                : "This list is partner-protected, but no one has accepted yet. Send a new invitation or switch the gatekeeper to NoNet from the list details."
            return
        }
        performHardDelete(list)
    }

    /// Actually delete a list — runs the Core Data purge plus all UserDefaults
    /// companion-data cleanup. Called directly by `deleteList` for non-Hard
    /// lists, and by the NoNetGatekeeperSheet callback once the user has
    /// satisfied the 200-char gate.
    private func performHardDelete(_ list: ListEntity) {
        let id = list.id
        BlockingEngine.shared.purge(listId: id)
        context.delete(list)
        switch context.saveIfNeeded() {
        case .success:
            BreaksStore.clear(for: id)
            ManualStateStore.clear(for: id)
            EmergencyUnlockStore.clear(for: id)
        case .failure(let error):
            saveErrorMessage = lang.isArabicEffective
                ? "تعذّر حذف القائمة: \(error.localizedDescription)"
                : "Couldn't delete the list: \(error.localizedDescription)"
        }
    }

    private var shareMessage: String {
        let activeCount = activeLists.count
        let totalCount = lists.count
        if lang.isArabicEffective {
            return "أستخدم تطبيق NoNet لحجب الإلهاءات وزيادة تركيزي — \(activeCount) قائمة فعّالة من أصل \(totalCount). جرّبه معي!"
        } else {
            return "I'm using NoNet to block distractions and stay focused — \(activeCount) active list(s) out of \(totalCount). Join me!"
        }
    }

    // Permission states (centralized)
    @StateObject private var permissions = PermissionsManager.shared
    @AppStorage(AppStorageKeys.permissionsExpanded) private var permissionsExpanded: Bool = false
    private var hasScreenTimePermission: Bool { permissions.isScreenTimeGranted }
    private var hasNotificationPermission: Bool { permissions.isNotificationsGranted }

    // ─── Alert sources (data) ───
    // Computed conditions for the consolidated alertsStrip(). Each is a pure
    // predicate — the strip decides which one wins by priority order.

    /// iCloud account is unavailable AND user has at least one Hard Mode list
    /// (Recovery Partner relies on iCloud; without it the safety net is broken).
    private var iCloudAlertReason: String? {
        let hasHardList = lists.contains { $0.protection == "hard" }
        guard hasHardList else { return nil }
        return partnerStore.accountUnavailableReason(isArabic: lang.isArabicEffective)
    }

    /// `DeviceActivityMonitor` extension hasn't responded in 24h despite the
    /// user having Scheduled or Time-Limit lists that need it. Silent failure
    /// becomes a 1-star review territory; surface it explicitly.
    private var monitorAlertActive: Bool {
        let scheduledLists = lists.filter { $0.blockType == "scheduled" || $0.blockType == "timeLimit" }
        let oldestCreation = scheduledLists.map { $0.createdAt }.min()
        return MonitorHealthcheck.shouldShowBanner(oldestScheduledOrLimit: oldestCreation)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: NNSpacing.md) {
                    // Welcome card — re-introduces the logo (removed in the
                    // initial v1.3.0 redesign) at a much smaller scale than the
                    // old 204pt hero. Costs ~88pt vs. the original 33% of the
                    // iPhone SE viewport.
                    welcomeCard()

                    // Consolidated alerts — at most one major banner shows at a
                    // time (priority: Permissions → iCloud → Monitor). Inbound
                    // partner requests get their own (richer) banner below,
                    // since they are interactive and shouldn't be dismissed by
                    // a less-important alert taking the slot.
                    if hasScreenTimePermission && hasNotificationPermission {
                        if let reason = iCloudAlertReason {
                            slimAlertBanner(
                                icon: "exclamationmark.icloud.fill",
                                title: lang.isArabicEffective ? "iCloud غير متاح" : "iCloud unavailable",
                                detail: reason
                            )
                        } else if monitorAlertActive {
                            slimAlertBanner(
                                icon: "bolt.slash.fill",
                                title: lang.isArabicEffective ? "الجدولة غير مفعّلة" : "Scheduling not active",
                                detail: lang.isArabicEffective
                                    ? "نظام الجدولة لم يستجب خلال آخر 24 ساعة. تواصل مع الدعم."
                                    : "Scheduling hasn't responded in 24h. Contact support."
                            )
                        }
                    }

                    // Inbound partner requests — one card per pending request,
                    // each with Approve / Deny actions. Cards disappear the
                    // moment the user decides (CloudKitPartnerStore updates
                    // pendingPartnerRequests via fetchPendingRequestsForMe).
                    if !partnerStore.pendingPartnerRequests.isEmpty {
                        VStack(spacing: NNSpacing.xs) {
                            ForEach(partnerStore.pendingPartnerRequests) { request in
                                partnerRequestBanner(request)
                            }
                        }
                    }

                    // Permissions banner — kept inline because it has expand/collapse UX
                    if !(hasScreenTimePermission && hasNotificationPermission) {
                        let requiredCount = (hasScreenTimePermission ? 0 : 1) + (hasNotificationPermission ? 0 : 1)
                        VStack(spacing: 0) {
                            HStack(spacing: NNSpacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppColors.warningFg)
                                    .font(.callout)
                                Text(lang.isArabicEffective
                                     ? "أذونات ناقصة (\(requiredCount))"
                                     : "Missing permissions (\(requiredCount))")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                Text(lang.isArabicEffective
                                     ? (permissionsExpanded ? "إخفاء" : "إصلاح")
                                     : (permissionsExpanded ? "Hide" : "Fix"))
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(AppColors.accent)
                                Image(systemName: permissionsExpanded ? "chevron.up" : "chevron.down")
                                    .foregroundColor(AppColors.accent)
                                    .font(.caption.weight(.semibold))
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { permissionsExpanded.toggle() } }
                            .padding(.horizontal, NNSpacing.md)
                            .frame(minHeight: 44) // HIG minimum touch target
                            .padding(.vertical, NNSpacing.xs)
                            .background(AppColors.warningBg)
                            .overlay(
                                RoundedRectangle(cornerRadius: permissionsExpanded ? 0 : 12)
                                    .stroke(AppColors.warningFg.opacity(0.3), lineWidth: NNBorder.hairline)
                            )
                            if permissionsExpanded {
                                VStack(spacing: 0) {
                                    // Screen Time row
                                    HStack(spacing: NNSpacing.sm) {
                                        Image(systemName: "lock.iphone").foregroundColor(AppColors.accent)
                                        Text(lang.isArabicEffective ? "Screen Time" : "Screen Time")
                                            .font(.subheadline)
                                            .foregroundColor(AppColors.textPrimary)
                                        Spacer()
                                        if !hasScreenTimePermission {
                                            Button(action: { requestScreenTimeAuth() }) {
                                                Text(lang.isArabicEffective ? "منح" : "Grant")
                                                    .font(.footnote.weight(.semibold))
                                                    .padding(.horizontal, NNSpacing.sm)
                                                    .frame(minHeight: 44) // HIG minimum touch target
                                                    .background(AppColors.accent)
                                                    .foregroundColor(.white)
                                                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.chip))
                                            }
                                            .buttonStyle(.plain)
                                        } else {
                                            HStack(spacing: NNSpacing.xxs) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(AppColors.successGreen)
                                                    .font(.caption)
                                                Text(lang.isArabicEffective ? "مُفعَّل" : "Granted")
                                                    .font(.footnote)
                                                    .foregroundColor(AppColors.textSecondary)
                                            }
                                        }
                                    }
                                    .padding(NNSpacing.md)
                                    Divider().background(AppColors.uiBorder.opacity(0.35))
                                    // Notifications row
                                    HStack(spacing: NNSpacing.sm) {
                                        Image(systemName: "bell").foregroundColor(AppColors.accent)
                                        Text(lang.isArabicEffective ? "الإشعارات" : "Notifications")
                                            .font(.subheadline)
                                            .foregroundColor(AppColors.textPrimary)
                                        Spacer()
                                        if !hasNotificationPermission {
                                            Button(action: { requestNotificationsAuth() }) {
                                                Text(lang.isArabicEffective ? "تفعيل" : "Enable")
                                                    .font(.footnote.weight(.semibold))
                                                    .padding(.horizontal, NNSpacing.sm)
                                                    .frame(minHeight: 44) // HIG minimum touch target
                                                    .background(AppColors.accent)
                                                    .foregroundColor(.white)
                                                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.chip))
                                            }
                                            .buttonStyle(.plain)
                                        } else {
                                            HStack(spacing: NNSpacing.xxs) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(AppColors.successGreen)
                                                    .font(.caption)
                                                Text(lang.isArabicEffective ? "مُفعَّل" : "Enabled")
                                                    .font(.footnote)
                                                    .foregroundColor(AppColors.textSecondary)
                                            }
                                        }
                                    }
                                    .padding(NNSpacing.md)
                                }
                                .background(AppColors.uiSurface)
                                .overlay(
                                    // Side+bottom border only (top edge meets the banner).
                                    Rectangle().stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
                                )
                            }
                        }
                        // Outer container: slim banner radius when collapsed,
                        // full-card radius when expanded. The outer clip rounds the
                        // whole stack so banner + detail share a single outer shape.
                        .clipShape(RoundedRectangle(cornerRadius: permissionsExpanded ? 20 : 12))
                    }

                    // Primary CTA — the single dominant action
                    CreateBlocklistCard(lang: lang, useGradientCTA: false) {
                        showingCreate = true
                    }
                    .sheet(isPresented: $showingCreate) {
                        CreateListSheet().environmentObject(lang)
                    }

                    // ── LISTS ──
                    if lists.isEmpty {
                        EmptyState(
                            icon: "square.and.pencil",
                            title: lang.isArabicEffective ? "لا توجد قوائم بعد" : "No lists yet",
                            message: lang.isArabicEffective
                                ? "ابدأ رحلتك بإنشاء أوّل قائمة حجب."
                                : "Tap Create List above to start your focus journey.",
                            actionTitle: lang.isArabicEffective ? "أنشئ قائمتك الأولى" : "Create your first list",
                            action: { showingCreate = true }
                        )
                        .padding(.top, NNSpacing.xs)
                    } else {
                        // Active section — section header + flat rows in a single card
                        if !activeLists.isEmpty {
                            VStack(alignment: .leading, spacing: NNSpacing.xs) {
                                Text(lang.isArabicEffective ? "النشطة الآن" : "Active now")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(AppColors.textSecondary)
                                    .padding(.horizontal, NNSpacing.xxs)
                                VStack(spacing: 0) {
                                    ForEach(activeLists) { item in
                                        listRow(item: item, isActive: true)
                                        if item.id != activeLists.last?.id {
                                            Divider()
                                                .background(AppColors.uiBorder.opacity(0.5))
                                                .padding(.horizontal, NNSpacing.md)
                                        }
                                    }
                                }
                                .background(AppColors.uiSurface)
                                .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
                                .overlay(RoundedRectangle(cornerRadius: NNRadius.card)
                                    .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline))
                            }
                        }

                        // Other lists — collapsed by default to keep the home calm
                        if !nonActiveLists.isEmpty {
                            DisclosureGroup(isExpanded: $showOtherLists) {
                                VStack(spacing: 0) {
                                    ForEach(nonActiveLists) { item in
                                        listRow(item: item, isActive: false)
                                        if item.id != nonActiveLists.last?.id {
                                            Divider()
                                                .background(AppColors.uiBorder.opacity(0.5))
                                                .padding(.horizontal, NNSpacing.md)
                                        }
                                    }
                                }
                                .background(AppColors.uiSurface)
                                .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
                                .overlay(RoundedRectangle(cornerRadius: NNRadius.card)
                                    .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline))
                                .padding(.top, NNSpacing.xs)
                            } label: {
                                Text(lang.isArabicEffective
                                     ? "عرض \(nonActiveLists.count) قائمة غير نشطة"
                                     : "Show \(nonActiveLists.count) inactive lists")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .tint(AppColors.textSecondary)
                            .padding(.horizontal, NNSpacing.xxs)
                        }
                    }

                    // Subtle footer stats — only when there's real data to show
                    if !activeLists.isEmpty {
                        HStack(spacing: NNSpacing.sm) {
                            Spacer()
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.caption2)
                                .foregroundColor(AppColors.textSecondary)
                            Text(lang.isArabicEffective
                                 ? "\(activeLists.count) قائمة نشطة الآن"
                                 : "\(activeLists.count) active right now")
                                .font(.footnote)
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                        }
                        .padding(.top, NNSpacing.md)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, NNSpacing.xl)
                .padding(.top, NNSpacing.sm)
                .padding(.bottom, NNSpacing.xxl - 4)
            }
            .background(AppColors.uiBackground)
            .navigationTitle(homeNavTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Share moved from inline button to toolbar — Apple HIG pattern
                // for secondary actions on a content screen. Only renders when
                // there's something worth sharing (at least one list exists).
                if !lists.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: shareMessage) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(AppColors.accent)
                        }
                        .accessibilityLabel(lang.isArabicEffective ? "مشاركة تقدّمي" : "Share progress")
                    }
                }
            }
            .alert(isPresented: $showDeleteConfirm) {
                Alert(
                    title: Text(lang.isArabicEffective ? "حذف هذه القائمة؟" : "Delete this list?"),
                    message: Text(lang.isArabicEffective ? "سيتوقّف الحجب فوراً، ولا يمكن استعادة الإعدادات بعد الحذف." : "The block will stop immediately, and the settings can't be restored after deletion."),
                    primaryButton: .destructive(Text(lang.isArabicEffective ? "احذف القائمة" : "Delete list")) {
                        if let toDelete = listToDelete {
                            deleteList(toDelete)
                        }
                        listToDelete = nil
                    },
                    secondaryButton: .cancel(Text(lang.isArabicEffective ? "احتفظ بها" : "Keep it")) {
                        listToDelete = nil
                    }
                )
            }
            .alert(
                lang.isArabicEffective ? "تعذّر الحفظ" : "Save failed",
                isPresented: Binding(get: { saveErrorMessage != nil }, set: { if !$0 { saveErrorMessage = nil } })
            ) {
                Button(lang.isArabicEffective ? "حسناً" : "OK", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "")
            }
            .sheet(item: $gatekeeperSheetList) { list in
                NoNetGatekeeperSheet(
                    listID: list.id,
                    listName: list.name,
                    action: .delete,
                    onReasonAccepted: { performHardDelete(list) },
                    onWaitStarted: {
                        // Force a re-read so the new countdown badge shows up
                        // on the list card.
                        refreshTick &+= 1
                    }
                )
                .environmentObject(lang)
            }
            .sheet(item: $partnerRequestSheet) { ctx in
                RequestActionSheet(
                    listID: ctx.id,
                    listName: ctx.listName,
                    action: ctx.action,
                    partnership: ctx.partnership,
                    onRequestSent: {
                        Task {
                            await partnerStore.fetchMyOutgoingRequests()
                        }
                    }
                )
                .environmentObject(lang)
            }
            .onAppear {
                checkPermissions()
            }
        }
    }

    // ─── View helpers (extracted to keep the body readable) ───

    /// Empty nav title — the hero below the title carries the brand. Keeping
    /// the nav bar empty avoids duplicating "حرر نفسك" / "NoNet" between the
    /// title bar and the hero card.
    private var homeNavTitle: String { "" }

    /// Top hero: large centered logo + tagline. Replaces the earlier
    /// horizontal welcomeCard (50×50 logo with greeting beside it) after
    /// user feedback — they wanted the icon big with "حرر نفسك" underneath
    /// in a clear vertical stack. Sized at ~150pt to stay well under the
    /// original v1.2.0 hero (204pt) while still feeling prominent.
    ///
    /// Layout:
    ///   ┌─ 96×96 infoBg circle ─┐
    ///   │      72×72 logo       │
    ///   └───────────────────────┘
    ///         حرر نفسك           ← .title.weight(.semibold)
    ///       أهلاً، [Name]        ← optional, only when name is set
    @ViewBuilder
    private func welcomeCard() -> some View {
        // Compact hero — 72pt circle with 52pt logo. The previous 96pt circle
        // dominated the iPhone SE viewport and pushed the primary CTA below
        // the fold. Smaller hero leaves more room for the action without
        // losing brand presence.
        VStack(spacing: NNSpacing.xs) {
            ZStack {
                Circle()
                    .fill(AppColors.infoBg)
                    .frame(width: 72, height: 72)
                Image("nonet_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .accessibilityHidden(true)
            }

            let trimmedName = obName.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty {
                Text(AppStrings.heroTitle(lang))
                    .font(.title2.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
            } else {
                // Combine hero + greeting in one line to save vertical space.
                Text(lang.isArabicEffective ? "أهلاً، \(trimmedName)" : "Welcome, \(trimmedName)")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, NNSpacing.xs)
        .padding(.bottom, NNSpacing.xs)
    }

    /// Slim 44pt warning banner used by the consolidated alerts strip. Matches
    /// the existing Permission-banner visual language (warningBg + warningFg
    /// border, single row) so all home-screen alerts share one shape.
    @ViewBuilder
    private func slimAlertBanner(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: NNSpacing.sm) {
            Image(systemName: icon)
                .foregroundColor(AppColors.alertRed)
                .font(.callout)
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text(detail)
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, NNSpacing.md)
        .padding(.vertical, NNSpacing.sm)
        .background(AppColors.alertRed.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: NNRadius.control)
                .stroke(AppColors.alertRed.opacity(0.3), lineWidth: NNBorder.hairline)
        )
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
    }

    /// Banner for a single inbound partner request. Renders the action type +
    /// list name + reason + sender, with Approve / Deny inline. The buttons
    /// kick off CloudKit updates and the banner disappears once
    /// pendingPartnerRequests no longer contains this request.
    @ViewBuilder
    private func partnerRequestBanner(_ request: BreakAttempt) -> some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.xs) {
            HStack(alignment: .top, spacing: NNSpacing.xs) {
                Image(systemName: "envelope.open.badge.clock")
                    .foregroundColor(AppColors.accent)
                    .font(.callout)
                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 2) {
                    Text(requestBannerTitle(request))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                    if let reason = request.reason, !reason.isEmpty {
                        Text(lang.isArabicEffective ? "السبب: \(reason)" : "Reason: \(reason)")
                            .font(.footnote)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: NNSpacing.sm) {
                Button(action: { decide(request: request, approve: false) }) {
                    Text(lang.isArabicEffective ? "أرفض" : "Deny")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color.clear)
                        .foregroundColor(AppColors.alertRed)
                        .overlay(
                            RoundedRectangle(cornerRadius: NNRadius.control)
                                .stroke(AppColors.alertRed.opacity(0.4), lineWidth: NNBorder.input)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                }
                .buttonStyle(.plain)

                Button(action: { decide(request: request, approve: true) }) {
                    Text(lang.isArabicEffective ? "أوافق" : "Approve")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(AppColors.accent)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, NNSpacing.md)
        .padding(.vertical, NNSpacing.sm)
        .background(AppColors.infoBg)
        .overlay(
            RoundedRectangle(cornerRadius: NNRadius.control)
                .stroke(AppColors.accent.opacity(0.3), lineWidth: NNBorder.hairline)
        )
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
    }

    /// Build the banner title for a BreakAttempt — "Khalid wants to delete
    /// 'Focus Time'." Falls back to a generic owner label when the request
    /// doesn't have a Partnership cached (e.g. fresh fetch hasn't completed).
    private func requestBannerTitle(_ request: BreakAttempt) -> String {
        let owner: String = {
            if let partnership = partnerStore.partnerships.first(where: { $0.id == request.partnershipID }) {
                return partnership.ownerDisplayName
            }
            return lang.isArabicEffective ? "أحد شركائك" : "A partner"
        }()
        let listName = request.listName
        if lang.isArabicEffective {
            switch request.type {
            case .delete:  return "\(owner) يطلب حذف «\(listName)»"
            case .disable: return "\(owner) يطلب إيقاف «\(listName)»"
            case .modify:  return "\(owner) يطلب تعديل «\(listName)»"
            case .uninstallAttempt: return "\(owner) قد حاول إلغاء تثبيت التطبيق"
            }
        } else {
            switch request.type {
            case .delete:  return "\(owner) wants to delete \"\(listName)\""
            case .disable: return "\(owner) wants to pause \"\(listName)\""
            case .modify:  return "\(owner) wants to modify \"\(listName)\""
            case .uninstallAttempt: return "\(owner) attempted to uninstall the app"
            }
        }
    }

    /// Approve or deny an inbound partner request. The CloudKit update happens
    /// inside the store; we just wait for it to refresh
    /// pendingPartnerRequests so the banner disappears.
    private func decide(request: BreakAttempt, approve: Bool) {
        Task {
            if approve {
                await partnerStore.approveRequest(request.id)
            } else {
                await partnerStore.denyRequest(request.id)
            }
        }
    }

    /// Single list row — kept in one helper so Active and Other lists share
    /// the exact same row visual. The play/pause toggle is hidden for Hard
    /// Mode lists (you can't pause them by design) and the row swaps the
    /// toggle side for RTL.
    @ViewBuilder
    private func listRow(item: ListEntity, isActive: Bool) -> some View {
        HStack(spacing: NNSpacing.sm) {
            if !lang.isArabicEffective && item.protection != "hard" {
                toggleButton(for: item)
            }
            NavigationLink(destination: ListDetailView(list: item)) {
                ListRowCore(
                    item: item,
                    isActive: isActive,
                    pendingPartnerLabel: pendingPartnerLabel(for: item)
                )
            }
            if lang.isArabicEffective && item.protection != "hard" {
                toggleButton(for: item)
            }
        }
        .padding(.horizontal, NNSpacing.md)
        .padding(.vertical, NNSpacing.xs)
    }

    /// Returns the localized "awaiting partner" badge label when there's a
    /// pending outgoing approval request for this list, otherwise nil.
    /// Drives the small chip rendered inside ListRowCore.
    private func pendingPartnerLabel(for item: ListEntity) -> String? {
        guard partnerStore.myOutgoingRequests.contains(where: { $0.listID == item.id && $0.status == .pending }) else {
            return nil
        }
        return lang.isArabicEffective ? "بانتظار الشريك" : "Awaiting partner"
    }

    @ViewBuilder
    private func toggleButton(for item: ListEntity) -> some View {
        let isActive = isActiveNow(item)
        Button(action: { toggleManual(for: item) }) {
            // 44×44 hit area, 36pt visual chip inside — meets HIG minimum
            // without making the chip itself look chunky next to row text.
            ZStack {
                RoundedRectangle(cornerRadius: NNRadius.chip)
                    .fill(AppColors.infoBg)
                    .frame(width: 36, height: 36)
                Image(systemName: isActive ? "pause.fill" : "play.fill")
                    .font(.nnSmallButton)
                    .foregroundColor(AppColors.accent)
            }
            .frame(width: NNHitTarget.minimum, height: NNHitTarget.minimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isActive
                            ? (lang.isArabicEffective ? "إيقاف \(item.name)" : "Pause \(item.name)")
                            : (lang.isArabicEffective ? "تشغيل \(item.name)" : "Resume \(item.name)"))
    }

    private func checkPermissions() {
        permissions.bootstrap()
    }

    private func isActiveNow(_ l: ListEntity) -> Bool {
        // Manual override takes precedence (UserDefaults-backed)
        if ManualStateStore.isActive(for: l.id) { return true }
        // Forever blocks are always active until the list is purged.
        if l.blockType == "forever" { return true }
        // Time-Limit is always "active" (monitoring runs daily); the shield itself only
        // kicks in once the user crosses the daily threshold.
        if l.blockType == "timeLimit" { return true }
        let now = Date()
        if l.blockType == "now" {
            let end = l.createdAt.addingTimeInterval(TimeInterval(l.durationSeconds))
            return now < end
        }
        if l.blockType == "scheduled" {
            guard let data = l.scheduleSlots else { return false }
            let decoded = SchedulePersistence.decode(data)
            if decoded.isEmpty { return false }
            let slots = decoded.map { ScheduleSlot(id: $0.id, day: $0.day, fromMinutes: $0.fromMinutes, toMinutes: $0.toMinutes) }
            let cal = Calendar.current
            let comps = cal.dateComponents([.weekday, .hour, .minute], from: now)
            guard let weekday = comps.weekday, let h = comps.hour, let m = comps.minute else { return false }
            let dayIndex = (weekday - 1) % 7 // 0..6, Sunday=0
            let minutesNow = h * 60 + m
            return slots.contains { $0.day == dayIndex && minutesNow >= $0.fromMinutes && minutesNow < $0.toMinutes }
        }
        return false
    }
}

private extension HomeView {
    func toggleManual(for list: ListEntity) {
        // Hard Mode normally blocks the toggle — that's the whole point. But
        // once an emergency-unlock request has matured (7 days elapsed), the
        // user has *earned* the right to release; let the toggle deactivate
        // the list in that one specific case. Without this, the matured-unlock
        // banner would say "use the toggle" but the toggle would silently
        // do nothing (the original P0).
        if list.protection == "hard" && !EmergencyUnlockStore.isGranted(for: list.id) {
            return
        }
        let wasActive = ManualStateStore.isActive(for: list.id)
        ManualStateStore.toggle(for: list.id)
        if wasActive {
            BlockingEngine.shared.deactivate(list: list)
            // Consume the matured unlock so it isn't reusable indefinitely;
            // a future re-block requires a fresh 7-day request.
            if list.protection == "hard" {
                EmergencyUnlockStore.clear(for: list.id)
            }
        } else {
            BlockingEngine.shared.activate(list: list)
        }
        refreshTick += 1 // Force UI refresh
    }
}


private struct CreateBlocklistCard: View {
    @ObservedObject var lang: LanguageManager
    let useGradientCTA: Bool
    var onCreate: () -> Void

    var body: some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm) {
            HStack {
                Text(AppStrings.createBlocklistTitle(lang))
                    .font(.nnCardTitle)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Image(systemName: "plus")
                    .foregroundColor(AppColors.accent)
                    .frame(width: 28, height: 28)
                    .background(AppColors.infoBg)
                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.chip))
                    .accessibilityHidden(true) // decorative — the Button below carries the action label
            }
            Button(action: onCreate) {
                Text(lang.isArabicEffective ? "ابدأ" : "Get Started")
                    .font(.nnCardTitle)
                    .frame(maxWidth: .infinity)
                    .frame(height: NNHitTarget.minimum)
                    .background(AppColors.accent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
            }
        }
        .padding(NNSpacing.md)
        .background(AppColors.uiSurface)
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.container))
        .overlay(
            RoundedRectangle(cornerRadius: NNRadius.container)
                .stroke(AppColors.uiBorder, lineWidth: NNBorder.strong)
        )
    }
}

private struct ListRowCore: View {
    let item: ListEntity
    let isActive: Bool
    /// When non-nil, a small chip is shown next to the protection badge to
    /// signal there's a pending recovery-partner approval request for this
    /// list. The caller computes the localized label so this view doesn't
    /// need a LanguageManager dependency.
    var pendingPartnerLabel: String? = nil
    @Environment(\.layoutDirection) private var layoutDirection

    /// Localized label for the list's blockType — surfaces the difference
    /// between immediate / scheduled / time-limit / forever lists at a glance
    /// rather than burying it in the detail view. nil for `now` (default
    /// case), which doesn't need its own chip.
    private var typeLabel: (icon: String, text: String)? {
        let isRTL = layoutDirection == .rightToLeft
        switch item.blockType {
        case "scheduled":
            return ("calendar", isRTL ? "مجدول" : "Scheduled")
        case "timeLimit":
            return ("clock.badge", isRTL ? "حد يومي" : "Daily limit")
        case "forever":
            return ("infinity", isRTL ? "للأبد" : "Forever")
        default:
            return nil
        }
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: layoutDirection == .rightToLeft ? .trailing : .leading, spacing: NNSpacing.xs - 2) {
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                HStack(spacing: NNSpacing.xs) {
                    ProtectionBadge(isHard: item.protection == "hard", isRTL: layoutDirection == .rightToLeft)
                    if let type = typeLabel {
                        chip(icon: type.icon, text: type.text, color: AppColors.textSecondary)
                    }
                    if let label = pendingPartnerLabel {
                        chip(icon: "hourglass", text: label, color: AppColors.accent)
                    }
                }
            }
            Spacer()
            if item.protection == "hard" && isActive {
                Text(layoutDirection == .rightToLeft ? "مفعّلة الآن" : "Active")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(AppColors.infoFg)
                    .padding(.vertical, NNSpacing.xs - 2)
                    .padding(.horizontal, NNSpacing.sm - 2)
                    .background(AppColors.infoBg)
                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.chip))
            }
        }
        .padding(.vertical, NNSpacing.md)
    }

    /// Pill-shape chip used for blockType + pending-partner badges. Background
    /// uses the color's 0.08 opacity so chips stay quiet against the row.
    @ViewBuilder
    private func chip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: NNSpacing.xxs) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundColor(color)
        .padding(.vertical, NNSpacing.xxs - 1)
        .padding(.horizontal, NNSpacing.xs)
        .background(color.opacity(0.10))
        .clipShape(Capsule())
    }
}


extension ListEntity: Identifiable {}

#Preview {
    HomeView().environmentObject(LanguageManager.shared)
}

// MARK: - HomeView Action Helpers

private extension HomeView {
    func requestScreenTimeAuth() {
        Task { await permissions.requestScreenTime() }
    }

    func requestNotificationsAuth() {
        Task { await permissions.requestNotifications() }
    }
}
