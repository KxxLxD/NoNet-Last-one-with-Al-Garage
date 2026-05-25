import SwiftUI

struct ChallengesView: View {
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @State private var showFooter: Bool = false
    @State private var totalPoints: Int = 0
    @State private var level: Int = 1
    @State private var nextLevelPoints: Int = 200

    var body: some View {
        VStack(spacing: 0) {
            header()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    pointsCard()
                    Text(lang.isArabicEffective ? "التحديات" : "Challenges")
                        .font(.nnSectionTitle)
                        .foregroundColor(AppColors.textPrimary)
                    Text(lang.isArabicEffective ? "اختر تحديات تكسب بها نقاطاً ثم احفظ." : "Pick challenges to earn points, then save.")
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)

                    ChallengeCardCompact(
                        title: lang.isArabicEffective ? "حجب المحتوى للبالغين والمواعدة والقمار" : "Adult/Dating/Gambling",
                        description: lang.isArabicEffective ? "إيقاف دائم" : "Block forever",
                        options: simpleOptions([lang.isArabicEffective ? "حجب دائم" : "Block forever"], pts: [60]),
                        onChange: apply
                    )

                    ChallengeCardCompact(
                        title: lang.isArabicEffective ? "التقليل من المقاطع القصيرة" : "Shorts/Video time",
                        description: lang.isArabicEffective ? "حدّد وقتك" : "Set your limit",
                        options: timeOptions(), onChange: apply
                    )

                    ChallengeCardCompact(
                        title: lang.isArabicEffective ? "التقليل من شبكات التواصل" : "Social media time",
                        description: lang.isArabicEffective ? "حدّد وقتك" : "Set your limit",
                        options: timeOptions(), onChange: apply
                    )

                    SoftDivider(width: 300, opacity: 0.70)

                    SleepChallengeCard(lang: lang, onChange: apply)

                    SoftDivider(width: 300, opacity: 0.70)

                    ChallengeCardCompact(
                        title: lang.isArabicEffective ? "ألعاب" : "Games",
                        description: lang.isArabicEffective ? "حدّد وقتك" : "Set your limit",
                        options: timeOptions(), onChange: apply
                    )

                    ChallengeCardCompact(
                        title: lang.isArabicEffective ? "تسوّق وتوصيل" : "Shopping & Delivery",
                        description: lang.isArabicEffective ? "حدّد وقتك/الأيام" : "Set time/days",
                        options: timeOptions(), onChange: apply
                    )

                    ChallengeCardCompact(
                        title: lang.isArabicEffective ? "إشعارات أقل" : "Fewer notifications",
                        description: lang.isArabicEffective ? "اسكت المشتّتات" : "Mute distractors",
                        options: simpleOptions(["4h","8h", lang.isArabicEffective ? "أيام العمل" : "Workdays", lang.isArabicEffective ? "دائماً" : "Always"], pts: [10,20,30,40]),
                        onChange: apply
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, showFooter ? 120 : 28)
                .background(AppColors.uiBackground)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            if showFooter {
                Footer(totalPoints: totalPoints, onDone: { dismiss() }, lang: lang)
            }
        }
    }

    private func header() -> some View {
        HStack {
            Button(action: { dismiss() }) {
                Text(lang.isArabicEffective ? "إغلاق" : "Close")
                    .font(.subheadline)
                    .foregroundColor(AppColors.accent)
            }
            Spacer()
            Button(action: { dismiss() }) {
                Text(lang.isArabicEffective ? "تم" : "Done")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(AppColors.uiSurface)
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(AppColors.uiBorder), alignment: .bottom)
    }

    private func pointsCard() -> some View {
        let progress = min(1.0, Double(totalPoints % nextLevelPoints) / Double(nextLevelPoints))
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text((lang.isArabicEffective ? "النقاط" : "Points") + ": \(totalPoints)")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text((lang.isArabicEffective ? "المستوى" : "Level") + ": \(level)")
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
            ZStack(alignment: .leading) {
                Capsule().fill(AppColors.uiBorder.opacity(0.6)).frame(height: 8)
                Capsule().fill(AppColors.accent).frame(width: CGFloat(progress) * UIScreen.main.bounds.width * 0.6, height: 8)
            }
        }
        .padding(16)
        .background(AppColors.uiSurface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.uiBorder, lineWidth: 0.5))
    }

    private func apply(_ added: Int) {
        totalPoints = max(0, totalPoints + added)
        if totalPoints >= nextLevelPoints { level += 1; totalPoints = 0 }
        if level >= 1 { showFooter = true }
    }

    private func timeOptions() -> [ChallengeOption] {
        [
            .option(label: "4h", points: 10),
            .option(label: "2h", points: 20),
            .option(label: "1h", points: 30),
            .option(label: lang.isArabicEffective ? "حجب دائم" : "Block", points: 50)
        ]
    }

    private func simpleOptions(_ labels: [String], pts: [Int]) -> [ChallengeOption] {
        zip(labels, pts).map { .option(label: $0.0, points: $0.1) }
    }
}

private enum ChallengeOption: Hashable { case option(label: String, points: Int) }

private struct ChallengeCardCompact: View {
    let title: String
    let description: String
    let options: [ChallengeOption]
    var onChange: (Int) -> Void
    @State private var selected: ChallengeOption? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.nnSubheader.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
            Text(description)
                .font(.footnote)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
            ChipGrid(options: options, selected: $selected) { opt in if case let .option(_, p) = opt { onChange(p) } }
        }
        .padding(16)
        .background(AppColors.uiSurface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.uiBorder, lineWidth: 0.5))
    }
}

private struct ChipGrid: View {
    let options: [ChallengeOption]
    @Binding var selected: ChallengeOption?
    var onPick: (ChallengeOption) -> Void

    private var columns: [GridItem] { [GridItem(.adaptive(minimum: 120), spacing: 8)] }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(options, id: \.self) { opt in
                let isSel = selected == opt
                Button(action: { selected = opt; onPick(opt) }) {
                    Text(label(for: opt))
                        .font(.nnSmallButton)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSel ? AppColors.accent : AppColors.uiSurface)
                        .foregroundColor(isSel ? .white : AppColors.textPrimary)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.uiBorder, lineWidth: isSel ? 0 : 0.5))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func label(for opt: ChallengeOption) -> String {
        if case let .option(label, _) = opt { return label }
        return ""
    }
}

private struct SleepChallengeCard: View {
    @ObservedObject var lang: LanguageManager
    var onChange: (Int) -> Void
    @State private var from: Date = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var to: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var allDays: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang.isArabicEffective ? "نوم بلا إنترنت" : "No‑Internet Sleep")
                .font(.nnSubheader.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
            Text(lang.isArabicEffective ? "اقتراح: 8م → 8ص (كل الأيام). يمكنك التعديل." : "Suggestion: 8pm → 8am (every day). You can edit.")
                .font(.footnote)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
            HStack(spacing: 12) {
                DatePicker(lang.isArabicEffective ? "من" : "From", selection: $from, displayedComponents: .hourAndMinute)
                DatePicker(lang.isArabicEffective ? "إلى" : "To", selection: $to, displayedComponents: .hourAndMinute)
            }
            Toggle(lang.isArabicEffective ? "كل الأيام" : "Every day", isOn: $allDays)
                .tint(AppColors.accent)
            Button(action: { onChange(40) }) {
                Text(lang.isArabicEffective ? "اعتمد هذه الأوقات" : "Apply these times")
                    .font(.nnSmallButton)
                    .frame(height: 36)
                    .padding(.horizontal, 12)
                    .background(AppColors.accent)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding(16)
        .background(AppColors.uiSurface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.uiBorder, lineWidth: 0.5)
        )
    }
}

private struct Footer: View {
    let totalPoints: Int
    let onDone: () -> Void
    @ObservedObject var lang: LanguageManager
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text((lang.isArabicEffective ? "النقاط: " : "Points: ") + "\(totalPoints)")
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text(lang.isArabicEffective ? "Lv 1 → Lv 2" : "Lv 1 → Lv 2")
                    .foregroundColor(AppColors.textSecondary)
            }
            Button(action: onDone) {
                Text(lang.isArabicEffective ? "حفظ وإغلاق" : "Save & close")
                    .font(.nnButton)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppColors.accent)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(AppColors.uiSurface)
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(AppColors.uiBorder), alignment: .top)
    }
}

#Preview {
    ChallengesView().environmentObject(LanguageManager.shared)
} 