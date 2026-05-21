//
//  LegalContent.swift
//  blocking app
//
//  Centralized legal text — bilingual (English / Arabic).
//
//  NOTE: This content was drafted as a strong default for a local-first wellness app that
//  does NOT collect or transmit personal data. If you change data collection, networking,
//  or third-party integrations, you MUST review and update both texts and consult a lawyer
//  before App Store submission, especially for PDPL (Saudi Arabia) and GDPR (EU).
//

import Foundation

enum LegalContent {
    static let lastUpdated = "2026-05-22"

    // MARK: - Privacy Policy
    static let privacyArabic: String = """
سياسة الخصوصية — تطبيق NoNet

آخر تحديث: \(lastUpdated)

نحن في NoNet نقدّر خصوصيتك. صُمّم التطبيق ليعمل بشكل محلي على جهازك بقدر الإمكان، دون إرسال بياناتك الشخصية إلى خوادمنا.

١) البيانات التي نجمعها
- التطبيق لا يجمع بيانات شخصية تعريفية (الاسم، البريد، رقم الهاتف) ولا يرسلها لأي خادم.
- جميع قوائم الحجب، الجداول، الإعدادات، وبيانات الإدمان التي تدخلها تُخزَّن محلياً على جهازك فقط داخل Core Data و UserDefaults.

٢) أذونات النظام
- Screen Time (Family Controls): يستخدم محلياً لتفعيل ميزة حجب التطبيقات والمواقع عبر iOS. لا تُرسل بيانات الأنشطة المختارة إلى خوادمنا.
- الإشعارات: تُستخدم لتنبيهك بمواعيد الحجب أو نهايته.

٣) المشتريات داخل التطبيق
- تتم عبر StoreKit الخاص بشركة Apple. لا نرى بيانات بطاقتك الائتمانية أو هويتك في حساب Apple.
- معلومات الاشتراك يديرها App Store وفقاً لسياسة Apple.

٤) Sign in with Apple
- إذا اخترت تسجيل الدخول بـ Apple، يُحفظ معرّف Apple الخاص بك في Keychain على جهازك فقط.
- لا نرسل هذا المعرّف إلى أي خادم.

٥) المساعد المحلي (Chat)
- يعمل بنظام محلي يطابق الكلمات المفتاحية. لا تُرسل رسائلك إلى أي خادم.

٦) عدم التتبع
- لا نستخدم Google Analytics ولا Firebase ولا أي أداة تتبع أو تحليلات لجهة خارجية.
- لا نستخدم ملفات ارتباط (Cookies) ولا معرفات إعلانية.

٧) أمان البيانات
- البيانات المخزنة محلياً محمية بآليات iOS القياسية.
- المعرفات الحساسة (مثل Apple ID) محفوظة في Keychain مع وصول After First Unlock.

٨) حقوقك (PDPL السعودي و GDPR)
- لك الحق في الوصول إلى بياناتك (وهي محلية على جهازك بالأساس).
- لك الحق في حذف بياناتك بحذف التطبيق أو من خلال إعدادات النظام.
- لك الحق في تصحيح بياناتك من داخل التطبيق.

٩) الأطفال
- التطبيق غير موجّه للأطفال دون سن ١٣ عاماً.

١٠) تغييرات السياسة
- قد نحدّث هذه السياسة. سيُعرض الإصدار الأحدث داخل التطبيق وسيُذكر تاريخ آخر تحديث أعلاه.

١١) التواصل
- لأي استفسار: support@nonet.app
"""

    static let privacyEnglish: String = """
Privacy Policy — NoNet App

Last updated: \(lastUpdated)

At NoNet we value your privacy. This app is designed to operate locally on your device as much as possible, without sending your personal data to our servers.

1) Data we collect
- The app does NOT collect identifiable personal data (name, email, phone) and does not transmit them to any server.
- All blocklists, schedules, settings, and onboarding profile data you enter are stored locally on your device only, in Core Data and UserDefaults.

2) System permissions
- Screen Time (Family Controls): used locally to enable app/website blocking via iOS. Selection data is not transmitted to our servers.
- Notifications: used to notify you of blocking start/end events.

3) In-app purchases
- Handled by Apple StoreKit. We do not see your credit card information or Apple Account identity.
- Subscription information is managed by the App Store per Apple policies.

4) Sign in with Apple
- If you choose to sign in with Apple, your Apple user identifier is stored in the iOS Keychain on your device only.
- We do not transmit this identifier to any server.

5) Local assistant (Chat)
- Operates with a local keyword-matching engine. Your messages are not sent to any server.

6) No tracking
- We do not use Google Analytics, Firebase, or any third-party analytics/tracking SDKs.
- We do not use Cookies or advertising identifiers.

7) Data security
- Locally-stored data is protected by standard iOS mechanisms.
- Sensitive identifiers (e.g., Apple user ID) are stored in the Keychain with "After First Unlock" accessibility.

8) Your rights (Saudi PDPL and EU GDPR)
- You have the right to access your data (which is stored locally by default).
- You have the right to erase your data by deleting the app or via system settings.
- You have the right to correct your data from within the app.

9) Children
- The app is not directed to children under the age of 13.

10) Policy changes
- We may update this policy. The latest version will be shown in the app, with the last-updated date shown above.

11) Contact
- For any inquiries: support@nonet.app
"""

    // MARK: - Terms of Service
    static let termsArabic: String = """
الشروط والأحكام — تطبيق NoNet

آخر تحديث: \(lastUpdated)

باستخدامك تطبيق NoNet (يُشار إليه فيما يلي بـ"التطبيق") فإنك توافق على هذه الشروط.

١) الاستخدام
- يُتاح التطبيق للاستخدام الشخصي وغير التجاري لتحسين عاداتك الرقمية وتعزيز التركيز.
- لا يجوز إعادة هندسة التطبيق أو محاولة تجاوز أنظمة Apple الأمنية أو نظام الاشتراك.

٢) الاشتراكات
- يقدّم التطبيق اشتراكات شهرية وسنوية تُدار بالكامل عبر App Store.
- يتجدد الاشتراك تلقائياً ما لم تُلغِه قبل ٢٤ ساعة من نهاية الفترة الحالية.
- يمكنك إدارة وإلغاء الاشتراك من إعدادات Apple → معرف Apple → الاشتراكات.

٣) الضمان الذهبي (الاسترداد)
- نقدم سياسة استرداد:
  - للاشتراك الشهري: استرداد كامل خلال ١٤ يوماً من تاريخ الاشتراك.
  - للاشتراك السنوي: استرداد كامل خلال شهر واحد من تاريخ الاشتراك.
- نظراً لأن المدفوعات تُعالجها Apple، فإن طلبات الاسترداد تُقدَّم عبر App Store → "الإبلاغ عن مشكلة" أو reportaproblem.apple.com.
- في حال رفض Apple الاسترداد لأي سبب، التزامنا بالضمان قائم ضمن المدة المذكورة أعلاه.

٤) المحتوى والملكية الفكرية
- التطبيق ومحتواه (التصميم، الكود، الشعارات) محمي بحقوق ملكية فكرية.

٥) إخلاء المسؤولية
- التطبيق يُقدَّم "كما هو". لا نضمن منع الإلهاءات بنسبة ١٠٠٪، لأن نظام Screen Time من Apple يضع حدوداً تقنية.
- لا نتحمل مسؤولية أي أضرار غير مباشرة ناتجة عن استخدام أو تعطّل التطبيق.

٦) إيقاف الخدمة
- يحق لنا إيقاف الحساب في حال تبيّن أن المستخدم خالف هذه الشروط.

٧) القانون الحاكم
- تخضع هذه الشروط لأنظمة المملكة العربية السعودية، ولأنظمة الاتحاد الأوروبي بالقدر الذي تنطبق فيه على المستخدمين هناك.

٨) التواصل
- لأي استفسار قانوني أو طلب استرداد: support@nonet.app
"""

    static let termsEnglish: String = """
Terms & Conditions — NoNet App

Last updated: \(lastUpdated)

By using the NoNet app (hereafter "the App") you agree to these terms.

1) Use
- The App is provided for personal, non-commercial use to improve your digital habits and focus.
- You may not reverse-engineer the App or attempt to bypass Apple security or subscription systems.

2) Subscriptions
- The App offers monthly and yearly subscriptions managed entirely via the App Store.
- Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period.
- You can manage and cancel subscriptions from Apple Settings → Apple ID → Subscriptions.

3) Golden Guarantee (Refunds)
- We offer a refund policy:
  - Monthly subscription: full refund within 14 days of purchase.
  - Yearly subscription: full refund within 1 month of purchase.
- Since payments are processed by Apple, refund requests must be submitted via App Store → "Report a Problem" or reportaproblem.apple.com.
- If Apple denies a refund for any reason, our guarantee commitment stands within the periods above.

4) Content and Intellectual Property
- The App and its content (design, code, logos) are protected by intellectual property rights.

5) Disclaimer
- The App is provided "as is". We do not guarantee 100% distraction prevention, as Apple's Screen Time system imposes technical limits.
- We are not liable for indirect damages arising from the use of, or inability to use, the App.

6) Service Termination
- We reserve the right to terminate accounts of users found violating these terms.

7) Governing Law
- These terms are governed by the laws of the Kingdom of Saudi Arabia, and EU laws to the extent applicable to users there.

8) Contact
- For any legal inquiry or refund request: support@nonet.app
"""
}
