//
//  LegalContent.swift
//  blocking app
//
//  Centralized legal text — bilingual (English / Arabic).
//
//  Restructured 2026-06: moved from flat `String` blobs to a structured
//  section model so the PoliciesView can render a Table of Contents, anchor
//  links, and plain-language TL;DR boxes. Coverage updated to address GDPR
//  (EU), PDPL (Saudi Arabia), CCPA (California), and COPPA (US children's
//  privacy) at a best-effort baseline.
//
//  IMPORTANT: This text is a strong default for a local-first wellness app
//  that does NOT operate its own backend. It MUST be reviewed by qualified
//  counsel before App Store submission. Some fields are placeholders (`[TBD:
//  …]`) that need to be filled in with the legal entity's real registered
//  information before publication.
//

import Foundation

/// A single addressable section of a legal document.
///
/// - `id` is a stable anchor used by `PoliciesView` to scroll to the section
///   from the Table of Contents. Keep it kebab-case and unique within a
///   document.
/// - `summary` is a one- or two-line plain-language "TL;DR" rendered in a
///   highlight box above the full body. Optional — pass `nil` for a section
///   that doesn't benefit from a summary (e.g. the closing contact block).
/// - `body` is the legal text itself, already localized to the requested
///   language. The view applies `.textSelection(.enabled)` so users can copy
///   any passage.
struct LegalSection: Identifiable {
    let id: String
    let title: String
    let summary: String?
    let body: String
}

enum LegalContent {
    // MARK: - Versioning

    /// Date when the *current* document took effect. Displayed prominently at
    /// the top of the policies screen.
    static let effectiveDate = "2026-06-01"
    /// Date of the most recent edit. May equal `effectiveDate` on a fresh
    /// publish; diverges when small clarifications are made between major
    /// updates.
    static let lastUpdated = "2026-06-01"

    // MARK: - Entity / Controller information
    //
    // These placeholders must be replaced before App Store publication.
    // GDPR Article 13(1)(a) requires the data controller's identity to be
    // disclosed; PDPL Article 12 and CCPA §1798.130(a)(1)(B) are analogous.

    static let entityName = "NoNet Company"
    /// Placeholder — user said they'd provide the real CR number later
    /// (current value 777777 is a stand-in to keep the document readable).
    static let entityRegistration = "[TBD — placeholder] 777777"
    static let entityAddress = "King Abdulaziz City for Science and Technology (KACST), The Garage, Riyadh, Saudi Arabia"
    static let entityJurisdiction = "Kingdom of Saudi Arabia"

    // MARK: - Contact channels

    static let supportEmail = "support@nonet.app"
    /// Dedicated privacy / DPO inbox. Falls back to support email until the
    /// real mailbox is provisioned.
    static let privacyContactEmail = "privacy@nonet.app"

    // MARK: - Public API — Privacy

    static func privacySections(isArabic: Bool) -> [LegalSection] {
        isArabic ? privacyAr : privacyEn
    }

    // MARK: - Public API — Terms

    static func termsSections(isArabic: Bool) -> [LegalSection] {
        isArabic ? termsAr : termsEn
    }

    // MARK: - Privacy Policy (Arabic)

    private static let privacyAr: [LegalSection] = [
        LegalSection(
            id: "intro",
            title: "1. مقدمة",
            summary: "تطبيق NoNet مصمَّم محلياً على جهازك. بياناتك لا تمر عبر خوادمنا — هذه السياسة توضّح بالضبط ما الذي يحدث.",
            body: """
نحن في NoNet نأخذ خصوصيتك بجدية. هذه السياسة تشرح كيف نتعامل مع بياناتك عند استخدامك لتطبيق NoNet ("التطبيق").

التطبيق مبني وفق مبدأ الخصوصية أولاً (Privacy by Design): معظم البيانات تبقى على جهازك، ولا نشغّل خوادم خاصة بنا. حين تُستخدم خدمة من Apple (مثل iCloud الاختياري أو StoreKit للمدفوعات)، فإنها تعمل وفقاً لسياسة Apple، ولا تمر عبرنا.

باستخدامك للتطبيق، فإنك توافق على ممارسات الخصوصية الموضحة هنا.
"""
        ),
        LegalSection(
            id: "controller",
            title: "2. من نحن — مسؤول البيانات",
            summary: "هذا هو الكيان القانوني المسؤول عن التطبيق وبياناتك.",
            body: """
الكيان القانوني المسؤول عن معالجة بياناتك (Data Controller) وفقاً للأنظمة المعمول بها:

• الاسم القانوني: \(entityName)
• السجل التجاري: \(entityRegistration)
• العنوان: \(entityAddress)
• البريد للاستفسارات القانونية: \(privacyContactEmail)
• البريد للدعم العام: \(supportEmail)

نظراً لطبيعة التطبيق المحلية، لا نقوم بتعيين مسؤول حماية بيانات (DPO) رسمي بموجب GDPR Article 37. ومع ذلك، يمكنك التواصل معنا في أي وقت عبر بريد الخصوصية أعلاه لأي طلب يتعلق ببياناتك.
"""
        ),
        LegalSection(
            id: "data-collected",
            title: "3. البيانات التي نتعامل معها",
            summary: "ثلاث فئات: بيانات محلية على جهازك فقط، بيانات اختيارية في iCloud، وبيانات تديرها Apple.",
            body: """
نقسّم البيانات إلى ثلاث فئات واضحة:

أ) بيانات محلية على جهازك فقط (لا تغادر الجهاز):
• قوائم الحجب وعناصرها (تطبيقات/مواقع/فئات مختارة)
• جداول الحجب والإعدادات
• إجابات الإعداد الأولي (الاسم، الفئة العمرية، الأهداف)
• محادثات المساعد المحلي (تعمل بنظام مطابقة كلمات، بدون إرسال للسحابة)
• في حال أنشأت حساباً بالبريد محلياً: عنوان البريد + نسخة مُشفّرة من كلمة المرور (مخزّنة في Keychain)

ب) بيانات iCloud الاختيارية — فقط عند تفعيل ميزة "شريك التعافي":
• معرّف Apple مُستعار (pseudonymous) للمستخدم وللشريك
• اسم العرض الذي تختاره لنفسك
• اسم القائمة المُشاركة
• سجلات محاولات كسر الحجب (نوع المحاولة + الوقت)
ملاحظة: هذه البيانات تُخزَّن في حساب iCloud الخاص بك وحساب الشريك فقط. لا تمر عبر خوادمنا. يمكنك إلغاء الشراكة في أي وقت.

ج) بيانات تديرها Apple بشكل مستقل (لا نراها):
• بيانات الاشتراك والدفع — يديرها App Store / StoreKit بالكامل
• معرّف Sign in with Apple — يُحفظ في Keychain على جهازك فقط، ولا نرسله

لا نجمع: أسماء حقيقية، أرقام هواتف، مواقع جغرافية، بيانات بطاقات ائتمانية، أو معرّفات إعلانية.
"""
        ),
        LegalSection(
            id: "use",
            title: "4. كيف نستخدم بياناتك والأساس القانوني",
            summary: "نستخدم بياناتك فقط لتشغيل التطبيق على جهازك. لا توجد معالجة لأغراض تسويقية أو تحليلية.",
            body: """
الأغراض التي تُستخدم فيها بياناتك، والأساس القانوني لكل منها (GDPR Article 6):

• تشغيل ميزات الحجب وعرض قوائمك — أداء العقد (Article 6(1)(b))
• حفظ تفضيلاتك وإعداداتك بين الجلسات — أداء العقد
• شريك التعافي (اختياري) — موافقتك الصريحة (Article 6(1)(a)) — تستطيع سحب الموافقة بإلغاء الشراكة
• إنشاء حساب البريد المحلي (اختياري) — أداء العقد
• معالجة المدفوعات — تتم عبر Apple، ولسنا الـ Controller لها

لا نستخدم بياناتك لأغراض تسويق مُوجَّه، إعلانات سلوكية، أو ملفات تعريف (profiling).
"""
        ),
        LegalSection(
            id: "sharing",
            title: "5. مشاركة البيانات",
            summary: "لا نبيع ولا نشارك بياناتك مع أي طرف ثالث.",
            body: """
نحن لا نبيع بياناتك ولا نشاركها مع أطراف ثالثة لأغراضهم الخاصة. لا يوجد لدينا:
• شركاء إعلانيون
• شركات تحليلات (Analytics)
• وسطاء بيانات
• شركات تتبّع

الاستثناء الوحيد: عند استخدامك لميزة "شريك التعافي"، تتم مشاركة بيانات محددة (الموضّحة في القسم 3) مع الشريك الذي اخترته أنت بشكل صريح، عبر بنية iCloud Sharing من Apple. أنت تتحكم في هذه المشاركة وتقدر على إلغائها في أي لحظة.
"""
        ),
        LegalSection(
            id: "transfers",
            title: "6. نقل البيانات الدولي",
            summary: "بياناتك المحلية لا تُنقل دولياً. iCloud (اختياري) يخضع لبنية Apple التحتية العالمية.",
            body: """
البيانات المحلية على جهازك لا تُنقل عبر الحدود — تبقى على جهازك.

عند استخدامك ميزة "شريك التعافي" أو Sign in with Apple، فإن البنية التحتية لـ Apple iCloud قد تخزّن البيانات في مراكز بيانات حول العالم وفقاً لسياسة Apple وضمانات النقل لديها (Standard Contractual Clauses حسب GDPR Chapter V، أو ما يعادلها).

نحن لسنا الـ Controller لهذه التحويلات؛ Apple هي مشغّل البنية التحتية. للاطلاع على تفاصيل أكثر، راجع سياسة خصوصية Apple على apple.com/privacy.
"""
        ),
        LegalSection(
            id: "retention",
            title: "7. مدة الاحتفاظ بالبيانات",
            summary: "البيانات المحلية تبقى حتى تحذفها أنت أو تحذف التطبيق.",
            body: """
نظراً لأن البيانات مخزّنة على جهازك:
• تبقى البيانات إلى أن تحذفها يدوياً من داخل التطبيق
• أو تختفي بالكامل عند حذف التطبيق
• أو عند تنفيذ "إعادة تعيين المحتوى والإعدادات" من إعدادات iOS

لا نحدّد حداً زمنياً للاحتفاظ من جانبنا — أنت تتحكم في حذف بياناتك.

سجلات شريك التعافي في iCloud: تبقى ما دامت الشراكة نشطة، وتُحذف تلقائياً عند إلغاء الشراكة من أي طرف. لا تحفظ Apple نسخاً منها بعد الحذف عادةً، لكن راجع سياسة iCloud من Apple للتفاصيل.
"""
        ),
        LegalSection(
            id: "security",
            title: "8. أمان البيانات",
            summary: "نعتمد على آليات أمان iOS القياسية + التشفير الذي توفّره Apple.",
            body: """
نطبّق التدابير التقنية والتنظيمية المناسبة لحماية بياناتك:

• البيانات المحلية محمية بآليات Sandbox من iOS
• المعرّفات الحساسة (Apple ID، كلمات مرور البريد) مخزَّنة في Keychain مع وصول "After First Unlock"
• كلمات مرور حسابات البريد المحلية مُشفَّرة (hashed) قبل التخزين
• الاتصالات الخارجية مع Apple iCloud تتم عبر TLS

أنت مسؤول عن حماية جهازك بقفل شاشة قوي وعدم مشاركته مع آخرين، لأن أي شخص لديه وصول لجهازك لديه نظرياً وصول لبياناتك.

في حال علمنا بخرق أمني يؤثر على بياناتك، سنقوم بإخطارك دون تأخير غير مبرر وفقاً للأنظمة المعمول بها.
"""
        ),
        LegalSection(
            id: "gdpr-rights",
            title: "9. حقوقك تحت GDPR (المستخدمون الأوروبيون)",
            summary: "إذا كنت داخل الاتحاد الأوروبي/المنطقة الاقتصادية الأوروبية، لديك ثمانية حقوق محددة.",
            body: """
إذا كنت في الاتحاد الأوروبي أو المنطقة الاقتصادية الأوروبية أو المملكة المتحدة، فإن GDPR/UK GDPR يمنحك الحقوق التالية:

• الحق في الوصول (Article 15): استعراض ما يخزَّن — بياناتك متاحة لك بالكامل داخل التطبيق
• الحق في التصحيح (Article 16): تعديل أي بيانات غير دقيقة — من داخل التطبيق مباشرة
• الحق في المحو (Article 17 — "الحق في النسيان"): حذف بياناتك بحذف التطبيق أو من داخله
• الحق في تقييد المعالجة (Article 18): طلب توقيف المعالجة في حالات معينة
• الحق في نقل البيانات (Article 20): الحصول على نسخة آلية القراءة — راسلنا على \(privacyContactEmail) ونرسلها لك
• الحق في الاعتراض (Article 21): الاعتراض على المعالجة لأسباب تخص وضعك الشخصي
• الحق في عدم الخضوع لقرار آلي (Article 22): لا نتخذ قرارات آلية مؤثرة عليك
• الحق في سحب الموافقة في أي وقت (Article 7(3)): يطبَّق على ميزة شريك التعافي وأي ميزة أخرى تعتمد على موافقتك

لممارسة أي حق: \(privacyContactEmail)

كذلك لديك الحق في تقديم شكوى لدى السلطة الإشرافية لحماية البيانات في بلدك (Article 77). للقائمة الكاملة: edpb.europa.eu.
"""
        ),
        LegalSection(
            id: "pdpl-rights",
            title: "10. حقوقك تحت نظام حماية البيانات الشخصية (PDPL — السعودية)",
            summary: "إذا كنت في المملكة العربية السعودية، نظام PDPL يمنحك حقوقاً مماثلة.",
            body: """
وفقاً لنظام حماية البيانات الشخصية الصادر بالمرسوم الملكي رقم م/19 (وتعديلاته):

• الحق في العلم: معرفة الأساس القانوني للمعالجة (موضّح في القسم 4 أعلاه)
• الحق في الوصول إلى بياناتك
• الحق في طلب الحصول على بياناتك بصيغة مقروءة
• الحق في طلب تصحيح أو استكمال أو تحديث البيانات
• الحق في طلب إتلاف البيانات

لممارسة أي حق: \(privacyContactEmail)

كذلك لك الحق في تقديم شكوى للهيئة السعودية للبيانات والذكاء الاصطناعي (SDAIA) عبر بوابتها الرسمية.
"""
        ),
        LegalSection(
            id: "ccpa-rights",
            title: "11. حقوق سكان كاليفورنيا (CCPA / CPRA)",
            summary: "إذا كنت من مقيمي كاليفورنيا، CCPA يمنحك حقوقاً إضافية.",
            body: """
وفقاً لقانون خصوصية المستهلك في كاليفورنيا (CCPA) وتعديلاته (CPRA):

• الحق في المعرفة: ما البيانات التي نتعامل معها (موضّح في القسم 3)
• الحق في الحذف: نحذف بياناتك عند الطلب
• الحق في تصحيح البيانات غير الدقيقة
• الحق في رفض بيع البيانات أو مشاركتها: ⚠️ نحن لا نبيع ولا نشارك بياناتك لأي طرف ثالث، لذلك لا يوجد ما يجب رفضه. ومع ذلك، إذا كنت ترغب في تأكيد ذلك، تواصل معنا.
• الحق في عدم التمييز عند ممارسة حقوقك

لا نستخدم "Sensitive Personal Information" بمفهوم CPRA (مثل بيانات صحية أو دينية أو بيومترية).

للتواصل: \(privacyContactEmail) — اكتب "CCPA Request" في عنوان البريد.
"""
        ),
        LegalSection(
            id: "children",
            title: "12. خصوصية الأطفال",
            summary: "التطبيق ليس موجهاً للأطفال دون 13 سنة.",
            body: """
التطبيق غير موجَّه للأطفال دون سن 13 عاماً، وفقاً لقانون COPPA الأمريكي. لا نجمع عن قصد أي بيانات شخصية من أطفال دون هذا السن.

داخل الاتحاد الأوروبي (GDPR Article 8)، سن الموافقة يتراوح بين 13 و 16 حسب الدولة. إذا كان عمرك دون السن المعمول به في بلدك، يجب أن يوافق ولي أمرك على استخدامك للتطبيق.

إذا اكتشفنا أن مستخدماً دون السن المسموح به أدخل بياناته، سنقوم بحذف الحساب وأي بيانات مرتبطة به فوراً. للإبلاغ: \(privacyContactEmail).
"""
        ),
        LegalSection(
            id: "cookies",
            title: "13. ملفات تعريف الارتباط والمعرّفات",
            summary: "لا نستخدم ملفات تعريف ارتباط، ولا معرّفات إعلانية، ولا أدوات تتبع.",
            body: """
صراحةً ولوضوح كامل:

• لا نستخدم ملفات Cookies — التطبيق هو تطبيق iOS أصلي، ليس متصفحاً
• لا نستخدم معرّف الإعلان (IDFA / IDFV)
• لا نستخدم Apple App Tracking Transparency لأننا لا نتتبع أصلاً
• لا نشغّل Google Analytics أو Firebase أو أي SDK تحليلات تابع لطرف ثالث
• لا نستخدم Facebook SDK أو أدوات تتبّع شبكية

التطبيق يعمل دون اتصال إنترنت لكل ميزاته الأساسية. الاتصالات الوحيدة تكون لـ App Store (للاشتراك) و iCloud (لو فعّلت شريك التعافي).
"""
        ),
        LegalSection(
            id: "changes",
            title: "14. تحديثات هذه السياسة",
            summary: "نشعرك بالتغييرات الجوهرية. التغييرات البسيطة يكفي ذكرها في تاريخ آخر تحديث.",
            body: """
قد نُحدِّث هذه السياسة من وقت لآخر. عند التحديث:

• تاريخ النفاذ وتاريخ آخر تحديث المعروضان في أعلى الصفحة سيتغيَّران
• للتغييرات الجوهرية (Material Changes) — مثل توسيع نطاق جمع البيانات — سنُشعرك داخل التطبيق ونعطيك فرصة لمراجعة التغييرات قبل المتابعة

استمرارك في استخدام التطبيق بعد التحديث يعني موافقتك على السياسة المُحدَّثة. إذا لم توافق، تستطيع إلغاء الاشتراك (إن وُجد) وحذف التطبيق.
"""
        ),
        LegalSection(
            id: "contact-privacy",
            title: "15. التواصل والشكاوى",
            summary: "تواصل معنا مباشرة، أو تواصل مع جهة إشرافية في بلدك.",
            body: """
للأسئلة، الطلبات، أو الشكاوى المتعلقة بخصوصيتك:

• البريد المخصص للخصوصية: \(privacyContactEmail)
• بريد الدعم العام: \(supportEmail)

نهدف للرد خلال 30 يوماً (حد GDPR Article 12(3))، وعادةً ما نرد خلال أيام معدودة.

لتقديم شكوى لجهة إشرافية:
• EU/EEA: السلطة الإشرافية في بلدك (قائمة كاملة على edpb.europa.eu)
• السعودية: الهيئة السعودية للبيانات والذكاء الاصطناعي (SDAIA)
• كاليفورنيا: California Privacy Protection Agency (cppa.ca.gov)
• المملكة المتحدة: Information Commissioner's Office (ico.org.uk)
"""
        )
    ]

    // MARK: - Privacy Policy (English)

    private static let privacyEn: [LegalSection] = [
        LegalSection(
            id: "intro",
            title: "1. Introduction",
            summary: "NoNet is built to run on your device. Your data does not pass through our servers — this policy explains exactly what happens.",
            body: """
We at NoNet take your privacy seriously. This Privacy Policy explains how we handle your information when you use the NoNet app ("the App").

The App is built on a Privacy-by-Design principle: most data stays on your device, and we do not run our own servers. When an Apple service is used (such as optional iCloud or StoreKit for payments), it operates under Apple's policies — never through us.

By using the App, you agree to the privacy practices described here.
"""
        ),
        LegalSection(
            id: "controller",
            title: "2. Who We Are — Data Controller",
            summary: "This is the legal entity responsible for the App and your data.",
            body: """
The legal entity responsible for processing your data (the "Data Controller") under applicable law:

• Legal name: \(entityName)
• Commercial registration: \(entityRegistration)
• Address: \(entityAddress)
• Privacy inquiries: \(privacyContactEmail)
• General support: \(supportEmail)

Given the App's local-first nature, we do not appoint a formal Data Protection Officer under GDPR Article 37. You can, however, contact us at any time at the privacy address above for any data-related request.
"""
        ),
        LegalSection(
            id: "data-collected",
            title: "3. Data We Handle",
            summary: "Three categories: local-only on your device, optional iCloud data, and Apple-managed data.",
            body: """
We split data into three clear categories:

a) Local-only on your device (never leaves the device):
• Blocklists and their items (selected apps/websites/categories)
• Blocking schedules and settings
• Onboarding profile answers (display name, age group, goals)
• Local assistant conversations (keyword-matched, no cloud send)
• If you create a local email account: your email address and a hashed copy of your password (stored in Keychain)

b) Optional iCloud data — only when you enable "Recovery Partner":
• Pseudonymous Apple user identifier (yours and the partner's)
• A display name you chose for yourself
• The shared list's name
• Break-attempt records (attempt type + timestamp)
Note: this data is stored in your iCloud and the partner's iCloud. It does not transit our servers. You can revoke the partnership at any time.

c) Apple-managed data (we never see it):
• Subscription and payment data — fully handled by App Store / StoreKit
• Sign in with Apple identifier — kept in Keychain on your device only; never transmitted by us

We do not collect: real names, phone numbers, location, credit card data, or advertising identifiers.
"""
        ),
        LegalSection(
            id: "use",
            title: "4. How We Use Your Data — Legal Basis",
            summary: "We use your data only to run the App on your device. No marketing or analytics processing.",
            body: """
Purposes for which your data is used, and the legal basis for each (GDPR Article 6):

• Running blocking features and showing your lists — Performance of contract (Article 6(1)(b))
• Persisting your preferences across sessions — Performance of contract
• Recovery Partner (optional) — Your explicit consent (Article 6(1)(a)) — withdraw by revoking the partnership
• Local email account creation (optional) — Performance of contract
• Payment processing — handled by Apple; we are not the Controller for it

We do not use your data for targeted advertising, behavioral marketing, or profiling.
"""
        ),
        LegalSection(
            id: "sharing",
            title: "5. Data Sharing",
            summary: "We do not sell or share your data with any third party.",
            body: """
We do not sell or share your data with third parties for their own purposes. We have no:
• Advertising partners
• Analytics vendors
• Data brokers
• Tracking companies

The single exception: when you use the "Recovery Partner" feature, specific data (described in Section 3) is shared with the partner you explicitly chose, via Apple's iCloud Sharing infrastructure. You control this sharing and can revoke it at any time.
"""
        ),
        LegalSection(
            id: "transfers",
            title: "6. International Data Transfers",
            summary: "Your local data is not transferred internationally. Optional iCloud uses Apple's global infrastructure.",
            body: """
Local data on your device is not transferred across borders — it stays on your device.

When you use Recovery Partner or Sign in with Apple, Apple's iCloud infrastructure may store data in data centers worldwide under Apple's policies and transfer safeguards (Standard Contractual Clauses per GDPR Chapter V, or equivalents).

We are not the Controller for those transfers; Apple is the infrastructure operator. For details, see Apple's privacy policy at apple.com/privacy.
"""
        ),
        LegalSection(
            id: "retention",
            title: "7. Data Retention",
            summary: "Local data stays until you delete it or delete the App.",
            body: """
Because data is stored on your device:
• Data remains until you manually delete it from within the App
• Or disappears entirely when you delete the App
• Or when you run iOS Settings → "Erase All Content and Settings"

We do not enforce a retention limit from our side — you control the deletion of your data.

Recovery Partner records in iCloud: remain while the partnership is active and are deleted automatically when either side revokes the partnership. Apple does not typically retain copies after deletion, but see Apple's iCloud policy for details.
"""
        ),
        LegalSection(
            id: "security",
            title: "8. Data Security",
            summary: "We rely on standard iOS security and Apple-provided encryption.",
            body: """
We implement appropriate technical and organizational measures to protect your data:

• Local data is protected by iOS sandboxing
• Sensitive identifiers (Apple ID, email passwords) are stored in Keychain with "After First Unlock" accessibility
• Local-account email passwords are hashed before storage
• External communications with Apple iCloud are over TLS

You are responsible for protecting your device with a strong screen lock and not sharing it, since anyone with access to your device theoretically has access to your data.

If we become aware of a security breach affecting your data, we will notify you without undue delay as required by applicable law.
"""
        ),
        LegalSection(
            id: "gdpr-rights",
            title: "9. Your Rights Under GDPR (EU/EEA/UK Users)",
            summary: "If you're in the EU, EEA, or UK, you have eight specific rights.",
            body: """
If you reside in the EU, EEA, or UK, GDPR/UK GDPR grants you the following rights:

• Right of access (Article 15): see what's stored — all your data is visible inside the App
• Right to rectification (Article 16): correct inaccurate data — directly from within the App
• Right to erasure / "right to be forgotten" (Article 17): delete by deleting the App or from within it
• Right to restriction of processing (Article 18): pause processing in specific cases
• Right to data portability (Article 20): receive a machine-readable copy — email us at \(privacyContactEmail)
• Right to object (Article 21): object to processing for reasons specific to your situation
• Right not to be subject to automated decisions (Article 22): we make no automated decisions affecting you
• Right to withdraw consent at any time (Article 7(3)): applies to Recovery Partner and any other consent-based feature

To exercise any right: \(privacyContactEmail)

You also have the right to lodge a complaint with your local data protection supervisory authority (Article 77). Full list: edpb.europa.eu.
"""
        ),
        LegalSection(
            id: "pdpl-rights",
            title: "10. Your Rights Under PDPL (Saudi Arabia)",
            summary: "If you're in Saudi Arabia, PDPL grants you similar rights.",
            body: """
Under the Personal Data Protection Law (Royal Decree No. M/19 and amendments):

• Right to be informed: know the legal basis of processing (covered in Section 4 above)
• Right to access your data
• Right to receive a readable copy
• Right to request correction, completion, or update
• Right to request data destruction

To exercise any right: \(privacyContactEmail)

You also have the right to file a complaint with the Saudi Data and Artificial Intelligence Authority (SDAIA) via its official portal.
"""
        ),
        LegalSection(
            id: "ccpa-rights",
            title: "11. California Residents' Rights (CCPA / CPRA)",
            summary: "If you're a California resident, CCPA gives you additional rights.",
            body: """
Under the California Consumer Privacy Act (CCPA) and its amendments (CPRA):

• Right to know: what data we handle (covered in Section 3)
• Right to delete: we delete your data on request
• Right to correct inaccurate data
• Right to opt out of the sale or sharing of personal information: ⚠️ We do not sell or share your data with any third party, so there is nothing to opt out of. However, if you'd like a confirmation, contact us.
• Right to non-discrimination when exercising your rights

We do not handle "Sensitive Personal Information" as defined by CPRA (e.g. health, religion, biometrics).

To contact: \(privacyContactEmail) — write "CCPA Request" in the subject line.
"""
        ),
        LegalSection(
            id: "children",
            title: "12. Children's Privacy",
            summary: "The App is not directed to children under 13.",
            body: """
The App is not directed to children under the age of 13, in accordance with the US COPPA. We do not knowingly collect any personal data from children under that age.

In the EU (GDPR Article 8), the age of consent ranges between 13 and 16 depending on the member state. If you are under the applicable age in your country, your parent or guardian must consent to your use of the App.

If we discover that an underage user has entered data, we will delete the account and any associated data immediately. To report: \(privacyContactEmail).
"""
        ),
        LegalSection(
            id: "cookies",
            title: "13. Cookies & Identifiers",
            summary: "We do not use cookies, advertising identifiers, or tracking tools.",
            body: """
Explicitly and for full clarity:

• We do not use cookies — the App is a native iOS app, not a web browser
• We do not use the Advertising Identifier (IDFA / IDFV)
• We do not use Apple App Tracking Transparency because we do not track to begin with
• We do not run Google Analytics, Firebase, or any third-party analytics SDK
• We do not use the Facebook SDK or any web tracking tools

The App operates offline for all core features. The only network calls are to App Store (for subscriptions) and iCloud (only if you enable Recovery Partner).
"""
        ),
        LegalSection(
            id: "changes",
            title: "14. Updates to This Policy",
            summary: "We notify you of material changes. Minor edits just bump the last-updated date.",
            body: """
We may update this policy from time to time. When we do:

• The "Effective date" and "Last updated" shown at the top of the screen will change
• For material changes — such as expanding the scope of data collection — we will notify you within the App and give you a chance to review the changes before continuing

Continued use of the App after an update constitutes your acceptance of the updated policy. If you disagree, you may cancel your subscription (if any) and delete the App.
"""
        ),
        LegalSection(
            id: "contact-privacy",
            title: "15. Contact & Complaints",
            summary: "Contact us directly, or contact a supervisory authority in your country.",
            body: """
For questions, requests, or complaints related to your privacy:

• Dedicated privacy address: \(privacyContactEmail)
• General support: \(supportEmail)

We aim to respond within 30 days (GDPR Article 12(3) limit), and usually reply within a few days.

To file a complaint with a supervisory authority:
• EU/EEA: your local supervisory authority (full list at edpb.europa.eu)
• Saudi Arabia: Saudi Data and Artificial Intelligence Authority (SDAIA)
• California: California Privacy Protection Agency (cppa.ca.gov)
• United Kingdom: Information Commissioner's Office (ico.org.uk)
"""
        )
    ]

    // MARK: - Terms of Service (Arabic)

    private static let termsAr: [LegalSection] = [
        LegalSection(
            id: "acceptance",
            title: "1. القبول والتطبيق",
            summary: "باستخدام التطبيق، فإنك توافق على هذه الشروط.",
            body: """
هذه هي الشروط والأحكام ("الشروط") التي تحكم استخدامك لتطبيق NoNet ("التطبيق").

بتنزيل التطبيق أو تثبيته أو استخدامه، فإنك تُقرّ بأنك قرأت هذه الشروط وفهمتها ووافقت على الالتزام بها. إذا كنت لا توافق، يرجى عدم استخدام التطبيق.

هذه الشروط مكمّلة لاتفاقية ترخيص المستخدم النهائي القياسية من Apple (Standard EULA) المطبَّقة على جميع تطبيقات App Store. في حال التعارض، تسود الشروط الأكثر حماية للمستخدم.
"""
        ),
        LegalSection(
            id: "about-us",
            title: "2. من نحن",
            summary: "هذه معلومات الكيان المُشغِّل للتطبيق.",
            body: """
التطبيق مُقدَّم من قِبل:

• الكيان: \(entityName)
• السجل التجاري: \(entityRegistration)
• العنوان: \(entityAddress)
• البريد للتواصل العام: \(supportEmail)
"""
        ),
        LegalSection(
            id: "eligibility",
            title: "3. الأهلية",
            summary: "العمر 13+ كحد أدنى. قد يكون الحد أعلى في بعض الدول.",
            body: """
لاستخدام التطبيق:

• يجب أن يكون عمرك 13 سنة على الأقل (الحد الأدنى وفقاً لـ COPPA الأمريكي)
• إذا كنت في الاتحاد الأوروبي، قد يكون الحد الأدنى لسن الموافقة الرقمية في بلدك بين 13 و 16 سنة (GDPR Article 8) — إذا كان عمرك دون ذلك، يجب الحصول على موافقة ولي الأمر
• يجب أن يكون لديك القدرة القانونية على إبرام عقد ملزم في ولايتك القضائية
• يجب ألا تكون ممنوعاً من تلقي خدمات تحت قوانين بلدك أو بلد إقامتك
"""
        ),
        LegalSection(
            id: "license",
            title: "4. ترخيص الاستخدام",
            summary: "نمنحك ترخيصاً شخصياً محدوداً لاستخدام التطبيق.",
            body: """
نمنحك ترخيصاً شخصياً، غير حصري، غير قابل للنقل، وغير قابل للترخيص من الباطن، لتنزيل وتثبيت واستخدام التطبيق على جهاز Apple مملوك لك أو تحت سيطرتك، فقط للأغراض الشخصية وغير التجارية.

تستطيع:
✓ استخدام التطبيق لأغراضك الشخصية
✓ إنشاء قوائم حجب وجداول كما تريد
✓ مشاركة لقطات شاشة (Screenshots) من التطبيق

لا تستطيع:
✗ إعادة بيع أو إعادة توزيع التطبيق
✗ استخدام التطبيق لأغراض تجارية أو نيابة عن طرف ثالث
✗ محاولة تعطيل أو تجاوز ميزات الحماية أو الاشتراك
✗ استخدام التطبيق بطرق تنتهك قوانين بلدك

ملاحظة لمستخدمي الاتحاد الأوروبي: لا شيء في هذه الشروط يقيّد حقك في التحليل العكسي (Reverse Engineering) لأغراض التوافق التشغيلي وفقاً للمادة 6 من توجيه الاتحاد الأوروبي 2009/24/EC.
"""
        ),
        LegalSection(
            id: "subscriptions",
            title: "5. الاشتراكات والفوترة",
            summary: "اشتراكاتك تُدار عبر App Store. تتجدد تلقائياً وتقدر تلغيها متى ما شئت.",
            body: """
يقدّم التطبيق اشتراكات اختيارية لتفعيل الميزات المميزة (Premium):

أ) خطط الاشتراك:
• شهرية
• سنوية

ب) التجديد التلقائي:
• تتجدد الاشتراكات تلقائياً في نهاية كل دورة فوترة ما لم تقم بإلغائها قبل 24 ساعة على الأقل من نهاية الدورة الحالية
• يتم تحصيل رسوم التجديد عبر حساب Apple ID الخاص بك

ج) إدارة الاشتراك:
• تستطيع إدارة وإلغاء اشتراكك من: إعدادات iOS → اسمك → الاشتراكات
• الإلغاء يوقف التجديد التلقائي ويُبقي الميزات المميزة فعّالة إلى نهاية الدورة المدفوعة

د) جميع المدفوعات تُعالجها Apple عبر App Store. نحن لا نرى تفاصيل بطاقتك الائتمانية أو معلومات الدفع.
"""
        ),
        LegalSection(
            id: "trial",
            title: "6. التجربة المجانية",
            summary: "نقدّم تجربة مجانية مدتها 7 أيام إن توفّرت لخطتك.",
            body: """
قد نُقدّم فترة تجربة مجانية لمدة 7 أيام عند الاشتراك لأول مرة. خلال فترة التجربة:

• تحصل على وصول كامل للميزات المميزة
• لن تُحصَّل أي رسوم
• تستطيع الإلغاء في أي وقت من خلال إعدادات Apple ID قبل نهاية التجربة

عند انتهاء فترة التجربة دون إلغاء، يبدأ الاشتراك المدفوع تلقائياً وتُحصَّل الرسوم.
"""
        ),
        LegalSection(
            id: "refunds",
            title: "7. الضمان الذهبي — سياسة الاسترداد",
            summary: "نساعدك في طلب استرداد عبر Apple ضمن المُدد المذكورة.",
            body: """
نلتزم بـ"الضمان الذهبي" لراحتك:

• الاشتراك الشهري: نساعدك على الحصول على استرداد كامل عبر Apple خلال شهر واحد من تاريخ الشراء
• الاشتراك السنوي: نساعدك على الحصول على استرداد كامل عبر Apple خلال شهرين من تاريخ الشراء

ملاحظة مهمة عن آلية الاسترداد:
• جميع المدفوعات تُعالَج عبر Apple، والاسترداد الفعلي يخضع لتقدير Apple
• الطريقة الرسمية لطلب الاسترداد: App Store → "الإبلاغ عن مشكلة" أو reportaproblem.apple.com
• إذا رفضت Apple طلبك ضمن مُدد ضماننا، تواصل معنا على \(supportEmail) وسنبذل قصارى جهدنا للتدخل والمساعدة

التزامنا هو بذل أفضل الجهود (Best-Effort) في مساعدتك. لا يمكننا قانونياً ضمان قرار Apple، لأن الفلوس تمر عبرهم.
"""
        ),
        LegalSection(
            id: "acceptable-use",
            title: "8. السلوك المقبول",
            summary: "استخدم التطبيق بشكل مسؤول ولا تحاول الإضرار به أو بالآخرين.",
            body: """
عند استخدامك للتطبيق، تتعهد بألا:

• تنتهك أي قانون معمول به
• تحاول الوصول غير المصرّح به لأنظمة التطبيق
• تستخدم التطبيق لإيذاء شخص آخر (مثل استخدام شريك التعافي لمضايقة)
• تنشر محتوى مسيء أو غير قانوني في أي حقل إدخال
• تتدخّل مع تشغيل التطبيق أو خدمات Apple

نحتفظ بالحق في تعليق أو إنهاء وصولك في حال انتهاك هذه الشروط.
"""
        ),
        LegalSection(
            id: "ip",
            title: "9. الملكية الفكرية",
            summary: "التطبيق وكل عناصره ملك لنا. أنت تملك بياناتك.",
            body: """
التطبيق وكافة محتوياته — بما في ذلك التصميم، الكود، الشعارات، النصوص، الأيقونات، والمواد التعليمية — محمي بحقوق الملكية الفكرية وهي مملوكة لنا أو لمرخّصينا.

أنت تحتفظ بكافة الحقوق على البيانات التي تدخلها أنت (قوائم الحجب، الإعدادات، إلخ).

العلامة التجارية "NoNet" والشعار محمية كعلامات تجارية.
"""
        ),
        LegalSection(
            id: "disclaimer",
            title: "10. إخلاء المسؤولية",
            summary: "التطبيق يُقدَّم \"كما هو\" دون ضمانات صريحة.",
            body: """
التطبيق يُقدَّم "كما هو" و "كما هو متاح" دون أي ضمانات صريحة أو ضمنية، بما في ذلك على سبيل المثال لا الحصر:

• ضمانات القابلية للتسويق
• الملاءمة لغرض معين
• عدم انتهاك حقوق الغير
• الدقة المطلقة في منع الإلهاءات (نظام Screen Time من Apple يضع حدوداً تقنية)
• استمرارية الخدمة بدون انقطاع
• خلو التطبيق من الأخطاء

لا نضمن أن التطبيق سيمنع كل الإلهاءات بنسبة 100%، أو سيتوافق مع جميع الأجهزة، أو سيلبي توقعاتك بالكامل.

ملاحظة لمستخدمي الاتحاد الأوروبي: لا شيء في هذا القسم يقيّد حقوقك القانونية المُلزِمة بموجب قانون حماية المستهلك في بلدك (مثل الضمانات القانونية للملاءمة).
"""
        ),
        LegalSection(
            id: "liability-cap",
            title: "11. سقف المسؤولية المالية",
            summary: "حد المسؤولية يساوي ما دفعته في آخر 12 شهراً.",
            body: """
إلى أقصى حد يسمح به القانون المعمول به:

• مسؤوليتنا الإجمالية تجاهك عن جميع المطالبات الناشئة عن أو المرتبطة بالتطبيق محدودة بالمبلغ الذي دفعته للتطبيق خلال 12 شهراً السابقة للمطالبة، أو 50 دولاراً أمريكياً (أيهما أكبر)
• لا نتحمل مسؤولية الأضرار غير المباشرة، التبعية، الخاصة، أو العقابية، بما في ذلك خسارة الأرباح، خسارة البيانات، أو الأضرار غير الملموسة
• لا نتحمل مسؤولية أضرار ناشئة عن: استخدامك للتطبيق، عدم القدرة على الوصول إليه، أي محتوى تم إنشاؤه عبر التطبيق، أو أي تصرف من طرف ثالث

ملاحظة لمستخدمي الاتحاد الأوروبي: لا شيء في هذا القسم يستبعد المسؤولية عن الوفاة أو الإصابة الجسدية الناتجة عن إهمالنا، أو عن الاحتيال، أو عن أي مسؤولية لا يمكن استبعادها قانونياً.
"""
        ),
        LegalSection(
            id: "indemnification",
            title: "12. التعويض",
            summary: "تتحمل التبعات إذا انتهكت الشروط أو أضررت بطرف ثالث.",
            body: """
توافق على تعويضنا والدفاع عنا ضد أي مطالبات، خسائر، أو نفقات (بما فيها أتعاب المحاماة المعقولة) ناشئة عن أو مرتبطة بـ:

• انتهاكك لهذه الشروط
• استخدامك للتطبيق بطريقة مخالفة للقانون
• إضرارك بحقوق طرف ثالث

هذا الالتزام يصمد بعد إنهاء حسابك أو استخدامك للتطبيق.
"""
        ),
        LegalSection(
            id: "termination",
            title: "13. الإنهاء",
            summary: "تقدر تنهي استخدامك متى ما شئت بحذف التطبيق. ونقدر ننهي وصولك إذا انتهكت الشروط.",
            body: """
أ) إنهاء من جانبك:
• تستطيع إيقاف استخدام التطبيق في أي وقت بحذفه من جهازك
• إذا كان لديك اشتراك، يجب إلغاءه من إعدادات Apple ID

ب) إنهاء من جانبنا:
• نحتفظ بالحق في تعليق أو إنهاء وصولك في حال انتهاك جوهري لهذه الشروط، بعد إشعارك (متى أمكن) لإصلاح الوضع
• في حالات الانتهاكات الخطيرة (مثل الاحتيال أو إيذاء طرف ثالث)، قد يكون الإنهاء فورياً ودون إشعار مسبق

ج) ما يحدث للبيانات بعد الإنهاء:
• البيانات المحلية على جهازك تُحذف عند حذف التطبيق
• شراكات شريك التعافي تنتهي تلقائياً
"""
        ),
        LegalSection(
            id: "disputes",
            title: "14. حل النزاعات",
            summary: "نحاول الحل بالحوار أولاً. للمستخدمين الأوروبيين، تُحفَظ حقوقهم في محاكمهم.",
            body: """
أ) الحل الودي أولاً:
في حال نشوء أي نزاع، نشجّع التواصل معنا أولاً على \(supportEmail) لمحاولة الحل بشكل ودي. هذه الخطوة شرط مسبق قبل اللجوء لأي إجراء رسمي.

ب) المستخدمون خارج الاتحاد الأوروبي:
أي نزاع لم يُحَل ودياً يُحال إلى التحكيم وفقاً لأنظمة المملكة العربية السعودية أمام مركز التحكيم التجاري السعودي (SCCA). يكون مكان التحكيم في الرياض، ولغته العربية.

ج) المستخدمون داخل الاتحاد الأوروبي:
تُحفظ كافة حقوقكم في اللجوء لمحاكم بلد إقامتكم وفقاً لقوانين حماية المستهلك المُلزِمة، وتستطيعون أيضاً استخدام منصة فض النزاعات الإلكترونية للاتحاد الأوروبي على ec.europa.eu/consumers/odr.

د) لا يتنازل أي طرف عن حقه في اللجوء للقضاء بسبب طلب وقتي عاجل أو حماية حقوق الملكية الفكرية.
"""
        ),
        LegalSection(
            id: "law",
            title: "15. القانون الحاكم",
            summary: "أنظمة المملكة العربية السعودية. حقوق المستهلك الإلزامية تُحفظ.",
            body: """
هذه الشروط تخضع لأنظمة المملكة العربية السعودية وتُفسَّر وفقاً لها.

استثناء: إذا كنت مستهلكاً في الاتحاد الأوروبي أو في دولة أخرى تطبق قوانين حماية مستهلك إلزامية، فإن تلك القوانين تُطبَّق بالقدر الذي توفر لك حماية أعلى، ولا يمكن التنازل عنها بموجب اختيار القانون أعلاه.
"""
        ),
        LegalSection(
            id: "general",
            title: "16. أحكام عامة",
            summary: "بنود قانونية معيارية: استقلالية البنود، اتفاقية كاملة، وأكثر.",
            body: """
أ) الاتفاقية الكاملة: هذه الشروط، مع سياسة الخصوصية، تشكّل الاتفاقية الكاملة بينك وبيننا فيما يتعلق بالتطبيق.

ب) استقلالية البنود: إذا اعتُبر أي بند في هذه الشروط غير قابل للتنفيذ، يبقى باقي البنود ساري المفعول.

ج) التنازل: عدم ممارستنا أي حق لا يُعد تنازلاً عنه.

د) النقل: لا يجوز لك نقل هذه الشروط دون موافقتنا الخطية. نحن نقدر على نقلها لخلف قانوني (مثل في حالة الاندماج).

هـ) القوة القاهرة: لا نتحمل مسؤولية التأخير أو الإخفاق الناتج عن أحداث خارجة عن سيطرتنا المعقولة.

و) العلاقة: علاقتنا معك هي علاقة طرفين مستقلين — لا توجد شراكة أو وكالة أو تشغيل مشترك.
"""
        ),
        LegalSection(
            id: "contact-terms",
            title: "17. التواصل",
            summary: "لأي سؤال قانوني أو طلب رسمي.",
            body: """
لأي استفسارات قانونية أو طلبات رسمية:

• البريد الإلكتروني: \(supportEmail)
• البريد للمسائل القانونية الخاصة: \(privacyContactEmail)
• العنوان البريدي: \(entityAddress)
"""
        )
    ]

    // MARK: - Terms of Service (English)

    private static let termsEn: [LegalSection] = [
        LegalSection(
            id: "acceptance",
            title: "1. Acceptance & Scope",
            summary: "By using the App, you agree to these Terms.",
            body: """
These are the Terms & Conditions ("Terms") that govern your use of the NoNet app ("the App").

By downloading, installing, or using the App, you acknowledge that you have read, understood, and agreed to be bound by these Terms. If you do not agree, please do not use the App.

These Terms are supplementary to Apple's Standard End User License Agreement, which applies to all App Store apps. In case of conflict, the terms most protective of the user prevail.
"""
        ),
        LegalSection(
            id: "about-us",
            title: "2. About Us",
            summary: "This is the entity operating the App.",
            body: """
The App is provided by:

• Entity: \(entityName)
• Commercial registration: \(entityRegistration)
• Address: \(entityAddress)
• General contact: \(supportEmail)
"""
        ),
        LegalSection(
            id: "eligibility",
            title: "3. Eligibility",
            summary: "Age 13+ minimum. May be higher in certain countries.",
            body: """
To use the App:

• You must be at least 13 years old (US COPPA minimum)
• If you reside in the EU, your country's digital consent age may be between 13 and 16 (GDPR Article 8) — if you are below that, parental consent is required
• You must have the legal capacity to enter into a binding contract in your jurisdiction
• You must not be prohibited from receiving services under the laws of your country of residence
"""
        ),
        LegalSection(
            id: "license",
            title: "4. License to Use",
            summary: "We grant you a personal, limited license to use the App.",
            body: """
We grant you a personal, non-exclusive, non-transferable, non-sublicensable license to download, install, and use the App on an Apple device that you own or control, solely for personal and non-commercial purposes.

You may:
✓ Use the App for personal purposes
✓ Create blocklists and schedules as you like
✓ Share screenshots of the App

You may not:
✗ Resell or redistribute the App
✗ Use the App commercially or on behalf of a third party
✗ Attempt to disable or bypass protection or subscription features
✗ Use the App in ways that violate your country's laws

Note for EU users: nothing in these Terms limits your right to reverse engineering for interoperability purposes under Article 6 of EU Directive 2009/24/EC.
"""
        ),
        LegalSection(
            id: "subscriptions",
            title: "5. Subscriptions & Billing",
            summary: "Subscriptions are managed by the App Store. They auto-renew and you can cancel anytime.",
            body: """
The App offers optional subscriptions to unlock Premium features:

a) Subscription plans:
• Monthly
• Yearly

b) Auto-renewal:
• Subscriptions auto-renew at the end of each billing cycle unless cancelled at least 24 hours before the end of the current cycle
• Renewal charges are billed via your Apple ID

c) Subscription management:
• Manage and cancel from: iOS Settings → Your Name → Subscriptions
• Cancelling stops auto-renewal and keeps Premium features active until the end of the paid cycle

d) All payments are processed by Apple via the App Store. We do not see your credit card details or payment information.
"""
        ),
        LegalSection(
            id: "trial",
            title: "6. Free Trial",
            summary: "We offer a 7-day free trial when available for your plan.",
            body: """
We may offer a 7-day free trial on first subscription. During the trial:

• You get full access to Premium features
• No charges will be billed
• You can cancel at any time from your Apple ID settings before the trial ends

If the trial ends without cancellation, the paid subscription begins automatically and you are billed.
"""
        ),
        LegalSection(
            id: "refunds",
            title: "7. The Golden Guarantee — Refund Policy",
            summary: "We help you request a refund from Apple within the stated windows.",
            body: """
We commit to the "Golden Guarantee" for your peace of mind:

• Monthly subscription: we help you obtain a full refund via Apple within 1 month of purchase
• Yearly subscription: we help you obtain a full refund via Apple within 2 months of purchase

Important note about the refund mechanism:
• All payments are processed by Apple, and the actual refund is at Apple's discretion
• The official refund request flow: App Store → "Report a Problem" or reportaproblem.apple.com
• If Apple denies your request within our guarantee windows, contact us at \(supportEmail) and we will do our best to intervene and help

Our commitment is a best-effort assistance. We cannot legally guarantee Apple's decision, since the money flows through them.
"""
        ),
        LegalSection(
            id: "acceptable-use",
            title: "8. Acceptable Use",
            summary: "Use the App responsibly and don't attempt to harm it or others.",
            body: """
When using the App, you undertake not to:

• Violate any applicable law
• Attempt unauthorized access to the App's systems
• Use the App to harm someone (e.g. using Recovery Partner to harass)
• Submit offensive or unlawful content in any input field
• Interfere with the App's operation or Apple's services

We reserve the right to suspend or terminate your access if you violate these Terms.
"""
        ),
        LegalSection(
            id: "ip",
            title: "9. Intellectual Property",
            summary: "The App and all its elements are ours. You own your data.",
            body: """
The App and all its contents — including design, code, logos, text, icons, and educational materials — are protected by intellectual property rights and are owned by us or our licensors.

You retain all rights to the data you enter (blocklists, settings, etc.).

The "NoNet" trademark and logo are protected as trademarks.
"""
        ),
        LegalSection(
            id: "disclaimer",
            title: "10. Disclaimer of Warranties",
            summary: "The App is provided \"as is\" without express warranties.",
            body: """
The App is provided "AS IS" and "AS AVAILABLE" without any express or implied warranties, including but not limited to:

• Merchantability
• Fitness for a particular purpose
• Non-infringement
• Absolute accuracy in preventing distractions (Apple's Screen Time imposes technical limits)
• Uninterrupted service
• Freedom from errors

We do not warrant that the App will block all distractions 100%, that it will work on all devices, or that it will fully meet your expectations.

Note for EU users: nothing in this section limits your mandatory consumer law rights in your country (such as statutory warranties of conformity).
"""
        ),
        LegalSection(
            id: "liability-cap",
            title: "11. Limitation of Liability",
            summary: "Liability cap equals what you paid in the last 12 months.",
            body: """
To the maximum extent permitted by applicable law:

• Our total liability to you for all claims arising from or related to the App is limited to the amount you paid for the App in the 12 months preceding the claim, or USD 50, whichever is greater
• We are not liable for indirect, consequential, special, or punitive damages, including loss of profits, loss of data, or intangible damages
• We are not liable for damages arising from: your use of the App, your inability to access it, any content generated through the App, or any third-party action

Note for EU users: nothing in this section excludes liability for death or personal injury arising from our negligence, or for fraud, or for any liability that cannot be legally excluded.
"""
        ),
        LegalSection(
            id: "indemnification",
            title: "12. Indemnification",
            summary: "You bear the consequences if you violate the Terms or harm a third party.",
            body: """
You agree to indemnify and defend us against any claims, losses, or expenses (including reasonable attorneys' fees) arising from or related to:

• Your breach of these Terms
• Your unlawful use of the App
• Your infringement of a third party's rights

This obligation survives the termination of your account or use of the App.
"""
        ),
        LegalSection(
            id: "termination",
            title: "13. Termination",
            summary: "You can end use anytime by deleting the App. We can end your access if you breach the Terms.",
            body: """
a) Termination by you:
• You can stop using the App at any time by deleting it from your device
• If you have a subscription, it must be cancelled from your Apple ID settings

b) Termination by us:
• We reserve the right to suspend or terminate your access for material breach of these Terms, after notifying you (where possible) to remediate
• In cases of serious breaches (e.g. fraud or harm to a third party), termination may be immediate and without prior notice

c) What happens to data after termination:
• Local data on your device is deleted when the App is deleted
• Recovery Partner partnerships end automatically
"""
        ),
        LegalSection(
            id: "disputes",
            title: "14. Dispute Resolution",
            summary: "We try amicable resolution first. EU users retain their court rights.",
            body: """
a) Amicable resolution first:
For any dispute, please contact us first at \(supportEmail) to attempt amicable resolution. This step is a prerequisite to any formal proceeding.

b) Non-EU users:
Any unresolved dispute shall be referred to arbitration under the laws of the Kingdom of Saudi Arabia before the Saudi Center for Commercial Arbitration (SCCA). The seat of arbitration shall be Riyadh, and the language shall be Arabic.

c) EU users:
All rights to bring proceedings before the courts of your country of residence are preserved under mandatory consumer protection laws. You may also use the EU Online Dispute Resolution platform at ec.europa.eu/consumers/odr.

d) Neither party waives its right to seek injunctive relief or to protect intellectual property rights in court.
"""
        ),
        LegalSection(
            id: "law",
            title: "15. Governing Law",
            summary: "Laws of the Kingdom of Saudi Arabia. Mandatory consumer protections preserved.",
            body: """
These Terms are governed by and construed in accordance with the laws of the Kingdom of Saudi Arabia.

Exception: if you are a consumer in the EU or in another country with mandatory consumer protection laws, those laws apply to the extent they provide you greater protection and cannot be waived by the choice of law above.
"""
        ),
        LegalSection(
            id: "general",
            title: "16. General Provisions",
            summary: "Standard legal clauses: severability, entire agreement, and more.",
            body: """
a) Entire agreement: these Terms, together with the Privacy Policy, constitute the entire agreement between you and us regarding the App.

b) Severability: if any provision in these Terms is deemed unenforceable, the remaining provisions remain in full effect.

c) Waiver: our failure to exercise any right does not constitute a waiver of it.

d) Assignment: you may not assign these Terms without our written consent. We may assign them to a legal successor (e.g. in case of a merger).

e) Force majeure: we are not liable for delays or failures resulting from events beyond our reasonable control.

f) Relationship: our relationship with you is that of independent parties — there is no partnership, agency, or joint operation.
"""
        ),
        LegalSection(
            id: "contact-terms",
            title: "17. Contact",
            summary: "For any legal question or formal request.",
            body: """
For any legal inquiries or formal requests:

• Email: \(supportEmail)
• Email for legal-specific matters: \(privacyContactEmail)
• Postal address: \(entityAddress)
"""
        )
    ]
}
