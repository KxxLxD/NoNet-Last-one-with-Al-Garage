# Changelog

كل التغييرات البارزة للمشروع موثّقة هنا.

التنسيق مبني على [Keep a Changelog](https://keepachangelog.com/ar/1.0.0/)،
ويتبع المشروع [Semantic Versioning](https://semver.org/lang/ar/).

## [Unreleased]

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

[Unreleased]: https://github.com/khalidnonet/blocking-app/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/khalidnonet/blocking-app/releases/tag/v1.0.0
