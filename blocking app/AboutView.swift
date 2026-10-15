import SwiftUI

struct AboutView: View {
    @EnvironmentObject var lang: LanguageManager
    private var isArabic: Bool { lang.isArabicEffective }

    private var appName: String { isArabic ? "نونِت" : "NoNet" }
    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return isArabic ? "الإصدار \(v)" : "Version \(v)"
    }
    private var buildString: String {
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return isArabic ? "بناء \(b)" : "Build \(b)"
    }
    private var currentYear: String {
        String(Calendar.current.component(.year, from: Date()))
    }

    var body: some View {
        ZStack {
            AppColors.uiBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.xl) {
                    heroSection
                    privacyBadge
                    featuresGrid
                    appInfoCard
                    entityCard
                    linksCard
                    creditsFooter
                }
                .padding(.horizontal, NNSpacing.lg)
                .padding(.vertical, NNSpacing.xl)
            }
        }
        .navigationTitle(isArabic ? "عن التطبيق" : "About App")
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: NNSpacing.sm) {
            Image("nonet_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
                .shadow(color: AppColors.accent.opacity(0.15), radius: 12, y: 4)

            Text(appName)
                .font(.largeTitle.weight(.bold))
                .foregroundColor(AppColors.accent)

            Text(isArabic
                 ? "استعد تركيزك. تخلّص من الإلهاءات."
                 : "Reclaim your focus. Remove the distractions.")
                .font(.body.weight(.medium))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, NNSpacing.md)
    }

    // MARK: - Privacy badge

    private var privacyBadge: some View {
        // The previous "100% Privacy" claim was demoted to a more defensible
        // "Privacy-first" wording: the optional Recovery Partner uses Apple's
        // iCloud (a backend, even if not ours), and local email accounts do
        // persist user data on-device. The footnote acknowledges the
        // iCloud caveat plainly so the badge isn't read as misleading under
        // EU UCPD or KSA consumer-protection law.
        VStack(spacing: NNSpacing.xxs) {
            HStack(spacing: NNSpacing.xs) {
                Image(systemName: "lock.shield.fill")
                    .font(.subheadline)
                    .foregroundColor(AppColors.warningFg)
                Text(isArabic ? "خصوصية أولوية — بياناتك على جهازك*" : "Privacy-first — your data stays on your device*")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.warningFg)
            }
            .padding(.horizontal, NNSpacing.md)
            .padding(.vertical, NNSpacing.sm)
            .background(Capsule().fill(AppColors.warningBg))

            Text(isArabic
                 ? "* ميزة \"شريك التعافي\" الاختيارية تستخدم iCloud من Apple فقط."
                 : "* Optional Recovery Partner uses Apple's iCloud only.")
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Features

    private struct Feature: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let description: String
    }

    private var features: [Feature] {
        if isArabic {
            return [
                Feature(icon: "shield.lefthalf.filled", title: "الوضع الصارم",
                        description: "اختر التزامك. لا يمكنك تجاوز الحجب حتى ينتهي وقته."),
                Feature(icon: "calendar", title: "جدولة ذكية",
                        description: "قوائم متعددة بأوقات وأيام مختلفة. وقت العمل، وقت النوم."),
                Feature(icon: "globe", title: "عربي وإنجليزي",
                        description: "دعم RTL كامل. واجهة طبيعية للقارئ العربي."),
                Feature(icon: "lock.fill", title: "خصوصية أولوية",
                        description: "لا متتبعات خارجية، لا تحليلات، لا خوادمنا. iCloud اختياري للشريك."),
                Feature(icon: "bolt.fill", title: "حجب حقيقي عبر Apple",
                        description: "يستخدم Screen Time API الرسمي. حجب على مستوى النظام."),
                Feature(icon: "gift.fill", title: "تجربة مجانية 7 أيام",
                        description: "جرّب كل المزايا المميزة بدون التزام. ألغِ متى شئت.")
            ]
        } else {
            return [
                Feature(icon: "shield.lefthalf.filled", title: "Hard Mode",
                        description: "Commit and you can't undo it until time runs out."),
                Feature(icon: "calendar", title: "Smart Scheduling",
                        description: "Multiple lists with different times and days."),
                Feature(icon: "globe", title: "Arabic & English",
                        description: "Full RTL support. Natural for Arabic readers."),
                Feature(icon: "lock.fill", title: "Privacy-first",
                        description: "No third-party trackers, no analytics, no servers of ours. iCloud optional for Recovery Partner."),
                Feature(icon: "bolt.fill", title: "Real Blocking via Apple",
                        description: "Uses official Screen Time API. System-level blocking."),
                Feature(icon: "gift.fill", title: "7-Day Free Trial",
                        description: "Try all premium features. Cancel anytime.")
            ]
        }
    }

    private var featuresGrid: some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.sm) {
            Text(isArabic ? "ما يميّز NoNet" : "What makes NoNet different")
                .font(.nnCardTitle)
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                .padding(.bottom, NNSpacing.xxs)

            ForEach(features) { feature in
                HStack(alignment: .top, spacing: NNSpacing.sm) {
                    Image(systemName: feature.icon)
                        .font(.title2)
                        .foregroundColor(AppColors.accent)
                        .frame(width: 32, height: 32)
                        .background(AppColors.infoBg)
                        .clipShape(RoundedRectangle(cornerRadius: NNRadius.chip))
                    VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.xxs) {
                        Text(feature.title)
                            .font(.nnButton)
                            .foregroundColor(AppColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                        Text(feature.description)
                            .font(.footnote)
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                            .multilineTextAlignment(isArabic ? .trailing : .leading)
                    }
                }
                .padding(.vertical, NNSpacing.xxs)
            }
        }
        .padding(NNSpacing.lg)
        .background(AppColors.uiSurface)
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.container))
        .overlay(
            RoundedRectangle(cornerRadius: NNRadius.container)
                .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
        )
    }

    // MARK: - App info card

    private var appInfoCard: some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.xs + 2) {
            Text(isArabic ? "معلومات التطبيق" : "App Information")
                .font(.nnSubheader.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                .padding(.bottom, NNSpacing.xxs)

            infoRow(label: isArabic ? "الاسم" : "Name", value: appName)
            Divider().background(AppColors.uiBorder.opacity(0.4))
            infoRow(label: isArabic ? "الإصدار" : "Version", value: versionString)
            Divider().background(AppColors.uiBorder.opacity(0.4))
            infoRow(label: isArabic ? "البناء" : "Build", value: buildString)
            Divider().background(AppColors.uiBorder.opacity(0.4))
            infoRow(label: isArabic ? "النظام الأدنى" : "Min iOS", value: "iOS 16.0+")
            Divider().background(AppColors.uiBorder.opacity(0.4))
            infoRow(label: isArabic ? "الأجهزة" : "Devices", value: "iPhone + iPad")
        }
        .padding(NNSpacing.lg)
        .background(AppColors.uiSurface)
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.container))
        .overlay(
            RoundedRectangle(cornerRadius: NNRadius.container)
                .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
        )
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundColor(AppColors.textPrimary)
            Spacer()
            Text(value).foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Entity (Data Controller) card
    //
    // GDPR Article 13, PDPL, and CCPA all require the operating legal entity
    // to be identifiable to the user. Surfacing this in About — alongside the
    // full text in PoliciesView — makes the controller discoverable from any
    // entry point without burying it inside the policy document.
    private var entityCard: some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.xs + 2) {
            Text(isArabic ? "الكيان المُشغِّل" : "Operating Entity")
                .font(.nnSubheader.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                .padding(.bottom, NNSpacing.xxs)

            infoRow(label: isArabic ? "الاسم القانوني" : "Legal name", value: LegalContent.entityName)
            Divider().background(AppColors.uiBorder.opacity(0.4))
            infoRow(label: isArabic ? "السجل التجاري" : "Registration", value: LegalContent.entityRegistration)
            Divider().background(AppColors.uiBorder.opacity(0.4))
            VStack(alignment: isArabic ? .trailing : .leading, spacing: 2) {
                HStack {
                    Text(isArabic ? "العنوان" : "Address").foregroundColor(AppColors.textPrimary)
                    Spacer()
                }
                Text(LegalContent.entityAddress)
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(isArabic ? .trailing : .leading)
                    .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
            }
            Divider().background(AppColors.uiBorder.opacity(0.4))
            Link(destination: URL(string: "mailto:\(LegalContent.privacyContactEmail)")!) {
                HStack {
                    Text(isArabic ? "بريد الخصوصية" : "Privacy contact")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text(LegalContent.privacyContactEmail)
                        .foregroundColor(AppColors.accent)
                        .font(.footnote)
                }
                .frame(minHeight: NNHitTarget.minimum)
            }
        }
        .textSelection(.enabled)
        .padding(NNSpacing.lg)
        .background(AppColors.uiSurface)
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.container))
        .overlay(
            RoundedRectangle(cornerRadius: NNRadius.container)
                .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
        )
    }

    // MARK: - Links

    private var linksCard: some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.sm) {
            Text(isArabic ? "روابط" : "Links")
                .font(.nnSubheader.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)

            Link(destination: URL(string: "mailto:support@nonet.app")!) {
                linkRow(icon: "envelope.fill", text: isArabic ? "بريد الدعم" : "Support Email")
            }
            Divider().background(AppColors.uiBorder.opacity(0.4))
            NavigationLink(destination: PoliciesView().environmentObject(lang)) {
                linkRow(icon: "doc.text.fill", text: isArabic ? "السياسات والشروط" : "Policies & Terms")
            }
            Divider().background(AppColors.uiBorder.opacity(0.4))
            NavigationLink(destination: FAQView().environmentObject(lang)) {
                linkRow(icon: "questionmark.circle.fill", text: isArabic ? "الأسئلة الشائعة" : "FAQ")
            }
        }
        .padding(NNSpacing.lg)
        .background(AppColors.uiSurface)
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.container))
        .overlay(
            RoundedRectangle(cornerRadius: NNRadius.container)
                .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
        )
    }

    private func linkRow(icon: String, text: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(AppColors.accent)
                .font(.title3)
            Text(text)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Image(systemName: isArabic ? "chevron.left" : "chevron.right")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(minHeight: NNHitTarget.minimum)
    }

    // MARK: - Credits footer

    private var creditsFooter: some View {
        VStack(spacing: NNSpacing.xs) {
            HStack(spacing: NNSpacing.xxs) {
                Text(isArabic ? "شكراً لاستخدامك NoNet" : "Thanks for using NoNet")
                Image(systemName: "heart.fill")
                    .foregroundColor(AppColors.accent)
                    .font(.footnote)
            }
            .font(.footnote.weight(.medium))
            .foregroundColor(AppColors.textPrimary)

            Text(isArabic
                 ? "صُنع بعناية لمساعدتك على تركيز أعمق."
                 : "Made with care to help you focus deeper.")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            // Year computed at render time so the footer never goes stale.
            // Copyright line names the legal entity for IP-ownership clarity
            // (a generic brand name like "NoNet App" would be weaker in any
            // future infringement dispute).
            Text("© \(currentYear) \(LegalContent.entityName)")
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary.opacity(0.7))
                .padding(.top, NNSpacing.xxs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, NNSpacing.lg)
    }
}

#Preview {
    NavigationView { AboutView().environmentObject(LanguageManager.shared) }
}
