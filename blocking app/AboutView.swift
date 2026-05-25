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

    var body: some View {
        ZStack {
            AppColors.uiBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: isArabic ? .trailing : .leading, spacing: 24) {
                    heroSection
                    privacyBadge
                    featuresGrid
                    appInfoCard
                    linksCard
                    creditsFooter
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle(isArabic ? "عن التطبيق" : "About App")
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 12) {
            Image("nonet_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 18))
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
        .padding(.vertical, 16)
    }

    // MARK: - Privacy badge

    private var privacyBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(AppColors.warningFg)
            Text(isArabic ? "خصوصية 100% — محلي على جهازك" : "100% Privacy — Local on your device")
                .font(.footnote.weight(.semibold))
                .foregroundColor(AppColors.warningFg)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(AppColors.warningBg))
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
                Feature(icon: "lock.fill", title: "خصوصية مطلقة",
                        description: "لا تتبع، لا تحليلات، لا backend. كل بياناتك على جهازك."),
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
                Feature(icon: "lock.fill", title: "Absolute Privacy",
                        description: "No tracking, no analytics, no backend. All on-device."),
                Feature(icon: "bolt.fill", title: "Real Blocking via Apple",
                        description: "Uses official Screen Time API. System-level blocking."),
                Feature(icon: "gift.fill", title: "7-Day Free Trial",
                        description: "Try all premium features. Cancel anytime.")
            ]
        }
    }

    private var featuresGrid: some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: 12) {
            Text(isArabic ? "ما يميّز NoNet" : "What makes NoNet different")
                .font(.nnCardTitle)
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                .padding(.bottom, 4)

            ForEach(features) { feature in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: feature.icon)
                        .font(.title2)
                        .foregroundColor(AppColors.accent)
                        .frame(width: 32, height: 32)
                        .background(AppColors.infoBg)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: isArabic ? .trailing : .leading, spacing: 4) {
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
                .padding(.vertical, 4)
            }
        }
        .padding(20)
        .background(AppColors.uiSurface)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
    }

    // MARK: - App info card

    private var appInfoCard: some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: 10) {
            Text(isArabic ? "معلومات التطبيق" : "App Information")
                .font(.nnSubheader.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                .padding(.bottom, 4)

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
        .padding(20)
        .background(AppColors.uiSurface)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundColor(AppColors.textPrimary)
            Spacer()
            Text(value).foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Links

    private var linksCard: some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: 12) {
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
        .padding(20)
        .background(AppColors.uiSurface)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
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
    }

    // MARK: - Credits footer

    private var creditsFooter: some View {
        VStack(spacing: 8) {
            // SF Symbol heart renders consistently across fonts and Dynamic
            // Type sizes; the emoji 💙 was font-dependent and could fall back
            // to a black-and-white glyph on some configurations.
            HStack(spacing: 4) {
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
            Text("© 2026 NoNet App")
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary.opacity(0.7))
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

#Preview {
    NavigationView { AboutView().environmentObject(LanguageManager.shared) }
}
