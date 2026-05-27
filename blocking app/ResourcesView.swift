//
//  ResourcesView.swift
//  blocking app
//
//  Educational/motivational content shown from Settings. Static SwiftUI cards —
//  no fetch, no media assets, no analytics. v1 establishes the surface; videos
//  and infographic images land later when production-quality assets exist.
//

import SwiftUI

struct ResourcesView: View {
    @EnvironmentObject var lang: LanguageManager
    private var isArabic: Bool { lang.isArabicEffective }

    var body: some View {
        ScrollView {
            VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.md) {
                Text(isArabic ? "موارد ومعرفة" : "Resources & Knowledge")
                    .font(.nnSectionTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)

                Text(isArabic
                     ? "محتوى تعليمي قصير يساعدك على فهم سلوكك الرقمي وبناء عادات صحية."
                     : "Short, focused reading to help you understand your digital habits and build healthier ones.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(isArabic ? .trailing : .leading)
                    .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)

                infographicCard(
                    icon: "iphone.gen3",
                    accentColor: AppColors.alertRed,   // alarming statistics → red
                    title: isArabic ? "إحصائيات إدمان الشاشات" : "Screen-time addiction in numbers",
                    bullets: isArabic
                        ? ["البالغ يفتح هاتفه ~58 مرة يومياً.",
                           "متوسط استخدام السوشيال 2.5 ساعة/يوم.",
                           "55% يشعرون بقلق عند البعد عن الهاتف.",
                           "كل إشعار يقطع التركيز نحو 23 دقيقة."]
                        : ["Adults unlock their phones ~58×/day.",
                           "Average social-media use: 2.5 hours/day.",
                           "55% report anxiety when away from their phone.",
                           "Each notification breaks focus for ~23 minutes."]
                )

                infographicCard(
                    icon: "leaf.fill",
                    accentColor: AppColors.successGreen, // benefits / growth → green
                    title: isArabic ? "فوائد التخلص الرقمي" : "Benefits of a digital detox",
                    bullets: isArabic
                        ? ["تحسّن جودة النوم خلال أسبوع.",
                           "زيادة قدرة التركيز والاستيعاب.",
                           "انخفاض ملحوظ في مستوى التوتر.",
                           "وقت أكثر للعائلة والهوايات الحقيقية."]
                        : ["Better sleep quality within a week.",
                           "Improved focus and comprehension.",
                           "Noticeable reduction in stress.",
                           "More time for family and real hobbies."]
                )

                infographicCard(
                    icon: "shield.lefthalf.filled",
                    accentColor: AppColors.accent,       // how NoNet works → brand accent
                    title: isArabic ? "كيف يعمل NoNet" : "How NoNet works",
                    bullets: isArabic
                        ? ["يستخدم Screen Time من Apple — حماية رسمية.",
                           "البيانات تبقى على جهازك افتراضياً. iCloud يُستخدم فقط عند تفعيل شريك التعافي (اختياري).",
                           "وضع صارم يمنعك من فك الحجب أثناء التركيز.",
                           "شريك التعافي يستلم إشعاراً عند محاولات الكسر."]
                        : ["Uses Apple Screen Time — official OS protection.",
                           "Data stays local by default. iCloud is used only when Recovery Partner is enabled (optional).",
                           "Hard Mode prevents you from disabling mid-session.",
                           "Your recovery partner is notified on break attempts."]
                )

                Spacer(minLength: NNSpacing.xs)
            }
            .padding(.horizontal, NNSpacing.xl)
            .padding(.top, NNSpacing.md)
            .padding(.bottom, NNSpacing.xxl - 4)
        }
        .background(AppColors.uiBackground)
        .navigationTitle(isArabic ? "الموارد" : "Resources")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Each card carries its own `accentColor` so the three categories
    /// (alarming statistics / benefits / how-NoNet-works) read as visually
    /// distinct rather than three identical blue blocks. Bullets use a
    /// filled-circle SF Symbol instead of the bullet character, which kept
    /// rendering inconsistently across font fallbacks.
    private func infographicCard(icon: String, accentColor: Color, title: String, bullets: [String]) -> some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.sm) {
            HStack(spacing: NNSpacing.xs + 2) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(accentColor)
                    .frame(width: 36, height: 36)
                    .background(accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.chip))
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(isArabic ? .trailing : .leading)
                Spacer(minLength: 0)
            }
            VStack(alignment: isArabic ? .trailing : .leading, spacing: NNSpacing.xs) {
                ForEach(bullets, id: \.self) { line in
                    HStack(alignment: .top, spacing: NNSpacing.xs) {
                        if isArabic {
                            Spacer(minLength: 0)
                            Text(line)
                                .font(.footnote)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.trailing)
                            Image(systemName: "circle.fill")
                                .font(.caption2)
                                .foregroundColor(accentColor)
                                .padding(.top, NNSpacing.xxs + 1)
                        } else {
                            Image(systemName: "circle.fill")
                                .font(.caption2)
                                .foregroundColor(accentColor)
                                .padding(.top, NNSpacing.xxs + 1)
                            Text(line)
                                .font(.footnote)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
        .padding(NNSpacing.lg)
        .background(AppColors.uiSurface)
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.container))
        .overlay(
            RoundedRectangle(cornerRadius: NNRadius.container)
                .stroke(accentColor.opacity(0.25), lineWidth: NNBorder.hairline)
        )
    }
}

#Preview {
    NavigationStack { ResourcesView().environmentObject(LanguageManager.shared) }
}
