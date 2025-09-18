import SwiftUI

struct PoliciesView: View {
    @EnvironmentObject var lang: LanguageManager
    private var isArabic: Bool { lang.isArabicEffective }

    var body: some View {
        ZStack {
            AppColors.uiBackground.ignoresSafeArea()
        ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                        Text(isArabic ? "الشروط والأحكام" : "Terms & Conditions").font(.headline).foregroundColor(AppColors.textPrimary)
                    Text(isArabic ? "نص تجريبي – سيتم تحديث المحتوى لاحقًا." : "Placeholder text – content to be updated later.")
                            .foregroundColor(AppColors.textSecondary)
                }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(AppColors.uiSurface)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
                    .padding(.horizontal, 24)

                    SoftDivider()
                        .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 8) {
                        Text(isArabic ? "سياسة الخصوصية" : "Privacy Policy").font(.headline).foregroundColor(AppColors.textPrimary)
                    Text(isArabic ? "نص تجريبي – سيتم تحديث المحتوى لاحقًا." : "Placeholder text – content to be updated later.")
                            .foregroundColor(AppColors.textSecondary)
                }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(AppColors.uiSurface)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
                    .padding(.horizontal, 24)
            }
                .padding(.top, 16)
            }
        }
        .navigationTitle(isArabic ? "السياسات والشروط" : "Policies & Terms")
    }
}

private struct SoftDivider: View {
    var body: some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(AppColors.uiBorder.opacity(0.70))
                .frame(width: 300, height: 1)
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationView { PoliciesView().environmentObject(LanguageManager.shared) }
} 