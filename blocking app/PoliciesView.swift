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
                    VStack(alignment: .leading, spacing: 12) {
                        Text(currentText)
                            .font(.body)
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(isArabic ? .trailing : .leading)
                            .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                            .textSelection(.enabled)
                    }
                    .padding(16)
                    .background(AppColors.uiSurface)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
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
