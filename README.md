# NoNet — تطبيق الحجب الذكي

تطبيق iOS للرفاهية الرقمية يساعد المستخدمين على تقليل إدمان التطبيقات والمواقع عبر قوائم حجب قابلة للجدولة، باستخدام نظام **Screen Time / FamilyControls** من Apple.

- 🇸🇦 العربية / 🇬🇧 English (RTL/LTR كامل)
- iOS 16+
- SwiftUI + Core Data + StoreKit 2
- محلي بالكامل (لا backend، لا تتبع، لا analytics خارجي)

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

## 📚 وثائق إضافية

- [ARCHITECTURE.md](ARCHITECTURE.md) — تفاصيل البنية والتدفقات
- [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) — قائمة مراجعة قبل النشر
- [GSTACK_GUIDE_AR.md](GSTACK_GUIDE_AR.md) — دليل gstack الشامل بالعربية
- [docs/RETRO_2026-05-22.md](docs/RETRO_2026-05-22.md) — Retrospective

---

## 📄 الترخيص

خاص — جميع الحقوق محفوظة.
