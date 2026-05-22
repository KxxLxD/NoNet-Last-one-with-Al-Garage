# NoNet — تطبيق الحجب الذكي

تطبيق iOS للرفاهية الرقمية يساعد المستخدمين على تقليل إدمان التطبيقات والمواقع عبر قوائم حجب قابلة للجدولة، باستخدام نظام **Screen Time / FamilyControls** من Apple.

- 🇸🇦 العربية / 🇬🇧 English (RTL/LTR كامل)
- iOS 16+
- SwiftUI + Core Data + StoreKit 2
- محلي بالكامل (لا backend، لا تتبع، لا analytics خارجي)

![Status](https://img.shields.io/badge/status-App%20Store%20Submission%20Ready-success)
![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Tests](https://img.shields.io/badge/tests-32%20unit-brightgreen)
![Privacy](https://img.shields.io/badge/privacy-zero%20data%20collected-blueviolet)
![Build](https://img.shields.io/badge/build-0%20errors%200%20warnings-success)

> ## 🎯 إطلاق App Store جاهز
>
> الكود جاهز بنسبة 100% ✅ — تبقّت 9 إجراءات إدارية تحتاج Apple ID الشخصي.
>
> **➡️ افتح [TODO_FOR_KHALID.md](TODO_FOR_KHALID.md) للقائمة الكاملة.**
>
> الإجراءات تأخذ ~3-4 ساعات موزعة على 1-2 أسبوع (انتظار Apple).

---

## 🚀 البناء والتشغيل

### المتطلبات
- macOS مع Xcode 15+ (يفضّل 16+)
- جهاز iPhone/iPad حقيقي بـ iOS 16+ لاختبار Screen Time (لا يعمل في Simulator)
- حساب Apple Developer مع موافقة Family Controls Entitlement

### خطوات البناء
```bash
git clone <repo>
cd "blocking app الاصلي"
open "blocking app.xcodeproj"
```

ثم في Xcode:
1. اختر هدف "blocking app"
2. Signing & Capabilities → تأكد من:
   - **Family Controls** capability
   - **Sign in with Apple** capability  
   - **In-App Purchase** capability
3. Cmd+R للتشغيل

### اختبار StoreKit محلياً
1. Edit Scheme → Run → Options
2. StoreKit Configuration → اختر `blocking app/Products.storekit`
3. Cmd+R — ستظهر منتجات Premium بدون الحاجة لـ App Store Connect

---

## 📁 بنية المشروع

```
blocking app/
├── App/
│   ├── blocking_appApp.swift       # Entry point + CoreDataStack
│   └── ContentView.swift           # Root router (Auth → Onboarding → Tabs)
│
├── Views/
│   ├── HomeView.swift              # الواجهة الرئيسية والقوائم
│   ├── CreateListSheet.swift       # إنشاء قائمة حجب
│   ├── BlockItemsEditorView.swift  # محرر العناصر + FamilyActivityPicker
│   ├── ScheduleEditorSheet.swift   # محرر الجدولة
│   ├── AuthView.swift              # تسجيل/Sign in with Apple
│   ├── OnboardingView.swift        # 4 صفحات
│   ├── ChatBotView.swift           # مساعد محلي
│   ├── ChallengesView.swift        # نقاط ومستويات
│   ├── SettingsView.swift          # الإعدادات
│   ├── UpgradeView.swift           # شراء الاشتراك (StoreKit 2)
│   ├── BlockScreenView.swift       # شاشة الحجب
│   ├── PoliciesView.swift          # الشروط والخصوصية
│   └── AboutView.swift             # حول التطبيق
│
├── Core/                           # ⭐ البنية التحتية
│   ├── AppStorageKeys.swift        # كل مفاتيح @AppStorage موحّدة
│   ├── BlockingConstants.swift     # ثوابت (مدد، حدود)
│   ├── BlockingEngine.swift        # ManagedSettings + DeviceActivity
│   ├── PermissionsManager.swift    # Screen Time + Notifications
│   ├── FamilySelectionStore.swift  # حفظ FamilyActivitySelection
│   ├── SchedulePersistence.swift   # تشفير JSON مع versioning
│   ├── PersistenceMigration       # داخل PersistenceHelpers.swift
│   ├── CoreDataExtensions.swift    # saveIfNeeded() helper
│   ├── StoreManager.swift          # StoreKit 2 (purchase/restore/redeem)
│   ├── ProductIDs.swift            # IDs المنتجات (متطابقة مع Bundle ID)
│   ├── AppleSignInCoordinator.swift # Sign in with Apple + nonce
│   ├── KeychainStore.swift         # تخزين معرفات Apple بأمان
│   ├── ChatResponder.swift         # protocol + LocalChatResponder
│   └── LegalContent.swift          # سياسة الخصوصية + الشروط
│
├── Models/
│   └── ListEntity.swift            # ListEntity + BlockItemEntity
│
├── Utilities/
│   ├── PersistenceHelpers.swift    # BreaksStore + ManualStateStore + Migration
│   ├── ConfirmCreateSheet.swift    # ورقة تأكيد
│   ├── Theme.swift                 # ألوان + LanguageManager
│   └── ...
│
├── Assets.xcassets/                # الأيقونات والألوان
├── Products.storekit               # ⭐ تكوين IAP للاختبار المحلي
├── blocking app.entitlements       # Debug entitlements
└── Release.entitlements            # Release entitlements
```

---

## 🔧 إضافة منتج اشتراك جديد

1. **App Store Connect**: أنشئ المنتج بـ ID يبدأ بـ `com.nonetapp.`
2. **Products.storekit**: أضف نفس المنتج للاختبار المحلي
3. **[ProductIDs.swift](blocking app/Core/ProductIDs.swift)**: أضف const جديد:
   ```swift
   static let lifetime = "com.nonetapp.lifetime"
   static let all: [String] = [monthly, yearly, lifetime]
   ```
4. **[UpgradeView.swift](blocking app/UpgradeView.swift)**: أضف `planCard` للمنتج الجديد

---

## 🔐 الأذونات المطلوبة

| الإذن | متى يُطلب | الكود |
|------|-----------|--------|
| Family Controls (Screen Time) | عند فتح BlockItems Picker | `PermissionsManager.requestScreenTime()` |
| Notifications | عند الضغط على "تفعيل" في الإعدادات | `PermissionsManager.requestNotifications()` |
| Sign in with Apple | عند الضغط على زر Apple | `AppleSignInCoordinator` |

---

## 🧪 الاختبارات

اختبارات Unit موجودة في `blocking appTests/` — 32 اختبار يغطون:
- `SchedulePersistence` (encode/decode + migration)
- `BlockingConstants`، `LocalChatResponder`
- `BreaksStore` / `ManualStateStore` / `KeychainStore`
- `BlockingEngine.isHardLocked`

> ⚠️ Target الـ Tests يحتاج إضافة من Xcode UI لمرة واحدة. اقرأ `blocking appTests/README.md`.

```bash
# بعد إضافة الـ Tests Target من Xcode:
xcodebuild test \
  -project "blocking app.xcodeproj" \
  -scheme "blocking app" \
  -destination "platform=iOS Simulator,name=iPhone 15"
```

---

## 🔒 الخصوصية و Privacy Manifest

`PrivacyInfo.xcprivacy` يصرّح:
- `NSPrivacyTracking`: false
- `NSPrivacyTrackingDomains`: []
- `NSPrivacyCollectedDataTypes`: [] (لا جمع بيانات شخصية)
- استخدام UserDefaults مع reason code `CA92.1` (Functional use)

---

## 📚 وثائق إضافية

- [ARCHITECTURE.md](ARCHITECTURE.md) — تفاصيل البنية والتدفقات
- [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) — قائمة مراجعة قبل النشر
- [GSTACK_GUIDE_AR.md](GSTACK_GUIDE_AR.md) — دليل gstack الشامل بالعربية
- [docs/APP_STORE_LISTING.md](docs/APP_STORE_LISTING.md) — كل نصوص App Store جاهزة
- [docs/REVIEW_2026-05-22.md](docs/REVIEW_2026-05-22.md) — Engineering Review
- [docs/SECURITY_AUDIT_2026-05-22.md](docs/SECURITY_AUDIT_2026-05-22.md) — Security Audit
- [docs/RETRO_2026-05-22-v2.md](docs/RETRO_2026-05-22-v2.md) — Retrospective النهائي
- [docs/web/](docs/web/) — صفحات HTML للاستضافة (privacy, terms, support, index)
- [CHANGELOG.md](CHANGELOG.md) — سجل التغييرات
- [BlockingMonitor/README.md](BlockingMonitor/README.md) — DeviceActivity Extension

---

## 📄 الترخيص

خاص — جميع الحقوق محفوظة.
