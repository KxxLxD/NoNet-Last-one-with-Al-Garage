# تحليل الفجوة بين NoNet Web و NoNet iOS

> **الغرض من هذا الملف:** مقارنة منهجية بين ميزات نسخة الويب (الموثّقة في [FEATURE_REFERENCE_FROM_WEB_AR.md](FEATURE_REFERENCE_FROM_WEB_AR.md)) وما هو منفّذ فعلاً في المشروع iOS الحالي. يحدد ما يمكن جلبه، ما يجب تأجيله، وما هو مستحيل تقنياً.

**تاريخ التحليل:** 2026-05-22
**نسخة iOS المرجعية:** v1.0.0

---

## 🗂️ جدول المحتويات

1. [الملخّص التنفيذي](#الملخص-التنفيذي)
2. [مفاتيح الترميز](#مفاتيح-الترميز)
3. [جدول المقارنة الكامل](#جدول-المقارنة-الكامل)
4. [الميزات الموجودة في iOS — تفاصيل](#الميزات-الموجودة-في-ios)
5. [الميزات المفقودة القابلة للجلب — تفاصيل](#الميزات-المفقودة-القابلة-للجلب)
6. [الميزات المؤجّلة (مستقبلية)](#الميزات-المؤجّلة-مستقبلية)
7. [الميزات المستحيلة تقنياً](#الميزات-المستحيلة-تقنياً)
8. [العقاب المالي و سياسة Apple 3.1.1](#العقاب-المالي-و-سياسة-apple-311)
9. [خارطة الطريق المقترحة](#خارطة-الطريق-المقترحة)

---

## الملخّص التنفيذي

من إجمالي **27 ميزة** موثّقة في دليل نسخة الويب:

| الفئة | العدد | النسبة |
|------|------|--------|
| ✅ موجودة في iOS | 15 | 56% |
| 🟢 مفقودة قابلة للجلب (سهلة) | 4 | 15% |
| 🟡 مفقودة قابلة للجلب (متوسطة) | 3 | 11% |
| 🎯 مفقودة مهمة (تحتاج تصميم خاص) | 1 | 4% |
| 📝 مؤجّلة كمستقبلية | 2 | 7% |
| ❌ مستحيلة تقنياً | 6 | 22% |

**الأولوية القصوى:** شريك التعافي (سيُنفّذ عبر CloudKit — انظر [PARTNER_FEATURE_DESIGN_AR.md](PARTNER_FEATURE_DESIGN_AR.md)).

**استبعادات نهائية:**
- العقاب المالي للجمعيات (يصطدم بـ Apple Guideline 3.1.1).
- 6 toggles من "الإعدادات المتقدمة" (تحتاج MDM، لا توجد APIs عامة في iOS).

---

## مفاتيح الترميز

| الرمز | المعنى |
|------|--------|
| ✅ | موجود ومُنفّذ بالكامل في iOS |
| ⚠️ | موجود جزئياً (يحتاج توسعة) |
| 🟢 | مفقود وسهل الجلب (≤ ساعتين) |
| 🟡 | مفقود ويحتاج جهد متوسط (يوم - يومين) |
| 🎯 | مفقود ومهم (يحتاج تصميم معماري) |
| 📝 | مؤجّل لإصدار مستقبلي (موثّق فقط) |
| ❌ | مستحيل على iOS بدون MDM |
| 🚫 | ممنوع بسياسة Apple |

---

## جدول المقارنة الكامل

### A. شاشات التطبيق

| # | الميزة | iOS | الملف المرجعي | ملاحظات |
|---|--------|-----|---------------|---------|
| 1 | Onboarding متعدد الصفحات | ✅ | `OnboardingView.swift` | 4 صفحات، يجمع `obName`, `obGender`, `obAgeGroup`, `obApps`, `obCats`, `obGoals` |
| 2 | تبديل اللغة في Onboarding | ✅ | `OnboardingView.swift:18` | `lang.isArabicEffective` |
| 3 | الشاشة الرئيسية بقوائم Cards | ✅ | `HomeView.swift` | عرض ListEntity من Core Data |
| 4 | BlockScreen (شاشة الحجب) | ✅ | `BlockScreenView.swift` | مع break pills و heroView |
| 5 | Settings | ✅ | `SettingsView.swift` | لغة، اشتراك، help، links |
| 6 | FAQ | ✅ | `SettingsView.swift` → `FAQView` | — |
| 7 | Privacy + Terms | ✅ | `PoliciesView.swift` + `Core/LegalContent.swift` | عربي وإنجليزي |
| 8 | Premium upgrade | ✅ | `UpgradeView.swift` | شهري + سنوي + Apple Redeem |
| 9 | ChatBot | ✅ | `ChatBotView.swift` | محلي عبر `LocalChatResponder` |
| 10 | Logout | ❌ → 🟢 | `SettingsView.swift` | **مفقود — يجب إضافته** |
| 11 | Resources/Academy | ❌ → 🟢 | — | مفقود — صفحة static ممكنة |

### B. تدفق إنشاء القائمة (9 خطوات في الويب → 6 في iOS)

| # | الخطوة | iOS | ملاحظات |
|---|--------|-----|---------|
| 1 | اسم القائمة | ✅ | `CreateListSheet.swift:239` — TextField مع validation (min 2 chars) |
| 2 | اختيار apps/sites/categories | ✅ | عبر `FamilyActivityPicker` في `BlockItemsEditorView` |
| 3 | الإعدادات المتقدمة (8 toggles) | ❌ | معظمها مستحيل — انظر القسم المخصص |
| 4 | نوع الحظر: Now / Scheduled / TimeLimit / Forever | ⚠️ | فقط Now و Scheduled موجودان |
| 4a | Block type: **Now** | ✅ | `ListEntity.blockType = "now"` |
| 4b | Block type: **Scheduled** | ✅ | مع DeviceActivityCenter |
| 4c | Block type: **TimeLimit** (حد يومي) | 🟡 | مفقود — يحتاج DeviceActivity threshold |
| 4d | Block type: **Forever** | 🟢 | مفقود — سهل (`endDate = .distantFuture`) |
| 5 | Breaks (عدد × مدة) | ✅ | `breaksCount` (0-5) + `breakDurationMinutes` (5/10/15) |
| 6 | مستوى الحماية: No / Hard Mode | ✅ | `protection: "noProtection" | "hard"` |
| 7 | شريك التعافي + OTP | 🎯 | **يُنفّذ عبر CloudKit — انظر [PARTNER_FEATURE_DESIGN_AR.md](PARTNER_FEATURE_DESIGN_AR.md)** |
| 8 | العقاب المالي + جمعيات | 🚫 | **مرفوض — يصطدم بـ Apple 3.1.1** |
| 9 | Summary | ✅ | `ConfirmCreateSheet.swift` |

### C. ميزات النظام

| # | الميزة | iOS | ملاحظات |
|---|--------|-----|---------|
| 1 | حدود النسخة المجانية (3 قوائم) | ✅ | `BlockingConstants.freeTierListLimit = 3` |
| 2 | حد Hard Mode للمجاني (1 قائمة) | ✅ | محقّق في `CreateListSheet` |
| 3 | StoreKit 2 (شهري + سنوي) | ✅ | `StoreManager.swift` + `ProductIDs.swift` |
| 4 | Promo code | ✅ | عبر Apple's `presentRedeemSheet()` |
| 5 | Sign in with Apple | ✅ | `AppleSignInCoordinator.swift` |
| 6 | RTL/LTR كامل | ✅ | `LanguageManager` في `Theme.swift` |
| 7 | Privacy Manifest | ✅ | `PrivacyInfo.xcprivacy` |
| 8 | استخدام بيانات Onboarding | ⚠️ | تُجمع لكن لا تُستخدم — 🟢 سهل التوظيف |

---

## الميزات الموجودة في iOS

هذه الميزات موجودة ومُنفّذة. لا حاجة لتعديل إلا للتحسين.

### 1. Onboarding (4 صفحات + بيانات)
- **الملف:** `blocking app/OnboardingView.swift`
- **مفاتيح AppStorage:** `obName`, `obGender`, `obAgeGroup`, `obApps`, `obCats`, `obGoals`
- **ملاحظة:** البيانات تُجمع لكن لا تُستخدم لاحقاً. خطة الجلب التالية ستفعّل استخدامها (راجع الميزات المفقودة).

### 2. الحجب الفوري والمجدول
- **الملف:** `blocking app/Core/BlockingEngine.swift`
- **يعمل عبر:** `ManagedSettingsStore(named: "blocklist.<UUID>")` لكل قائمة + `DeviceActivityCenter` للجدولة.

### 3. Hard Mode (وضع الحماية الصارم)
- **الملف:** `blocking app/CreateListSheet.swift:12`
- **منع التعديل/الحذف:** محقّق في `HomeView` — أزرار Edit/Delete مخفية للقوائم بـ `protection = "hard"` ونشطة.

### 4. Breaks (الاستراحات)
- **الملف:** `blocking app/Core/BlockingConstants.swift:12-15`
- **القيم:** عدد 0-5، مدة 5/10/15 دقيقة.

### 5. StoreKit 2 الكامل
- **الملفات:** `StoreManager.swift`, `ProductIDs.swift`, `Products.storekit`
- **منتجات:** `com.nonetapp.monthly`, `com.nonetapp.yearly`
- **يدعم:** Purchase, Restore, Redeem (promo codes عبر Apple).

### 6. ChatBot المحلي
- **الملفات:** `ChatBotView.swift`, `Core/ChatResponder.swift`
- **محلي بالكامل** — لا اتصال شبكة.
- **البنية المعمارية:** `protocol ChatResponder` يسمح بتبديل `LocalChatResponder` بـ `RemoteChatResponder` لاحقاً بدون تغيير الـ View.

### 7. سياسة الخصوصية والشروط
- **الملفات:** `PoliciesView.swift` + `Core/LegalContent.swift`
- **متاح بـ:** العربية والإنجليزية، متوافق مع PDPL (السعودية) + GDPR.

---

## الميزات المفقودة القابلة للجلب

### 🟢 P0 — Logout (نصف ساعة)
**المشكلة:** لا يوجد زر تسجيل خروج. المستخدم لا يستطيع الانفصال عن حسابه.
**الحل:**
- إضافة قسم "الحساب" في `SettingsView.swift` مع زر "تسجيل الخروج".
- عند الضغط:
  1. مسح `KeychainStore` (بيانات Apple Sign-In).
  2. Reset `@AppStorage(AppStorageKeys.isAuthenticated) = false`.
  3. ContentView يرجع لـ `AuthView` تلقائياً.
- إضافة Alert تأكيد قبل التنفيذ.

### 🟢 P0 — Block Type: Forever (ساعة)
**المشكلة:** لا يوجد خيار حظر دائم (مفيد للمحتوى الإباحي/القمار).
**الحل:**
- إضافة case في `ListEntity.blockType`: `"forever"`.
- في `CreateListSheet`: إضافة خيار رابع للـ block type.
- في `BlockingEngine.activate(_:)`: عند `blockType == "forever"`، طبّق shield بدون expiry (لا `DeviceActivitySchedule`, فقط `ManagedSettings` دائم).
- في `HomeView` و `BlockScreenView`: عرض "للأبد" بدلاً من العداد.
- ملاحظة UX: تحذير مرتين قبل التفعيل (لا رجوع).

### 🟢 P1 — استخدام بيانات Onboarding (ساعتان)
**المشكلة:** نجمع 6 حقول من المستخدم في Onboarding ثم نتجاهلها.
**الحل:**
- في `CreateListSheet` عند فتحه أول مرة:
  - إذا `obApps` غير فارغة → اعرضها كـ "تطبيقات اقترحتها سابقاً" قابلة للإضافة بضغطة.
  - إذا `obCats` فيها فئات معروفة (social/games/shopping) → اقترح تفعيلها افتراضياً.
- في `HomeView`: إذا `obName` موجود، اعرض "أهلاً يا {obName}".

### 🟢 P2 — Academy/Resources (يوم)
**المشكلة:** لا يوجد محتوى تعليمي.
**الحل:**
- صفحة `ResourcesView.swift` static فيها:
  - 2-3 إنفوجرافيك (PNG في Assets).
  - روابط مجتمع (Telegram/WhatsApp — موجودة لكن مخفية حالياً).
- لا فيديوهات في v1 (تحتاج استضافة).

### 🟡 P1 — Block Type: Time-Limit (يوم)
**المشكلة:** لا يوجد "ساعة واحدة يومياً" (مفيد جداً للسوشيال).
**الحل:**
- إضافة case `"timeLimit"` في `ListEntity`.
- استخدام `DeviceActivityCenter.startMonitoring` مع `DeviceActivityEvent` (threshold = duration).
- في `BlockingMonitor` extension: عند `eventDidReachThreshold`، طبّق shield لبقية اليوم.
- Reset يومياً عبر `intervalEnd` (00:00 من اليوم التالي).
- **يحتاج اختبار على جهاز حقيقي.**

### 🟡 P2 — حظر الإشعارات أثناء shield (نصف يوم)
**المشكلة:** الإشعارات تظهر حتى أثناء الحجب (يكسر التركيز).
**الحل:**
- في `BlockingEngine.activate(_:)`: أضف `store.notifications.applications = selection.applicationTokens`.
- ملاحظة: هذا الـ API محدود — يخفي الـ badge والـ banner للتطبيقات المحجوبة فقط.

---

## الميزات المؤجّلة (مستقبلية)

هذه الميزات موثّقة كـ "مستقبلية" لكنها لن تُنفّذ في القريب.

### 📝 ChatBot عبر LLM خارجي
**السبب:** يكسر معمارية offline-first.
**القرار:** نبقي `LocalChatResponder` للمستخدمين الذين يفضّلون الخصوصية، ونوفّر `RemoteChatResponder` (يستخدم Claude API) كخيار مدفوع.
**المتطلب:** `ChatResponder` protocol جاهز للتبديل.
**التوقيت:** بعد إصدار v1.1.

### 📝 Academy expansion (فيديوهات)
**السبب:** يحتاج استضافة فيديوهات (YouTube/Vimeo embed) + إنفوجرافيك احترافي.
**التوقيت:** بعد v1.0 وجمع feedback من المستخدمين.

### 📝 العقاب المالي
**السبب:** يصطدم بـ Apple Guideline 3.1.1 (تفاصيل في القسم التالي).
**التوقيت:** يحتاج بحث عن حل بديل متوافق.

---

## الميزات المستحيلة تقنياً

هذه الميزات في دليل الويب لكنها **لا يمكن تنفيذها على iOS** بدون MDM (Mobile Device Management) أو Configuration Profiles. لا توجد APIs عامة لها.

| الميزة | لماذا مستحيلة |
|--------|--------------|
| **Grayscale toggle** | لا API عام لتغيير display color filters. متاح فقط من Settings → Accessibility → Color Filters. |
| **Airplane mode toggle** | لا API عام. حتى Shortcuts تتطلب user interaction. |
| **Blue-light filter** | Night Shift يُدار من النظام فقط، لا API. |
| **Block App Store** | يتطلب Configuration Profile (MDM). |
| **Block VPN** | يتطلب MDM Restrictions Payload. |
| **Block Settings app** | يتطلب MDM/Restrictions Payload. |

**الحل العملي:** لو احتاج المستخدم هذه القيود، يُرجع لإعدادات Screen Time في النظام نفسه (`Settings → Screen Time → Content & Privacy Restrictions`). نستطيع إضافة "زر يفتح هذه الإعدادات" عبر `UIApplication.openURL` مع scheme `App-Prefs:` (لكن Apple ترفض هذا عادة في App Review).

**القرار النهائي:** نشطب هذه الـ 6 خيارات من خطة الجلب. نوضح في FAQ سبب عدم وجودها.

---

## العقاب المالي و سياسة Apple 3.1.1

### المشكلة
دليل الويب يصف ميزة:
> "العقاب المالي" — المستخدم يحدد مبلغ (5/10/20/50 SAR)، ومستفيد (محفظة NoNet أو جمعية خيرية)، ويُخصم تلقائياً عند كسر الحجب.

### لماذا هذا يصطدم بـ Apple

**App Store Review Guideline 3.1.1 (In-App Purchase):**
> "If you want to unlock features or functionality within your app (by way of example: subscriptions, in-game currencies, **game levels**, access to premium content, or unlocking a full version), you must use **in-app purchase**. Apps may not use their own mechanisms to unlock content or functionality..."

**Guideline 3.1.5(a) (Goods and Services Outside of the App):**
> "If your app enables people to purchase **physical goods or services** that will be consumed outside of the app, you must use purchase methods other than in-app purchase to collect those payments..."

**التفسير القانوني:**
- "العقاب" آلية دفع داخل التطبيق → يجب أن يكون عبر StoreKit (IAP)، **و** Apple يأخذ 30%.
- لو الدفع يذهب للجمعية، هذا "خدمة خارج التطبيق" → لا يُسمح بـ IAP، يجب طرق دفع أخرى (لكن لا يُسمح بربطها بفك حجب داخل التطبيق).
- النتيجة: مهما كان الحل، يصطدم بقاعدة ما.

### الاستثناءات الممكنة (لكن صعبة)
- **منصات تبرّع معتمدة من Apple:** Benevity, Network for Good (لكن لا توجد طريقة لربط التبرّع بـ "كسر حجب" دون فقدان موافقة Apple).
- **اشتراك Premium جزء منه يذهب للجمعية:** ممكن، لكن المستخدم لا يختار المبلغ ولا متى.

### القرار
**استبعاد ميزة العقاب المالي من خارطة الطريق.** سنوثّقها كـ "مستقبلية" مع بحث عن حل متوافق لاحقاً.

**بديل أضعف لكن متوافق:** "شريك التعافي" (CloudKit) يلعب دور الضمير الأخلاقي. عند كسر الحجب → الشريك يستلم إشعار فوري. هذا "عقاب اجتماعي" بدل مالي.

---

## خارطة الطريق المقترحة

### ⏳ Sprint 1 — Quick Wins (نصف يوم)
- [ ] Logout (`SettingsView` + `KeychainStore`).
- [ ] Block Type: Forever (`ListEntity` + `BlockingEngine` + `CreateListSheet`).

### ⏳ Sprint 2 — UX Polish (نصف يوم)
- [ ] استخدام بيانات Onboarding للاقتراحات الذكية.
- [ ] حظر الإشعارات أثناء shield.

### ⏳ Sprint 3 — Time-Limit (يوم)
- [ ] Block Type: TimeLimit + DeviceActivity threshold.
- [ ] اختبار على جهاز حقيقي.

### 🎯 Sprint 4 — شريك التعافي (4-5 أيام)
- المرجع الكامل: [PARTNER_FEATURE_DESIGN_AR.md](PARTNER_FEATURE_DESIGN_AR.md).

### ⏳ Sprint 5 — Resources (يوم)
- [ ] صفحة Resources بإنفوجرافيك static.
- [ ] إظهار روابط Telegram/WhatsApp (مخفية حالياً).

### ❌ خارج النطاق نهائياً
- 6 toggles من "الإعدادات المتقدمة" (مستحيلة بدون MDM).
- العقاب المالي (Apple 3.1.1).

---

## ملاحظات للتنفيذ

1. **اختبار على جهاز حقيقي ضروري** لكل ما يتعلق بـ FamilyControls/DeviceActivity/CloudKit. Simulator لا يعمل لهذه الـ frameworks.
2. **CloudKit يحتاج capability جديدة** في entitlements — انظر `PARTNER_FEATURE_DESIGN_AR.md` للتفاصيل.
3. **كل تعديل على `ListEntity` يحتاج migration** عبر `PersistenceHelpers.PersistenceMigration`.
4. **مفاتيح UserDefaults الجديدة** يجب أن تستخدم prefix `v1:` للحفاظ على الاتساق.
5. **Logging:** استخدم `os.Logger(subsystem: "app.nonet.blocking", category: "...")` — لا `print`.
