import SwiftUI

@available(iOS 17.0, *)
struct SettingsView: View {
    @EnvironmentObject var lang: LanguageManager
    @AppStorage(AppStorageKeys.isPremium) private var isPremium: Bool = false
    @State private var navigateToUpgrade = false
    // showComingSoonAlert is kept (still wired to the FAQItem patterns) but
    // the Community section that used to trigger it is hidden until v1.4 —
    // see the inline comment in body where the section used to live.
    @State private var showComingSoonAlert = false

    #if DEBUG
    @AppStorage(AppStorageKeys.isAdmin) private var isAdmin: Bool = false
    @AppStorage(AppStorageKeys.showOnboardingAfterLogin) private var showOnboardingAfterLogin: Bool = false
    @State private var showAdminSheet: Bool = false
    @State private var showReplayConfirm: Bool = false
    #endif

    private func hapticLight() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.lg) {

                    // ─── 1. Subscription (top — primary value prop) ───────
                    settingsSection(
                        title: lang.isArabicEffective ? "الاشتراك" : "Subscription",
                        icon: "crown.fill",
                        // Subscription keeps a more prominent feel: larger padding
                        // and the bigger radius, because it's the page's anchor.
                        cardPadding: NNSpacing.lg,
                        cardRadius: NNRadius.container
                    ) {
                        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm) {
                            HStack {
                                Text(lang.isArabicEffective ? "الحالة" : "Status")
                                Spacer()
                                let badgeText = isPremium ? (lang.isArabicEffective ? "Premium مفعَّل" : "Premium active") : (lang.isArabicEffective ? "نسخة مجانية" : "Free version")
                                Text(badgeText)
                                    .font(.footnote)
                                    .padding(.horizontal, NNSpacing.xs + 2)
                                    .padding(.vertical, NNSpacing.xxs)
                                    .background(
                                        Capsule().fill(isPremium ? AppColors.successGreen.opacity(0.12) : AppColors.infoBg)
                                    )
                                    .foregroundColor(isPremium ? AppColors.successGreen : AppColors.accent)
                            }
                            Text(lang.isArabicEffective ? "الترقية تفتح الجدولة والميزات المتقدمة." : "Upgrade unlocks scheduling and advanced features.")
                                .font(.footnote)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                            Text(lang.isArabicEffective ? "ضمان ذهبي: استرجاع شهر للشهري / شهرين للسنوي." : "Golden Guarantee: refund within 1 month monthly / 2 months yearly.")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Button(action: { hapticLight(); navigateToUpgrade = true }) {
                                Text(isPremium ? (lang.isArabicEffective ? "إدارة الاشتراك" : "Manage Subscription") : (lang.isArabicEffective ? "ترقية إلى Premium" : "Upgrade to Premium"))
                                    .font(.nnButton)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: NNHitTarget.minimum)
                                    .background(AppColors.accent)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                            }
                            .buttonStyle(.plain)
                            .navigationDestination(isPresented: $navigateToUpgrade) {
                                UpgradeView().environmentObject(lang)
                            }
                        }
                    }

                    // ─── 2. Display & Language ─────────────────────────────
                    settingsSection(title: lang.isArabicEffective ? "العرض واللغة" : "Display & Language", icon: "paintpalette.fill") {
                        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm) {
                            Text(lang.isArabicEffective ? "لغة التطبيق" : "App Language")
                                .font(.headline)
                            // Bind to selected (not isArabicEffective) so "System" survives
                            // as a real third option — the previous binding silently
                            // collapsed any non-AR/EN choice into one of those two.
                            Picker("", selection: Binding<LanguageManager.LanguageOption>(
                                get: { lang.selected },
                                set: { lang.updateLanguage($0) }
                            )) {
                                Text(lang.isArabicEffective ? "النظام" : "System").tag(LanguageManager.LanguageOption.system)
                                Text("العربية").tag(LanguageManager.LanguageOption.arabic)
                                Text("English").tag(LanguageManager.LanguageOption.english)
                            }
                            .pickerStyle(.segmented)
                            // Explain what "System" follows so users don't wonder.
                            if lang.selected == .system {
                                Text(lang.isArabicEffective
                                     ? "تتبع لغة جهازك تلقائياً."
                                     : "Follows your device language automatically.")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }

                    // ─── 3. Support & Learning ────────────────────────────
                    // Renamed from "Help & Support" — the section mixes pure
                    // support (Email) with educational content (FAQ, Resources).
                    // "Preview Block Screen" was removed: it's a developer demo,
                    // not user-facing.
                    settingsSection(title: lang.isArabicEffective ? "الدعم والتعلّم" : "Support & Learning", icon: "lifepreserver.fill") {
                        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm) {
                            Link(destination: supportMailURL()) {
                                supportRow(icon: "envelope", label: lang.isArabicEffective ? "بريد الدعم" : "Support Email")
                            }
                            .simultaneousGesture(TapGesture().onEnded { hapticLight() })
                            .accessibilityHint(lang.isArabicEffective ? "يفتح تطبيق البريد لإرسال طلب دعم" : "Opens Mail to send a support request")
                            SoftDivider(maxWidth: 280, opacity: 0.7)
                            NavigationLink(destination: FAQView().environmentObject(lang)) {
                                supportRow(icon: "questionmark.circle", label: lang.isArabicEffective ? "الأسئلة الشائعة" : "FAQ")
                            }
                            .simultaneousGesture(TapGesture().onEnded { hapticLight() })
                            .accessibilityHint(lang.isArabicEffective ? "يعرض الأسئلة الشائعة وأجوبتها" : "Shows frequently asked questions and answers")
                            SoftDivider(maxWidth: 280, opacity: 0.7)
                            NavigationLink(destination: ResourcesView().environmentObject(lang)) {
                                supportRow(icon: "book.fill", label: lang.isArabicEffective ? "الموارد" : "Resources")
                            }
                            .simultaneousGesture(TapGesture().onEnded { hapticLight() })
                            .accessibilityHint(lang.isArabicEffective ? "محتوى تعليمي عن الإدمان الرقمي" : "Educational content about digital habits")
                        }
                    }

                    // ─── 4. Legal & About ─────────────────────────────────
                    // Merged from two separate single-row sections — both belong
                    // to "footer info" semantically.
                    settingsSection(title: lang.isArabicEffective ? "القانوني والمعلومات" : "Legal & About", icon: "doc.text.fill") {
                        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm) {
                            NavigationLink(destination: PoliciesView().environmentObject(lang)) {
                                supportRow(icon: "doc.text", label: lang.isArabicEffective ? "السياسات والشروط" : "Policies & Terms")
                            }
                            .accessibilityHint(lang.isArabicEffective ? "يعرض شروط الخدمة وسياسة الخصوصية" : "Shows Terms of Service and Privacy Policy")
                            SoftDivider(maxWidth: 280, opacity: 0.7)
                            NavigationLink(destination: AboutView().environmentObject(lang)) {
                                supportRow(icon: "info.circle", label: lang.isArabicEffective ? "معلومات التطبيق" : "App Information")
                            }
                            .accessibilityHint(lang.isArabicEffective ? "معلومات التطبيق ورقم الإصدار" : "App information and version number")
                        }
                    }

                    #if DEBUG
                    // ─── Admin Tools (DEBUG + isAdmin only) ───────────────
                    // Only renders when the user logged in via the "admin"
                    // dev account. Compiled out completely in Release builds.
                    if isAdmin {
                        adminSection
                    }
                    #endif

                    // ─── 5. Account (bottom — destructive zone) ───────────
                    // Community section (WhatsApp / Telegram) is intentionally
                    // hidden until v1.4 when the channel URLs are provisioned;
                    // showing "Soon" placeholders made the page feel half-shipped.
                    settingsSection(title: lang.isArabicEffective ? "الحساب" : "Account", icon: "person.circle.fill") {
                        VStack(alignment: .center, spacing: NNSpacing.sm) {
                            LogoutButton()
                                .environmentObject(lang)
                        }
                    }
                }
                .padding(.bottom, NNSpacing.xxl - 4)
            }
            .background(AppColors.uiBackground)
            .navigationTitle(AppStrings.settingsTitle(lang))
        }
        .alert(lang.isArabicEffective ? "قريباً" : "Coming Soon", isPresented: $showComingSoonAlert) {
            Button(lang.isArabicEffective ? "حسناً" : "OK", role: .cancel) {}
        } message: {
            Text(lang.isArabicEffective
                 ? "ستفتح هذه القناة قريباً. شكراً لصبرك!"
                 : "This channel will open soon. Thanks for your patience!")
        }
        #if DEBUG
        .sheet(isPresented: $showAdminSheet) {
            AdminToolsSheet().environmentObject(lang)
        }
        .alert(
            lang.isArabicEffective ? "إعادة عرض الاونبوردينج؟" : "Replay onboarding?",
            isPresented: $showReplayConfirm
        ) {
            Button(lang.isArabicEffective ? "إلغاء" : "Cancel", role: .cancel) {}
            Button(lang.isArabicEffective ? "ابدأ" : "Replay") {
                showOnboardingAfterLogin = true
            }
        } message: {
            Text(lang.isArabicEffective
                ? "بيرجع التطبيق لشاشة الاونبوردينج. تقدر تتنقل بها وترجع للتطبيق بعدها."
                : "The app will restart onboarding. You can scroll through and return to the app afterwards.")
        }
        #endif
    }

    #if DEBUG
    /// Admin-only section — surfaced only when `isAdmin == true` (set by the
    /// "admin" dev login in `AuthView`). Compiled out of Release builds.
    @ViewBuilder
    private var adminSection: some View {
        settingsSection(
            title: lang.isArabicEffective ? "أدوات الأدمن" : "Admin Tools",
            icon: "lock.shield.fill"
        ) {
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm) {
                Text(lang.isArabicEffective
                    ? "هذي الأدوات ظاهرة فقط لمستخدم الأدمن في نسخة المطور."
                    : "Admin-only — visible to the admin user in Debug builds.")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                Button(action: { hapticLight(); showAdminSheet = true }) {
                    HStack {
                        Image(systemName: "switch.2")
                            .foregroundColor(AppColors.accent)
                        Text(lang.isArabicEffective ? "تحكم الاشتراك والتجربة" : "Subscription & trial controls")
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Image(systemName: lang.isArabicEffective ? "chevron.left" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(minHeight: NNHitTarget.minimum)
                }
                .buttonStyle(.plain)

                SoftDivider(maxWidth: 280, opacity: 0.7)

                Button(action: { hapticLight(); showReplayConfirm = true }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .foregroundColor(AppColors.accent)
                        Text(lang.isArabicEffective ? "إعادة عرض الاونبوردينج" : "Replay onboarding")
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Image(systemName: lang.isArabicEffective ? "chevron.left" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(minHeight: NNHitTarget.minimum)
                }
                .buttonStyle(.plain)
            }
        }
    }
    #endif

    /// Single section wrapper — header + card body, all sections share this
    /// rhythm so the page reads as a coherent list of grouped settings.
    /// `cardPadding` and `cardRadius` default to the slightly tighter spec
    /// (16/16) used by secondary sections; the Subscription section overrides
    /// to the larger (20/20) treatment to feel primary.
    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        icon: String? = nil,
        cardPadding: CGFloat = NNSpacing.md,
        cardRadius: CGFloat = NNRadius.card,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm) {
            HStack(spacing: NNSpacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.accent)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.nnSectionTitle)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, NNSpacing.xl)
            content()
                .padding(cardPadding)
                .background(AppColors.uiSurface)
                .clipShape(RoundedRectangle(cornerRadius: cardRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cardRadius)
                        .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
                )
                .padding(.horizontal, NNSpacing.xl)
        }
    }

    /// Consistent row template for navigation/support rows. Touch target
    /// guaranteed ≥ 44pt via minHeight (HIG compliance — previously rows
    /// inherited natural text height which could fall under 44).
    @ViewBuilder
    private func supportRow(icon: String, label: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(AppColors.accent)
                .font(.nnCardBody)
            Text(label)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
        }
        .frame(minHeight: NNHitTarget.minimum)
    }

    /// Pre-fills the support email with the app version + iOS version so the
    /// user doesn't have to type context. Falls back to a bare mailto: if
    /// either string is missing for any reason.
    private func supportMailURL() -> URL {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let iosVersion = UIDevice.current.systemVersion
        let device = UIDevice.current.model
        let subject = lang.isArabicEffective ? "طلب دعم من NoNet" : "NoNet support request"
        let bodyLines = [
            lang.isArabicEffective ? "اكتب طلبك هنا:" : "Describe your issue here:",
            "",
            "",
            "—",
            "App: \(appVersion) (\(buildNumber))",
            "iOS: \(iosVersion)",
            "Device: \(device)"
        ]
        let body = bodyLines.joined(separator: "\n")
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "support@nonet.app"
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url ?? URL(string: "mailto:support@nonet.app")!
    }
}

struct FAQView: View {
    @EnvironmentObject var lang: LanguageManager

    /// Topical buckets that the flat QA list is rendered under. Order matters:
    /// it controls vertical reading order on screen, which matters for
    /// scannability since the list is too long to consume top-to-bottom.
    private enum FAQCategory: String, CaseIterable, Identifiable {
        case basics, lists, protection, partner, premium, technical
        var id: String { rawValue }

        func title(isArabic: Bool) -> String {
            switch self {
            case .basics:     return isArabic ? "أساسيات" : "Basics"
            case .lists:      return isArabic ? "القوائم والحجب" : "Lists & Blocking"
            case .protection: return isArabic ? "الحماية" : "Protection"
            case .partner:    return isArabic ? "شريك التعافي" : "Recovery Partner"
            case .premium:    return isArabic ? "الاشتراك" : "Subscription"
            case .technical:  return isArabic ? "الحساب والتقنية" : "Account & Technical"
            }
        }
    }

    private struct QA: Identifiable {
        let id = UUID()
        let category: FAQCategory
        let ar: String
        let en: String
        let answerAr: String
        let answerEn: String
    }

    private var items: [QA] {
        [
            // ─── Basics ───────────────────────────────────────────────
            QA(category: .basics,
               ar: "ما هو تطبيق NoNet؟", en: "What is NoNet?",
               answerAr: "NoNet يساعدك على تنظيم استخدامك للإنترنت، وحجب التطبيقات والمواقع المشتّتة، وبناء عادات تركيز صحيّة.",
               answerEn: "NoNet helps you control internet use, block distracting apps/websites, and build healthy focus habits."),

            QA(category: .basics,
               ar: "ماذا عن الخصوصية والبيانات؟", en: "What about privacy and data?",
               answerAr: "بياناتك تبقى على جهازك افتراضياً (قوائم، إعدادات، محادثات المساعد). الاستثناء الوحيد ميزة \"شريك التعافي\" الاختيارية تستخدم iCloud الخاصة بـ Apple. للتفاصيل الكاملة: السياسات والشروط.",
               answerEn: "Your data stays on your device by default (lists, settings, assistant chats). The only exception is the optional Recovery Partner feature which uses Apple's iCloud. Full details in Policies & Terms."),

            QA(category: .basics,
               ar: "من يدير تطبيق NoNet؟", en: "Who runs NoNet?",
               answerAr: "تطبيق NoNet مُقدَّم من شركة NoNet Company، الرياض، المملكة العربية السعودية. التفاصيل الكاملة في صفحة \"معلومات التطبيق\" و\"السياسات والشروط\".",
               answerEn: "NoNet is operated by NoNet Company, Riyadh, Saudi Arabia. Full details in the App Information page and in Policies & Terms."),

            QA(category: .basics,
               ar: "هل يعمل بدون إنترنت؟", en: "Does it work offline?",
               answerAr: "نعم، الحجب يعمل على الجهاز نفسه باستخدام إذن Screen Time، حتى بدون اتصال.",
               answerEn: "Yes. Blocking works on-device via Screen Time permissions, even without internet."),

            // ─── Lists & Blocking ────────────────────────────────────
            QA(category: .lists,
               ar: "كيف أنشئ قائمة جديدة؟", en: "How do I create a new list?",
               answerAr: "الصفحة الرئيسية → أنشئ قائمة → أضف المواقع/التطبيقات/الفئات → اختر الحماية → حدّد المدة.",
               answerEn: "Home → Create List → add websites/apps/categories → choose protection → set duration."),

            QA(category: .lists,
               ar: "كيف أحذف قائمة حجب؟ وهل تُحذف عناصرها؟", en: "How do I delete a blocklist? Are its items deleted?",
               answerAr: "من تفاصيل القائمة → حذف. تُحذف القائمة بالكامل مع عناصرها من جهازك. القوائم في الوضع الصارم تحتاج تمر عبر الحارس قبل الحذف.",
               answerEn: "From list details → Delete. The list and its items are removed from your device. Hard-Mode lists require passing the gatekeeper before deletion."),

            QA(category: .lists,
               ar: "ما الفرق بين أنواع الحجب الأربعة؟", en: "What are the four block types?",
               answerAr: "- فوري: حجب يبدأ الآن لمدة محدّدة.\n- مجدول: يعمل تلقائياً في أيام/أوقات تختارها (ضمن Premium).\n- حد يومي: حصة دقائق محدّدة كل يوم، الحجب يبدأ بعد استنفادها.\n- دائم: حجب لا ينتهي إلا عبر فك الحجب الطارئ أو حذف القائمة.",
               answerEn: "- Now: blocks immediately for a set duration.\n- Scheduled: runs automatically on chosen days/times (Premium).\n- Daily Limit: a minute quota per day; blocking kicks in once exhausted.\n- Forever: never ends unless you use Emergency Unlock or delete the list."),

            QA(category: .lists,
               ar: "كيف أستخدم الجدولة؟", en: "How do scheduling blocks work?",
               answerAr: "من إنشاء القائمة → وقت الحجب → اختر \"الجدولة\" وحدّد الفترات حسب الأيام (ضمن الترقية).",
               answerEn: "In Create List → Time to block → choose \"Scheduled\" and set day/time ranges (part of Upgrade)."),

            QA(category: .lists,
               ar: "لماذا لا أرى كل التطبيقات عند الاختيار؟", en: "Why don't I see all apps in the picker?",
               answerAr: "يحتاج التطبيق إذن Screen Time. امنح الإذن من إعدادات الـ iPhone ثم أعد المحاولة.",
               answerEn: "Screen Time permission is required. Grant access in Settings, then try again."),

            // ─── Protection ──────────────────────────────────────────
            QA(category: .protection,
               ar: "ماذا أفعل لو علقت في Hard Mode؟", en: "What if I'm stuck in Hard Mode?",
               answerAr: "لقوائم Forever في وضع NoNet كحارس: استخدم \"فك الحجب الطارئ\" من شاشة تفاصيل القائمة — يفك الحجب تلقائياً بعد ٧ أيام. للقوائم الأخرى: مر عبر الحارس (NoNet أو شريكك) أو راسلنا على support@nonet.app.",
               answerEn: "For Forever lists with NoNet as gatekeeper: use \"Emergency Unlock\" from the list-detail screen — releases automatically after 7 days. For other lists: go through your gatekeeper (NoNet or partner), or email support@nonet.app."),

            QA(category: .protection,
               ar: "ما الفرق بين حارس NoNet والحارس الشريك؟", en: "NoNet vs. Partner gatekeeper — what's the difference?",
               answerAr: "- حارس NoNet: تطلب الفعل (حذف/إيقاف) ويُطبَّق بعد كتابة سبب + تأخير زمني — أنت تقرّر، لكن مع احتكاك متعمَّد.\n- الحارس الشريك: يصل الطلب لشخص اخترته أنت (Recovery Partner)، وينفّذ بعد موافقته فقط.",
               answerEn: "- NoNet gatekeeper: you request the action (delete/disable) and it applies after typing a reason + a delay — you decide, with deliberate friction.\n- Partner gatekeeper: the request reaches a person you chose (Recovery Partner) and only executes once they approve."),

            QA(category: .protection,
               ar: "كيف يعمل فك الحجب الطارئ (٧ أيام)؟", en: "How does the 7-day Emergency Unlock work?",
               answerAr: "في شاشة تفاصيل قائمة Forever (وضع NoNet كحارس) → اضغط \"اطلب فك الحجب\". يبدأ عداد ٧ أيام. خلال هذه المدة الحجب يبقى نشطاً. عند انتهاء العدّ، تقدر تفك الحجب نهائياً. تقدر تلغي الطلب في أي وقت قبل اكتماله.",
               answerEn: "On a Forever list's detail screen (NoNet gatekeeper) → tap \"Request unlock\". A 7-day countdown starts; the block stays active during it. When the timer hits zero you can release the block. You can cancel the request anytime before it matures."),

            // ─── Recovery Partner ────────────────────────────────────
            QA(category: .partner,
               ar: "ماذا يفعل شريك التعافي؟", en: "What does the Recovery Partner do?",
               answerAr: "شريك تثق به (صديق، مرشد، فرد من العائلة) يستلم إشعاراً عند كل محاولة لكسر قائمة Hard Mode، ويقرّر بنفسه الموافقة على الحذف/الإيقاف. وجود الشريك يمنع لحظة الضعف من تخريب التزامك.",
               answerEn: "A person you trust (friend, mentor, family member) is notified of every break-attempt on your Hard-Mode list, and decides themselves whether to approve a delete/disable request. Their presence keeps a weak moment from undoing your commitment."),

            QA(category: .partner,
               ar: "كيف أرسل دعوة شريك ومن يقدر يقبلها؟", en: "How do I invite a partner and who can accept?",
               answerAr: "في شاشة تفاصيل قائمة Hard Mode → \"دعوة شريك\" → يُنشأ رابط iCloud Share. أرسله للشخص اللي تختاره. أي شخص لديه حساب iCloud ويضغط الرابط يصير شريكك — لا يوجد رمز PIN، فأرسل الرابط فقط لمن تثق به.",
               answerEn: "From a Hard-Mode list's detail screen → \"Invite Partner\" → an iCloud Share link is generated. Send it to the person you chose. Anyone with an iCloud account who taps the link becomes your partner — there is no PIN, so only share with someone you trust."),

            QA(category: .partner,
               ar: "ما البيانات اللي يراها شريكي؟", en: "What data does my partner see?",
               answerAr: "اسم القائمة، الاسم الذي اخترته لنفسك، ومحاولات كسر الحجب (النوع + الوقت). لا يرى محتوى الجلسات، ولا التطبيقات المختارة، ولا أي بيانات أخرى عنك. تقدر تنهي الشراكة في أي وقت من شاشة تفاصيل القائمة.",
               answerEn: "The list's name, the display name you set for yourself, and break-attempt records (type + timestamp). They do NOT see session content, the specific apps you chose, or any other personal data. You can end the partnership anytime from the list-detail screen."),

            // ─── Premium / Subscription ──────────────────────────────
            QA(category: .premium,
               ar: "ما هي فوائد النسخة المميزة (Premium)؟", en: "What are the benefits of Premium?",
               answerAr: "- قوائم حجب غير محدودة (٣ في النسخة المجانية)\n- الوضع الصارم بدون عدّ\n- الجدولة الذكية والاستراحات المخطّطة\n- شريك التعافي (Hard Mode)\n- مساعد NoNet الذكي\n- اقتراحات وخطط جاهزة\n- دعم بأولوية",
               answerEn: "- Unlimited blocklists (3 on free)\n- Unlimited Hard Mode\n- Smart scheduling & planned breaks\n- Recovery Partner (Hard Mode)\n- NoNet AI assistant\n- Quick suggestions & ready plans\n- Priority support"),

            QA(category: .premium,
               ar: "هل توجد استراحات؟", en: "Are breaks allowed?",
               answerAr: "يمكنك تحديد عدد ومدة الاستراحات اليومية من خيار \"الاستراحات المسموحة\" عند إنشاء القائمة.",
               answerEn: "You can set daily break count and duration from \"Allows Breaks\" when creating a list."),

            QA(category: .premium,
               ar: "هل يوجد ضمان ذهبي؟", en: "Is there a Golden Guarantee?",
               answerAr: "الشهري: استرجاع كامل خلال شهر. السنوي: خلال شهرين. الاسترداد عبر App Store ونساعدك إن رفضته Apple.",
               answerEn: "Monthly: full refund within 1 month. Yearly: within 2 months. Refunds via App Store; we help if Apple denies it."),

            // ─── Account & Technical ─────────────────────────────────
            QA(category: .technical,
               ar: "إذا نسيت كلمة مرور حساب البريد المحلي ماذا أفعل؟", en: "What if I forget my local email account password?",
               answerAr: "حسابات البريد محلية بالكامل على جهازك ولا توجد طريقة لاستعادة كلمة المرور المنسية. إذا نسيتها: راسل الدعم على support@nonet.app — قد نحتاج إعادة تهيئة الحساب يدوياً وقد تفقد إعداداتك. الحل الأفضل: استخدم Sign in with Apple إن أردت حساباً قابلاً للاستعادة.",
               answerEn: "Email accounts live fully on your device and there is no way to recover a forgotten password. If you forget yours, email support@nonet.app — we may need to reset the account manually and your settings could be lost. Best practice: use Sign in with Apple if you want a recoverable account."),

            QA(category: .technical,
               ar: "ما البيانات التي تجمعونها في الإعداد الأولي (Onboarding)؟", en: "What data is collected during onboarding?",
               answerAr: "اسم تختاره أنت، فئتك العمرية، أهدافك، والتطبيقات/الفئات التي ترغب بتقليل استخدامها. كل هذه البيانات تبقى محلياً على جهازك ولا تُرسل لأي خادم. لإعادة تعيينها تحتاج حذف التطبيق وإعادة تثبيته.",
               answerEn: "A display name you choose, your age group, your goals, and the apps/categories you want to reduce. All of it stays locally on your device and is not sent to any server. To reset, delete and reinstall the app.")
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NNSpacing.lg) {
                Text(lang.isArabicEffective ? "الأسئلة الشائعة" : "Frequently Asked Questions")
                    .font(.nnSectionTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)

                // Render one FAQGroup per category, in declaration order. Each
                // group keeps the card-with-dividers treatment from the previous
                // single-list version — we just slice it by topic so a user
                // looking for, say, Recovery Partner info doesn't scroll past
                // 12 unrelated questions to reach it.
                ForEach(FAQCategory.allCases) { category in
                    let categoryItems = items.filter { $0.category == category }
                    if !categoryItems.isEmpty {
                        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm) {
                            Text(category.title(isArabic: lang.isArabicEffective))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
                                .padding(.horizontal, NNSpacing.xxs)

                            FAQGroup {
                                ForEach(Array(categoryItems.enumerated()), id: \.element.id) { idx, item in
                                    FAQItem(
                                        question: lang.isArabicEffective ? item.ar : item.en,
                                        answer: lang.isArabicEffective ? item.answerAr : item.answerEn
                                    )
                                    .environmentObject(lang)
                                    if idx < categoryItems.count - 1 {
                                        Divider()
                                            .background(AppColors.uiBorder.opacity(0.4))
                                            .padding(.horizontal, NNSpacing.md)
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, NNSpacing.xl)
            .padding(.top, NNSpacing.md)
            .padding(.bottom, NNSpacing.xxl - 4)
        }
        .background(AppColors.uiBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FAQItem: View {
    let question: String
    let answer: String
    @State private var isExpanded = false
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        // Inlined row for use inside a shared list card. Layout direction
        // handled by SwiftUI's RTL environment — no isArabic branching here
        // (caller's NavigationStack already flips the layout).
        VStack(alignment: .leading, spacing: NNSpacing.sm) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Text(question)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(minHeight: NNHitTarget.minimum)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(answer)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, NNSpacing.xs)
            }
        }
        .padding(.vertical, NNSpacing.xs)
        .padding(.horizontal, NNSpacing.md)
    }
}

/// Wraps FAQItems in a single card with dividers between each row — matches
/// the iOS Settings grouping convention and reduces the "every question is
/// its own bordered island" visual noise.
struct FAQGroup<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(AppColors.uiSurface)
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.container))
        .overlay(
            RoundedRectangle(cornerRadius: NNRadius.container)
                .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
        )
    }
}

struct LogoutButton: View {
    @EnvironmentObject var lang: LanguageManager
    @State private var showConfirm = false

    var body: some View {
        // Destructive actions read as more intentional with an outline rather
        // than a solid red fill — the user has to consciously pick the
        // dangerous option vs. tapping the most-prominent button on screen.
        Button(action: { showConfirm = true }) {
            Text(lang.isArabicEffective ? "تسجيل الخروج" : "Log out")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: NNHitTarget.minimum + 4)
                .foregroundColor(AppColors.alertRed)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: NNRadius.control)
                        .stroke(AppColors.alertRed, lineWidth: NNBorder.strong)
                )
                .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
        }
        .alert(lang.isArabicEffective ? "تسجيل الخروج؟" : "Log out?", isPresented: $showConfirm) {
            Button(role: .destructive) {
                // DataReset removes Keychain, all user-scoped AppStorage, the
                // per-list manual/breaks/emergency stores, Core Data lists,
                // and the pending break-attempt queue. isAuthenticated and
                // selectedTab go to 0 via the AppStorage wipe — no need to
                // set them inline. See DataReset.swift for the full inventory.
                DataReset.signOutAndClear()
            } label: {
                Text(lang.isArabicEffective ? "سجّل الخروج" : "Log out")
            }
            Button(role: .cancel) {
            } label: {
                Text(lang.isArabicEffective ? "إلغاء" : "Cancel")
            }
        } message: {
            Text(lang.isArabicEffective
                 ? "راح تنحذف قوائمك وحساب الاشتراك والملف الشخصي من هذا الجهاز. (الشركاء في iCloud يبقون مرتبطين بحسابك.)"
                 : "Your lists, subscription state, and profile will be removed from this device. (iCloud partner data stays linked to your Apple ID.)")
        }
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        SettingsView()
            .environmentObject(LanguageManager.shared)
    }
}
