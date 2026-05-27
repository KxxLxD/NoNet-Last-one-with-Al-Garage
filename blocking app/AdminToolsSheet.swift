import SwiftUI

#if DEBUG
/// QA / admin backdoor for flipping subscription state without going through
/// StoreKit. Lets the developer toggle `isPremium` and the 7-day trial start
/// timestamp directly, so the paywall / subscribed states can be exercised on
/// a real device without a sandbox purchase round-trip.
///
/// Trigger: low-contrast "Admin" footer link at the bottom of `UpgradeView`.
/// Credentials: `admin` / `1234` (kept intentionally trivial — this is a dev
/// aid, not a security boundary). The entire type is gated behind `#if DEBUG`
/// so it never enters the App Store binary.
struct AdminToolsSheet: View {
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppStorageKeys.isPremium) private var isPremium: Bool = false
    @AppStorage(AppStorageKeys.trialStartTs) private var trialStartTs: Double = 0
    @AppStorage(AppStorageKeys.hasShownTrialExpiredAlert) private var hasShownTrialExpiredAlert: Bool = false

    @State private var enteredUsername: String = ""
    @State private var enteredPassword: String = ""
    @State private var loginError: String? = nil
    @State private var authenticated: Bool = false

    private static let adminUsername = "admin"
    private static let adminPassword = "1234"

    private var isArabic: Bool { lang.isArabicEffective }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.uiBackground.ignoresSafeArea()
                Group {
                    if authenticated {
                        adminPanel
                    } else {
                        loginForm
                    }
                }
            }
            .navigationTitle(isArabic ? "أدوات الأدمن" : "Admin Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isArabic ? "إغلاق" : "Close") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    // ─── Login ────────────────────────────────────────────────────

    @ViewBuilder
    private var loginForm: some View {
        ScrollView {
            VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.lg) {
                VStack(spacing: NNSpacing.sm) {
                    ZStack {
                        Circle()
                            .fill(AppColors.infoBg)
                            .frame(width: 72, height: 72)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(AppColors.accent)
                    }
                    Text(isArabic ? "دخول الأدمن" : "Admin Login")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(isArabic
                        ? "خاص بالاختبار — يتيح تفعيل/إلغاء الاشتراك يدوياً."
                        : "Internal QA — toggles subscription state manually.")
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, NNSpacing.md)

                VStack(spacing: NNSpacing.sm) {
                    LabeledTextField(
                        title: isArabic ? "اسم المستخدم" : "Username",
                        placeholder: isArabic ? "أدخل اسم المستخدم" : "Enter username",
                        text: $enteredUsername,
                        // `.asciiCapable` forces a Latin-letters keyboard even
                        // when the device default is Arabic — prevents the
                        // user accidentally entering Arabic chars.
                        keyboardType: .asciiCapable,
                        autocapitalization: .never
                    )
                    .environmentObject(lang)

                    LabeledTextField(
                        title: isArabic ? "كلمة المرور" : "Password",
                        placeholder: isArabic ? "أدخل كلمة المرور" : "Enter password",
                        text: $enteredPassword,
                        secure: true,
                        // `.numberPad` for the password since "1234" is digits.
                        // Falls back to ASCII keyboard if device disallows it.
                        keyboardType: .asciiCapableNumberPad,
                        autocapitalization: .never
                    )
                    .environmentObject(lang)

                    if let loginError {
                        HStack(spacing: NNSpacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppColors.alertRed)
                                .font(.footnote)
                            Text(loginError)
                                .font(.footnote)
                                .foregroundColor(AppColors.alertRed)
                            Spacer(minLength: 0)
                        }
                    }

                    Button(action: attemptLogin) {
                        Text(isArabic ? "دخول" : "Sign in")
                            .font(.nnButton)
                            .frame(maxWidth: .infinity)
                            .frame(height: NNHitTarget.minimum + 6)
                            .background(canSubmitLogin ? AppColors.accent : AppColors.textDisabled)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmitLogin)
                }
                .padding(NNSpacing.md)
                .background(AppColors.uiSurface)
                .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: NNRadius.card)
                        .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
                )

                // Hint card — credentials are intentionally trivial so the
                // developer doesn't need to memorize them.
                VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.xxs) {
                    Text(isArabic ? "بيانات الدخول" : "Credentials")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(isArabic
                        ? "اسم المستخدم: admin\nكلمة المرور: 1234"
                        : "Username: admin\nPassword: 1234")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                }
                .padding(NNSpacing.sm)
                .background(AppColors.infoBg)
                .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
            }
            .padding(.horizontal, NNSpacing.xl)
            .padding(.bottom, NNSpacing.xl)
        }
    }

    private var canSubmitLogin: Bool {
        !enteredUsername.trimmingCharacters(in: .whitespaces).isEmpty &&
        !enteredPassword.isEmpty
    }

    /// Arabic keyboards auto-translate Western digits → Arabic-Indic digits
    /// (٠١٢٣٤٥٦٧٨٩). The user typing "1234" with Arabic active gets "١٢٣٤"
    /// which fails a naive `==` check. Normalize both ways before comparing
    /// so the developer doesn't have to switch keyboards mid-login.
    private func normalize(_ s: String) -> String {
        var out = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // Arabic-Indic digits (U+0660–U+0669)
        let arabicIndic = Array("٠١٢٣٤٥٦٧٨٩")
        // Extended Arabic-Indic / Persian digits (U+06F0–U+06F9)
        let persian = Array("۰۱۲۳۴۵۶۷۸۹")
        let ascii = Array("0123456789")
        for i in 0..<10 {
            out = out.replacingOccurrences(of: String(arabicIndic[i]), with: String(ascii[i]))
            out = out.replacingOccurrences(of: String(persian[i]), with: String(ascii[i]))
        }
        return out
    }

    private func attemptLogin() {
        let u = normalize(enteredUsername).lowercased()
        let p = normalize(enteredPassword)
        if u == Self.adminUsername && p == Self.adminPassword {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeInOut(duration: 0.2)) {
                authenticated = true
                loginError = nil
            }
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            loginError = isArabic
                ? "اسم المستخدم أو كلمة المرور غير صحيحة."
                : "Incorrect username or password."
        }
    }

    // ─── Admin panel ──────────────────────────────────────────────

    @ViewBuilder
    private var adminPanel: some View {
        ScrollView {
            VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.lg) {
                stateSummary
                premiumCard
                trialCard
                resetCard
            }
            .padding(.horizontal, NNSpacing.xl)
            .padding(.top, NNSpacing.md)
            .padding(.bottom, NNSpacing.xl)
        }
    }

    @ViewBuilder
    private var stateSummary: some View {
        let premiumLabel = isPremium
            ? (isArabic ? "Premium مفعَّل" : "Premium ACTIVE")
            : (isArabic ? "Premium غير مفعَّل" : "Premium OFF")
        let trialLabel: String = {
            if trialStartTs <= 0 { return isArabic ? "بدون تجربة" : "No trial" }
            let start = Date(timeIntervalSince1970: trialStartTs)
            let elapsed = Date().timeIntervalSince(start)
            let remaining = BlockingConstants.trialDurationSeconds - elapsed
            if remaining <= 0 {
                return isArabic ? "التجربة منتهية" : "Trial expired"
            }
            let days = max(0, Int(ceil(remaining / BlockingConstants.secondsPerDayInterval)))
            return isArabic ? "تجربة نشطة — متبقي \(days) يوم" : "Trial active — \(days) day\(days == 1 ? "" : "s") left"
        }()

        VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.xs) {
            HStack(spacing: NNSpacing.xs) {
                Image(systemName: isPremium ? "checkmark.seal.fill" : "circle.dashed")
                    .foregroundColor(isPremium ? AppColors.successGreen : AppColors.textSecondary)
                Text(premiumLabel)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                Spacer(minLength: 0)
            }
            HStack(spacing: NNSpacing.xs) {
                Image(systemName: "gift.fill")
                    .foregroundColor(AppColors.accent)
                Text(trialLabel)
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
                Spacer(minLength: 0)
            }
        }
        .padding(NNSpacing.md)
        .background(isPremium ? AppColors.successBg : AppColors.infoBg)
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
    }

    @ViewBuilder
    private var premiumCard: some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.sm) {
            Text(isArabic ? "حالة الاشتراك" : "Subscription state")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            Toggle(isOn: Binding(
                get: { isPremium },
                set: { newValue in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    isPremium = newValue
                }
            )) {
                Text(isArabic ? "تفعيل Premium" : "Premium active")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textPrimary)
            }
            .tint(AppColors.accent)

            Text(isArabic
                ? "يقلب @AppStorage(isPremium) مباشرة. مفيد لاختبار حالة \"أنت مشترك\" في صفحة الترقية."
                : "Flips @AppStorage(isPremium) directly. Useful for testing the 'subscribed' state of the upgrade page.")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(NNSpacing.md)
        .background(AppColors.uiSurface)
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: NNRadius.card)
                .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
        )
    }

    @ViewBuilder
    private var trialCard: some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.sm) {
            Text(isArabic ? "التجربة المجانية" : "Free trial")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            HStack(spacing: NNSpacing.xs) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    trialStartTs = Date().timeIntervalSince1970
                    hasShownTrialExpiredAlert = false
                }) {
                    Label(isArabic ? "ابدأ الآن" : "Start now", systemImage: "play.fill")
                        .font(.nnSmallButton)
                        .frame(maxWidth: .infinity)
                        .frame(height: NNHitTarget.minimum)
                        .foregroundColor(.white)
                        .background(AppColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                }
                .buttonStyle(.plain)

                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    // Move start back by 8 days so isTrialActive flips to false
                    // without losing the fact that a trial was ever started.
                    trialStartTs = Date().timeIntervalSince1970 - (BlockingConstants.trialDurationSeconds + 86_400)
                }) {
                    Label(isArabic ? "انتهت" : "Expire", systemImage: "clock.badge.exclamationmark")
                        .font(.nnSmallButton)
                        .frame(maxWidth: .infinity)
                        .frame(height: NNHitTarget.minimum)
                        .foregroundColor(AppColors.accent)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: NNRadius.control)
                                .stroke(AppColors.accent, lineWidth: NNBorder.input)
                        )
                }
                .buttonStyle(.plain)
            }

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                trialStartTs = 0
                hasShownTrialExpiredAlert = false
            }) {
                Label(isArabic ? "مسح التجربة" : "Clear trial", systemImage: "trash")
                    .font(.nnSmallButton)
                    .frame(maxWidth: .infinity)
                    .frame(height: NNHitTarget.minimum)
                    .foregroundColor(AppColors.textSecondary)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: NNRadius.control)
                            .stroke(AppColors.uiBorder, lineWidth: NNBorder.input)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(NNSpacing.md)
        .background(AppColors.uiSurface)
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: NNRadius.card)
                .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
        )
    }

    @ViewBuilder
    private var resetCard: some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.xs) {
            Button(action: {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                isPremium = false
                trialStartTs = 0
                hasShownTrialExpiredAlert = false
            }) {
                Label(isArabic ? "صفّر كل شيء" : "Reset everything", systemImage: "arrow.counterclockwise")
                    .font(.nnSmallButton)
                    .frame(maxWidth: .infinity)
                    .frame(height: NNHitTarget.minimum)
                    .foregroundColor(AppColors.alertRed)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: NNRadius.control)
                            .stroke(AppColors.alertRed, lineWidth: NNBorder.input)
                    )
            }
            .buttonStyle(.plain)

            Text(isArabic
                ? "يلغي Premium، يمسح التجربة، ويعيد تنبيه انتهاء التجربة."
                : "Disables Premium, clears trial, and resets the trial-expired alert.")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(isArabic ? .trailing : .leading)
        }
        .padding(NNSpacing.md)
        .background(AppColors.uiSurface)
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: NNRadius.card)
                .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
        )
    }
}

#Preview {
    AdminToolsSheet().environmentObject(LanguageManager.shared)
}
#endif
