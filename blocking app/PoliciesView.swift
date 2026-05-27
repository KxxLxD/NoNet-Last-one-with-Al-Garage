import SwiftUI

/// Legal document viewer for Terms of Service and Privacy Policy.
///
/// Structure (top → bottom):
///   1. Tab picker (Terms / Privacy)
///   2. Meta card — Effective date, Last-updated date, Data Controller entity
///   3. Table of Contents — tappable section titles that scroll to the body
///   4. Section cards — each numbered, with optional TL;DR highlight box and
///      the full legal body (selectable)
///
/// All sections render expanded by default. Best practice for legal pages is
/// to make the text immediately visible — accordion-style hiding can be read
/// as "burying the disclosure" by regulators and is poor accessibility.
///
/// Anchor jumps use `ScrollViewReader` + `.id(section.id)` so the ToC links
/// scroll the corresponding card into view with an easeInOut animation.
struct PoliciesView: View {
    @EnvironmentObject var lang: LanguageManager
    @State private var selectedTab: Int  // 0 = Terms, 1 = Privacy

    /// Default-init keeps existing call sites working (Settings + About both
    /// open on the Terms tab). UpgradeView's two paywall links pass an
    /// explicit `initialTab` so each label deep-links to its own document —
    /// Apple §3.1.2(a) wants distinct paths to Terms vs Privacy.
    init(initialTab: Int = 0) {
        self._selectedTab = State(initialValue: initialTab)
    }

    private var isArabic: Bool { lang.isArabicEffective }

    private var sections: [LegalSection] {
        selectedTab == 0
            ? LegalContent.termsSections(isArabic: isArabic)
            : LegalContent.privacySections(isArabic: isArabic)
    }

    var body: some View {
        ZStack {
            AppColors.uiBackground.ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.lg) {
                        tabPicker
                            .id("top")
                        metaCard
                        tocCard(proxy: proxy)
                        ForEach(sections) { section in
                            sectionCard(section)
                                .id(section.id)
                        }
                        backToTopButton(proxy: proxy)
                    }
                    .padding(.horizontal, NNSpacing.xl)
                    .padding(.top, NNSpacing.sm)
                    .padding(.bottom, NNSpacing.xxl)
                }
            }
        }
        .navigationTitle(isArabic ? "السياسات والشروط" : "Policies & Terms")
        .navigationBarTitleDisplayMode(.inline)
    }

    // ─── Tab picker ───────────────────────────────────────────────

    @ViewBuilder
    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            Text(isArabic ? "الشروط" : "Terms").tag(0)
            Text(isArabic ? "الخصوصية" : "Privacy").tag(1)
        }
        .pickerStyle(.segmented)
    }

    // ─── Meta card (dates + entity) ───────────────────────────────

    @ViewBuilder
    private var metaCard: some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.sm) {
            HStack(spacing: NNSpacing.xs) {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundColor(AppColors.accent)
                VStack(alignment: isArabic ? .trailing : .leading, spacing: 2) {
                    Text(isArabic ? "تاريخ النفاذ" : "Effective date")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Text(LegalContent.effectiveDate)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)
                }
                Spacer(minLength: NNSpacing.lg)
                VStack(alignment: isArabic ? .leading : .trailing, spacing: 2) {
                    Text(isArabic ? "آخر تحديث" : "Last updated")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Text(LegalContent.lastUpdated)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)
                }
            }

            Divider().background(AppColors.uiBorder.opacity(0.5))

            VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.xxs) {
                HStack(spacing: NNSpacing.xs) {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(AppColors.accent)
                        .font(.caption)
                    Text(isArabic ? "مسؤول البيانات (Data Controller)" : "Data Controller")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Spacer(minLength: 0)
                }
                Text(LegalContent.entityName)
                    .font(.footnote)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                Text(isArabic
                     ? "السجل التجاري: \(LegalContent.entityRegistration)"
                     : "CR: \(LegalContent.entityRegistration)")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                Text(LegalContent.entityAddress)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                    .multilineTextAlignment(isArabic ? .trailing : .leading)
            }
            .textSelection(.enabled)
        }
        .padding(NNSpacing.md)
        .background(AppColors.uiSurface)
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: NNRadius.card)
                .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
        )
    }

    // ─── Table of Contents ────────────────────────────────────────

    @ViewBuilder
    private func tocCard(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.sm) {
            HStack(spacing: NNSpacing.xs) {
                Image(systemName: "list.bullet.indent")
                    .foregroundColor(AppColors.accent)
                Text(isArabic ? "فهرس الأقسام" : "Table of Contents")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                Spacer(minLength: 0)
            }

            VStack(spacing: 0) {
                ForEach(Array(sections.enumerated()), id: \.element.id) { idx, section in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo(section.id, anchor: .top)
                        }
                    }) {
                        HStack {
                            Text(section.title)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textPrimary)
                                .multilineTextAlignment(isArabic ? .trailing : .leading)
                                .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                            Image(systemName: isArabic ? "chevron.left" : "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.vertical, NNSpacing.xs)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: NNHitTarget.minimum)

                    if idx < sections.count - 1 {
                        Divider().background(AppColors.uiBorder.opacity(0.3))
                    }
                }
            }
        }
        .padding(NNSpacing.md)
        .background(AppColors.uiSurface)
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: NNRadius.card)
                .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
        )
    }

    // ─── Section card ─────────────────────────────────────────────

    @ViewBuilder
    private func sectionCard(_ section: LegalSection) -> some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.sm) {
            Text(section.title)
                .font(.title3.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                .multilineTextAlignment(isArabic ? .trailing : .leading)

            if let summary = section.summary {
                tldrBox(summary)
            }

            Text(section.body)
                .font(.body)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(isArabic ? .trailing : .leading)
                .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
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
    private func tldrBox(_ summary: String) -> some View {
        HStack(alignment: .top, spacing: NNSpacing.xs) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(AppColors.accent)
                .font(.caption)
                .padding(.top, 2)
            VStack(alignment: isArabic ? .trailing : .leading, spacing: 2) {
                Text(isArabic ? "ملخص بسيط" : "TL;DR")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppColors.accent)
                    .textCase(.uppercase)
                Text(summary)
                    .font(.footnote)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(isArabic ? .trailing : .leading)
                    .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
            }
        }
        .padding(NNSpacing.sm)
        .background(AppColors.infoBg)
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
        .textSelection(.enabled)
    }

    // ─── Back to top ──────────────────────────────────────────────

    @ViewBuilder
    private func backToTopButton(proxy: ScrollViewProxy) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.4)) {
                proxy.scrollTo("top", anchor: .top)
            }
        }) {
            HStack(spacing: NNSpacing.xs) {
                Image(systemName: "arrow.up.circle.fill")
                Text(isArabic ? "العودة للأعلى" : "Back to top")
            }
            .font(.footnote.weight(.semibold))
            .foregroundColor(AppColors.accent)
            .frame(maxWidth: .infinity)
            .frame(minHeight: NNHitTarget.minimum)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isArabic ? "العودة لأعلى الصفحة" : "Back to top of page")
    }
}

#Preview {
    NavigationView { PoliciesView().environmentObject(LanguageManager.shared) }
}
