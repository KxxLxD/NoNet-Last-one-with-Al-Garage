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
    // حالة خطأ الحفظ
    @State private var saveErrorMessage: String? = nil

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
    private let trialDuration: TimeInterval = 7 * 24 * 3600
    private var isTrialActive: Bool {
        trialStartTs > 0 && Date().timeIntervalSince1970 < trialStartTs + trialDuration
    }
    private var trialRemainingDays: Int {
        guard isTrialActive else { return 0 }
        let remaining = (trialStartTs + trialDuration - Date().timeIntervalSince1970) / (24 * 3600)
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
    private func deleteList(_ list: ListEntity) {
        if BlockingEngine.shared.isHardLocked(list: list) {
            saveErrorMessage = lang.isArabicEffective
                ? "لا يمكن حذف قائمة بوضع صارم حتى انتهاء المدة."
                : "Can't delete a Hard-Mode list until its duration ends."
            // Notify the recovery partner (if any) that a delete attempt was made.
            if let partnership = CloudKitPartnerStore.shared.partnership(for: list.id) {
                let id = list.id
                let name = list.name
                Task {
                    await CloudKitPartnerStore.shared.recordBreakAttempt(
                        partnershipID: partnership.id,
                        listID: id,
                        listName: name,
                        type: .delete,
                        reachedThrough: "home_delete_button"
                    )
                }
            }
            return
        }
        let id = list.id
        BlockingEngine.shared.purge(listId: id)
        context.delete(list)
        switch context.saveIfNeeded() {
        case .success:
            BreaksStore.clear(for: id)
            ManualStateStore.clear(for: id)
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

    /// Only worth nagging about iCloud when at least one Hard-Mode list exists —
    /// otherwise the recovery-partner feature isn't reachable anyway.
    @ViewBuilder
    private func iCloudBannerIfNeeded() -> some View {
        let hasHardList = lists.contains { $0.protection == "hard" }
        if hasHardList, let reason = partnerStore.accountUnavailableReason(isArabic: lang.isArabicEffective) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.icloud.fill")
                    .foregroundColor(AppColors.alertRed)
                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 4) {
                    Text(lang.isArabicEffective ? "تنبيه iCloud" : "iCloud Notice")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(AppColors.alertRed)
                    Text(reason)
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(AppColors.alertRed.opacity(0.08))
            .cornerRadius(12)
        }
    }

    /// Banner shown when the user has Scheduled or Time-Limit lists that
    /// should have triggered the BlockingMonitor extension but haven't —
    /// signal that the extension target isn't bound, the App Group is missing,
    /// or signing/provisioning is wrong. Without this signal the silent failure
    /// turns into 1-star reviews ("the schedule didn't work").
    @ViewBuilder
    private func monitorBannerIfNeeded() -> some View {
        let scheduledLists = lists.filter { $0.blockType == "scheduled" || $0.blockType == "timeLimit" }
        let oldestCreation = scheduledLists.map { $0.createdAt }.min()
        if MonitorHealthcheck.shouldShowBanner(oldestScheduledOrLimit: oldestCreation) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "bolt.slash.fill")
                    .foregroundColor(AppColors.alertRed)
                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 4) {
                    Text(lang.isArabicEffective ? "الجدولة غير مفعّلة" : "Scheduling not active")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(AppColors.alertRed)
                    Text(lang.isArabicEffective
                         ? "نظام مراقبة الجدولة (DeviceActivityMonitor) لم يستجب خلال آخر 24 ساعة. القوائم المجدولة وحدود الوقت اليومي قد لا تطبّق الحجب تلقائياً. تواصل مع الدعم."
                         : "The scheduling extension hasn't responded in the last 24 hours. Scheduled lists and daily Time-Limit blocks may not apply automatically. Contact support.")
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(AppColors.alertRed.opacity(0.08))
            .cornerRadius(12)
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Hero
                    VStack(spacing: 12) {
                        let trimmedName = obName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedName.isEmpty {
                            Text(lang.isArabicEffective ? "أهلاً، \(trimmedName) 👋" : "Welcome, \(trimmedName) 👋")
                                .font(.body.weight(.medium))
                                .foregroundColor(AppColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                        }
                        ZStack {
                            Circle()
                                .fill(AppColors.infoBg)
                                .frame(width: 96, height: 96)
                            Image("nonet_logo")
                            .resizable()
                            .scaledToFit()
                                .frame(width: 60, height: 60)
                        }
                        Text(AppStrings.heroTitle(lang))
                            .font(.nnHero)
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                        Text(AppStrings.homeSubtitle(lang))
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                    .padding(.bottom, 8)
                    
 
                     // Motivational stats
                     HStack(spacing: 12) {
                         SavedCycleCard(lang: lang)
                         LevelCard(lang: lang, value: "1")
                         ChallengesSimpleCard(lang: lang, value: "add")
                     }
                    // Secondary CTA — outlined style so the primary "Get Started" (below)
                    // stays the single dominant action on the screen. One primary per screen
                    // is the canonical "Visual Hierarchy" rule (Apple HIG + Material).
                    if !lists.isEmpty || !activeLists.isEmpty {
                        ShareLink(item: shareMessage) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text(lang.isArabicEffective ? "مشاركة تقدّمي" : "Share progress")
                            }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.clear)
                            .foregroundColor(AppColors.accent)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppColors.accent, lineWidth: 1)
                            )
                        }
                    }
                    iCloudBannerIfNeeded()
                    monitorBannerIfNeeded()
                    SoftDivider(width: 300, opacity: 0.70)

                    // Primary CTA — Create Blocklist
                    CreateBlocklistCard(lang: lang, useGradientCTA: false) {
                        showingCreate = true
                    }
                    .sheet(isPresented: $showingCreate) {
                        CreateListSheet().environmentObject(lang)
                    }
                    SoftDivider(width: 300, opacity: 0.70)

                    // Permissions (render only if missing).
                    // Collapsed: slim banner (warning style — single row, ~44pt tall) so it
                    //   signals "needs attention" without competing with the primary CTA.
                    // Expanded: full card with per-permission Grant buttons (unchanged UX).
                    if !(hasScreenTimePermission && hasNotificationPermission) {
                        let requiredCount = (hasScreenTimePermission ? 0 : 1) + (hasNotificationPermission ? 0 : 1)
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
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
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44) // HIG minimum touch target
                            .padding(.vertical, 8)
                            .background(AppColors.warningBg)
                            .overlay(
                                RoundedRectangle(cornerRadius: permissionsExpanded ? 0 : 12)
                                    .stroke(AppColors.warningFg.opacity(0.3), lineWidth: 0.5)
                            )
                            if permissionsExpanded {
                                VStack(spacing: 0) {
                                    // Screen Time row
                                    HStack(spacing: 12) {
                                        Image(systemName: "lock.iphone").foregroundColor(AppColors.accent)
                                        Text(lang.isArabicEffective ? "Screen Time" : "Screen Time")
                                            .font(.subheadline)
                                            .foregroundColor(AppColors.textPrimary)
                                        Spacer()
                                        if !hasScreenTimePermission {
                                            Button(action: { requestScreenTimeAuth() }) {
                                                Text(lang.isArabicEffective ? "منح" : "Grant")
                                                    .font(.footnote.weight(.semibold))
                                                    .padding(.horizontal, 12)
                                                    .frame(height: 30)
                                                    .background(AppColors.accent)
                                                    .foregroundColor(.white)
                                                    .cornerRadius(8)
                                            }
                                            .buttonStyle(.plain)
                                        } else {
                                            HStack(spacing: 4) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(AppColors.successGreen)
                                                    .font(.caption)
                                                Text(lang.isArabicEffective ? "مُفعَّل" : "Granted")
                                                    .font(.footnote)
                                                    .foregroundColor(AppColors.textSecondary)
                                            }
                                        }
                                    }
                                    .padding(16)
                                    Divider().background(AppColors.uiBorder.opacity(0.35))
                                    // Notifications row
                                    HStack(spacing: 12) {
                                        Image(systemName: "bell").foregroundColor(AppColors.accent)
                                        Text(lang.isArabicEffective ? "الإشعارات" : "Notifications")
                                            .font(.subheadline)
                                            .foregroundColor(AppColors.textPrimary)
                                        Spacer()
                                        if !hasNotificationPermission {
                                            Button(action: { requestNotificationsAuth() }) {
                                                Text(lang.isArabicEffective ? "تفعيل" : "Enable")
                                                    .font(.footnote.weight(.semibold))
                                                    .padding(.horizontal, 12)
                                                    .frame(height: 30)
                                                    .background(AppColors.accent)
                                                    .foregroundColor(.white)
                                                    .cornerRadius(8)
                                            }
                                            .buttonStyle(.plain)
                                        } else {
                                            HStack(spacing: 4) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(AppColors.successGreen)
                                                    .font(.caption)
                                                Text(lang.isArabicEffective ? "مُفعَّل" : "Enabled")
                                                    .font(.footnote)
                                                    .foregroundColor(AppColors.textSecondary)
                                            }
                                        }
                                    }
                                    .padding(16)
                                }
                                .background(AppColors.uiSurface)
                                .overlay(
                                    // Side+bottom border only (top edge meets the banner).
                                    Rectangle().stroke(AppColors.uiBorder, lineWidth: 0.5)
                                )
                            }
                        }
                        // Outer container: slim banner radius when collapsed,
                        // full-card radius when expanded. The outer clip rounds the
                        // whole stack so banner + detail share a single outer shape.
                        .clipShape(RoundedRectangle(cornerRadius: permissionsExpanded ? 20 : 12))
                        SoftDivider(width: 300, opacity: 0.70)
                    }

                    // Lists
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(lang.isArabicEffective ? "قوائمك" : "Your Lists")
                                .font(.nnSectionTitle)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Button(action: { showingCreate = true }) {
                                Image(systemName: "plus")
                                    .foregroundColor(AppColors.accent)
                                    .frame(width: 28, height: 28)
                                    .background(AppColors.infoBg)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }

                        if lists.isEmpty {
                            EmptyStateView(isArabic: lang.isArabicEffective)
                        } else {
                            VStack(spacing: 0) {
                                VStack(alignment: .leading, spacing: 8) {
                                    if !activeLists.isEmpty {
                                        Text(lang.isArabicEffective ? "القوائم النشطة" : "Active Lists")
                                            .font(.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                            .padding(.horizontal, 16)
                                            .padding(.top, 12)
                                    }
                                    // Active lists first
                                    ForEach(activeLists) { item in
                                        HStack(spacing: 12) {
                                            if !lang.isArabicEffective && item.protection != "hard" {
                                                Button(action: { toggleManual(for: item) }) {
                                                    Image(systemName: isActiveNow(item) ? "pause.fill" : "play.fill")
                                                        .font(.nnSmallButton)
                                                        .foregroundColor(AppColors.accent)
                                                        .frame(width: 32, height: 32)
                                                        .background(AppColors.infoBg)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            NavigationLink(destination: ListDetailView(list: item)) {
                                                ListRowCore(item: item, isActive: true)
                                            }
                                            if lang.isArabicEffective && item.protection != "hard" {
                                                Button(action: { toggleManual(for: item) }) {
                                                    Image(systemName: isActiveNow(item) ? "pause.fill" : "play.fill")
                                                        .font(.nnSmallButton)
                                                        .foregroundColor(AppColors.accent)
                                                        .frame(width: 32, height: 32)
                                                        .background(AppColors.infoBg)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        if item.id != activeLists.last?.id || !nonActiveLists.isEmpty {
                                            Divider().background(AppColors.uiBorder.opacity(0.6)).padding(.horizontal, 16)
                                        }
                                    }
                                    if !nonActiveLists.isEmpty {
                                        Text(lang.isArabicEffective ? "قوائم أخرى" : "Other Lists")
                                            .font(.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                            .padding(.horizontal, 16)
                                            .padding(.top, 12)
                                    }
                                    // Non-active lists
                                    ForEach(nonActiveLists) { item in
                                        HStack(spacing: 12) {
                                            if !lang.isArabicEffective && item.protection != "hard" {
                                                Button(action: { toggleManual(for: item) }) {
                                                    Image(systemName: isActiveNow(item) ? "pause.fill" : "play.fill")
                                                        .font(.nnSmallButton)
                                                        .foregroundColor(AppColors.accent)
                                                        .frame(width: 32, height: 32)
                                                        .background(AppColors.infoBg)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            NavigationLink(destination: ListDetailView(list: item)) {
                                                ListRowCore(item: item, isActive: false)
                                            }
                                            if lang.isArabicEffective && item.protection != "hard" {
                                                Button(action: { toggleManual(for: item) }) {
                                                    Image(systemName: isActiveNow(item) ? "pause.fill" : "play.fill")
                                                        .font(.nnSmallButton)
                                                        .foregroundColor(AppColors.accent)
                                                        .frame(width: 32, height: 32)
                                                        .background(AppColors.infoBg)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        if item.id != nonActiveLists.last?.id {
                                            Divider().background(AppColors.uiBorder.opacity(0.6)).padding(.horizontal, 16)
                                        }
                                    }
                                }
                                .background(AppColors.uiSurface)
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(AppColors.uiBorder, lineWidth: 0.5)
                                )
                                .padding(.top, 8)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
            .background(AppColors.uiBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
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
            .onAppear {
                checkPermissions()
            }
        }
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
        // once an emergency-unlock request has matured (72h elapsed), the user
        // has *earned* the right to release; let the toggle deactivate the
        // list in that one specific case. Without this, the matured-unlock
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
            // a future re-block requires a fresh 72h request.
            if list.protection == "hard" {
                EmergencyUnlockStore.clear(for: list.id)
            }
        } else {
            BlockingEngine.shared.activate(list: list)
        }
        refreshTick += 1 // Force UI refresh
    }
}


private struct PermissionCard: View {
    let title: String
    let message: String
    let icon: String
    let learnTitle: String
    var onLearn: () -> Void

    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        VStack(alignment: layoutDirection == .rightToLeft ? .trailing : .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundColor(AppColors.accent)
                Text(title).font(.headline)
            }
            Text(message).font(.subheadline).foregroundColor(AppColors.textSecondary)
            HStack {
                Spacer()
                Button(action: onLearn) {
                    Label(learnTitle, systemImage: "info.circle")
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.accent)
            }
        }
        .padding(20)
        .background(AppColors.uiSurface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.uiBorder, lineWidth: 0.5)
        )
    }
}

private struct RealListRow: View {
    let item: ListEntity
    let isActive: Bool
    let onToggle: () -> Void

    @Environment(\.layoutDirection) private var layoutDirection
    @EnvironmentObject private var lang: LanguageManager

    // Local decode model for schedule slots
    private struct Slot: Codable { let id: UUID; let day: Int; let fromMinutes: Int; let toMinutes: Int }

    var body: some View {
        HStack(alignment: .center) {
            if item.protection != "hard" {
                if !lang.isArabicEffective { // LTR → button on left
                    Button(action: { onToggle() }) {
                        Image(systemName: isActive ? "pause.fill" : "play.fill")
                            .font(.nnSmallButton)
                            .foregroundColor(AppColors.accent)
                            .frame(width: 32, height: 32)
                            .background(AppColors.infoBg)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: layoutDirection == .rightToLeft ? .trailing : .leading, spacing: 6) {
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                HStack(spacing: 8) {
                    ProtectionBadge(isHard: item.protection == "hard", isRTL: layoutDirection == .rightToLeft)
                }
            }
            Spacer()

            if item.protection != "hard" {
                if lang.isArabicEffective { // RTL → button on right
                    Button(action: { onToggle() }) {
                        Image(systemName: isActive ? "pause.fill" : "play.fill")
                            .font(.nnSmallButton)
                            .foregroundColor(AppColors.accent)
                            .frame(width: 32, height: 32)
                            .background(AppColors.infoBg)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            } else if isActive {
                Text(layoutDirection == .rightToLeft ? "مفعّلة الآن" : "Active")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(AppColors.infoFg)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(AppColors.infoBg)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: layoutDirection == .rightToLeft ? .trailing : .leading)
        .background(Color.clear)
    }

    private func itemsCountText(_ count: Int) -> String {
        if layoutDirection == .rightToLeft {
            return "\(arabicDigits(count)) عنصر"
        } else {
            return "\(count) items"
        }
    }

    private func arabicDigits(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ar")
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func decodedSlots() -> [Slot] {
        guard let data = item.scheduleSlots else { return [] }
        return SchedulePersistence.decode(data).map { Slot(id: $0.id, day: $0.day, fromMinutes: $0.fromMinutes, toMinutes: $0.toMinutes) }
    }

    private func scheduleSummaryBadged() -> String? {
        guard item.blockType == "scheduled" else { return nil }
        let slots = decodedSlots()
        guard !slots.isEmpty, let summary = scheduleSummary(slots) else { return nil }
        return summary
    }

    private func subtitleText() -> String? { /* kept for potential future use */
        if item.blockType == "forever" {
            return layoutDirection == .rightToLeft ? "حجب دائم" : "Permanent block"
        }
        if item.blockType == "timeLimit" {
            let minutes = Int(item.durationSeconds / 60)
            return layoutDirection == .rightToLeft ? "حد يومي \(minutes) دقيقة" : "Daily limit: \(minutes) min"
        }
        if item.blockType == "now" && isActive {
            let end = item.createdAt.addingTimeInterval(TimeInterval(item.durationSeconds))
            let remaining = Int(max(0, end.timeIntervalSince(Date())))
            if remaining <= 0 { return nil }
            return (layoutDirection == .rightToLeft ? "ينتهي خلال " : "Ends in ") + format(remaining)
        }
        if item.blockType == "scheduled" {
            let slots = decodedSlots()
            if !slots.isEmpty {
                if let summary = scheduleSummary(slots) { return summary }
                let cnt = slots.count
                return layoutDirection == .rightToLeft ? "جدولة: \(cnt) فترات" : "Scheduled: \(cnt) slots"
            }
        }
        return nil
    }

    private func scheduleSummary(_ slots: [Slot]) -> String? {
        guard let firstSlot = slots.first else { return nil }
        let uniqueTimes = Set(slots.map { "\($0.fromMinutes)-\($0.toMinutes)" })
        guard uniqueTimes.count == 1 else { return nil }
        let from = firstSlot.fromMinutes
        let to = firstSlot.toMinutes
        let days = Array(Set(slots.map { $0.day })).sorted()
        guard let firstDay = days.first, let lastDay = days.last else { return nil }
        let daysDesc: String
        if isContiguous(days) && days.count >= 2 {
            daysDesc = dayShortName(firstDay) + "–" + dayShortName(lastDay)
        } else if days.count <= 3 {
            daysDesc = days.map { dayShortName($0) }.joined(separator: layoutDirection == .rightToLeft ? "، " : ", ")
        } else {
            return nil
        }
        let time = formatHM(from) + "–" + formatHM(to)
        return (layoutDirection == .rightToLeft ? "\(daysDesc) \(time)" : "\(daysDesc) \(time)")
    }

    private func isContiguous(_ days: [Int]) -> Bool {
        guard days.count >= 2 else { return false }
        for i in 1..<days.count { if days[i] != days[i-1] + 1 { return false } }
        return true
    }

    private func dayShortName(_ d: Int) -> String {
        if layoutDirection == .rightToLeft {
            let names = ["الأحد","الإثنين","الثلاثاء","الأربعاء","الخميس","الجمعة","السبت"]
            return names[(d % 7 + 7) % 7]
        } else {
            let names = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
            return names[(d % 7 + 7) % 7]
        }
    }

    private func formatHM(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        let s = String(format: "%02d:%02d", h, m)
        return s
    }

    private func format(_ seconds: Int) -> String {
        let d = seconds / 86400
        let h = (seconds % 86400) / 3600
        let m = (seconds % 3600) / 60
        if layoutDirection == .rightToLeft {
            if d > 0 { return "\(d)ي \(h)س" }
            if h > 0 { return "\(h)س \(m)د" }
            return "\(m)د"
        } else {
            if d > 0 { return "\(d)d \(h)h" }
            if h > 0 { return "\(h)h \(m)m" }
            return "\(m)m"
        }
    }
}

private enum BadgeStyle { case neutral, warning, danger }

private struct Badge: View {
    let icon: String
    let text: String
    let style: BadgeStyle
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .frame(height: 24)
        .foregroundColor(fg)
        .background(bg)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(border, lineWidth: 0.5))
        .cornerRadius(8)
    }
    private var fg: Color {
        switch style {
        case .neutral: return AppColors.textPrimary
        case .warning: return AppColors.warningFg
        case .danger: return AppColors.alertRed
        }
    }
    private var bg: Color {
        switch style {
        case .neutral: return AppColors.uiSurface
        case .warning: return AppColors.warningBg
        case .danger: return AppColors.alertRed.opacity(0.10)
        }
    }
    private var border: Color {
        switch style {
        case .neutral: return AppColors.uiBorder
        case .warning: return AppColors.warningFg.opacity(0.6)
        case .danger: return AppColors.alertRed
        }
    }
}

private struct ProtectionBadge: View {
    let isHard: Bool
    let isRTL: Bool
    var body: some View {
        if isHard {
            Badge(icon: "lock.fill", text: isRTL ? "الوضع الصارم" : "Hard Mode", style: .danger)
        } else {
            Badge(icon: "lock.open", text: isRTL ? "بدون حماية" : "No Protection", style: .neutral)
        }
    }
}

private struct EmptyStateView: View {
    let isArabic: Bool
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.pencil")
                .font(.title)
                .foregroundColor(AppColors.textSecondary)
            Text(isArabic ? "ابدأ رحلتك بإنشاء أوّل قائمة حجب." : "Your focus journey starts here. Tap Create List.")
                .font(.subheadline)
                .multilineTextAlignment(isArabic ? .trailing : .center)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(AppColors.uiSurface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.uiBorder, lineWidth: 1)
        )
    }
}

private struct StatsCard: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundColor(AppColors.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .frame(height: 112)
        .background(AppColors.uiSurface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.uiBorder, lineWidth: 0.5)
        )
    }
}

private struct CreateBlocklistCard: View {
    @ObservedObject var lang: LanguageManager
    let useGradientCTA: Bool
    var onCreate: () -> Void

    var body: some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
            HStack {
                Text(AppStrings.createBlocklistTitle(lang))
                    .font(.nnCardTitle)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Image(systemName: "plus")
                    .foregroundColor(AppColors.accent)
                    .frame(width: 28, height: 28)
                    .background(AppColors.infoBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Button(action: onCreate) {
                Text(lang.isArabicEffective ? "ابدأ" : "Get Started")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        Group {
                            AppColors.accent
                        }
                    )
                    .foregroundColor(.white)
        .cornerRadius(12)
            }
        }
        .padding(16)
        .background(AppColors.uiSurface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.uiBorder, lineWidth: 1)
        )
    }
}

private struct ChallengesCard: View {
    @ObservedObject var lang: LanguageManager
    let value: String
    var showCTA: Bool = false
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                StatsCard(value: value, label: AppStrings.challengesLabel(lang))
                HStack {
                    Spacer()
                    Button(action: { /* add challenge */ }) {
                        Image(systemName: "plus")
                            .foregroundColor(AppColors.accent)
                            .frame(width: 24, height: 24)
                            .background(AppColors.infoBg)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(10)
                }
            }
            if showCTA {
                NavigationLink(destination: ChallengesView().environmentObject(lang)) {
                    Text(lang.isArabicEffective ? "استكشف التحديات (\(value))" : "Explore challenges (\(value))")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(AppColors.accent)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

private struct ChallengesSimpleCard: View {
    @ObservedObject var lang: LanguageManager
    let value: String
    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink(destination: ChallengesView().environmentObject(lang)) {
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.nnHero)
                        .foregroundColor(AppColors.trophyGold)
                    Text(lang.isArabicEffective ? "أضف تحدّي" : "Add Challenge")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .frame(height: 112)
                .background(AppColors.uiSurface)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppColors.uiBorder, lineWidth: 0.5)
                )
            }
            Image(systemName: "plus")
                .foregroundColor(AppColors.accent)
                .frame(width: 24, height: 24)
                .background(AppColors.infoBg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(10)
        }
    }
}

private struct SavedCycleCard: View {
    @ObservedObject var lang: LanguageManager
    @State private var scopeIndex: Int = 0 // 0=W, 1=M, 2=A
    private func nextScope() { scopeIndex = (scopeIndex + 1) % 3 }
    @State private var flash: Bool = false
    var body: some View {
        VStack(spacing: 6) {
            Text("2.5h")
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundColor(AppColors.textPrimary)
            Text(combinedLabel())
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .frame(height: 112)
        .background(
            ZStack {
                AppColors.uiSurface
                if flash { AppColors.accent.opacity(0.12) }
            }
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.uiBorder, lineWidth: 0.5)
        )
        .overlay(alignment: .topTrailing) {
            Button(action: {
                nextScope()
                withAnimation(.easeOut(duration: 0.2)) { flash = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    withAnimation(.easeIn(duration: 0.2)) { flash = false }
                }
            }) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(AppColors.accent)
                    .frame(width: 24, height: 24)
                    .background(AppColors.infoBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(8)
        }
        .contentShape(Rectangle())
    }
    private func scopeText() -> String {
        switch scopeIndex {
        case 0: return lang.isArabicEffective ? "أسبوعي" : "Weekly"
        case 1: return lang.isArabicEffective ? "شهري" : "Monthly"
        default: return lang.isArabicEffective ? "طوال الوقت" : "All‑time"
        }
    }
    private func combinedLabel() -> String {
        let saved = lang.isArabicEffective ? "تم توفيره" : "Saved"
        if lang.isArabicEffective {
            return "\(saved) (\(scopeText()))"
        } else {
            return scopeText() + " " + saved
        }
    }
}

private struct LevelCard: View {
    @ObservedObject var lang: LanguageManager
    let value: String
    @State private var showInfo: Bool = false
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                Text(value)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundColor(AppColors.textPrimary)
                Text(AppStrings.levelLabel(lang))
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .frame(height: 112)
            .background(AppColors.uiSurface)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppColors.uiBorder, lineWidth: 0.5)
            )
            Button(action: { showInfo = true }) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(AppColors.accent)
                    .frame(width: 24, height: 24)
                    .background(AppColors.infoBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(10)
        }
        .alert(isPresented: $showInfo) {
            Alert(
                title: Text(lang.isArabicEffective ? "كيف يعمل المستوى؟" : "How do levels work?"),
                message: Text(lang.isArabicEffective ? "نظام النقاط يعتمد على التحديات المكتملة والساعات التي تم توفيرها." : "Your points grow with completed challenges and hours saved."),
                dismissButton: .default(Text(lang.isArabicEffective ? "حسناً" : "OK"))
            )
        }
    }
}

struct ListDetailView: View {
    let list: ListEntity
    @EnvironmentObject var lang: LanguageManager
    @ObservedObject private var partnerStore = CloudKitPartnerStore.shared
    @State private var showEditSheet = false
    @State private var showHardAlert = false
    @State private var showPartnerInvite = false
    @State private var pendingShare: CKShare?
    @State private var partnerError: String?
    @State private var isCreatingPartnership = false
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
    @Environment(\.dismiss) private var dismiss

    private struct Slot: Codable { let id: UUID; let day: Int; let fromMinutes: Int; let toMinutes: Int }
    private let stableListId: UUID

    init(list: ListEntity) {
        self.list = list
        self.stableListId = list.id
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Hard mode banner
                if list.protection == "hard" {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lock.fill").foregroundColor(AppColors.alertRed)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lang.isArabicEffective ? "الوضع الصارم مفعل" : "Hard Mode Enabled")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppColors.alertRed)
                            Text(lang.isArabicEffective ? "لا يمكن التعديل أو الحذف أثناء تفعيل الوضع الصارم." : "Editing and deleting are disabled while Hard Mode is active.")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(AppColors.alertRed.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.alertRed, lineWidth: 0.5))
                    .cornerRadius(12)
                }

                // Emergency unlock — Forever + Hard only (D18)
                if list.protection == "hard" && list.blockType == "forever" {
                    emergencyUnlockCard()
                }

                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
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
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(AppColors.infoBg)
                            .cornerRadius(8)
                    } else {
                        Text(lang.isArabicEffective ? "غير نشطة" : "Inactive")
                            .font(.footnote)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                // Overview card
                VStack(alignment: .leading, spacing: 12) {
                    Text(lang.isArabicEffective ? "نظرة عامة" : "Overview")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.textSecondary)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text(lang.isArabicEffective ? "النوع" : "Type").foregroundColor(AppColors.textSecondary); Spacer(); Text(localizedBlockTypeLabel(list.blockType)).foregroundColor(AppColors.textPrimary) }
                        HStack { Text(lang.isArabicEffective ? "الحماية" : "Protection").foregroundColor(AppColors.textSecondary); Spacer(); Text(list.protection).foregroundColor(AppColors.textPrimary) }
                        HStack { Text(lang.isArabicEffective ? "الحالة" : "Status").foregroundColor(AppColors.textSecondary); Spacer(); Text(isActiveNowDetail() ? (lang.isArabicEffective ? "مفعّلة" : "Active") : (lang.isArabicEffective ? "غير نشطة" : "Inactive")).foregroundColor(AppColors.textPrimary) }
                        if let cnt = list.items?.count {
                            HStack { Text(lang.isArabicEffective ? "العناصر" : "Items").foregroundColor(AppColors.textSecondary); Spacer(); Text("\(cnt)").foregroundColor(AppColors.textPrimary) }
                        }
                    }
                    .padding(16)
                    .background(AppColors.uiSurface)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.uiBorder, lineWidth: 0.5))
                }

                // Timing card
                VStack(alignment: .leading, spacing: 12) {
                    Text(lang.isArabicEffective ? "الوقت" : "Timing")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.textSecondary)
                    VStack(alignment: .leading, spacing: 10) {
                        if list.blockType == "now" {
                            HStack { Text(lang.isArabicEffective ? "المدة" : "Duration").foregroundColor(AppColors.textSecondary); Spacer(); Text("\(list.durationSeconds/60) min").foregroundColor(AppColors.textPrimary) }
                        }
                        if list.blockType == "forever" {
                            HStack { Text(lang.isArabicEffective ? "المدة" : "Duration").foregroundColor(AppColors.textSecondary); Spacer(); Text(lang.isArabicEffective ? "♾️ دائم" : "♾️ Permanent").foregroundColor(AppColors.alertRed) }
                        }
                        if list.blockType == "timeLimit" {
                            HStack { Text(lang.isArabicEffective ? "الحد اليومي" : "Daily Limit").foregroundColor(AppColors.textSecondary); Spacer(); Text(lang.isArabicEffective ? "\(list.durationSeconds/60) دقيقة/يوم" : "\(list.durationSeconds/60) min/day").foregroundColor(AppColors.textPrimary) }
                        }
                        if let summary = scheduleSummaryText() {
                            HStack { Text(lang.isArabicEffective ? "الجدولة" : "Schedule").foregroundColor(AppColors.textSecondary); Spacer(); Text(summary).foregroundColor(AppColors.textPrimary) }
                        }
                        if let b = BreaksStore.load(for: stableListId) {
                            HStack { Text(lang.isArabicEffective ? "الاستراحات" : "Breaks").foregroundColor(AppColors.textSecondary); Spacer(); Text("\(b.count) × \(b.duration)m").foregroundColor(AppColors.textPrimary) }
                        }
                    }
                    .padding(16)
                    .background(AppColors.uiSurface)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.uiBorder, lineWidth: 0.5))
                }

                // Recovery Partner (Hard Mode only — see docs/PARTNER_FEATURE_DESIGN_AR.md)
                if list.protection == "hard" {
                    partnerSection()
                }

                // Actions
                if list.protection != "hard" {
                    HStack(spacing: 12) {
                        Button(action: { showEditSheet = true }) {
                            Text(lang.isArabicEffective ? "تحرير" : "Edit")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(AppColors.accent)
                                .foregroundColor(.white)
                                .cornerRadius(12)
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
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.alertRed, lineWidth: 1))
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(24)
            .background(AppColors.uiBackground)
        }
        .background(AppColors.uiBackground)
        .navigationTitle(lang.isArabicEffective ? "التفاصيل" : "Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditSheet) {
            CreateListSheet().environmentObject(lang)
        }
        .onChange(of: showEditSheet) { _ in }
        .onDisappear { }
    }

    /// D18 — Emergency unlock card for Forever + Hard lists.
    ///
    /// Three states surfaced to the user:
    /// * No pending request → explanation + "Request unlock (72h delay)" button.
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

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
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
        .padding(16)
        .background(AppColors.uiSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.uiBorder, lineWidth: 0.5))
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
                 ? "سيُرفع الحجب تلقائياً بعد 72 ساعة من الآن. تقدر تلغي الطلب في أي وقت قبل ذلك."
                 : "The block will release automatically 72 hours from now. You can cancel the request anytime before then.")
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

    private func emergencyUnlockIdleView() -> some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 10) {
            Text(lang.isArabicEffective
                 ? "الحجب الدائم لا يمكن إيقافه فوراً. اطلب فك الحجب الآن وسيُرفع تلقائياً بعد 72 ساعة — وقت كافٍ ليمر الاندفاع، لكنك لست محبوساً للأبد."
                 : "Forever blocks can't be deactivated instantly. Request unlock now and the block will release automatically after 72 hours — long enough for an impulse to pass, but not indefinitely locked.")
                .font(.footnote)
                .foregroundColor(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)

            Button(action: { showRequestUnlockConfirm = true }) {
                Text(lang.isArabicEffective ? "اطلب فك الحجب (تأخير 72 ساعة)" : "Request unlock (72-hour delay)")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppColors.alertRed.opacity(0.10))
                    .foregroundColor(AppColors.alertRed)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.alertRed.opacity(0.6), lineWidth: 1))
                    .cornerRadius(12)
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
        return VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 10) {
            HStack(spacing: 8) {
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
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.accent.opacity(0.6), lineWidth: 1))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    private func emergencyUnlockMaturedView() -> some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 10) {
            HStack(spacing: 8) {
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(AppColors.accent)
                Text(lang.isArabicEffective ? "شريك التعافي" : "Recovery Partner")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: 10) {
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
            .padding(16)
            .background(AppColors.uiSurface)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.uiBorder, lineWidth: 0.5))
        }
        .sheet(isPresented: $showPartnerInvite) {
            if let share = pendingShare {
                PartnerInviteView(
                    share: share,
                    container: partnerStore.container,
                    isArabic: lang.isArabicEffective,
                    onCompletion: {
                        showPartnerInvite = false
                        Task { await partnerStore.fetchPartnerships() }
                    }
                )
                .ignoresSafeArea()
            }
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
            lang.isArabicEffective ? "تعذّر دعوة شريك" : "Couldn't invite partner",
            isPresented: Binding(get: { partnerError != nil }, set: { if !$0 { partnerError = nil } })
        ) {
            Button(lang.isArabicEffective ? "حسناً" : "OK", role: .cancel) { partnerError = nil }
        } message: {
            Text(partnerError ?? "")
        }
        .onAppear {
            Task { await partnerStore.fetchPartnerships() }
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
        Button(action: {
            disclosureAccepted = false
            showInviteDisclosure = true
        }) {
            HStack {
                if isCreatingPartnership {
                    ProgressView().progressViewStyle(.circular).tint(.white)
                } else {
                    Image(systemName: "envelope.fill")
                }
                Text(lang.isArabicEffective ? "دعوة شريك" : "Invite Partner")
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(AppColors.accent)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(isCreatingPartnership)
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

        HStack(spacing: 8) {
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
                .padding(.top, 4)
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
                .padding(.top, 4)
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
        .padding(.top, 4)
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

    private func invitePartner() {
        isCreatingPartnership = true
        let listID = stableListId
        let displayName = list.name
        Task {
            do {
                let (share, _) = try await CloudKitPartnerStore.shared.createPartnership(
                    ownerDisplayName: displayName,
                    associatedListID: listID
                )
                await MainActor.run {
                    pendingShare = share
                    isCreatingPartnership = false
                    showPartnerInvite = true
                }
            } catch {
                await MainActor.run {
                    partnerError = error.localizedDescription
                    isCreatingPartnership = false
                }
            }
        }
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
        case "forever":   return lang.isArabicEffective ? "دائم ♾️" : "Forever ♾️"
        default:          return type
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

extension ListEntity: Identifiable {}

#Preview {
    HomeView().environmentObject(LanguageManager.shared)
}

// MARK: - Actions
private extension HomeView {
    func requestScreenTimeAuth() {
        Task { await permissions.requestScreenTime() }
    }

    func requestNotificationsAuth() {
        Task { await permissions.requestNotifications() }
    }
}

private struct ListRowCore: View {
    let item: ListEntity
    let isActive: Bool
    @Environment(\.layoutDirection) private var layoutDirection
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: layoutDirection == .rightToLeft ? .trailing : .leading, spacing: 6) {
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                HStack(spacing: 8) {
                    ProtectionBadge(isHard: item.protection == "hard", isRTL: layoutDirection == .rightToLeft)
                }
            }
            Spacer()
            if item.protection == "hard" && isActive {
                Text(layoutDirection == .rightToLeft ? "مفعّلة الآن" : "Active")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(AppColors.infoFg)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(AppColors.infoBg)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 16)
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
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.title)
                            .foregroundColor(AppColors.alertRed)
                        Text(isArabic ? "قبل إرسال الدعوة" : "Before you send the invitation")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(AppColors.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
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
                    .padding(16)
                    .background(AppColors.uiSurface)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.uiBorder, lineWidth: 0.5))

                    Button(action: { if accepted { onContinue() } }) {
                        Text(isArabic ? "إنشاء الرابط ومتابعة" : "Create link and continue")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(accepted ? AppColors.accent : AppColors.accent.opacity(0.4))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .disabled(!accepted)
                }
                .padding(20)
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
        HStack(alignment: .top, spacing: 12) {
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