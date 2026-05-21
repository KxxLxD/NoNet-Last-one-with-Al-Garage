# بنية تطبيق NoNet

## نظرة عامة

NoNet تطبيق iOS محلي بالكامل (offline-first). كل البيانات مخزنة على جهاز المستخدم في Core Data و UserDefaults و Keychain. لا توجد اتصالات شبكة خارج StoreKit (Apple) و Sign in with Apple.

---

## مخطط المكونات

```
┌──────────────────────────────────────────────────────────────────┐
│                      blocking_appApp (Entry)                     │
│  - CoreDataStack.shared                                          │
│  - PersistenceMigration.runIfNeeded()                            │
│  - seedIfNeeded() → 3 default lists                              │
└─────────────────────────────┬────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                          ContentView                             │
│  isAuthenticated? → AuthView                                     │
│  showOnboardingAfterLogin? → OnboardingView                      │
│  else → TabView { HomeView | ChatBotView | SettingsView }        │
└─────────────────────────────┬────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
   ┌─────────┐          ┌──────────┐          ┌──────────┐
   │HomeView │          │ChatBotV. │          │SettingsV.│
   └────┬────┘          └────┬─────┘          └────┬─────┘
        │                    │                     │
        ▼                    ▼                     ▼
  CreateListSheet      ChatResponder          UpgradeView
        │              (protocol)             (StoreKit2)
        ▼              LocalChatResponder
  BlockItemsEditor
        │
        ▼
  FamilyActivityPicker (Apple)
```

---

## التدفق الحرج: من اختيار التطبيقات إلى الحجب الفعلي

```
المستخدم
   │
   ▼
[يضغط "إنشاء قائمة"] CreateListSheet
   │
   ▼
[يفتح محرر العناصر] BlockItemsEditorView
   │
   ▼
[يضغط على Apps]
   │
   ▼
   PermissionsManager.requestScreenTime()  ──→ ✅ مُنح
   │
   ▼
   FamilyActivityPicker (نظام Apple)
   │
   ▼
   [المستخدم يختار تطبيقات/فئات/مواقع]
   │
   ▼
   draft.familySelection = FamilyActivitySelection
   │
   ▼
[المستخدم يضغط "تم"]
   │
   ▼
   CreateListSheet.save()
   │
   ├──→ ListEntity في Core Data
   ├──→ BlockItemEntity × N
   ├──→ FamilySelectionStore.save(selection, for: list.id)
   ├──→ BreaksStore.save(...)
   └──→ BlockingEngine.shared.activate(list)
                │
                ├──→ ManagedSettingsStore(named: "blocklist.<UUID>")
                │    .shield.applications = selection.applicationTokens
                │    .shield.applicationCategories = .specific(...)
                │    .shield.webDomains = selection.webDomainTokens
                │
                └──→ إذا blockType == "scheduled":
                     DeviceActivityCenter.startMonitoring(...)
                     ↓
                     [TODO: DeviceActivityMonitor extension يطبق shields في الوقت المحدد]
```

---

## دور كل ملف في `Core/`

| الملف | الغرض |
|------|-------|
| **AppStorageKeys.swift** | كل سلاسل مفاتيح `@AppStorage` في مكان واحد — استبعاد الأخطاء الإملائية. |
| **BlockingConstants.swift** | ثوابت مثل `breakDurationOptions = [5,10,15]`، `minBlockSeconds = 300`. |
| **BlockingEngine.swift** | محرك الحجب — يدير `ManagedSettingsStore` لكل قائمة + `DeviceActivityCenter` للجدولة. |
| **PermissionsManager.swift** | `@MainActor ObservableObject` يدير حالة Screen Time + Notifications، يستمع لـ `didBecomeActiveNotification`. |
| **FamilySelectionStore.swift** | يحفظ `FamilyActivitySelection` (رموز التطبيقات/الفئات) في UserDefaults كـ JSON. |
| **SchedulePersistence.swift** | encode/decode لـ `scheduleSlots` مع payload `{version, slots}` للتطوّر المستقبلي. |
| **CoreDataExtensions.swift** | `saveIfNeeded() -> Result<Void, Error>` — مع `os.Logger`. |
| **StoreManager.swift** | StoreKit 2 — products/purchase/restore/redeem + `Transaction.updates` listener. |
| **ProductIDs.swift** | IDs المنتجات (`com.nonetapp.monthly` / `.yearly`). |
| **AppleSignInCoordinator.swift** | Sign in with Apple مع nonce/SHA256 — يحفظ `userIdentifier` في Keychain. |
| **KeychainStore.swift** | Wrapper بسيط حول `Security` framework. |
| **ChatResponder.swift** | `protocol ChatResponder` + `LocalChatResponder` (محلي بدون شبكة). |
| **LegalContent.swift** | نصوص سياسة الخصوصية والشروط بالعربية والإنجليزية. |

---

## طبقات التخزين

| الطبقة | المحتوى | المسار |
|--------|--------|--------|
| **Core Data** | قوائم الحجب وعناصرها | `~/Library/Application Support/Model.sqlite` |
| **UserDefaults (v1:)** | Breaks، manual state، family selection، AppStorage | محلي ضمن sandbox |
| **Keychain** | Apple userID فقط | محمي بـ `After First Unlock` |
| **AppStorage** | حالة UI، trial، premium، onboarding | عبر UserDefaults |

---

## معالجة الأخطاء

كل عمليات الحفظ في Core Data تستخدم:
```swift
extension NSManagedObjectContext {
    func saveIfNeeded() -> Result<Void, Error>
}
```

الأخطاء تُعرض للمستخدم عبر Alert، وتُسجَّل عبر `os.Logger` بـ subsystem `app.nonet.blocking`.

---

## الـ Versioning

| البيانات | آلية الـ versioning |
|----------|---------------------|
| UserDefaults keys | prefix `v1:` |
| Schedule slots JSON | `{"version": 1, "slots": [...]}` مع fallback للنسخة القديمة |
| Family selection | JSON من Apple (محمي بـ Codable) |

---

## الديون التقنية المعروفة

1. **لا توجد اختبارات (Tests)** — لا XCTest target.
2. **DeviceActivityMonitor Extension غير موجود** — الجدولة تُسجَّل لكن الـ shields لا تُطبَّق تلقائياً في الوقت المحدد (يحتاج Extension target في Xcode).
3. **Apple Sign In لا backend** — يحفظ في Keychain فقط، لا verification مع خادم.
4. **Onboarding data** — تُجمع في AppStorage لكن لا تُستخدم.
5. **Family Controls على Simulator** — لا يعمل، يحتاج جهاز حقيقي.

---

## القرارات المعمارية

- **Programmatic Core Data model** بدلاً من `.xcdatamodeld` — سهل version control لكن يحتاج migration manual.
- **Singleton CoreDataStack** — مقبول لأن التطبيق محلي ولا concurrency معقد.
- **ManagedSettingsStore per list** (وليس واحد عام) — يسمح بحجب قوائم متعددة بشكل مستقل.
- **JSON في binary field لـ scheduleSlots** — مرن، لكن يحتاج فحص في decode.
- **Logging عبر os.Logger** بدلاً من print — يظهر في Console.app ويُحجب في Release.
