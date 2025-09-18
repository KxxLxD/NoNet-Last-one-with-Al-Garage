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

    // حالة الاشتراك/التجربة
    @AppStorage("isPremium") private var isPremium: Bool = false
    @AppStorage("trialStartTs") private var trialStartTs: Double = 0
    @AppStorage("selectedTab") private var selectedTab: Int = 0
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

    @State private var showFAQ: Bool = false
    
    // Permission states
    @State private var hasScreenTimePermission: Bool = false
    @State private var hasNotificationPermission: Bool = false
    @State private var permissionsExpanded: Bool = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Hero
                    VStack(spacing: 12) {
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
                    SoftDivider(width: 300, opacity: 0.70)

                                        // Stats cards
                    HStack(spacing: 12) {
                        SavedCycleCard(lang: lang)
                        StatsCard(value: "1", label: AppStrings.levelLabel(lang))
                        ChallengesSimpleCard(lang: lang, value: "7")
                    }
                    SoftDivider(width: 300, opacity: 0.70)

                                        // Share progress
                    Button(action: { /* share placeholder */ }) {
                        Text(lang.isArabicEffective ? "مشاركة" : "Share")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(AppColors.accentDark)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    SoftDivider(width: 300, opacity: 0.70)

                    // Create Blocklist Card
                    CreateBlocklistCard(lang: lang, useGradientCTA: false) {
                        showingCreate = true
                    }
                    .sheet(isPresented: $showingCreate) {
                        CreateListSheet().environmentObject(lang)
                    }
                    SoftDivider(width: 300, opacity: 0.70)

                    // Permissions (collapsed card)
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
                                        Button(action: { /* request notifications */ }) {
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

                    // Lists
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(lang.isArabicEffective ? "قوائمك" : "Your Lists")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                        }

                        if lists.isEmpty {
                            EmptyStateView(isArabic: lang.isArabicEffective)
                        } else {
                            VStack(spacing: 0) {
                                VStack(spacing: 0) {
                                // Active lists first
                                ForEach(activeLists) { item in
                                    NavigationLink(destination: ListDetailView(list: item)) {
                                            RealListRow(item: item, isActive: true)
                                    }
                                        if item.id != activeLists.last?.id || !nonActiveLists.isEmpty {
                                            SoftDivider(width: 300, opacity: 0.70)
                                            }
                                        }
                                // Non-active lists
                                ForEach(nonActiveLists) { item in
                                    NavigationLink(destination: ListDetailView(list: item)) {
                                            RealListRow(item: item, isActive: false)
                                    }
                                        if item.id != nonActiveLists.last?.id {
                                            SoftDivider(width: 300, opacity: 0.70)
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
                            context.delete(toDelete)
                            try? context.save()
                        }
                        listToDelete = nil
                    },
                    secondaryButton: .cancel(Text(lang.isArabicEffective ? "إلغاء" : "Cancel")) {
                        listToDelete = nil
                    }
                )
            }
            .sheet(isPresented: $showFAQ) {
                FAQView().environmentObject(lang)
            }
            .onAppear {
                checkPermissions()
            }
        }
    }
    
    private func checkPermissions() {
        // Check Screen Time permission
        if #available(iOS 16.0, *) {
            Task {
                let status = await AuthorizationCenter.shared.authorizationStatus
                await MainActor.run {
                    hasScreenTimePermission = (status == .approved)
                }
            }
        }
        
        // Check Notification permission
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                hasNotificationPermission = (settings.authorizationStatus == .authorized)
            }
        }
    }

    private func isActiveNow(_ l: ListEntity) -> Bool {
        let now = Date()
        if l.blockType == "now" {
            let end = l.createdAt.addingTimeInterval(TimeInterval(l.durationSeconds))
            return now < end
        }
        if l.blockType == "scheduled" {
            guard let data = l.scheduleSlots, let slots = try? JSONDecoder().decode([ScheduleSlot].self, from: data) else { return false }
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

    @Environment(\.layoutDirection) private var layoutDirection
    @EnvironmentObject private var lang: LanguageManager

    // Local decode model for schedule slots
    private struct Slot: Codable { let id: UUID; let day: Int; let fromMinutes: Int; let toMinutes: Int }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: layoutDirection == .rightToLeft ? .trailing : .leading, spacing: 8) {
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                HStack(spacing: 8) {
                    if let schedule = scheduleSummaryBadged() {
                        Badge(icon: "calendar", text: schedule, style: .neutral)
                    }
                    ProtectionBadge(isHard: item.protection == "hard", isRTL: layoutDirection == .rightToLeft)
                    if let c = item.items?.count {
                        Badge(icon: "list.bullet", text: itemsCountText(c), style: .neutral)
                    }
                }
            }
            Spacer()
            if isActive {
                Text(layoutDirection == .rightToLeft ? "استئناف" : "Resume")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(AppColors.infoFg)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(AppColors.infoBg)
                    .cornerRadius(8)
            }
        }
        .padding(20)
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

    private func scheduleSummaryBadged() -> String? {
        if item.blockType == "scheduled", let data = item.scheduleSlots, let slots = try? JSONDecoder().decode([Slot].self, from: data), let summary = scheduleSummary(slots) {
            return summary
        }
        return nil
    }

    private func subtitleText() -> String? { /* kept for potential future use */
        if item.blockType == "now" && isActive {
            let end = item.createdAt.addingTimeInterval(TimeInterval(item.durationSeconds))
            let remaining = Int(max(0, end.timeIntervalSince(Date())))
            if remaining <= 0 { return nil }
            return (layoutDirection == .rightToLeft ? "ينتهي خلال " : "Ends in ") + format(remaining)
        }
        if item.blockType == "scheduled", let data = item.scheduleSlots {
            if let slots = try? JSONDecoder().decode([Slot].self, from: data) {
                if let summary = scheduleSummary(slots) { return summary }
                let cnt = slots.count
                return layoutDirection == .rightToLeft ? "جدولة: \(cnt) فترات" : "Scheduled: \(cnt) slots"
            }
        }
        return nil
    }

    private func scheduleSummary(_ slots: [Slot]) -> String? {
        guard !slots.isEmpty else { return nil }
        let uniqueTimes = Set(slots.map { "\($0.fromMinutes)-\($0.toMinutes)" })
        guard uniqueTimes.count == 1 else { return nil }
        let from = slots.first!.fromMinutes
        let to = slots.first!.toMinutes
        let days = Array(Set(slots.map { $0.day })).sorted()
        let daysDesc: String
        if isContiguous(days) && days.count >= 2 {
            daysDesc = dayShortName(days.first!) + "–" + dayShortName(days.last!)
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
        .frame(height: 100)
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
            VStack(spacing: 8) {
                Text(value)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundColor(AppColors.textPrimary)
                Text(AppStrings.challengesLabel(lang))
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .frame(height: 100)
            .background(AppColors.uiSurface)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppColors.uiBorder, lineWidth: 0.5)
            )
            NavigationLink(destination: ChallengesView().environmentObject(lang)) {
                Image(systemName: "plus")
                    .foregroundColor(AppColors.accentDark)
                    .frame(width: 24, height: 24)
                    .background(AppColors.infoBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
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
        .frame(height: 100)
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

struct ListDetailView: View {
    let list: ListEntity
    @EnvironmentObject var lang: LanguageManager
    @State private var showEditSheet = false
    @State private var showHardAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(list.name)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            HStack(spacing: 12) {
                Text((lang.isArabicEffective ? "النوع:" : "Type:") + " \(list.blockType)")
                    .foregroundColor(AppColors.textSecondary)
                Text((lang.isArabicEffective ? "الحماية:" : "Protection:") + " \(list.protection)")
                    .foregroundColor(AppColors.textSecondary)
            }
            if list.blockType == "now" {
                Text((lang.isArabicEffective ? "المدة:" : "Duration:") + " \(list.durationSeconds/60) min")
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer(minLength: 0)

            Button(action: {
                if list.protection == "hard" { showHardAlert = true } else { showEditSheet = true }
            }) {
                Text(lang.isArabicEffective ? "تحرير القائمة" : "Edit List")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppColors.accentDark)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding(24)
        .background(AppColors.uiBackground)
        .navigationTitle(lang.isArabicEffective ? "التفاصيل" : "Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditSheet) {
            NavigationView { CreateListSheet().environmentObject(lang) }
                .padding(16)
        }
        .alert(lang.isArabicEffective ? "غير مسموح" : "Not Allowed", isPresented: $showHardAlert) {
            Button(lang.isArabicEffective ? "حسنًا" : "OK", role: .cancel) {}
        } message: {
            Text(lang.isArabicEffective ? "هذه القائمة في الوضع الصارم — لا يمكن تعديلها أو حذفها الآن." : "This list is in Hard Mode — editing is disabled.")
        }
    }
}

extension ListEntity: Identifiable {}

#Preview {
    HomeView().environmentObject(LanguageManager.shared)
}

// MARK: - Actions
private extension HomeView {
    func requestScreenTimeAuth() {
        if #available(iOS 16.0, *) {
            Task { _ = try? await AuthorizationCenter.shared.requestAuthorization(for: .individual) }
        }
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