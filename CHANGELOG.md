# Changelog

كل التغييرات البارزة للمشروع موثّقة هنا.

التنسيق مبني على [Keep a Changelog](https://keepachangelog.com/ar/1.0.0/)،
ويتبع المشروع [Semantic Versioning](https://semver.org/lang/ar/).

## [Unreleased]

## [1.2.0] — 2026-05-25

### الإصدار الثالث — نظام تصميم موحَّد + موثوقيّة + ميزات تجربة جديدة

#### المضاف (Added)

- **شريك التعافي الآن صامد ضد الانقطاع** — محاولات كسر الحجب اللي تفشل في
  الوصول لـ CloudKit (offline، حساب iCloud غير متاح، أو CKError مؤقّت)
  تُحفَظ في طابور محلي مع 50 عنصر حد أقصى، وتُعاد المحاولة تلقائياً عند
  استعادة الاتصال أو تغيّر حالة الحساب. الشريك راح يستلم محاولات الكسر
  حتى لو المستخدم كان مقطوع وقت المحاولة.
- **فك حجب طوارئ بعد 72 ساعة** للقوائم Hard + Forever — يحلّ Apple Review
  Guideline 5.1.1 (السيطرة للمستخدم) بدون كسر مبدأ مقاومة الاندفاع.
  المستخدم يطلب الفك، ينتظر 3 أيام، ثم يقدر يحرّر القفل. النمط مطابق
  لـ Cold Turkey و Opal Hard Mode.
- **بذر قائمة حجب أوّليّة من بيانات Onboarding** — بدل ما يبدأ المستخدم
  الجديد بشاشة فارغة، التطبيق ينشئ قائمة inactive تلقائياً من الفئات
  والأهداف اللي اختارها في Onboarding. ضغطة واحدة لتفعيلها.
- **دعم Family Sharing لاشتراك Premium** — أعضاء عائلة المشترك يستلمون
  Premium تلقائياً (`familyShareable: true` + معالجة `.familyShared`
  ownership type في StoreKit).
- **عدّاد خطوات صريح في Onboarding** — بدل الـ dots لوحدها، الآن يظهر
  "خطوة X من 4" تحت TabView.
- **مكوّن SoftDivider مشترك** في `Core/Components.swift` — يستبدل 7 نُسخ
  مكرّرة كانت مبعثرة في الـ Views، ويتجاوب مع الشاشات الصغيرة (لم يعد
  يفيض على iPhone SE).
- **نظام Design Tokens موحَّد** في `Core/DesignTokens.swift` — Typography
  (Hero / SectionTitle / CardTitle / Button / Caption)، Spacing scale،
  Radius، Border، HitTarget. مصدر حقيقة واحد يطابق UI-Mode.mdc.

#### المُصلَح (Fixed)

- **Recovery Partner owner/invitee detection كانت tautology** —
  المقارنة مع نص ثابت `"<self>"` غير موجود في الكود أصلاً، فالمدعو كان
  يرى دائماً "بانتظار قبول الشريك…" بدل اسم المالك. الآن يقارن
  `partnership.partnerUserID` مع `userRecordID` المُخزَّن من حساب iCloud
  للجهاز.
- **App Group misconfig كان يفشل بصمت** — `FamilySelectionStore` كان
  يـ fallback لـ `UserDefaults.standard` لمّا الـ App Group entitlement
  مفقود، فالـ extension والـ main app يصيران منفصلين بدون أيّ تحذير.
  الآن الـ detection صريح + banner للمستخدم + heartbeat من الـ extension
  يكشف الحالة عبر `MonitorHealthcheck`.
- **خطأ Core Data save كان يكشف رسالة تقنيّة للمستخدم** — `error.
  localizedDescription` كان يطلع داخل alert. الآن يُسجَّل في Logger
  داخلياً، والمستخدم يشوف رسالة قابلة للتنفيذ.
- **زر "Upgrade" في limit alert ما كان مترجَم** — كان `Button("Upgrade")`
  بالإنجليزي حتى لو الواجهة عربيّة. الآن "رقّي حسابي".
- **`isOwnerView` tautology** — fix كامل لتمييز المالك من المدعو في
  Recovery Partner UI.
- **SmartListSeeder كان يقرأ مفتاح UserDefaults خطأ** — `"v1:lang.
  selected"` بدل `"AppLanguage"`، والقيم خطأ كمان (`"ar"/"en"` بدل
  `"arabic"/"english"`). نتيجته: القوائم المبذورة بلغة خاطئة لكل
  مستخدم بدّل اللغة من الإعدادات.
- **Emergency Unlock matured ما كان يقدر يحرّر فعلياً** — الـ banner
  يقول "استخدم الـ toggle" لكن `toggleManual` كان early-return لـ Hard
  Mode دائماً. الآن يسمح بالـ deactivate لمّا الفك ينضج.

#### المُعَدَّل (Changed)

- **توحيد Accent Color على #2563EB** — كان `accentDark` (#4DA2FC) المستخدم
  السائد، لكنه فشل AA contrast للنص الأبيض (3.4:1). الآن `#2563EB` بـ
  contrast 4.83:1 ✅. 112 مرجع legacy → 0.
- **استبدال 96 استدعاء `.system(size:)` بـ semantic Fonts** — Dynamic
  Type الآن يشتغل على كل النصوص (a11y requirement).
- **توحيد cornerRadius على token scale** (8/12/16/20) — 0 قيم off-scale.
- **توحيد UX Copy** — أزرار "تأكيد" العامّة → labels وصفيّة ("فعّل الصارم"،
  "احذف القائمة"، "سجّل الخروج"، "اطلب الفك")، توحيد الإملاء "حسناً"،
  "لاحقاً"، توحيد "تم" المُحمَّل دلالياً → "مُفعَّل" مع ✓ green.
- **Permission Card → slim warning banner** عند الـ collapsed (44pt)،
  ما يتنافس مع الـ Primary CTA. الـ expanded state بنفس Grant/Enable
  buttons.
- **Share Progress** من primary fill → secondary outline، عشان "ابدأ"
  يبقى الـ CTA الوحيد المهيمن.

#### الأمان والموثوقيّة (Reliability)

- `BlockingMonitor` extension يكتب heartbeat على كل استدعاء
  (`intervalDidStart` / `intervalDidEnd` / `eventDidReachThreshold`)،
  وَ `MonitorHealthcheck` يقرأها للكشف عن انقطاع الـ extension.
- Xcode 16 build settings + Arabic localization region.

## [1.1.0] — 2026-05-22

### الإصدار الثاني — شريك التعافي وأنواع الحجب الجديدة

#### المُصلح (Bug Fixes / Monetization)

- **حدّ القوائم للنسخة المجانية (3 قوائم)** كان معرَّفاً في
  `BlockingConstants.freeTierListLimit` لكن غير مُفعَّل في الـ UI —
  مفعَّل الآن في `CreateListSheet.attemptConfirm()`.
- **حدّ Hard Mode الواحد للنسخة المجانية** — لم يكن موجوداً أصلاً.
  مع Forever block type كان المستخدم المجاني يقدر يحجب دائماً بلا حدود
  (يُلغي قيمة Premium). أُضيف `freeTierHardLimit = 1` constant + فحص في
  `CreateListSheet.attemptConfirm()`. النسخة المجانية الآن تستطيع قائمة
  Hard Mode واحدة فقط.

#### المضاف

- **شريك التعافي (Recovery Partner)** عبر CloudKit + Apple ID — دعوة شريك تعافي
  لقوائم Hard Mode، استلام push notifications عند محاولات الكسر، عرض سجل
  المحاولات الكامل. لا backend خاص، لا OTP — verification حقيقي عبر Apple ID.
- **نوع حظر "للأبد" (Forever)** — حجب دائم بدون نهاية، مع تحذيرات ثلاثية قبل
  التفعيل (banner أحمر + alert أول + alert تأكيد نهائي). مناسب للمحتوى الإباحي
  وتطبيقات القمار.
- **نوع حظر "الحد اليومي" (Time-Limit)** — حصة يومية بالدقائق (15/30/60/90/120)،
  shield يتفعّل تلقائياً بعد تجاوز الحصة ويُرفع منتصف الليل. يعتمد على
  `DeviceActivityEvent` threshold.
- **صفحة الموارد (Resources)** في الإعدادات → 3 بطاقات تعليمية static
  (إحصائيات إدمان الشاشات، فوائد التخلص الرقمي، كيف يعمل NoNet).
- **شخصنة Onboarding** — تحية باسم المستخدم في الـ Home + اقتراحات للفئات
  والتطبيقات في `CreateListSheet` بناءً على ما اختاره في Onboarding.
- **iCloud-unavailable banner** في Home عند وجود قوائم Hard Mode وفقدان iCloud.

#### المحسَّن

- `BlockingEngine.isHardLocked()` يدعم الآن Forever + TimeLimit (لا نهاية طبيعية).
- `BlockingMonitor` extension يميّز بين schedule/limit activities ويعالج
  `eventDidReachThreshold` للـ Time-Limit.
- `ListDetailView` يعرض نوع الحظر بنص محلَّى (`localizedBlockTypeLabel`) بدلاً
  من الـ raw string.
- `BlockingEngine.purge()` يوقف monitoring لكلا prefix الأنشطة
  (`schedule.<UUID>` + `limit.<UUID>`).

#### المعمارية

- `CloudKitPartnerStore.swift` (جديد) — singleton wrapper لكل عمليات CloudKit
  (account status, createPartnership, acceptInvitation, fetchPartnerships,
  recordBreakAttempt, fetchBreakAttempts, revokePartnership, setupSubscriptions).
- `PartnerInviteView.swift` (جديد) — UIViewControllerRepresentable حول
  `UICloudSharingController`.
- `AppDelegate.swift` + `PartnerSceneDelegate` (جديد) — يستلمان
  `windowScene(_:userDidAcceptCloudKitShareWith:)`.
- `ResourcesView.swift` (جديد) — صفحة static بـ SwiftUI، لا أصول صور.
- 3 entitlements جديدة في Debug + Release: `iCloud-services` (CloudKit)،
  `iCloud-container-identifiers` (`iCloud.com.nonetapp`)، `aps-environment`.

#### الوثائق

- `docs/FEATURE_REFERENCE_FROM_WEB_AR.md` — مرجع نسخة NoNet Web الكامل (1038 سطر).
- `docs/FEATURE_GAP_ANALYSIS_AR.md` — مقارنة منهجية بين 27 ميزة (78% منها
  ممكن، 22% مستحيل على iOS بدون MDM).
- `docs/PARTNER_FEATURE_DESIGN_AR.md` — التصميم المعتمد لشريك التعافي
  (CloudKit + Apple ID) مع 6 خيارات بديلة موزونة و 8 حالات حافة.
- `CLAUDE.md` موسَّع بـ build commands و architecture conventions و عَلاقات
  multi-file (الـ blocking flow).

#### يحتاج إعداد يدوي بعد الـ merge

- Xcode → Signing & Capabilities → إضافة iCloud (CloudKit) + Push Notifications.
- App Store Connect → CloudKit Dashboard → إنشاء container `iCloud.com.nonetapp`
  والـ schema (`Partnership`, `BreakAttempt`).
- `Localizable.strings` → إضافة `PARTNER_BREAK_TITLE` و `PARTNER_BREAK_BODY`
  (نصوص الـ push notifications).
- اختبار يدوي على جهازين iPhone حقيقيين (Family Controls و CloudKit لا يعملان
  بشكل كامل في Simulator).

## [1.0.0] — 2026-05-22

### الإصدار الأول الجاهز للنشر على App Store

#### المضاف
- **محرّك الحجب الحقيقي** عبر `FamilyControls` + `ManagedSettingsStore` + `DeviceActivityCenter`
- **إنشاء وإدارة قوائم الحجب** مع دعم الوضع الفوري (Now) والمجدول (Scheduled)
- **الوضع الصارم (Hard Mode)** — لا يمكن إيقاف الحجب قبل انتهاء المدة
- **StoreKit 2 كامل** — منتجين شهري وسنوي مع تجربة مجانية 7 أيام
- **Sign in with Apple** مع تخزين آمن في Keychain
- **مساعد محلي (Chat)** بالعربية والإنجليزية — بدون اتصال شبكة
- **Onboarding** بـ 4 صفحات لجمع تفضيلات المستخدم
- **التحديات والنقاط** (gamification)
- **دعم RTL/LTR كامل** للعربية والإنجليزية
- **سياسة خصوصية وشروط استخدام** مهنية متوافقة مع PDPL (السعودية) و GDPR
- **Privacy Manifest** (`PrivacyInfo.xcprivacy`) للامتثال لمتطلبات iOS 17+
- **StoreKit Configuration File** للاختبار المحلي
- **BlockingMonitor extension scaffold** لتطبيق الـ shields المجدولة في الخلفية
- **اختبارات unit** على Core/ modules
- **توثيق شامل**: README, ARCHITECTURE, DEPLOYMENT_CHECKLIST, GSTACK_GUIDE_AR

#### الأمان
- App Attest entitlement (development في Debug، production في Release)
- لا تتبع، لا analytics خارجي، لا third-party SDKs
- Keychain configuration بـ `AfterFirstUnlockThisDeviceOnly`
- معالجة nonce + SHA256 لـ Sign in with Apple
- لا hardcoded secrets أو API keys

#### البنية التحتية
- مجلد `Core/` مع 13 ملف بنية تحتية موحّدة
- معالجة أخطاء Core Data مركزية عبر `saveIfNeeded()`
- Versioning للـ UserDefaults (prefix `v1:`) و scheduleSlots JSON payload
- `PermissionsManager` مركزي لـ Screen Time + Notifications
- `BlockingConstants` لكل magic numbers
- `os.Logger` بـ subsystem `app.nonet.blocking`

#### معالجة الديون التقنية
- إزالة ملفات `.backup` (HomeView, ContentView, CreateListSheet)
- إزالة جميع force unwraps الخطرة
- توحيد جميع `@AppStorage` keys في enum `AppStorageKeys`
- توحيد iOS Deployment Target على 16.0 (كان 16.0/16.6)
- تشديد domain validation و email validation (regex بدلاً من contains)
- إزالة كود الخصم المضمّن "nonet" واستبداله بـ Apple Offer Code Redemption

#### Apple Setup
- Bundle ID: `com.nonetapp`
- Team: `L2T9STCPA5`
- ProductIDs: `com.nonetapp.monthly`, `com.nonetapp.yearly`
- `NSFamilyControlsUsageDescription` مع رسالة بالعربية
- Family Controls + Sign in with Apple capabilities في الـ entitlements

[Unreleased]: https://github.com/KxxLxD/NoNet-Last-one-with-Al-Garage/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/KxxLxD/NoNet-Last-one-with-Al-Garage/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/KxxLxD/NoNet-Last-one-with-Al-Garage/releases/tag/v1.0.0
