import SwiftUI

struct AuthView: View {
    @EnvironmentObject var lang: LanguageManager
    @AppStorage("isAuthenticated") private var isAuthenticated: Bool = false
    @AppStorage("showOnboardingAfterLogin") private var showOnboardingAfterLogin: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "shield.lefthalf.fill")
                    .font(.system(size: 64))
                    .foregroundColor(AppColors.primaryBlue)

                Text(lang.isArabicEffective ? "سجّل دخولك للمتابعة" : "Sign in to continue")
                    .multilineTextAlignment(lang.isArabicEffective ? .trailing : .center)
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    Button(action: { handleSocial(provider: "apple") }) {
                        HStack {
                            Image(systemName: "apple.logo")
                            Text(lang.isArabicEffective ? "تابع عبر Apple" : "Continue with Apple")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    Button(action: { handleSocial(provider: "google") }) {
                        HStack {
                            Image(systemName: "globe")
                            Text(lang.isArabicEffective ? "تابع عبر Google" : "Continue with Google")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(.systemBackground))
                        .foregroundColor(.primary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)

                Spacer()

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

    private func handleSocial(provider: String) {
        // Mock auth for MVP
        isAuthenticated = true
        showOnboardingAfterLogin = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

#Preview {
    AuthView().environmentObject(LanguageManager.shared)
} 