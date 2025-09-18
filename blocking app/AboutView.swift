import SwiftUI

struct AboutView: View {
    @EnvironmentObject var lang: LanguageManager
    private var isArabic: Bool { lang.isArabicEffective }

    private var appName: String { isArabic ? "نونِت" : "NoNet" }
    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return isArabic ? "الإصدار \(v)" : "Version \(v)"
    }

    var body: some View {
        ZStack {
            AppColors.uiBackground.ignoresSafeArea()
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                        HStack { Text(isArabic ? "الاسم" : "Name").foregroundColor(AppColors.textPrimary); Spacer(); Text(appName).foregroundColor(AppColors.textSecondary) }
                        HStack { Text(isArabic ? "الإصدار" : "Version").foregroundColor(AppColors.textPrimary); Spacer(); Text(versionString).foregroundColor(AppColors.textSecondary) }
            }
                    .padding(16)
                    .background(AppColors.uiSurface)
                    .cornerRadius(20)
                .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppColors.uiBorder, lineWidth: 0.5)
                )
                    .padding(.horizontal, 24)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle(isArabic ? "عن التطبيق" : "About App")
    }
}

#Preview {
    NavigationView { AboutView().environmentObject(LanguageManager.shared) }
} 