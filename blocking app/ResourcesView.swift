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
            VStack(alignment: isArabic ? .trailing : .leading, spacing: 16) {
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
                    title: isArabic ? "كيف يعمل NoNet" : "How NoNet works",
                    bullets: isArabic
                        ? ["يستخدم Screen Time من Apple — حماية رسمية.",
                           "البيانات محلية، لا تُرسل لأي خادم خارجي.",
                           "وضع صارم يمنعك من فك الحجب أثناء التركيز.",
                           "شريك التعافي يستلم إشعاراً عند محاولات الكسر."]
                        : ["Uses Apple Screen Time — official OS protection.",
                           "All data stays local; nothing is sent to a backend.",
                           "Hard Mode prevents you from disabling mid-session.",
                           "Your recovery partner is notified on break attempts."]
                )

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(AppColors.uiBackground)
        .navigationTitle(isArabic ? "الموارد" : "Resources")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infographicCard(icon: String, title: String, bullets: [String]) -> some View {
        VStack(alignment: isArabic ? .trailing : .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(AppColors.accent)
                    .frame(width: 36, height: 36)
                    .background(AppColors.infoBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(isArabic ? .trailing : .leading)
                Spacer(minLength: 0)
            }
            VStack(alignment: isArabic ? .trailing : .leading, spacing: 8) {
                ForEach(bullets, id: \.self) { line in
                    HStack(alignment: .top, spacing: 8) {
                        if isArabic {
                            Spacer(minLength: 0)
                            Text(line)
                                .font(.footnote)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.trailing)
                            Text("•").foregroundColor(AppColors.accent)
                        } else {
                            Text("•").foregroundColor(AppColors.accent)
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
        .padding(20)
        .background(AppColors.uiSurface)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
    }
}

#Preview {
    NavigationStack { ResourcesView().environmentObject(LanguageManager.shared) }
}
