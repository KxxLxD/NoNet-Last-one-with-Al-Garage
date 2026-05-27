//
//  ListDetailView.swift
//  blocking app
//
//  Detail screen for a single ListEntity — extracted from HomeView.swift so
//  the home surface stays focused on the list-of-lists. ListDetailView is
//  presented via NavigationLink from HomeView's listRow.
//
//  Owns the Hard-Mode action ladder (delete / disable / modify), emergency
//  unlock countdown UI, partner section, and BreakAttempt history. Also hosts
//  PartnerInviteDisclosureSheet, which is only shown from inside this view.
//

import SwiftUI
import CoreData
import CloudKit


struct ListDetailView: View {
    let list: ListEntity
    @EnvironmentObject var lang: LanguageManager
    @ObservedObject private var partnerStore = CloudKitPartnerStore.shared
    @State private var showEditSheet = false
    @State private var showPartnerInvite = false
    /// User-facing error surfaced via .alert at the bottom of the body. Set
    /// from beginAction when a Hard+Partner list has no accepted partnership.
    @State private var partnerError: String?
    // D14 — Share URL disclosure. The CKShare URL is permanent and accepts the
    // first iCloud user who taps it, with no PIN or revocation per-recipient.
    // We surface that risk before generating the share so the user understands
    // what they're about to put in a chat.
    @State private var showInviteDisclosure = false
    @State private var disclosureAccepted = false
    // D18 — Emergency unlock request UI state. The store is the source of truth;
    // this nonce just forces the view to re-render after a request / cancel,
    // since EmergencyUnlockStore reads through UserDefaults (not @Published).
    @State private var emergencyUnlockNonce = UUID()
    @State private var showRequestUnlockConfirm = false
    @State private var showCancelUnlockConfirm = false
    @State private var breakAttempts: [BreakAttempt] = []
    @State private var isLoadingAttempts = false
    // Hard-Mode delete/disable routing through the gatekeeper of choice.
    // Non-Hard lists use the inline "Delete" button below and never hit
    // these flows — only Hard Mode goes through the gatekeeper.
    @State private var gatekeeperSheetAction: GatekeeperAction?
    @State private var partnerRequestSheetAction: GatekeeperAction?
    @Environment(\.dismiss) private var dismiss

    private struct Slot: Codable { let id: UUID; let day: Int; let fromMinutes: Int; let toMinutes: Int }
    private let stableListId: UUID

    init(list: ListEntity) {
        self.list = list
        self.stableListId = list.id
    }

    var body: some View {
        // Body extracted to small `@ViewBuilder` properties below. SwiftUI's
        // type checker times out on long view bodies (>200 lines) and the
        // resulting "Cannot find X in scope" errors are misleading — splitting
        // out the cards keeps each branch small enough for fast inference.
        ScrollView {
            VStack(alignment: .leading, spacing: NNSpacing.md) {
                if list.protection == "hard" { hardModeBanner }
                if let pending = outgoingPendingRequest() {
                    pendingPartnerRequestBanner(request: pending)
                }
                if list.protection == "hard" && list.gatekeeperType == "nonet" {
                    emergencyUnlockCard()
                }
                headerSection
                overviewCard
                timingCard
                if list.protection == "hard" {
                    partnerSection()
                }
                if list.protection == "hard" && outgoingPendingRequest() == nil {
                    hardModeActionsRow()
                }
                if list.protection != "hard" {
                    nonHardActionsRow
                }
                Spacer(minLength: 0)
            }
            .padding(NNSpacing.xl)
            .background(AppColors.uiBackground)
        }
        .background(AppColors.uiBackground)
        // Stack context: use the list's actual name so the nav bar (and the
        // Back chevron's referenced screen) tell the user where they are.
        // Falls back to a generic title only if the entity has somehow been
        // deleted out from under us.
        .navigationTitle(list.isDeleted ? (lang.isArabicEffective ? "التفاصيل" : "Details") : list.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditSheet) {
            CreateListSheet().environmentObject(lang)
        }
        .onChange(of: showEditSheet) { _ in }
        .onDisappear { }
    }

    // MARK: - Body section views
    //
    // Extracted from the main body to keep each branch under the SwiftUI
    // type-check threshold. Order here mirrors render order.

    @ViewBuilder
    private var hardModeBanner: some View {
        HStack(alignment: .top, spacing: NNSpacing.sm) {
            Image(systemName: "lock.fill").foregroundColor(AppColors.alertRed)
            VStack(alignment: .leading, spacing: NNSpacing.xxs) {
                Text(lang.isArabicEffective ? "الوضع الصارم مفعل" : "Hard Mode Enabled")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.alertRed)
                Text(lang.isArabicEffective ? "لا يمكن التعديل أو الحذف أثناء تفعيل الوضع الصارم." : "Editing and deleting are disabled while Hard Mode is active.")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(NNSpacing.sm)
        .background(AppColors.alertRed.opacity(0.10))
        .overlay(RoundedRectangle(cornerRadius: NNRadius.control).stroke(AppColors.alertRed, lineWidth: NNBorder.hairline))
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: NNSpacing.xs) {
            HStack(spacing: NNSpacing.sm) {
                Text(list.name)
                    .font(.nnSectionTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                Spacer()
                ProtectionBadge(isHard: list.protection == "hard", isRTL: lang.isArabicEffective)
            }
            if isActiveNowDetail() {
                Text(lang.isArabicEffective ? "مفعّلة الآن" : "Active")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(AppColors.infoFg)
                    .padding(.vertical, NNSpacing.xs - 2)
                    .padding(.horizontal, NNSpacing.sm - 2)
                    .background(AppColors.infoBg)
                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.chip))
            } else {
                Text(lang.isArabicEffective ? "غير نشطة" : "Inactive")
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    /// Overview card — "Status" intentionally omitted; the chip below the
    /// header already shows active/inactive so repeating it here was visual
    /// debt with no info value.
    @ViewBuilder
    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: NNSpacing.sm) {
            Text(lang.isArabicEffective ? "نظرة عامة" : "Overview")
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.textSecondary)
            VStack(alignment: .leading, spacing: NNSpacing.sm - 2) {
                HStack {
                    Text(lang.isArabicEffective ? "النوع" : "Type").foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text(localizedBlockTypeLabel(list.blockType)).foregroundColor(AppColors.textPrimary)
                }
                HStack {
                    Text(lang.isArabicEffective ? "الحماية" : "Protection").foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text(localizedProtectionLabel(list.protection)).foregroundColor(AppColors.textPrimary)
                }
                if let cnt = list.items?.count {
                    HStack {
                        Text(lang.isArabicEffective ? "العناصر" : "Items").foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text("\(cnt)").foregroundColor(AppColors.textPrimary)
                    }
                }
            }
            .padding(NNSpacing.md)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
            .overlay(RoundedRectangle(cornerRadius: NNRadius.control).stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline))
            // Items preview chips — answers "what's actually being blocked
            // here" without forcing an Edit round-trip.
            itemsPreview()
        }
    }

    @ViewBuilder
    private var timingCard: some View {
        VStack(alignment: .leading, spacing: NNSpacing.sm) {
            Text(lang.isArabicEffective ? "الوقت" : "Timing")
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.textSecondary)
            VStack(alignment: .leading, spacing: NNSpacing.sm - 2) {
                if list.blockType == "now" {
                    nowRow
                }
                if list.blockType == "forever" {
                    foreverRow
                }
                if list.blockType == "timeLimit" {
                    timeLimitRow
                }
                if let summary = scheduleSummaryText() {
                    HStack {
                        Text(lang.isArabicEffective ? "الجدولة" : "Schedule").foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text(summary).foregroundColor(AppColors.textPrimary)
                    }
                }
                if let b = BreaksStore.load(for: stableListId) {
                    HStack {
                        Text(lang.isArabicEffective ? "الاستراحات" : "Breaks").foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text(lang.isArabicEffective ? "\(b.count) × \(b.duration) دقيقة" : "\(b.count) × \(b.duration)m")
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
            .padding(NNSpacing.md)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
            .overlay(RoundedRectangle(cornerRadius: NNRadius.control).stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline))
        }
    }

    @ViewBuilder
    private var nowRow: some View {
        HStack {
            Text(lang.isArabicEffective ? "المدة" : "Duration").foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(localizedMinutesLabel(Int(list.durationSeconds) / BlockingConstants.secondsPerMinute))
                .foregroundColor(AppColors.textPrimary)
        }
        // Live countdown for active `now` blocks. Updates every 30s. Shows
        // nothing when expired (the list simply reads as Inactive everywhere
        // else).
        if let remaining = remainingMinutesForNowBlock() {
            TimelineView(.periodic(from: .now, by: 30)) { _ in
                HStack {
                    Text(lang.isArabicEffective ? "متبقّي" : "Remaining").foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text(localizedMinutesLabel(remaining))
                        .foregroundColor(AppColors.accent)
                        .monospacedDigit()
                }
            }
        }
    }

    @ViewBuilder
    private var foreverRow: some View {
        HStack {
            Text(lang.isArabicEffective ? "المدة" : "Duration").foregroundColor(AppColors.textSecondary)
            Spacer()
            HStack(spacing: NNSpacing.xxs) {
                Image(systemName: "infinity")
                Text(lang.isArabicEffective ? "دائم" : "Permanent")
            }
            .foregroundColor(AppColors.alertRed)
        }
    }

    @ViewBuilder
    private var timeLimitRow: some View {
        HStack {
            Text(lang.isArabicEffective ? "الحد اليومي" : "Daily Limit").foregroundColor(AppColors.textSecondary)
            Spacer()
            let mins = Int(list.durationSeconds) / BlockingConstants.secondsPerMinute
            Text(lang.isArabicEffective ? "\(mins) دقيقة/يوم" : "\(mins) min/day")
                .foregroundColor(AppColors.textPrimary)
        }
    }

    @ViewBuilder
    private var nonHardActionsRow: some View {
        HStack(spacing: NNSpacing.sm) {
            Button(action: { showEditSheet = true }) {
                Text(lang.isArabicEffective ? "تحرير" : "Edit")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppColors.accent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
            }
            Button(role: .destructive, action: {
                if let ctx = list.managedObjectContext {
                    let id = list.id
                    BlockingEngine.shared.purge(listId: id)
                    ctx.delete(list)
                    _ = ctx.saveIfNeeded()
                    BreaksStore.clear(for: id)
                    ManualStateStore.clear(for: id)
                }
                dismiss()
            }) {
                Text(lang.isArabicEffective ? "حذف" : "Delete")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.clear)
                    .foregroundColor(AppColors.alertRed)
                    .overlay(RoundedRectangle(cornerRadius: NNRadius.control).stroke(AppColors.alertRed, lineWidth: NNBorder.strong))
            }
        }
    }

    /// D18 — Emergency unlock card for Forever + Hard lists.
    ///
    /// Three states surfaced to the user:
    /// * No pending request → explanation + "Request unlock (7-day delay)" button.
    /// * Pending request → live countdown + "Cancel request" button.
    /// * Matured request → green confirmation + "Release lock now" button.
    ///
    /// TimelineView re-renders every minute so the countdown ticks. The store
    /// itself is timestamp-based, so the same physical request remains valid
    /// across app launches without us having to schedule any timers.
    @ViewBuilder
    private func emergencyUnlockCard() -> some View {
        let id = stableListId
        let _ = emergencyUnlockNonce // re-evaluate when nonce changes

        VStack(alignment: .leading, spacing: NNSpacing.sm) {
            HStack(spacing: NNSpacing.xs) {
                Image(systemName: "key.fill")
                    .foregroundColor(AppColors.accent)
                Text(lang.isArabicEffective ? "فك الحجب الطارئ" : "Emergency Unlock")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.textSecondary)
            }

            if EmergencyUnlockStore.requestedAt(for: id) == nil {
                emergencyUnlockIdleView()
            } else {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    let granted = EmergencyUnlockStore.isGranted(for: id, now: context.date)
                    let remaining = EmergencyUnlockStore.remainingSeconds(for: id, now: context.date)
                    if granted {
                        emergencyUnlockMaturedView()
                    } else {
                        emergencyUnlockPendingView(remaining: remaining)
                    }
                }
            }
        }
        .padding(NNSpacing.md)
        .background(AppColors.uiSurface)
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
        .overlay(RoundedRectangle(cornerRadius: NNRadius.control).stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline))
        .alert(
            lang.isArabicEffective ? "طلب فك الحجب؟" : "Request unlock?",
            isPresented: $showRequestUnlockConfirm
        ) {
            Button(lang.isArabicEffective ? "اطلب الفك" : "Request unlock", role: .destructive) {
                EmergencyUnlockStore.requestUnlock(for: stableListId)
                emergencyUnlockNonce = UUID()
            }
            Button(lang.isArabicEffective ? "إلغاء" : "Cancel", role: .cancel) {}
        } message: {
            Text(lang.isArabicEffective
                 ? "سيُرفع الحجب تلقائياً بعد ٧ أيام من الآن. تقدر تلغي الطلب في أي وقت قبل ذلك."
                 : "The block will release automatically 7 days from now. You can cancel the request anytime before then.")
        }
        .alert(
            lang.isArabicEffective ? "إلغاء الطلب؟" : "Cancel request?",
            isPresented: $showCancelUnlockConfirm
        ) {
            Button(lang.isArabicEffective ? "نعم، أبقِ الحجب" : "Yes, keep blocked", role: .destructive) {
                EmergencyUnlockStore.clear(for: stableListId)
                emergencyUnlockNonce = UUID()
            }
            Button(lang.isArabicEffective ? "إلغاء" : "Cancel", role: .cancel) {}
        } message: {
            Text(lang.isArabicEffective
                 ? "سيبقى الحجب نشطاً ولن يُفك حتى تطلب من جديد."
                 : "The block stays active and will not release until you request again.")
        }
    }

    /// Pending outgoing approval request scoped to this list. Used by
    /// pendingPartnerRequestBanner to decide whether to render. Returns nil
    /// when no request is in flight (the common case).
    private func outgoingPendingRequest() -> BreakAttempt? {
        partnerStore.myOutgoingRequests.first {
            $0.listID == stableListId && $0.status == .pending
        }
    }

    /// Side-by-side Delete + Disable buttons for Hard-Mode lists. Each routes
    /// through the configured gatekeeper (NoNet ⇒ NoNetGatekeeperSheet,
    /// Human ⇒ RequestActionSheet). The Disable button is hidden for Forever
    /// lists since "pause" doesn't apply — Forever runs until the list itself
    /// is deleted.
    @ViewBuilder
    private func hardModeActionsRow() -> some View {
        VStack(spacing: NNSpacing.sm) {
            Button(role: .destructive, action: { beginAction(.delete) }) {
                Text(lang.isArabicEffective ? "اطلب حذف القائمة" : "Request to delete list")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: NNHitTarget.minimum + 4)
                    .background(Color.clear)
                    .foregroundColor(AppColors.alertRed)
                    .overlay(
                        RoundedRectangle(cornerRadius: NNRadius.control)
                            .stroke(AppColors.alertRed, lineWidth: NNBorder.input)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
            }
            .buttonStyle(.plain)

            if list.blockType != "forever" {
                Button(action: { beginAction(.disable) }) {
                    Text(lang.isArabicEffective ? "اطلب إيقاف الحجب" : "Request to pause block")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: NNHitTarget.minimum + 4)
                        .background(Color.clear)
                        .foregroundColor(AppColors.textPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: NNRadius.control)
                                .stroke(AppColors.uiBorder, lineWidth: NNBorder.input)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Route a Hard-Mode action through the right gatekeeper sheet. Called by
    /// Delete and Disable buttons; the sheet itself runs the local execution
    /// once the gate is passed (NoNet path) or fires a CloudKit request and
    /// the auto-executor takes over (Partner path).
    private func beginAction(_ action: GatekeeperAction) {
        if list.gatekeeperType == "partner" {
            // Need an accepted partnership before a request can be sent.
            // Without one the user is stuck — surface an error instead of
            // silent no-op.
            guard partnerStore.partnership(for: list.id)?.status == .accepted else {
                partnerError = lang.isArabicEffective
                    ? "لم يقبل أي شريك الدعوة بعد. أرسل دعوة جديدة أو حوّل الحارس إلى NoNet."
                    : "No partner has accepted the invitation yet. Send a new invite or switch the gatekeeper to NoNet."
                return
            }
            partnerRequestSheetAction = action
        } else {
            gatekeeperSheetAction = action
        }
    }

    /// Performs the local side of a Hard-Mode action after the NoNet gate
    /// has been passed. For delete: purge + Core Data delete + dismiss the
    /// detail view (the entity is gone). For disable: deactivate the engine
    /// + clear manual state — list stays in Core Data.
    private func performLocalAction(_ action: GatekeeperAction) {
        switch action {
        case .delete:
            let id = stableListId
            BlockingEngine.shared.purge(listId: id)
            if let ctx = list.managedObjectContext {
                ctx.delete(list)
                _ = ctx.saveIfNeeded()
            }
            BreaksStore.clear(for: id)
            ManualStateStore.clear(for: id)
            EmergencyUnlockStore.clear(for: id)
            dismiss()
        case .disable:
            _ = BlockingEngine.shared.deactivate(list: list, force: true)
            ManualStateStore.clear(for: list.id)
        case .modify:
            // Not surfaced today; left as a no-op so the enum is exhaustive.
            break
        }
    }

    /// Card displayed at the top of ListDetailView while a recovery-partner
    /// approval request is outstanding. Lets the user back out before the
    /// partner decides.
    @ViewBuilder
    private func pendingPartnerRequestBanner(request: BreakAttempt) -> some View {
        let partnerName = partnerStore.partnerships
            .first(where: { $0.id == request.partnershipID })
            .flatMap { $0.partnerDisplayName }
            ?? (lang.isArabicEffective ? "شريكك" : "your partner")

        // Outgoing-request banner uses a warning palette (amber) so it
        // visually differs from incoming-request banners on HomeView
        // (which use the accent/info palette). Same shape, different tone =
        // "this is your action waiting" vs "this is your partner needing
        // your action."
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.xs) {
            HStack(spacing: NNSpacing.xs) {
                Image(systemName: "hourglass")
                    .foregroundColor(AppColors.warningFg)
                    .font(.callout)
                Text(lang.isArabicEffective
                     ? "بانتظار موافقة \(partnerName)"
                     : "Awaiting \(partnerName)'s approval")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                Spacer(minLength: 0)
            }
            if let reason = request.reason, !reason.isEmpty {
                Text(lang.isArabicEffective ? "السبب الذي أرسلته: \(reason)" : "Your reason: \(reason)")
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
            }
            Button(action: {
                Task {
                    await partnerStore.cancelMyRequest(request.id)
                }
            }) {
                Text(lang.isArabicEffective ? "إلغاء الطلب" : "Cancel request")
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
        }
        .padding(NNSpacing.md)
        .background(AppColors.warningBg)
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: NNRadius.card)
                .stroke(AppColors.warningFg.opacity(0.3), lineWidth: NNBorder.hairline)
        )
    }

    private func emergencyUnlockIdleView() -> some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm - 2) {
            Text(lang.isArabicEffective
                 ? "الحجب الدائم لا يمكن إيقافه فوراً. اطلب فك الحجب الآن وسيُرفع تلقائياً بعد ٧ أيام — وقت كافٍ ليمر الاندفاع، لكنك لست محبوساً للأبد."
                 : "Forever blocks can't be deactivated instantly. Request unlock now and the block will release automatically after 7 days — long enough for an impulse to pass, but not indefinitely locked.")
                .font(.footnote)
                .foregroundColor(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)

            Button(action: { showRequestUnlockConfirm = true }) {
                Text(lang.isArabicEffective ? "اطلب فك الحجب (تأخير ٧ أيام)" : "Request unlock (7-day delay)")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppColors.alertRed.opacity(0.10))
                    .foregroundColor(AppColors.alertRed)
                    .overlay(RoundedRectangle(cornerRadius: NNRadius.control).stroke(AppColors.alertRed.opacity(0.6), lineWidth: NNBorder.strong))
                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
            }
            .buttonStyle(.plain)
        }
    }

    private func emergencyUnlockPendingView(remaining: TimeInterval) -> some View {
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let remainingText: String
        if lang.isArabicEffective {
            remainingText = "متبقي \(hours) ساعة و \(minutes) دقيقة"
        } else {
            remainingText = "\(hours)h \(minutes)m remaining"
        }
        return VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm - 2) {
            HStack(spacing: NNSpacing.xs) {
                Image(systemName: "hourglass")
                    .foregroundColor(AppColors.accent)
                Text(remainingText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
            }
            Text(lang.isArabicEffective
                 ? "بعد انتهاء العداد، يمكنك إيقاف الحجب من هنا."
                 : "Once the timer ends, you can deactivate the block from here.")
                .font(.footnote)
                .foregroundColor(AppColors.textSecondary)

            Button(action: { showCancelUnlockConfirm = true }) {
                Text(lang.isArabicEffective ? "إلغاء الطلب" : "Cancel request")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundColor(AppColors.accent)
                    .overlay(RoundedRectangle(cornerRadius: NNRadius.control).stroke(AppColors.accent.opacity(0.6), lineWidth: NNBorder.strong))
                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
            }
            .buttonStyle(.plain)
        }
    }

    private func emergencyUnlockMaturedView() -> some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm - 2) {
            HStack(spacing: NNSpacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.successGreen)
                Text(lang.isArabicEffective ? "اكتمل فك الحجب" : "Unlock matured")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.successGreen)
            }
            Text(lang.isArabicEffective
                 ? "يمكنك الآن إيقاف الحجب من هذه القائمة عبر زر إيقاف الحالة في الشاشة الرئيسية."
                 : "You can now deactivate this block from the toggle on the home screen.")
                .font(.footnote)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    @ViewBuilder
    private func partnerSection() -> some View {
        VStack(alignment: .leading, spacing: NNSpacing.sm) {
            HStack(spacing: NNSpacing.xs) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(AppColors.accent)
                Text(lang.isArabicEffective ? "شريك التعافي" : "Recovery Partner")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: NNSpacing.sm - 2) {
                if let existing = partnerStore.partnership(for: stableListId) {
                    partnerActiveView(existing)
                } else if let reason = partnerStore.accountUnavailableReason(isArabic: lang.isArabicEffective) {
                    partnerRationaleText()
                    Text(reason)
                        .font(.footnote)
                        .foregroundColor(AppColors.alertRed)
                        .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
                } else {
                    partnerRationaleText()
                    partnerInviteButton()
                }
            }
            .padding(NNSpacing.md)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
            .overlay(RoundedRectangle(cornerRadius: NNRadius.control).stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline))
        }
        .sheet(isPresented: $showPartnerInvite) {
            PartnerInviteView(
                listID: stableListId,
                listName: list.name,
                onCompletion: {
                    showPartnerInvite = false
                    Task { await partnerStore.fetchPartnerships() }
                }
            )
            .environmentObject(lang)
        }
        .sheet(isPresented: $showInviteDisclosure) {
            PartnerInviteDisclosureSheet(
                isArabic: lang.isArabicEffective,
                accepted: $disclosureAccepted,
                onContinue: {
                    showInviteDisclosure = false
                    invitePartner()
                },
                onCancel: { showInviteDisclosure = false }
            )
            .environmentObject(lang)
        }
        .alert(
            lang.isArabicEffective ? "تعذّر إتمام العملية" : "Couldn't complete action",
            isPresented: Binding(get: { partnerError != nil }, set: { if !$0 { partnerError = nil } })
        ) {
            Button(lang.isArabicEffective ? "حسناً" : "OK", role: .cancel) { partnerError = nil }
        } message: {
            Text(partnerError ?? "")
        }
        .sheet(item: $gatekeeperSheetAction) { action in
            NoNetGatekeeperSheet(
                listID: stableListId,
                listName: list.name,
                action: action,
                onReasonAccepted: { performLocalAction(action) },
                onWaitStarted: {
                    // Refresh the unlock card so the new countdown appears.
                    emergencyUnlockNonce = UUID()
                }
            )
            .environmentObject(lang)
        }
        .sheet(item: $partnerRequestSheetAction) { action in
            if let partnership = partnerStore.partnership(for: stableListId) {
                RequestActionSheet(
                    listID: stableListId,
                    listName: list.name,
                    action: action,
                    partnership: partnership,
                    onRequestSent: {
                        Task { await partnerStore.fetchMyOutgoingRequests() }
                    }
                )
                .environmentObject(lang)
            }
        }
        .onAppear {
            Task {
                await partnerStore.fetchPartnerships()
                await partnerStore.fetchMyOutgoingRequests()
            }
        }
    }

    private func partnerRationaleText() -> some View {
        Text(lang.isArabicEffective
             ? "ادعُ شخصاً تثق به ليُبلَّغ عند محاولاتك كسر الحجب — حماية إضافية لوضع التعافي."
             : "Invite someone you trust to be notified of break attempts — extra accountability for recovery mode.")
            .font(.footnote)
            .foregroundColor(AppColors.textSecondary)
            .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
            .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
    }

    private func partnerInviteButton() -> some View {
        // Tap opens the disclosure sheet; PartnerInviteView itself runs the
        // async createPartnership now (PR 2 refactor), so this button no
        // longer needs an in-flight ProgressView.
        Button(action: {
            disclosureAccepted = false
            showInviteDisclosure = true
        }) {
            HStack {
                Image(systemName: "envelope.fill")
                Text(lang.isArabicEffective ? "دعوة شريك" : "Invite Partner")
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(AppColors.accent)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func partnerActiveView(_ partnership: Partnership) -> some View {
        // Owner sees the partner's display name (if accepted); partner sees the
        // owner's. `partnerUserID` is the recipient's iCloud userRecordID — so
        // we compare it against THIS device's own cached recordID to know which
        // perspective to show. (Before the fix, the placeholder "<self>" string
        // was never written anywhere, making the comparison a tautology that
        // always returned isOwnerView=true.)
        let isInviteeView = partnerStore.isInvitee(partnership)
        let displayName = isInviteeView
            ? partnership.ownerDisplayName
            : (partnership.partnerDisplayName ?? (lang.isArabicEffective ? "بانتظار قبول الشريك…" : "Waiting for partner to accept…"))

        HStack(spacing: NNSpacing.xs) {
            Image(systemName: partnership.status == .accepted ? "checkmark.seal.fill" : "clock.fill")
                .foregroundColor(partnership.status == .accepted ? AppColors.successGreen : AppColors.textSecondary)
            Text(displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
            Spacer()
        }

        if !breakAttempts.isEmpty {
            Text(lang.isArabicEffective ? "آخر المحاولات" : "Recent attempts")
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.textSecondary)
                .padding(.top, NNSpacing.xxs)
            ForEach(breakAttempts.prefix(5)) { attempt in
                HStack {
                    Text(attemptTypeLabel(attempt.type))
                        .font(.footnote)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text(relativeTime(attempt.attemptedAt))
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        } else if !isLoadingAttempts {
            Text(lang.isArabicEffective ? "لا محاولات كسر مسجّلة — أحسنت." : "No break attempts logged — well done.")
                .font(.footnote)
                .foregroundColor(AppColors.successGreen)
                .padding(.top, NNSpacing.xxs)
        }

        Button(action: {
            isLoadingAttempts = true
            Task {
                let attempts = await partnerStore.fetchBreakAttempts(partnershipID: partnership.id)
                await MainActor.run {
                    breakAttempts = attempts
                    isLoadingAttempts = false
                }
            }
        }) {
            HStack {
                if isLoadingAttempts { ProgressView().progressViewStyle(.circular) }
                Text(lang.isArabicEffective ? "تحديث" : "Refresh")
                    .font(.footnote)
            }
            .foregroundColor(AppColors.accent)
        }
        .buttonStyle(.plain)
        .padding(.top, NNSpacing.xxs)
        .onAppear {
            if breakAttempts.isEmpty {
                isLoadingAttempts = true
                Task {
                    let attempts = await partnerStore.fetchBreakAttempts(partnershipID: partnership.id)
                    await MainActor.run {
                        breakAttempts = attempts
                        isLoadingAttempts = false
                    }
                }
            }
        }
    }

    private func attemptTypeLabel(_ type: BreakAttemptType) -> String {
        switch type {
        case .disable:          return lang.isArabicEffective ? "محاولة إيقاف" : "Disable attempt"
        case .delete:           return lang.isArabicEffective ? "محاولة حذف" : "Delete attempt"
        case .modify:           return lang.isArabicEffective ? "محاولة تعديل" : "Modify attempt"
        case .uninstallAttempt: return lang.isArabicEffective ? "محاولة إزالة التطبيق" : "Uninstall attempt"
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: lang.isArabicEffective ? "ar" : "en")
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Hand off to PartnerInviteView, which collects names from the user and
    /// runs createPartnership + share sheet itself. We no longer touch CloudKit
    /// directly from here — that work moved inside the invite view so the name
    /// fields are part of the same screen as the share.
    private func invitePartner() {
        // No async pre-step needed anymore — just open the invite sheet.
        showPartnerInvite = true
    }

    private func isActiveNowDetail() -> Bool {
        // Use stable id to avoid touching list.id after deletion
        if ManualStateStore.isActive(for: stableListId) { return true }
        // If the Core Data object is being deleted, avoid dereferencing its properties
        if list.isDeleted { return false }
        // Forever blocks are always active until purged.
        if list.blockType == "forever" { return true }
        // Time-Limit always monitoring (shield kicks in after daily threshold).
        if list.blockType == "timeLimit" { return true }
        let now = Date()
        if list.blockType == "now" {
            let end = list.createdAt.addingTimeInterval(TimeInterval(list.durationSeconds))
            return now < end
        }
        if list.blockType == "scheduled" {
            guard let data = list.scheduleSlots else { return false }
            let decoded = SchedulePersistence.decode(data)
            if decoded.isEmpty { return false }
            let cal = Calendar.current
            let comps = cal.dateComponents([.weekday, .hour, .minute], from: now)
            guard let weekday = comps.weekday, let h = comps.hour, let m = comps.minute else { return false }
            let dayIndex = (weekday - 1) % 7
            let minutesNow = h * 60 + m
            return decoded.contains { $0.day == dayIndex && minutesNow >= $0.fromMinutes && minutesNow < $0.toMinutes }
        }
        return false
    }

    private func localizedBlockTypeLabel(_ type: String) -> String {
        switch type {
        case "now":       return lang.isArabicEffective ? "فوري" : "Now"
        case "scheduled": return lang.isArabicEffective ? "مجدول" : "Scheduled"
        case "timeLimit": return lang.isArabicEffective ? "حد يومي" : "Daily Limit"
        case "forever":   return lang.isArabicEffective ? "دائم" : "Forever"
        default:          return type
        }
    }

    /// Translates the raw `protection` Core-Data string into a human label.
    /// The DB stores "hard" / "noProtection" because those are stable
    /// machine keys, but the user should never see them.
    private func localizedProtectionLabel(_ value: String) -> String {
        switch value {
        case "hard":         return lang.isArabicEffective ? "الوضع الصارم" : "Hard Mode"
        case "noProtection": return lang.isArabicEffective ? "بدون حماية" : "No Protection"
        default:             return value
        }
    }

    /// Pluralized minute label using BlockingConstants for the unit math.
    /// Centralized so all Timing rows share the same wording.
    private func localizedMinutesLabel(_ minutes: Int) -> String {
        if lang.isArabicEffective {
            return "\(minutes) دقيقة"
        }
        return "\(minutes) min"
    }

    /// Live remaining minutes for an active `now` block — drives the
    /// countdown row in the Timing card. Returns nil for non-`now` types,
    /// or when the window has already elapsed.
    private func remainingMinutesForNowBlock() -> Int? {
        guard list.blockType == "now", !list.isDeleted else { return nil }
        let end = list.createdAt.addingTimeInterval(TimeInterval(list.durationSeconds))
        let remaining = end.timeIntervalSince(Date())
        guard remaining > 0 else { return nil }
        // Round up so "0 min remaining" only shows when the block is truly over.
        return max(1, Int(ceil(remaining / Double(BlockingConstants.secondsPerMinute))))
    }

    /// Compact chip preview of the first few blocked items. Appears inside
    /// the Overview card so the user can answer "what's blocked here"
    /// without opening Edit. Categories get a `square.grid.2x2` icon, apps
    /// get `app.fill`, websites get `globe`.
    @ViewBuilder
    private func itemsPreview() -> some View {
        let allItems = (list.items ?? []).sorted { ($0.displayName ?? $0.value) < ($1.displayName ?? $1.value) }
        if !allItems.isEmpty {
            let visible = allItems.prefix(4)
            let extra = allItems.count - visible.count
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.xs) {
                Text(lang.isArabicEffective ? "ما يُحجب" : "What's blocked")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.textSecondary)
                FlowChipsRow(items: Array(visible).map { ($0.id, iconFor(kind: $0.kind), $0.displayName ?? $0.value) },
                             extraCount: extra,
                             extraLabel: lang.isArabicEffective ? "+\(extra) أكثر" : "+\(extra) more",
                             isRTL: lang.isArabicEffective)
            }
            .padding(.top, NNSpacing.xs)
        }
    }

    /// SF Symbol for each BlockItemEntity kind. Mirrors the icons used in
    /// CreateListSheet's selectedItemsSummary so the same item type looks
    /// the same wherever it appears.
    private func iconFor(kind: String?) -> String {
        switch kind {
        case "category": return "square.grid.2x2.fill"
        case "app":      return "app.fill"
        case "website":  return "globe"
        default:         return "circle"
        }
    }

    private func scheduleSummaryText() -> String? {
        guard list.blockType == "scheduled",
              let data = list.scheduleSlots else { return nil }
        let decoded = SchedulePersistence.decode(data)
        let slots = decoded.map { Slot(id: $0.id, day: $0.day, fromMinutes: $0.fromMinutes, toMinutes: $0.toMinutes) }
        guard let firstSlot = slots.first else { return nil }
        let uniqueTimes = Set(slots.map { "\($0.fromMinutes)-\($0.toMinutes)" })
        guard uniqueTimes.count == 1 else { return nil }
        let from = firstSlot.fromMinutes
        let to = firstSlot.toMinutes
        let days = Array(Set(slots.map { $0.day })).sorted()
        guard let firstDay = days.first, let lastDay = days.last else { return nil }
        func dayName(_ d: Int) -> String {
            if lang.isArabicEffective { return ["الأحد","الإثنين","الثلاثاء","الأربعاء","الخميس","الجمعة","السبت"][ (d % 7 + 7) % 7 ] }
            return ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][ (d % 7 + 7) % 7 ]
        }
        let daysDesc: String
        if days.count >= 2 && zip(days.dropFirst(), days).allSatisfy({ $0.0 == $0.1 + 1 }) {
            daysDesc = dayName(firstDay) + "–" + dayName(lastDay)
        } else if days.count <= 3 {
            daysDesc = days.map { dayName($0) }.joined(separator: lang.isArabicEffective ? "، " : ", ")
        } else { return nil }
        let time = String(format: "%02d:%02d", from/60, from%60) + "–" + String(format: "%02d:%02d", to/60, to%60)
        return daysDesc + " " + time
    }
}

// MARK: - Partner Invite Disclosure (D14)

/// Disclosure sheet shown before generating a Recovery Partner CKShare URL.
/// CKShare URLs are durable and unrevokable per-recipient: the first iCloud
/// user who taps the link accepts the share, regardless of whom the sender
/// intended. Apple authenticates the recipient by Apple ID but does not
/// verify *which* person that is. The acknowledgement here is friction by
/// design — it surfaces the trust requirement before a link enters a chat.
private struct PartnerInviteDisclosureSheet: View {
    let isArabic: Bool
    @Binding var accepted: Bool
    let onContinue: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: NNSpacing.sm) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.title)
                            .foregroundColor(AppColors.alertRed)
                        Text(isArabic ? "قبل إرسال الدعوة" : "Before you send the invitation")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(AppColors.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: NNSpacing.sm) {
                        bulletRow(
                            icon: "link",
                            text: isArabic
                                ? "أي شخص يضغط رابط الدعوة بحساب iCloud يصير شريك التعافي. لا يوجد رمز تأكيد إضافي."
                                : "Anyone who taps the invitation link with an iCloud account becomes your Recovery Partner. There is no extra PIN."
                        )
                        bulletRow(
                            icon: "person.crop.circle.badge.exclamationmark",
                            text: isArabic
                                ? "إذا أعدت توجيه الرابط للمحادثة الخطأ، الشخص الجديد سيستلم محاولات كسر الحجب بدلاً من شريكك."
                                : "If you forward the link to the wrong chat, the new person receives break-attempt notifications instead of your intended partner."
                        )
                        bulletRow(
                            icon: "arrow.uturn.backward.slash",
                            text: isArabic
                                ? "لا يمكن سحب الرابط بعد إرساله، لكن يمكنك إنهاء الشراكة من شاشة القائمة في أي وقت."
                                : "The link can't be revoked once sent, but you can end the partnership from the list screen at any time."
                        )
                    }

                    Toggle(isOn: $accepted) {
                        Text(isArabic
                             ? "أفهم وسأرسل الرابط لشخص أثق فيه فقط."
                             : "I understand and will share the link only with someone I trust.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .tint(AppColors.accent)
                    .padding(NNSpacing.md)
                    .background(AppColors.uiSurface)
                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                    .overlay(RoundedRectangle(cornerRadius: NNRadius.control).stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline))

                    Button(action: { if accepted { onContinue() } }) {
                        Text(isArabic ? "إنشاء الرابط ومتابعة" : "Create link and continue")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(accepted ? AppColors.accent : AppColors.accent.opacity(0.4))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                    }
                    .buttonStyle(.plain)
                    .disabled(!accepted)
                }
                .padding(NNSpacing.lg)
            }
            .background(AppColors.uiSurface.opacity(0.3))
            .navigationTitle(isArabic ? "دعوة شريك تعافي" : "Invite Recovery Partner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isArabic ? "إلغاء" : "Cancel") { onCancel() }
                }
            }
        }
        .environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
    }

    private func bulletRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: NNSpacing.sm) {
            Image(systemName: icon)
                .foregroundColor(AppColors.accent)
                .frame(width: 24, alignment: .center)
            Text(text)
                .font(.footnote)
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
        }
    }
} 