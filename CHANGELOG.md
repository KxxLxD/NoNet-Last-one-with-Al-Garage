# Changelog

كل التغييرات البارزة للمشروع موثّقة هنا.

التنسيق مبني على [Keep a Changelog](https://keepachangelog.com/ar/1.0.0/)،
ويتبع المشروع [Semantic Versioning](https://semver.org/lang/ar/).

## [Unreleased]

## [1.1.0] — 2026-05-22

### الإصدار الثاني — شريك التعافي وأنواع الحجب الجديدة

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
