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
    #if DEBUG
    @AppStorage(AppStorageKeys.isPremium) private var isPremium: Bool = false
    @AppStorage(AppStorageKeys.isAdmin) private var isAdmin: Bool = false
    #endif
    /// Sign-up only: ensures the user can repeat the password they just chose
    /// (catches typos that would otherwise lock them out, since this app has
    /// no email-based password recovery).
    @State private var passwordConfirm: String = ""
    @State private var showPassword: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showForgotPasswordAlert: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: NNSpacing.md) {
                Spacer(minLength: NNSpacing.sm)
                ZStack {
                    Circle()
                        .fill(AppColors.infoBg)
                        .frame(width: 96, height: 96)
                    Image("nonet_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .accessibilityHidden(true)
                }
                .padding(.top, NNSpacing.sm)

                Text(lang.isArabicEffective ? "سجّل دخولك أو أنشئ حساباً" : "Sign in or create an account")
                    .font(.nnCardTitle)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, NNSpacing.md)

                VStack(alignment: .leading, spacing: NNSpacing.sm) {
                    Picker("", selection: $mode) {
                        Text(lang.isArabicEffective ? "دخول" : "Sign in").tag(0)
                        Text(lang.isArabicEffective ? "تسجيل" : "Sign up").tag(1)
                    }
                    .pickerStyle(.segmented)

                    VStack(spacing: NNSpacing.sm) {
                        // Email field
                        TextField(lang.isArabicEffective ? "البريد الإلكتروني" : "Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled(true)
                            .padding(NNSpacing.sm)
                            .background(AppColors.uiSurface)
                            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                            .overlay(
                                RoundedRectangle(cornerRadius: NNRadius.control)
                                    .stroke(AppColors.uiBorder, lineWidth: NNBorder.input)
                            )

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
                            .padding(NNSpacing.sm)
                            .background(AppColors.uiSurface)
                            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                            .overlay(
                                RoundedRectangle(cornerRadius: NNRadius.control)
                                    .stroke(AppColors.uiBorder, lineWidth: NNBorder.input)
                            )

                            Button(action: { showPassword.toggle() }) {
                                Text(showPassword ? (lang.isArabicEffective ? "إخفاء" : "Hide") : (lang.isArabicEffective ? "إظهار" : "Show"))
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(AppColors.accent)
                                    .padding(.horizontal, NNSpacing.xs + 2)
                                    .padding(.vertical, NNSpacing.xxs + 2)
                                    .background(AppColors.infoBg)
                                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.chip))
                            }
                            .padding(.trailing, NNSpacing.xs)
                            .accessibilityLabel(showPassword
                                                ? (lang.isArabicEffective ? "إخفاء كلمة المرور" : "Hide password")
                                                : (lang.isArabicEffective ? "إظهار كلمة المرور" : "Show password"))
                        }

                        // Sign-up: confirm password + live strength indicator.
                        // Doing this conditionally keeps the sign-in surface
                        // uncluttered for the common case (returning user).
                        if mode == 1 {
                            SecureField(lang.isArabicEffective ? "تأكيد كلمة المرور" : "Confirm password", text: $passwordConfirm)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .padding(NNSpacing.sm)
                                .background(AppColors.uiSurface)
                                .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                                .overlay(
                                    RoundedRectangle(cornerRadius: NNRadius.control)
                                        .stroke(AppColors.uiBorder, lineWidth: NNBorder.input)
                                )

                            passwordStrengthBar
                        }

                        if let err = errorMessage, !err.isEmpty {
                            Text(err)
                                .font(.footnote)
                                .foregroundColor(AppColors.alertRed)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: primaryAction) {
                            Text(mode == 0 ? (lang.isArabicEffective ? "تسجيل الدخول" : "Sign in") : (lang.isArabicEffective ? "إنشاء حساب" : "Create account"))
                                .font(.nnButton)
                                .frame(maxWidth: .infinity)
                                .frame(height: NNHitTarget.minimum + 4)
                                .background(AppColors.accent)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                        }

                        if mode == 0 {
                            Button(action: { showForgotPasswordAlert = true }) {
                                Text(lang.isArabicEffective ? "تواصل مع الدعم لاستعادة الحساب" : "Contact support to recover account")
                                    .font(.footnote)
                                    .foregroundColor(AppColors.accent)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .accessibilityHint(lang.isArabicEffective ? "يفتح بريدك لإرسال رسالة دعم" : "Opens your email to send a support message")
                        } else {
                            Text(lang.isArabicEffective ? "بالتسجيل، أنت توافق على السياسات والشروط." : "By signing up, you agree to the policies and terms.")
                                .font(.footnote)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(NNSpacing.md)
                .background(AppColors.uiSurface)
                .clipShape(RoundedRectangle(cornerRadius: NNRadius.container))
                .overlay(
                    RoundedRectangle(cornerRadius: NNRadius.container)
                        .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
                )
                .padding(.horizontal, NNSpacing.xl)

                // OR divider — hairline weight matches every other divider in the app.
                HStack(spacing: NNSpacing.xs) {
                    Rectangle().fill(AppColors.uiBorder.opacity(0.5)).frame(maxHeight: NNBorder.hairline)
                    Text(lang.isArabicEffective ? "أو" : "OR")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Rectangle().fill(AppColors.uiBorder.opacity(0.5)).frame(maxHeight: NNBorder.hairline)
                }
                .padding(.horizontal, NNSpacing.xl)

                // Social buttons
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
                .frame(height: NNHitTarget.minimum + 4)
                .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                .padding(.horizontal, NNSpacing.xl)

                // Local-only mode notice — promoted from a quiet caption to
                // an info banner so users see the trade-off clearly before
                // signing up with email (no recovery, no cross-device sync).
                InfoBanner(
                    icon: "info.circle.fill",
                    title: lang.isArabicEffective ? "حسابات البريد محلية" : "Email accounts are local",
                    detail: lang.isArabicEffective
                         ? "تبقى على هذا الجهاز فقط. لا تستعيد كلمة المرور إن نسيتها — استخدم Apple إن أردت حساباً قابلاً للاستعادة."
                         : "They live only on this device — no recovery if you forget the password. Use Apple for a recoverable account.",
                    tone: .info
                )
                .padding(.horizontal, NNSpacing.xl)

                Spacer(minLength: NNSpacing.sm)
            }
            .navigationTitle(lang.isArabicEffective ? "مرحباً" : "Welcome")
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

    /// 3-segment bar that reflects passwordStrength(). Empty pw = all gray.
    /// Each filled segment uses red/amber/green depending on tier so the user
    /// sees immediate feedback as they type. Sign-up only.
    @ViewBuilder
    private var passwordStrengthBar: some View {
        let score = passwordStrength(password)
        let color: Color = {
            switch score {
            case 0, 1: return AppColors.alertRed
            case 2:    return AppColors.warningFg
            default:   return AppColors.successGreen
            }
        }()
        let label: String = {
            switch score {
            case 0:    return lang.isArabicEffective ? "اكتب كلمة مرور" : "Enter a password"
            case 1:    return lang.isArabicEffective ? "ضعيفة — أضف رقماً ورمزاً" : "Weak — add a digit and symbol"
            case 2:    return lang.isArabicEffective ? "متوسطة — أضف رمزاً" : "Medium — add a symbol"
            default:   return lang.isArabicEffective ? "قوية" : "Strong"
            }
        }()
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.xxs) {
            HStack(spacing: NNSpacing.xxs) {
                ForEach(0..<3) { idx in
                    Capsule()
                        .fill(idx < score ? color : AppColors.uiBorder)
                        .frame(height: 4)
                }
            }
            Text(label)
                .font(.caption)
                .foregroundColor(score >= 2 ? color : AppColors.textSecondary)
        }
    }

    private func primaryAction() {
        errorMessage = nil

        #if DEBUG
        // Two QA accounts, both accept any non-empty password:
        //   • "admin" → enables Premium, marks isAdmin, forces onboarding so
        //               the developer can review the full first-time flow plus
        //               any admin-only UI (e.g. the Admin Tools section in
        //               Settings).
        //   • "user"  → free tier returning user — skips onboarding and goes
        //               straight to the main app, simulating a normal session.
        // Both branches normalize Arabic-Indic digits so an Arabic keyboard
        // doesn't silently break the match. Compiled out in Release.
        let normalizedEmail = adminNormalize(email).lowercased()
        let normalizedPassword = adminNormalize(password)
        if !normalizedPassword.isEmpty {
            if normalizedEmail == "admin" {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                isPremium = true
                isAdmin = true
                showOnboardingAfterLogin = true
                isAuthenticated = true
                return
            }
            if normalizedEmail == "user" {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                isPremium = false
                isAdmin = false
                showOnboardingAfterLogin = false
                isAuthenticated = true
                return
            }
        }
        #endif

        if !isValidEmail(email) {
            errorMessage = lang.isArabicEffective ? "صيغة البريد غير صحيحة." : "Invalid email format."
            return
        }
        // Min 8 chars (was 6) — bare-minimum NIST guidance. Sign-up gets
        // the additional digit + symbol requirement so new accounts start
        // out reasonably strong; sign-in stays length-only so users with
        // legacy short passwords aren't locked out.
        if password.count < 8 {
            errorMessage = lang.isArabicEffective ? "كلمة المرور 8 أحرف على الأقل." : "Password must be at least 8 characters."
            return
        }
        if mode == 1 {
            // Sign-up path — also require digit + symbol so new accounts
            // start strong. Existing accounts (sign-in) are not regulated
            // here because we can't retro-strengthen them.
            let hasDigit = password.range(of: #"\d"#, options: .regularExpression) != nil
            let hasSymbol = password.range(of: #"[^A-Za-z0-9]"#, options: .regularExpression) != nil
            if !hasDigit || !hasSymbol {
                errorMessage = lang.isArabicEffective
                    ? "كلمة المرور تحتاج رقماً ورمزاً واحداً على الأقل."
                    : "Password needs at least one digit and one symbol."
                return
            }
            // Confirmation field — only meaningful on sign-up.
            if password != passwordConfirm {
                errorMessage = lang.isArabicEffective ? "كلمتا المرور غير متطابقتين." : "Passwords don't match."
                return
            }
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

    /// Heuristic password strength score (0-3). 0=empty, 1=length only,
    /// 2=length+digit, 3=length+digit+symbol. Drives the visual indicator
    /// under the password field on sign-up.
    fileprivate func passwordStrength(_ pw: String) -> Int {
        guard !pw.isEmpty else { return 0 }
        var score = 0
        if pw.count >= 8 { score += 1 }
        if pw.range(of: #"\d"#, options: .regularExpression) != nil { score += 1 }
        if pw.range(of: #"[^A-Za-z0-9]"#, options: .regularExpression) != nil { score += 1 }
        return score
    }

    #if DEBUG
    /// Mirrors the normalization in `AdminToolsSheet`: Arabic keyboards
    /// auto-translate ASCII digits → Arabic-Indic (٠-٩) or Persian (۰-۹),
    /// which would silently break the admin-bypass check. Trim + transliterate
    /// to ASCII before comparing.
    fileprivate func adminNormalize(_ s: String) -> String {
        var out = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let arabicIndic = Array("٠١٢٣٤٥٦٧٨٩")
        let persian = Array("۰۱۲۳۴۵۶۷۸۹")
        let ascii = Array("0123456789")
        for i in 0..<10 {
            out = out.replacingOccurrences(of: String(arabicIndic[i]), with: String(ascii[i]))
            out = out.replacingOccurrences(of: String(persian[i]), with: String(ascii[i]))
        }
        return out
    }
    #endif
}

#Preview {
    AuthView().environmentObject(LanguageManager.shared)
} 