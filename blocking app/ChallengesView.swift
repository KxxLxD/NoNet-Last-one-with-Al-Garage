import SwiftUI

struct ChallengesView: View {
    @EnvironmentObject var lang: LanguageManager
    @State private var showFooter: Bool = false
    @State private var totalPoints: Int = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(lang.isArabicEffective ? "التحديات" : "Challenges")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text(lang.isArabicEffective ? "اختر ما يناسبك واربح نقاطًا ترفع مستواك." : "Pick what suits you and earn points to level up.")
                    .font(.body)
                    .foregroundColor(AppColors.textSecondary)

                ChallengeChipsCard(title: lang.isArabicEffective ? "حظر المحتوى للبالغين والمواعدة والقمار" : "Adult/Dating/Gambling",
                                     description: lang.isArabicEffective ? "إيقاف دائم" : "Block forever",
                                     options: [.option(label: lang.isArabicEffective ? "حظر دائم" : "Block forever", points: 60)],
                                     onChange: apply)

                ChallengeChipsCard(title: lang.isArabicEffective ? "التقليل من المقاطع القصيرة" : "Shorts/Video time",
                                     description: lang.isArabicEffective ? "حدّد وقتك" : "Set your limit",
                                     options: timeOptions(), onChange: apply)

                ChallengeChipsCard(title: lang.isArabicEffective ? "التقليل من شبكات التواصل" : "Social media time",
                                     description: lang.isArabicEffective ? "حدّد وقتك" : "Set your limit",
                                     options: timeOptions(), onChange: apply)

                SleepChallengeCard(lang: lang, onChange: apply)

                ChallengeChipsCard(title: lang.isArabicEffective ? "ألعاب" : "Games",
                                     description: lang.isArabicEffective ? "حدّد وقتك" : "Set your limit",
                                     options: timeOptions(), onChange: apply)

                ChallengeChipsCard(title: lang.isArabicEffective ? "تسوّق وتوصيل" : "Shopping & Delivery",
                                     description: lang.isArabicEffective ? "حدّد وقتك/الأيام" : "Set time/days",
                                     options: timeOptions(), onChange: apply)

                ChallengeChipsCard(title: lang.isArabicEffective ? "إشعارات أقل" : "Fewer notifications",
                                     description: lang.isArabicEffective ? "أوقف المشتّتات في العمل" : "Mute distractors during work",
                                     options: [.option(label: "4h", points: 10), .option(label: "8h", points: 20), .option(label: lang.isArabicEffective ? "أيام العمل" : "Workdays", points: 30), .option(label: lang.isArabicEffective ? "دائمًا" : "Always", points: 40)],
                                     onChange: apply)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, showFooter ? 120 : 28)
            .background(AppColors.uiBackground)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            if showFooter {
                Footer(totalPoints: totalPoints, lang: lang)
            }
        }
    }

    private func apply(_ added: Int) {
        totalPoints = max(0, totalPoints + added)
        if totalPoints > 0 { showFooter = true }
    }

    private func timeOptions() -> [ChallengeOption] {
        [
            .option(label: "4h", points: 10),
            .option(label: "2h", points: 20),
            .option(label: "1h", points: 30),
            .option(label: lang.isArabicEffective ? "حظر دائم" : "Block", points: 50)
        ]
    }
}

private struct Footer: View {
    let totalPoints: Int
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
            Button(action: {}) {
                Text(lang.isArabicEffective ? "تطبيق التغييرات" : "Apply changes")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppColors.accentDark)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(AppColors.uiSurface)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundColor(AppColors.uiBorder), alignment: .top
        )
    }
}

private enum ChallengeOption: Hashable { case option(label: String, points: Int) }

private struct ChallengeChipsCard: View {
    let title: String
    let description: String
    let options: [ChallengeOption]
    var onChange: (Int) -> Void
    @State private var selected: ChallengeOption? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            Text(description)
                .font(.body)
                .foregroundColor(AppColors.textSecondary)
            WrapChips(options: options, selected: $selected) { opt in
                if case let .option(_, pts) = opt { onChange(pts) }
            }
        }
        .padding(20)
        .background(AppColors.uiSurface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.uiBorder, lineWidth: 0.5)
        )
    }
}

private struct WrapChips<Option: Hashable>: View {
    let options: [Option]
    @Binding var selected: Option?
    var onPick: (Option) -> Void

    var body: some View {
        FlowLayout(alignment: .leading, spacing: 8) {
            ForEach(options, id: \..self) { opt in
                Button(action: { selected = opt; onPick(opt) }) {
                    Text(label(for: opt))
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selected == opt ? AppColors.accentDark : AppColors.uiSurface)
                        .foregroundColor(selected == opt ? .white : AppColors.textPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10).stroke(AppColors.uiBorder, lineWidth: 0.5)
                        )
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func label(for opt: Option) -> String {
        if let c = opt as? ChallengeOption {
            switch c { case let .option(label, _): return label }
        }
        return "" // generic
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
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            Text(lang.isArabicEffective ? "اقتراح: 8م → 8ص (كل الأيام). يمكنك التعديل." : "Suggestion: 8pm → 8am (every day). You can edit.")
                .font(.body)
                .foregroundColor(AppColors.textSecondary)
            HStack(spacing: 12) {
                DatePicker(lang.isArabicEffective ? "من" : "From", selection: $from, displayedComponents: .hourAndMinute)
                DatePicker(lang.isArabicEffective ? "إلى" : "To", selection: $to, displayedComponents: .hourAndMinute)
            }
            Toggle(lang.isArabicEffective ? "كل الأيام" : "Every day", isOn: $allDays)
                .tint(AppColors.accentDark)
            Button(action: { onChange(40) }) {
                Text(lang.isArabicEffective ? "اعتمد هذه الأوقات" : "Apply these times")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(height: 36)
                    .padding(.horizontal, 12)
                    .background(AppColors.accentDark)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding(20)
        .background(AppColors.uiSurface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.uiBorder, lineWidth: 0.5)
        )
    }
}

// Simple flow layout for chips
private struct FlowLayout<Content: View>: View {
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    let content: () -> Content

    init(alignment: HorizontalAlignment, spacing: CGFloat, @ViewBuilder content: @escaping () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: spacing)], alignment: alignment, spacing: spacing) {
            content()
        }
    }
}

#Preview {
    ChallengesView().environmentObject(LanguageManager.shared)
} 