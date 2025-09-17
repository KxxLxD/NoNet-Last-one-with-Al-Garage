import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var lang: LanguageManager
    @AppStorage("showOnboardingAfterLogin") private var showOnboardingAfterLogin: Bool = false

    @State private var page: Int = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                TabView(selection: $page) {
                    VStack(spacing: 16) {
                        Text(lang.isArabicEffective ? "حرّر نفسك من الإدمان" : "Free yourself from addiction")
                            .font(.title2).multilineTextAlignment(.center)
                        Text("✨")
                            .font(.system(size: 56))
                    }
                    .tag(0)

                    VStack(spacing: 16) {
                        Text(lang.isArabicEffective ? "اختر مدة الحجب وابدأ التركيز" : "Choose blocking duration and start focusing")
                            .font(.title2).multilineTextAlignment(.center)
                        Text("⏱️")
                            .font(.system(size: 56))
                    }
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button(action: { showOnboardingAfterLogin = false }) {
                    Text(lang.isArabicEffective ? "تم" : "Done")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.primaryBlue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                HStack(spacing: 12) {
                    Text(lang.isArabicEffective ? "اللغة:" : "Language:")
                    Picker("Language", selection: $lang.selected) {
                        Text(lang.isArabicEffective ? "النظام" : "System").tag(LanguageManager.LanguageOption.system)
                        Text("عربي").tag(LanguageManager.LanguageOption.arabic)
                        Text("English").tag(LanguageManager.LanguageOption.english)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle(lang.isArabicEffective ? "مرحبًا" : "Welcome")
        }
    }
}

#Preview {
    OnboardingView().environmentObject(LanguageManager.shared)
} 