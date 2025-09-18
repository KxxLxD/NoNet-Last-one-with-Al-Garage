import SwiftUI

@available(iOS 17.0, *)
struct SettingsView: View {
    @EnvironmentObject var lang: LanguageManager
    @AppStorage("isPremium") private var isPremium: Bool = false
    @State private var showBlockPreview = false
    @State private var navigateToUpgrade = false
    
    private func hapticLight() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 24) {
                    // Language
                    HStack { Text(lang.isArabicEffective ? "اللغة" : "Language").font(.system(size: 22, weight: .semibold)).foregroundColor(AppColors.textPrimary); Spacer() }
                        .padding(.horizontal, 24)
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
                    .padding(20)
                    .background(AppColors.uiSurface)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppColors.uiBorder, lineWidth: 0.5)
                    )
                    .padding(.horizontal, 24)
                
                    // Subscription
                    HStack { Text(lang.isArabicEffective ? "الاشتراك" : "Subscription").font(.system(size: 22, weight: .semibold)).foregroundColor(AppColors.textPrimary); Spacer() }
                        .padding(.horizontal, 24)
                    VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
                        HStack {
                            Text(lang.isArabicEffective ? "الحالة" : "Status")
                            Spacer()
                            let badgeText = isPremium ? (lang.isArabicEffective ? "Premium فعال" : "Premium active") : (lang.isArabicEffective ? "نسخة مجانية" : "Free version")
                            Text(badgeText)
                                .font(.footnote)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().fill(isPremium ? AppColors.successGreen.opacity(0.12) : AppColors.infoBg)
                                )
                                .foregroundColor(isPremium ? AppColors.successGreen : AppColors.accentDark)
                        }
                        Text(lang.isArabicEffective ? "الترقية تفتح السكجوال والميزات المتقدمة." : "Upgrade unlocks scheduling and advanced features.")
                            .font(.footnote)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                        Text(lang.isArabicEffective ? "ضمان ذهبي: استرجاع 14 يومًا شهري / شهرين سنوي." : "Golden Guarantee: refund in 14 days monthly / 2 months yearly.")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                        Group {
                            Button(action: { hapticLight(); navigateToUpgrade = true }) {
                                Text(isPremium ? (lang.isArabicEffective ? "إدارة الاشتراك" : "Manage Subscription") : (lang.isArabicEffective ? "ترقية إلى Premium" : "Upgrade to Premium"))
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(AppColors.accentDark)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            .navigationDestination(isPresented: $navigateToUpgrade) {
                                UpgradeView().environmentObject(lang)
                            }
                        }
                    }
                    .padding(20)
                    .background(AppColors.uiSurface)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppColors.uiBorder, lineWidth: 0.5)
                    )
                    .padding(.horizontal, 24)

                    // Help & Support
                    HStack { Text(lang.isArabicEffective ? "المساعدة والدعم" : "Help & Support").font(.system(size: 22, weight: .semibold)).foregroundColor(AppColors.textPrimary); Spacer() }
                        .padding(.horizontal, 24)
                    VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
                        Link(destination: URL(string: "mailto:support@nonet.app")!) {
                            HStack {
                                Image(systemName: "envelope").foregroundColor(AppColors.accentDark)
                                    .font(.system(size: 20, weight: .regular))
                                Text(lang.isArabicEffective ? "بريد الدعم" : "Support Email")
                                Spacer()
                            }
                        }
                        .simultaneousGesture(TapGesture().onEnded { hapticLight() })
                        SoftDivider(width: 280, opacity: 0.70)
                        NavigationLink(destination: FAQView().environmentObject(lang)) {
                            HStack {
                                Image(systemName: "questionmark.circle").foregroundColor(AppColors.accentDark)
                                    .font(.system(size: 20, weight: .regular))
                                Text("FAQ")
                                Spacer()
                            }
                        }
                        .simultaneousGesture(TapGesture().onEnded { hapticLight() })
                        SoftDivider(width: 280, opacity: 0.70)
                        Button(action: { hapticLight(); showBlockPreview = true }) {
                            HStack {
                                Image(systemName: "eye").foregroundColor(AppColors.accentDark)
                                    .font(.system(size: 20, weight: .regular))
                                Text(lang.isArabicEffective ? "معاينة شاشة الحجب" : "Preview Block Screen")
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                    .background(AppColors.uiSurface)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppColors.uiBorder, lineWidth: 0.5)
                    )
                    .padding(.horizontal, 24)
                
                    // Community
                    HStack { Text(lang.isArabicEffective ? "المجتمع" : "Community").font(.system(size: 22, weight: .semibold)).foregroundColor(AppColors.textPrimary); Spacer() }
                        .padding(.horizontal, 24)
                    VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
                        Link(destination: URL(string: "https://example.com/whatsapp")!) {
                            HStack {
                                Image(systemName: "person.2.fill").foregroundColor(AppColors.accentDark)
                                    .font(.system(size: 20, weight: .regular))
                                Text(lang.isArabicEffective ? "مجموعة واتساب" : "WhatsApp Community")
                                Spacer()
                            }
                        }
                        .simultaneousGesture(TapGesture().onEnded { hapticLight() })
                        SoftDivider(width: 280, opacity: 0.70)
                        Link(destination: URL(string: "https://example.com/telegram")!) {
                            HStack {
                                Image(systemName: "paperplane.fill").foregroundColor(AppColors.accentDark)
                                    .font(.system(size: 20, weight: .regular))
                                Text(lang.isArabicEffective ? "قناة تيليجرام" : "Telegram Channel")
                                Spacer()
                            }
                        }
                        .simultaneousGesture(TapGesture().onEnded { hapticLight() })
                    }
                    .padding(20)
                    .background(AppColors.uiSurface)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppColors.uiBorder, lineWidth: 0.5)
                    )
                    .padding(.horizontal, 24)

                    // Legal
                    HStack { Text(lang.isArabicEffective ? "القانوني" : "Legal").font(.system(size: 22, weight: .semibold)).foregroundColor(AppColors.textPrimary); Spacer() }
                        .padding(.horizontal, 24)
                    VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
                        NavigationLink(destination: PoliciesView().environmentObject(lang)) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(AppColors.accentDark)
                                    .font(.system(size: 20, weight: .regular))
                                Text(lang.isArabicEffective ? "السياسات والشروط" : "Policies & Terms")
                                Spacer()
                            }
                        }
                    }
                    .padding(20)
                    .background(AppColors.uiSurface)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppColors.uiBorder, lineWidth: 0.5)
                    )
                    .padding(.horizontal, 24)

                    // About
                    HStack { Text(lang.isArabicEffective ? "حول التطبيق" : "About").font(.system(size: 22, weight: .semibold)).foregroundColor(AppColors.textPrimary); Spacer() }
                        .padding(.horizontal, 24)
                    VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
                        NavigationLink(destination: AboutView().environmentObject(lang)) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(AppColors.accentDark)
                                    .font(.system(size: 20, weight: .regular))
                                Text(lang.isArabicEffective ? "معلومات التطبيق" : "App Information")
                                Spacer()
                            }
                        }
                    }
                    .padding(20)
                    .background(AppColors.uiSurface)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppColors.uiBorder, lineWidth: 0.5)
                    )
                    .padding(.horizontal, 24)
                
                // Account / Logout
                    HStack { Text(lang.isArabicEffective ? "الحساب" : "Account").font(.system(size: 22, weight: .semibold)).foregroundColor(AppColors.textPrimary); Spacer() }
                        .padding(.horizontal, 24)
                    VStack(alignment: .center, spacing: 12) {
                        LogoutButton()
                            .environmentObject(lang)
                    }
                    .padding(20)
                    .background(AppColors.uiSurface)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppColors.uiBorder, lineWidth: 0.5)
                    )
                }
                .padding(.bottom, 28)
            }
            .background(AppColors.uiBackground)
            .navigationTitle(AppStrings.settingsTitle(lang))
        }
        .sheet(isPresented: $showBlockPreview) {
            BlockScreenView(
                isArabic: lang.isArabicEffective,
                onClose: { showBlockPreview = false },
                isOnBreak: false,
                upcomingBreakMinutes: nil,
                totalBreaks: 2,
                remainingBreaks: 2,
                breakDurationMinutes: 15
            )
                .environmentObject(lang)
                .padding(16)
        }
    }
}

struct FAQView: View {
    @EnvironmentObject var lang: LanguageManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 16) {
                Text(lang.isArabicEffective ? "الأسئلة الشائعة" : "Frequently Asked Questions")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
                
                // 1) What is NoNet?
                FAQItem(
                    question: lang.isArabicEffective ? "ما هو تطبيق نونت؟" : "What is NoNet?",
                    answer: lang.isArabicEffective ? "نونت يساعدك على ضبط استخدامك للإنترنت، حجب التطبيقات والمواقع المشتتة، وبناء عادات تركيز صحية." : "NoNet helps you control internet use, block distracting apps/websites, and build healthy focus habits."
                )
                
                // 2) Privacy & Data
                FAQItem(
                    question: lang.isArabicEffective ? "ماذا عن الخصوصية والبيانات؟" : "What about privacy and data?",
                    answer: lang.isArabicEffective ? "نحترم خصوصيتك — لا نبيع بياناتك. يعتمد التطبيق أساسًا على التخزين المحلي وعلى صلاحيات iOS." : "We respect your privacy — we don’t sell your data. The app relies primarily on local storage and iOS permissions."
                )
                
                // 3) Offline
                FAQItem(
                    question: lang.isArabicEffective ? "هل يعمل بدون إنترنت؟" : "Does it work offline?",
                    answer: lang.isArabicEffective ? "نعم، الحجب يعمل على الجهاز نفسه باستخدام صلاحيات Screen Time، حتى بدون اتصال." : "Yes. Blocking works on‑device via Screen Time permissions, even without internet."
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
                    answer: lang.isArabicEffective ? "يحتاج التطبيق إذن Screen Time. امنح الصلاحية من الإعدادات ثم أعد المحاولة." : "Screen Time permission is required. Grant access in Settings, then try again."
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
                    answer: lang.isArabicEffective ? "الشهري: استرجاع كامل خلال 14 يومًا. السنوي: خلال شهرين." : "Monthly: full refund within 14 days. Yearly: within two months."
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
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                    } else {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 20, weight: .regular))
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
    @AppStorage("isAuthenticated") private var isAuthenticated: Bool = true
    @AppStorage("selectedTab") private var selectedTab: Int = 0
    
    var body: some View {
        Button(action: { showConfirm = true }) {
            Text(lang.isArabicEffective ? "تسجيل الخروج" : "Log out")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundColor(.white)
                .background(AppColors.alertRed)
                .cornerRadius(12)
        }
        .alert(lang.isArabicEffective ? "تأكيد" : "Confirm", isPresented: $showConfirm) {
            Button(role: .destructive) {
                isAuthenticated = false
                selectedTab = 0
            } label: {
                Text(lang.isArabicEffective ? "تسجيل الخروج" : "Log out")
            }
            Button(role: .cancel) {
            } label: {
                Text(lang.isArabicEffective ? "إلغاء" : "Cancel")
            }
        } message: {
            Text(lang.isArabicEffective ? "هل أنت متأكد من تسجيل الخروج؟" : "Are you sure you want to log out?")
        }
    }
}

private struct SoftDivider: View {
    let width: CGFloat
    let opacity: Double
    var body: some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(AppColors.uiBorder.opacity(opacity))
                .frame(width: width, height: 1)
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        SettingsView()
            .environmentObject(LanguageManager.shared)
    }
}
