import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var lang: LanguageManager
    @AppStorage(AppStorageKeys.isAuthenticated) private var isAuthenticated: Bool = false
    @AppStorage(AppStorageKeys.showOnboardingAfterLogin) private var showOnboardingAfterLogin: Bool = false
    @StateObject private var appleSignIn = AppleSignInCoordinator.shared

    @State private var mode: Int = 0 // 0=Sign in, 1=Sign up
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showForgotPasswordAlert: Bool = false

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
                    .font(.nnCardTitle)
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
                                    .foregroundColor(AppColors.accent)
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
                                .background(AppColors.accent)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }

                        if mode == 0 {
                            Button(action: { showForgotPasswordAlert = true }) {
                                Text(lang.isArabicEffective ? "نسيت كلمة المرور؟" : "Forgot password?")
                                    .font(.footnote)
                                    .foregroundColor(AppColors.accent)
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
                    SignInWithAppleButton(.continue,
                        onRequest: { request in
                            appleSignIn.configure(request: request)
                        },
                        onCompletion: { result in
                            if appleSignIn.handle(result: result) {
                                isAuthenticated = true
                                showOnboardingAfterLogin = true
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 48)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)

                // Local-only mode notice
                Text(lang.isArabicEffective
                     ? "ملاحظة: إنشاء الحساب بالبريد محلي فقط — لربط حساب فعلي استخدم Apple."
                     : "Note: email accounts are stored locally only. For a real account, sign in with Apple.")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer(minLength: 12)
            }
            .navigationTitle(lang.isArabicEffective ? "مرحبًا" : "Welcome")
            .background(AppColors.uiBackground)
            .alert(
                lang.isArabicEffective ? "استعادة كلمة المرور" : "Password recovery",
                isPresented: $showForgotPasswordAlert
            ) {
                Button(lang.isArabicEffective ? "تواصل مع الدعم" : "Contact support") {
                    if let url = URL(string: "mailto:support@nonet.app?subject=Password%20Recovery") {
                        UIApplication.shared.open(url)
                    }
                }
                Button(lang.isArabicEffective ? "إلغاء" : "Cancel", role: .cancel) {}
            } message: {
                Text(lang.isArabicEffective
                     ? "راسل فريق الدعم لاستعادة كلمة المرور."
                     : "Contact our support team to recover your password.")
            }
        }
    }

    private func primaryAction() {
        errorMessage = nil
        if !isValidEmail(email) {
            errorMessage = lang.isArabicEffective ? "صيغة البريد غير صحيحة." : "Invalid email format."
            return
        }
        if password.count < 6 {
            errorMessage = lang.isArabicEffective ? "كلمة المرور 6 أحرف على الأقل." : "Password must be at least 6 characters."
            return
        }
        // Local-only auth: persist state. Future iterations should call a real backend.
        isAuthenticated = true
        showOnboardingAfterLogin = (mode == 1) // only on sign-up
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Stricter than the previous `contains("@") && contains(".")` check.
    private func isValidEmail(_ s: String) -> Bool {
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }
}

#Preview {
    AuthView().environmentObject(LanguageManager.shared)
} 