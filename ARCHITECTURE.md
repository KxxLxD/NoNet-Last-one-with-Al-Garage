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
| **AppStorageKeys.swift** | كل سلاسل مفاتيح `@AppStorage` في مكان واحد، كلها `v1:` prefix. مع migration table في `PersistenceMigration` للترقية من الأسماء القديمة. |
| **BlockingConstants.swift** | ثوابت (`breakDurationOptions = [5,10,15]`، `minBlockSeconds = 300`، `emergencyUnlockDelaySeconds = 7 أيام`، `challengePointsPerLevel = 200`، `seederDefaultDurationSeconds = 3600`). |
| **BlockingEngine.swift** | محرك الحجب — يدير `ManagedSettingsStore` لكل قائمة + `DeviceActivityCenter` للجدولة (schedule per slot × weekday). `purge(listId:)` هو المسار الوحيد لتنظيف per-list state. |
| **PermissionsManager.swift** | `@MainActor ObservableObject` يدير حالة Screen Time + Notifications، يستمع لـ `didBecomeActiveNotification`. |
| **FamilySelectionStore.swift** | يحفظ `FamilyActivitySelection` (رموز التطبيقات/الفئات) في App Group UserDefaults كـ JSON. |
| **SchedulePersistence.swift** | encode/decode لـ `scheduleSlots` مع payload `{version, slots}` للتطوّر المستقبلي. |
| **CoreDataExtensions.swift** | `saveIfNeeded() -> Result<Void, Error>` — مع `os.Logger`. |
| **CloudKitPartnerStore.swift** | `@MainActor ObservableObject` يدير شريك التعافي عبر CloudKit (privateDB + sharedDB + CKShare). يخزّن `databaseScope` على كل Partnership ليجنب double-DB lookup في العمليات اللاحقة. |
| **ApprovalExecutor.swift** | `executePendingApprovals()` — يطبّق الـ `.approved` requests محلياً (purge / deactivate / modify). Idempotent ضد الـ duplicate pushes. |
| **PendingBreakAttemptQueue.swift** | طابور offline للـ BreakAttempt records فشل CloudKit upload. سعة 50، يدعم status + reason للـ approval workflow. |
| **MonitorHealthcheck.swift** | يكشف إذا الـ BlockingMonitor extension متركّب بشكل صحيح عبر heartbeat key في App Group. |
| **EmergencyUnlockStore** (`PersistenceHelpers.swift`) | `@MainActor ObservableObject` لـ 7-day delay على Hard + Forever lists. ضمان Apple 5.1.1 (user control). |
| **TrialClock.swift** | حساب trial-elapsed math (isTrialActive / daysRemaining / hasTrialExpired) مع defense ضد clock rewind. |
| **LanguageResolver.swift** | single source of truth لـ effective UI language. يستخدمه LanguageManager + SmartListSeeder بدون duplication. |
| **DataReset.swift** | `signOutAndClear()` — تنظيف شامل عند logout (Keychain + AppStorage + per-list stores + Core Data + PendingQueue). |
| **SmartListSeeder.swift** | بذر قائمة inactive من بيانات onboarding بعد التسجيل. |
| **StoreManager.swift** | StoreKit 2 — products/purchase/restore/redeem + `Transaction.updates` listener. منتجات مرتبة بـ `ProductIDs.all` order (لا price assumption). |
| **ProductIDs.swift** | IDs المنتجات (`com.nonetapp.monthly` / `.yearly`). |
| **AppleSignInCoordinator.swift** | Sign in with Apple مع nonce/SHA256 — يحفظ `userIdentifier` في Keychain. |
| **KeychainStore.swift** | Wrapper بسيط حول `Security` framework. |
| **ChatResponder.swift** | `protocol ChatResponder` + `LocalChatResponder` (محلي بدون شبكة) مع token-aware keyword matching. |
| **LegalContent.swift** | نصوص سياسة الخصوصية والشروط بالعربية والإنجليزية. |
| **Components.swift** | مكتبة UI components مشتركة (SoftDivider, LabeledTextField, ProtectionBadge, EmptyState, ...). |
| **DesignTokens.swift** | Typography + spacing + radius + border + hit-target tokens — single source of truth للـ design system. |

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

## BlockingMonitor Extension (DeviceActivity)

عند `BlockingEngine.scheduleMonitoring(for:)`، يُسجَّل `DeviceActivitySchedule` مع iOS. عند بداية/نهاية النافذة الزمنية، iOS يستدعي callbacks في extension منفصل:

```
BlockingEngine.scheduleMonitoring(for: list)
   │
   ▼
DeviceActivityCenter.startMonitoring(name: "schedule.<UUID>", during: schedule)
   │
   ▼
[iOS تنتظر حتى يحين الوقت]
   │
   ▼
BlockingMonitor (extension process) — intervalDidStart
   │
   ├──→ يفك FamilyActivitySelection من UserDefaults (عبر App Group)
   │
   ├──→ ManagedSettingsStore(named: "blocklist.<UUID>")
   │    .shield.applications = selection.applicationTokens
   │    .shield.applicationCategories = .specific(...)
   │
   └──→ ✅ shields مطبَّقة
   
[عند نهاية النافذة]
   │
   ▼
BlockingMonitor — intervalDidEnd
   │
   └──→ store.clearAllSettings()
        ✅ shields مرفوعة
```

الـ Extension تحتاج إضافة Target من Xcode UI + App Group لمشاركة UserDefaults. التفاصيل في `BlockingMonitor/README.md`.

---

## الديون التقنية المعروفة

1. **Tests Target يحتاج إضافة من Xcode UI** — ملفات الاختبار موجودة لكن inert حتى تضاف للـ target.
2. **BlockingMonitor Target يحتاج إضافة من Xcode UI** — السكافولد جاهز.
3. **Apple Sign In لا backend** — يحفظ في Keychain فقط، لا verification مع خادم.
4. **Onboarding data** — تُجمع في AppStorage لكن لا تُستخدم.
5. **Family Controls على Simulator** — لا يعمل، يحتاج جهاز حقيقي.
6. **Auto-deactivation للقوائم المنتهية** — يحدث عند فتح التطبيق فقط، لا في الخلفية. (الحجب يُحرَّر منطقياً عبر isActiveNow، لكن الـ shield يبقى مطبَّق حتى opens.)

---

## القرارات المعمارية

- **Programmatic Core Data model** بدلاً من `.xcdatamodeld` — سهل version control لكن يحتاج migration manual.
- **Singleton CoreDataStack** — مقبول لأن التطبيق محلي ولا concurrency معقد.
- **ManagedSettingsStore per list** (وليس واحد عام) — يسمح بحجب قوائم متعددة بشكل مستقل.
- **JSON في binary field لـ scheduleSlots** — مرن، لكن يحتاج فحص في decode.
- **Logging عبر os.Logger** بدلاً من print — يظهر في Console.app ويُحجب في Release.
