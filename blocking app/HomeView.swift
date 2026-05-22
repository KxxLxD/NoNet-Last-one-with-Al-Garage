import SwiftUI
import FamilyControls
import CoreData
import UserNotifications

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

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Hero
                    VStack(spacing: 12) {
                        let trimmedName = obName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmedName.isEmpty {
                            Text(lang.isArabicEffective ? "أهلاً، \(trimmedName) 👋" : "Welcome, \(trimmedName) 👋")
                                .font(.system(size: 16, weight: .medium))
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
                            .font(.system(size: 28, weight: .semibold))
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
                    if !lists.isEmpty || !activeLists.isEmpty {
                        ShareLink(item: shareMessage) {
                            Text(lang.isArabicEffective ? "مشاركة" : "Share")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(AppColors.accentDark)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    SoftDivider(width: 300, opacity: 0.70)

                    // Primary CTA — Create Blocklist
                    CreateBlocklistCard(lang: lang, useGradientCTA: false) {
                        showingCreate = true
                    }
                    .sheet(isPresented: $showingCreate) {
                        CreateListSheet().environmentObject(lang)
                    }
                    SoftDivider(width: 300, opacity: 0.70)

                    // Permissions (render only if missing)
                    if !(hasScreenTimePermission && hasNotificationPermission) {
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Text(AppStrings.permissionsTitle(lang))
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                let requiredCount = (hasScreenTimePermission ? 0 : 1) + (hasNotificationPermission ? 0 : 1)
                                let isAllSet = requiredCount == 0
                                Text(isAllSet ? (lang.isArabicEffective ? "مكتملة" : "All set") : (lang.isArabicEffective ? "مطلوبة (\(requiredCount))" : "Required (\(requiredCount))"))
                                    .font(.footnote.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .frame(height: 26)
                                    .background(isAllSet ? Color.clear : AppColors.warningBg)
                                    .foregroundColor(isAllSet ? AppColors.textSecondary : AppColors.warningFg)
                                    .overlay(
                                        Capsule().stroke(isAllSet ? AppColors.uiBorder : AppColors.warningFg.opacity(0.5), lineWidth: 0.5)
                                    )
                                    .clipShape(Capsule())
                                Image(systemName: permissionsExpanded ? "chevron.up" : "chevron.down")
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { permissionsExpanded.toggle() } }
                            .padding(16)
                            .background(AppColors.uiSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: permissionsExpanded ? 0 : 20)
                                    .stroke(AppColors.uiBorder, lineWidth: 0.5)
                            )
                            if permissionsExpanded {
                                VStack(spacing: 0) {
                                    // Screen Time row
                                    HStack(spacing: 12) {
                                        Image(systemName: "lock.iphone").foregroundColor(AppColors.accentDark)
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
                                                    .background(AppColors.accentDark)
                                                    .foregroundColor(.white)
                                                    .cornerRadius(8)
                                            }
                                            .buttonStyle(.plain)
                                        } else {
                                            Text(lang.isArabicEffective ? "تم" : "Granted")
                                                .font(.footnote)
                                                .foregroundColor(AppColors.textSecondary)
                                        }
                                    }
                                    .padding(16)
                                    Divider().background(AppColors.uiBorder.opacity(0.35))
                                    // Notifications row
                                    HStack(spacing: 12) {
                                        Image(systemName: "bell").foregroundColor(AppColors.accentDark)
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
                                                    .background(AppColors.accentDark)
                                                    .foregroundColor(.white)
                                                    .cornerRadius(8)
                                            }
                                            .buttonStyle(.plain)
                                        } else {
                                            Text(lang.isArabicEffective ? "تم" : "Enabled")
                                                .font(.footnote)
                                                .foregroundColor(AppColors.textSecondary)
                                        }
                                    }
                                    .padding(16)
                                }
                                .background(AppColors.uiSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(AppColors.uiBorder, lineWidth: 0.5)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            }
                        }
                        .background(AppColors.uiSurface)
                        .cornerRadius(20)
                        SoftDivider(width: 300, opacity: 0.70)
                    }

                    // Share progress
                    // [Removed from here to reduce visual noise when completed]

                    // Permissions (moved above)
                    // [Removed from here to reduce visual noise when completed]

                    // Lists
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(lang.isArabicEffective ? "قوائمك" : "Your Lists")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Button(action: { showingCreate = true }) {
                                Image(systemName: "plus")
                                    .foregroundColor(AppColors.accentDark)
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
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(AppColors.accentDark)
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
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(AppColors.accentDark)
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
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(AppColors.accentDark)
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
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(AppColors.accentDark)
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
                    title: Text(lang.isArabicEffective ? "حذف القائمة" : "Delete List"),
                    message: Text(lang.isArabicEffective ? "هل أنت متأكد من حذف هذه القائمة؟" : "Are you sure you want to delete this list?"),
                    primaryButton: .destructive(Text(lang.isArabicEffective ? "حذف" : "Delete")) {
                        if let toDelete = listToDelete {
                            deleteList(toDelete)
                        }
                        listToDelete = nil
                    },
                    secondaryButton: .cancel(Text(lang.isArabicEffective ? "إلغاء" : "Cancel")) {
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
        guard list.protection != "hard" else { return }
        let wasActive = ManualStateStore.isActive(for: list.id)
        ManualStateStore.toggle(for: list.id)
        if wasActive {
            BlockingEngine.shared.deactivate(list: list)
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
                Image(systemName: icon).foregroundColor(AppColors.accentDark)
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
                .foregroundColor(AppColors.accentDark)
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
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.accentDark)
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
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.accentDark)
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
                .font(.system(size: 12, weight: .semibold))
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
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text(isArabic ? "رحلة تركيزك تبدأ من هنا. اضغط \"أنشئ قائمة\"." : "Your focus journey starts here. Tap Create List.")
                .font(.subheadline)
                .multilineTextAlignment(isArabic ? .trailing : .center)
                .foregroundColor(.secondary)
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
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Image(systemName: "plus")
                    .foregroundColor(AppColors.accent600)
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
                            AppColors.accentDark
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
                            .foregroundColor(AppColors.accentDark)
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
                        .background(AppColors.accentDark)
                        .foregroundColor(.white)
                        .cornerRadius(10)
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
                        .font(.system(size: 28, weight: .semibold))
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
                .foregroundColor(AppColors.accentDark)
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
                if flash { AppColors.accentDark.opacity(0.12) }
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
                    .foregroundColor(AppColors.accentDark)
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
                    .foregroundColor(AppColors.accentDark)
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
                dismissButton: .default(Text(lang.isArabicEffective ? "حسنًا" : "OK"))
            )
        }
    }
}

struct ListDetailView: View {
    let list: ListEntity
    @EnvironmentObject var lang: LanguageManager
    @State private var showEditSheet = false
    @State private var showHardAlert = false
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

                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Text(list.name)
                            .font(.system(size: 22, weight: .semibold))
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

                // Actions
                if list.protection != "hard" {
                    HStack(spacing: 12) {
                        Button(action: { showEditSheet = true }) {
                            Text(lang.isArabicEffective ? "تحرير" : "Edit")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(AppColors.accentDark)
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

private struct SoftDivider: View {
    let width: CGFloat
    let opacity: Double
    var body: some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(AppColors.uiBorder.opacity(opacity))
                .frame(width: width, height: 1)
            Spacer()
        }
        .padding(.vertical, 8)
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