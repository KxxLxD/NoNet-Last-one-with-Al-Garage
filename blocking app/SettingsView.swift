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

    private func hapticLight() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.lg) {

                    // ─── 1. Subscription (top — primary value prop) ───────
                    settingsSection(
                        title: lang.isArabicEffective ? "الاشتراك" : "Subscription",
                        // Subscription keeps a more prominent feel: larger padding
                        // and the bigger radius, because it's the page's anchor.
                        cardPadding: 20,
                        cardRadius: 20
                    ) {
                        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
                            HStack {
                                Text(lang.isArabicEffective ? "الحالة" : "Status")
                                Spacer()
                                let badgeText = isPremium ? (lang.isArabicEffective ? "Premium مفعَّل" : "Premium active") : (lang.isArabicEffective ? "نسخة مجانية" : "Free version")
                                Text(badgeText)
                                    .font(.footnote)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule().fill(isPremium ? AppColors.successGreen.opacity(0.12) : AppColors.infoBg)
                                    )
                                    .foregroundColor(isPremium ? AppColors.successGreen : AppColors.accent)
                            }
                            Text(lang.isArabicEffective ? "الترقية تفتح الجدولة والميزات المتقدمة." : "Upgrade unlocks scheduling and advanced features.")
                                .font(.footnote)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                            Text(lang.isArabicEffective ? "ضمان ذهبي: استرجاع 14 يوم شهري / شهرين سنوي." : "Golden Guarantee: refund in 14 days monthly / 2 months yearly.")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Button(action: { hapticLight(); navigateToUpgrade = true }) {
                                Text(isPremium ? (lang.isArabicEffective ? "إدارة الاشتراك" : "Manage Subscription") : (lang.isArabicEffective ? "ترقية إلى Premium" : "Upgrade to Premium"))
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(AppColors.accent)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            .navigationDestination(isPresented: $navigateToUpgrade) {
                                UpgradeView().environmentObject(lang)
                            }
                        }
                    }

                    // ─── 2. Display & Language ─────────────────────────────
                    settingsSection(title: lang.isArabicEffective ? "العرض واللغة" : "Display & Language") {
                        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
                            Text(lang.isArabicEffective ? "لغة التطبيق" : "App Language")
                                .font(.headline)
                            Picker("", selection: Binding<LanguageManager.LanguageOption>(
                                get: { lang.isArabicEffective ? .arabic : .english },
                                set: { lang.updateLanguage($0) }
                            )) {
                                Text("العربية").tag(LanguageManager.LanguageOption.arabic)
                                Text("English").tag(LanguageManager.LanguageOption.english)
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    // ─── 3. Support & Learning ────────────────────────────
                    // Renamed from "Help & Support" — the section mixes pure
                    // support (Email) with educational content (FAQ, Resources).
                    // "Preview Block Screen" was removed: it's a developer demo,
                    // not user-facing.
                    settingsSection(title: lang.isArabicEffective ? "الدعم والتعلّم" : "Support & Learning") {
                        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
                            Link(destination: URL(string: "mailto:support@nonet.app")!) {
                                supportRow(icon: "envelope", label: lang.isArabicEffective ? "بريد الدعم" : "Support Email")
                            }
                            .simultaneousGesture(TapGesture().onEnded { hapticLight() })
                            SoftDivider(width: 280, opacity: 0.70)
                            NavigationLink(destination: FAQView().environmentObject(lang)) {
                                supportRow(icon: "questionmark.circle", label: lang.isArabicEffective ? "الأسئلة الشائعة" : "FAQ")
                            }
                            .simultaneousGesture(TapGesture().onEnded { hapticLight() })
                            SoftDivider(width: 280, opacity: 0.70)
                            NavigationLink(destination: ResourcesView().environmentObject(lang)) {
                                supportRow(icon: "book.fill", label: lang.isArabicEffective ? "الموارد" : "Resources")
                            }
                            .simultaneousGesture(TapGesture().onEnded { hapticLight() })
                        }
                    }

                    // ─── 4. Legal & About ─────────────────────────────────
                    // Merged from two separate single-row sections — both belong
                    // to "footer info" semantically.
                    settingsSection(title: lang.isArabicEffective ? "القانوني والمعلومات" : "Legal & About") {
                        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
                            NavigationLink(destination: PoliciesView().environmentObject(lang)) {
                                supportRow(icon: "doc.text", label: lang.isArabicEffective ? "السياسات والشروط" : "Policies & Terms")
                            }
                            SoftDivider(width: 280, opacity: 0.70)
                            NavigationLink(destination: AboutView().environmentObject(lang)) {
                                supportRow(icon: "info.circle", label: lang.isArabicEffective ? "معلومات التطبيق" : "App Information")
                            }
                        }
                    }

                    // ─── 5. Account (bottom — destructive zone) ───────────
                    // Community section (WhatsApp / Telegram) is intentionally
                    // hidden until v1.4 when the channel URLs are provisioned;
                    // showing "Soon" placeholders made the page feel half-shipped.
                    settingsSection(title: lang.isArabicEffective ? "الحساب" : "Account") {
                        VStack(alignment: .center, spacing: 12) {
                            LogoutButton()
                                .environmentObject(lang)
                        }
                    }
                }
                .padding(.bottom, 28)
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
    }

    /// Single section wrapper — header + card body, all sections share this
    /// rhythm so the page reads as a coherent list of grouped settings.
    /// `cardPadding` and `cardRadius` default to the slightly tighter spec
    /// (16/16) used by secondary sections; the Subscription section overrides
    /// to the larger (20/20) treatment to feel primary.
    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String,
        cardPadding: CGFloat = 16,
        cardRadius: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.nnSectionTitle)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 24)
            content()
                .padding(cardPadding)
                .background(AppColors.uiSurface)
                .clipShape(RoundedRectangle(cornerRadius: cardRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cardRadius)
                        .stroke(AppColors.uiBorder, lineWidth: 0.5)
                )
                .padding(.horizontal, 24)
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
        .frame(minHeight: 44)
    }
}

struct FAQView: View {
    @EnvironmentObject var lang: LanguageManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 16) {
                Text(lang.isArabicEffective ? "الأسئلة الشائعة" : "Frequently Asked Questions")
                    .font(.nnSectionTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
                
                // 1) What is NoNet?
                FAQItem(
                    question: lang.isArabicEffective ? "ما هو تطبيق NoNet؟" : "What is NoNet?",
                    answer: lang.isArabicEffective ? "NoNet يساعدك على تنظيم استخدامك للإنترنت، وحجب التطبيقات والمواقع المشتّتة، وبناء عادات تركيز صحيّة." : "NoNet helps you control internet use, block distracting apps/websites, and build healthy focus habits."
                )
                
                // 2) Privacy & Data
                FAQItem(
                    question: lang.isArabicEffective ? "ماذا عن الخصوصية والبيانات؟" : "What about privacy and data?",
                    answer: lang.isArabicEffective ? "نحترم خصوصيتك — لا نبيع بياناتك. يعتمد التطبيق أساساً على التخزين المحلي وعلى أذونات iOS." : "We respect your privacy — we don’t sell your data. The app relies primarily on local storage and iOS permissions."
                )
                
                // 3) Offline
                FAQItem(
                    question: lang.isArabicEffective ? "هل يعمل بدون إنترنت؟" : "Does it work offline?",
                    answer: lang.isArabicEffective ? "نعم، الحجب يعمل على الجهاز نفسه باستخدام إذن Screen Time، حتى بدون اتصال." : "Yes. Blocking works on‑device via Screen Time permissions, even without internet."
                )
                
                SoftDivider(width: 280, opacity: 0.7)
                
                // 4) Breaks
                FAQItem(
                    question: lang.isArabicEffective ? "هل توجد استراحات؟" : "Are breaks allowed?",
                    answer: lang.isArabicEffective ? "يمكنك تحديد عدد ومدة الاستراحات اليومية من خيار \"الاستراحات المسموحة\" عند إنشاء القائمة." : "You can set daily break count and duration from \"Allows Breaks\" when creating a list."
                )
                
                // 5) Hard Mode
                FAQItem(
                    question: lang.isArabicEffective ? "ماذا أفعل لو علقت في Hard Mode؟" : "What if I’m stuck in Hard Mode?",
                    answer: lang.isArabicEffective ? "تواصل معنا عبر بريد الدعم داخل الإعدادات. سنساعدك وفق سياسة الضمان الذهبي." : "Contact support via the in‑app email. We’ll help per the Golden Guarantee policy."
                )
                
                SoftDivider(width: 280, opacity: 0.7)
                
                // 6) Create List
                FAQItem(
                    question: lang.isArabicEffective ? "كيف أنشئ قائمة جديدة؟" : "How do I create a new list?",
                    answer: lang.isArabicEffective ? "الصفحة الرئيسية → أنشئ قائمة → أضف المواقع/التطبيقات/الفئات → اختر الحماية → حدّد المدة." : "Home → Create List → add websites/apps/categories → choose protection → set duration."
                )
                
                // 7) Delete List
                FAQItem(
                    question: lang.isArabicEffective ? "كيف أحذف قائمة حجب؟ وهل تُحذف عناصرها؟" : "How do I delete a blocklist? Are its items deleted?",
                    answer: lang.isArabicEffective ? "من تفاصيل القائمة → حذف. تُحذف القائمة بالكامل مع عناصرها من جهازك." : "From list details → Delete. The list and its items are removed from your device."
                )
                
                // 8) Scheduling
                FAQItem(
                    question: lang.isArabicEffective ? "كيف أستخدم الجدولة؟" : "How do scheduling blocks work?",
                    answer: lang.isArabicEffective ? "من إنشاء القائمة → وقت الحجب → اختر \"الجدولة\" وحدّد الفترات حسب الأيام (ضمن الترقية)." : "In Create List → Time to block → choose \"Scheduled\" and set day/time ranges (part of Upgrade)."
                )
                
                // 9) App Picker permission
                FAQItem(
                    question: lang.isArabicEffective ? "لماذا لا أرى كل التطبيقات عند الاختيار؟" : "Why don’t I see all apps in the picker?",
                    answer: lang.isArabicEffective ? "يحتاج التطبيق إذن Screen Time. امنح الإذن من إعدادات الـ iPhone ثم أعد المحاولة." : "Screen Time permission is required. Grant access in Settings, then try again."
                )
                
                SoftDivider(width: 280, opacity: 0.7)
                
                // 10) Premium benefits
                FAQItem(
                    question: lang.isArabicEffective ? "ما هي فوائد النسخة المميزة (Premium)؟" : "What are the benefits of Premium?",
                    answer: lang.isArabicEffective ? "- قوائم غير محدودة\n- وضع الحماية الصارم غير محدود\n- اقتراحات سريعة وخطط جاهزة\n- مشاركة مجتمعية ومعسكرات تنظيف" : "- Unlimited lists\n- Unlimited Hard Mode\n- Quick suggestions & ready plans\n- Community participation and detox camps"
                )
                
                // 11) Golden Guarantee
                FAQItem(
                    question: lang.isArabicEffective ? "هل يوجد ضمان ذهبي؟" : "Is there a Golden Guarantee?",
                    answer: lang.isArabicEffective ? "الشهري: استرجاع كامل خلال 14 يوم. السنوي: خلال شهرين." : "Monthly: full refund within 14 days. Yearly: within two months."
                )
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 28)
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
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 16) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    if lang.isArabicEffective {
                        Text(question)
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.trailing)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.nnCardBody)
                            .foregroundColor(AppColors.textSecondary)
                    } else {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.nnCardBody)
                            .foregroundColor(AppColors.textSecondary)
                        Text(question)
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                }
            }
            
            if isExpanded {
                Text(answer)
                    .font(.body)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.top, 4)
                    .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
            }
        }
        .padding(20)
        .background(AppColors.uiSurface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.uiBorder, lineWidth: 0.5)
        )
    }
}

struct LogoutButton: View {
    @EnvironmentObject var lang: LanguageManager
    @State private var showConfirm = false
    @AppStorage(AppStorageKeys.isAuthenticated) private var isAuthenticated: Bool = true
    @AppStorage(AppStorageKeys.selectedTab) private var selectedTab: Int = 0
    
    var body: some View {
        // Destructive actions read as more intentional with an outline rather
        // than a solid red fill — the user has to consciously pick the
        // dangerous option vs. tapping the most-prominent button on screen.
        Button(action: { showConfirm = true }) {
            Text(lang.isArabicEffective ? "تسجيل الخروج" : "Log out")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
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
                AppleSignInCoordinator.shared.signOut()
                isAuthenticated = false
                selectedTab = 0
            } label: {
                Text(lang.isArabicEffective ? "سجّل الخروج" : "Log out")
            }
            Button(role: .cancel) {
            } label: {
                Text(lang.isArabicEffective ? "إلغاء" : "Cancel")
            }
        } message: {
            Text(lang.isArabicEffective ? "راح تحتاج تسجّل دخولك مرة ثانية للوصول لقوائمك وإعداداتك." : "You'll need to sign in again to access your lists and settings.")
        }
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        SettingsView()
            .environmentObject(LanguageManager.shared)
    }
}
