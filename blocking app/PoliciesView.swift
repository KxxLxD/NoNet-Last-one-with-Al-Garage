import SwiftUI

struct PoliciesView: View {
    @EnvironmentObject var lang: LanguageManager
    @State private var selectedTab: Int = 0
    private var isArabic: Bool { lang.isArabicEffective }

    var body: some View {
        ZStack {
            AppColors.uiBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text(isArabic ? "الشروط" : "Terms").tag(0)
                    Text(isArabic ? "الخصوصية" : "Privacy").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.top, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: NNSpacing.sm) {
                        // Subtle hint that the body text is selectable —
                        // .textSelection has no visual affordance otherwise.
                        HStack(spacing: 6) {
                            Image(systemName: "text.cursor")
                                .font(.caption2)
                            Text(isArabic ? "اضغط مطوّلاً لتحديد ونسخ النص" : "Long-press to select and copy text")
                                .font(.caption)
                            Spacer(minLength: 0)
                            Text(isArabic ? "آخر تحديث: مايو 2026" : "Last updated: May 2026")
                                .font(.caption)
                        }
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.bottom, NNSpacing.xs)

                        Text(currentText)
                            .font(.body)
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(isArabic ? .trailing : .leading)
                            .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                            .textSelection(.enabled)
                    }
                    .padding(NNSpacing.lg)
                    .background(AppColors.uiSurface)
                    .cornerRadius(NNRadius.container)
                    .overlay(
                        RoundedRectangle(cornerRadius: NNRadius.container)
                            .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
                    )
                    .padding(.horizontal, NNSpacing.xl)
                    .padding(.top, NNSpacing.md)
                    .padding(.bottom, NNSpacing.xl)
                }
            }
        }
        .navigationTitle(isArabic ? "السياسات والشروط" : "Policies & Terms")
    }

    private var currentText: String {
        if selectedTab == 0 {
            return isArabic ? LegalContent.termsArabic : LegalContent.termsEnglish
        } else {
            return isArabic ? LegalContent.privacyArabic : LegalContent.privacyEnglish
        }
    }
}

#Preview {
    NavigationView { PoliciesView().environmentObject(LanguageManager.shared) }
}
