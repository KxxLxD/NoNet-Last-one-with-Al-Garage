import SwiftUI

struct AuthView: View {
    @EnvironmentObject var lang: LanguageManager
    @AppStorage("isAuthenticated") private var isAuthenticated: Bool = false
    @AppStorage("showOnboardingAfterLogin") private var showOnboardingAfterLogin: Bool = false

    @State private var mode: Int = 0 // 0=Sign in, 1=Sign up
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Spacer(minLength: 12)
                Image("nonet_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .padding(.top, 12)

                Text(lang.isArabicEffective ? "سجّل دخولك أو أنشئ حسابًا" : "Sign in or create an account")
                    .font(.system(size: 20, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    Picker("", selection: $mode) {
                        Text(lang.isArabicEffective ? "دخول" : "Sign in").tag(0)
                        Text(lang.isArabicEffective ? "تسجيل" : "Sign up").tag(1)
                    }
                    .pickerStyle(.segmented)

                    VStack(spacing: 12) {
                        // Email field
                        TextField(lang.isArabicEffective ? "البريد الإلكتروني" : "Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled(true)
                            .padding(12)
                            .background(AppColors.uiSurface)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.uiBorder, lineWidth: 0.5))

                        // Password field
                        ZStack(alignment: .trailing) {
                            Group {
                                if showPassword {
                                    TextField(lang.isArabicEffective ? "كلمة المرور" : "Password", text: $password)
                                } else {
                                    SecureField(lang.isArabicEffective ? "كلمة المرور" : "Password", text: $password)
                                }
                            }
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .padding(12)
                            .background(AppColors.uiSurface)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.uiBorder, lineWidth: 0.5))

                            Button(action: { showPassword.toggle() }) {
                                Text(showPassword ? (lang.isArabicEffective ? "إخفاء" : "Hide") : (lang.isArabicEffective ? "إظهار" : "Show"))
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(AppColors.accentDark)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(AppColors.infoBg)
                                    .cornerRadius(8)
                            }
                            .padding(.trailing, 8)
                        }

                        if let err = errorMessage, !err.isEmpty {
                            Text(err)
                                .font(.footnote)
                                .foregroundColor(AppColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: primaryAction) {
                            Text(mode == 0 ? (lang.isArabicEffective ? "تسجيل الدخول" : "Sign in") : (lang.isArabicEffective ? "إنشاء حساب" : "Create account"))
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(AppColors.accentDark)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }

                        if mode == 0 {
                            Button(action: { /* forgot password action */ }) {
                                Text(lang.isArabicEffective ? "نسيت كلمة المرور؟" : "Forgot password?")
                                    .font(.footnote)
                                    .foregroundColor(AppColors.accentDark)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Text(lang.isArabicEffective ? "بالتسجيل، أنت توافق على السياسات والشروط." : "By signing up, you agree to the policies and terms.")
                                .font(.footnote)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(16)
                .background(AppColors.uiSurface)
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
                .padding(.horizontal, 24)

                // OR divider
                HStack {
                    Rectangle().fill(AppColors.uiBorder.opacity(0.5)).frame(height: 1)
                    Text(lang.isArabicEffective ? "أو" : "OR").font(.caption).foregroundColor(AppColors.textSecondary)
                    Rectangle().fill(AppColors.uiBorder.opacity(0.5)).frame(height: 1)
                }
                .padding(.horizontal, 24)

                // Social buttons
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
                .padding(.horizontal, 24)

                Spacer(minLength: 12)
            }
            .navigationTitle(lang.isArabicEffective ? "مرحبًا" : "Welcome")
            .background(AppColors.uiBackground)
        }
    }

    private func primaryAction() {
        errorMessage = nil
        let isValidEmail = email.contains("@") && email.contains(".")
        let isValidPassword = password.count >= 6
        if !isValidEmail {
            errorMessage = lang.isArabicEffective ? "صيغة البريد غير صحيحة." : "Invalid email format."
            return
        }
        if !isValidPassword {
            errorMessage = lang.isArabicEffective ? "كلمة المرور 6 أحرف على الأقل." : "Password must be at least 6 characters."
            return
        }
        handleSocial(provider: mode == 0 ? "signin" : "signup")
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