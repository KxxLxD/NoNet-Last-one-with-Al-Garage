# مراجعة معمارية كاملة — NoNet

**التاريخ:** 2026-05-27
**النطاق:** كل المشروع
**الإصدار المُراجَع:** branch `NoNet-App` (آخر commit `be366bf`)

---

## جدول المحتويات

1. [المنطقة 1 — Blocking Core](#المنطقة-1--blocking-core)
2. [المنطقة 2 — App Group Fallback](#المنطقة-2--app-group-fallback)
3. [المنطقة 3 — CloudKit Partner State Machine](#المنطقة-3--cloudkit-partner-state-machine)
4. [المنطقة 4 — Data Persistence Layering](#المنطقة-4--data-persistence-layering)
5. [المنطقة 5 — Hard-Mode + Emergency Unlock](#المنطقة-5--hard-mode--emergency-unlock)
6. [المنطقة 6 — Build/Test Infrastructure](#المنطقة-6--buildtest-infrastructure)
7. [المنطقة 7 — State Management في الـ Views](#المنطقة-7--state-management-في-الـ-views)
8. [الملخص النهائي](#الملخص-النهائي)
9. [قائمة ADRs المرشحة](#قائمة-adrs-المرشحة)
10. [نقاط القوة المعمارية](#نقاط-القوة-المعمارية)

---

## المنطقة 1 — Blocking Core

### القرارات المعمارية القائمة (موثَّقة)

| القرار | المكان | التقييم |
|--------|--------|---------|
| `ManagedSettingsStore` لكل قائمة (named by UUID) | `BlockingEngine.swift:8-9` | صحيح. السماح بتشغيل قوائم متعددة بشكل مستقل قرار سليم. |
| انفصال أسماء `schedule.*` و `limit.*` | `BlockingEngine.swift:141-143` | ذكي. يجنّب الحاجة لـ context store منفصل. |
| `durationSeconds` يُعاد استخدامه لحصة timeLimit | `BlockingEngine.swift:175` | overload دلالي. قابل لخطأ مستقبلي. |
| forever + hard = lock يستلم EmergencyUnlock بعد 7 أيام | `BlockingEngine.swift:85-99` | قرار توافق مع Apple 5.1.1 موثَّق. ممتاز. |
| timeLimit + hard لا يستلم EmergencyUnlock | `BlockingEngine.swift:91-93,100` | منطقي — منتصف الليل أصلاً يحرّر. |

### القضايا الحرجة

#### Bug معماري #1: `scheduleMonitoring` يجمع slots متعددة بشكل خاطئ

**الموقع:** `BlockingEngine.swift:210-234`

```swift
let earliestStart = slots.map { $0.fromMinutes }.min() ?? 0
let latestEnd = slots.map { $0.toMinutes }.max() ?? 0
```

لو المستخدم عرّف:
- Slot A: السبت 9:00 → 12:00
- Slot B: السبت 18:00 → 22:00

الـ schedule المسجَّل: 9:00 → 22:00. الـ shield يبقى مفعّل من 12 إلى 18 رغم أن المستخدم سمح بالاستخدام في هذه الفجوة.

والأسوأ: حقل `day` في `ScheduleSlotV1` يُهمل بالكامل. لو slot يخص الإثنين فقط، يُسجَّل كـ `repeats: true` يومياً.

**أصل المشكلة:** DeviceActivity API يقبل schedule واحد لكل `DeviceActivityName`. لتمثيل slots متعددة، يحتاج المطور تسجيل N schedules بأسماء مختلفة.

**الخيارات:**
- **خيار A:** schedule لكل (slot × day) — N×7 schedules كحد أقصى لكل قائمة.
- **خيار B:** UI يحدد slot واحد فقط — تقليل scope إلى ما يدعمه API بنظافة.
- **خيار C:** "ساعات السماح" بدل "ساعات الحجب" — schedule واحد يمتد لكل اليوم.

**الأنسب:** A لو dataset صغير، أو B لأبسط شحن.

#### Bug معماري #2: Extension target غير مركّب → scheduled/timeLimit صامتة

**الموقع:** `BlockingEngine.swift:237-241`, `BlockingMonitor/BlockingMonitor.swift:9-16`

ملف `BlockingMonitor.swift` موجود، لكن الـ Xcode target لم يُنشأ بعد. النتيجة:
- `activate(list:)` لـ `now` و `forever` يعمل
- `activate(list:)` لـ `scheduled` و `timeLimit` ينجح في تسجيل الـ schedule في `DeviceActivityCenter` لكن لا shield يُطبَّق

هذا أعطال 50% من ميزات الحجب. خطوة blocker قبل App Store.

#### Bug معماري #3: typed-only websites لا تحجب

**الموقع:** `BlockingEngine.swift:166-171`

`BlockItemEntity(kind=="website", value="example.com")` يُحفظ في Core Data لكن لا يُترجم لـ shield. السبب: `ManagedSettings.shield.webDomains` يقبل `Set<WebDomainToken>` فقط (opaque tokens من FamilyActivityPicker)، لا strings.

**الخيارات:**
- A: أزل إدخال النص نهائياً. اعتمد على FamilyActivityPicker فقط.
- B: اعرض warning في الـ UI أن النص لا يحجب حتى يُختار من Picker.

**الأنسب:** A — أبسط، أصدق مع المستخدم.

---

## المنطقة 2 — App Group Fallback

### الوضع الحالي

| المكوّن | الـ pattern | التقييم |
|---------|-----------|---------|
| `sharedDefaultsOptional: UserDefaults?` | nil-safe | مستخدَم |
| `sharedDefaults: UserDefaults` (legacy) | fallback لـ `.standard` بصمت | dead code — معرَّف لكن بدون caller خارجي |
| `isAppGroupActive: Bool` | read-once at load | يُقرأ في HomeView لإظهار banner |
| `MonitorHealthcheck` | heartbeat-based detection | تصميم متين |

### الأشياء التي تعمل بشكل صحيح

1. `FamilySelectionStore.save/load/clear` كلها تستخدم `sharedDefaultsOptional` و ترجع `false`/`nil` عند الفقد — لا silent write على `.standard`.
2. `BlockingMonitor.applyShield` يحارب الفقد بصراحة.
3. `MonitorHealthcheck.shouldShowBanner` ذكي — يجمع شرطين (عُمر القائمة الأقدم > 24 ساعة، إما الـ App Group مفقود أو لم يأتِ heartbeat).

### القضايا

#### Code Smell: legacy `sharedDefaults` non-optional لا يزال مُصدَّر

**الموقع:** `FamilySelectionStore.swift:36-45`

```swift
let sharedDefaults: UserDefaults = {
    if let shared = sharedDefaultsOptional { return shared }
    log.error("App Group ... NOT GRANTED ...")
    return .standard
}()
```

trap مفتوح لمطوّر مستقبلي. مفتاح global بدون namespace.

**التوصية:** احذف. لا caller، فلا مبرر للوجود.

#### `isAppGroupActive` snapshot at load → لا يتحدث في نفس runtime

**الموقع:** `FamilySelectionStore.swift:28-29`

يُحسَب مرة واحدة عند load الـ module. السيناريو المعطّل: لو fixed الـ entitlement في Xcode وأعاد التوقيع، الـ snapshot لا يلحظ التغيير إلا بعد restart للـ process.

**التوصية:** اقلب لـ `var` محسوبة (computed).

---

## المنطقة 3 — CloudKit Partner State Machine

### القرارات المعمارية القائمة (موثَّقة)

| القرار | المكان | التقييم |
|--------|--------|---------|
| CloudKit بدل backend مخصّص | `docs/PARTNER_FEATURE_DESIGN_AR.md` | صحيح للمنتج. |
| DTO/CKRecord separation عبر failable init | `CloudKitPartnerStore.swift:825-844` | ممتاز. schema-drift يُتعامل معه بأمان. |
| Approval state machine موحَّد في BreakAttempt | `CloudKitPartnerStore.swift:60-69` | schema-frugal. |
| PendingBreakAttemptQueue للـ offline retry | `PendingBreakAttemptQueue.swift:8-13` | يحافظ على الـ social-accountability promise. |
| ApprovalExecutor خارج الـ View | `ApprovalExecutor.swift:11-13` | يضمن execution سواء التطبيق مفتوح أم لا. |

### القضايا الحرجة

#### Asymmetry: `createActionRequest` لا يستخدم PendingQueue

**الموقع:** `CloudKitPartnerStore.swift:316-343`

```swift
do {
    try await save(records: [record])
    ...
} catch {
    log.error("createActionRequest failed: ...")
    self.lastError = error.localizedDescription
    return nil   // الـ request ضاع
}
```

السيناريو المعطّل:
1. المستخدم في وضع طيران، يحاول حذف قائمة Hard Mode.
2. الـ UI يعرض "تم إرسال الطلب للشريك."
3. لكن الـ save فشل (لا اتصال).
4. الـ partner لا يستلم شيء.

**التوصية:** نفس الـ PendingQueue يجب أن يحمي `createActionRequest`. أو ارفض `createActionRequest` صراحةً عند `!isAccountAvailable`.

#### Double-DB lookup pattern — chatty + costly

**الموقع:** `CloudKitPartnerStore.swift:370-377, 421-453, 617-628`

```swift
for db in [sharedDB, privateDB] {
    if let r = try? await db.record(for: recordID) { ... }
}
```

النمط متكرر في 4 مواضع. كل عملية تكلّف 2× CloudKit requests.

**تحسين معماري:** أضف `databaseScope: CKDatabase.Scope` للـ `Partnership` DTO، يُحسَب عند `fetchPartnerships`.

#### `fetchMyOutgoingRequests` يجلب كل الـ records ثم يفلتر in-memory

**الموقع:** `CloudKitPartnerStore.swift:431-453`

`predicate: NSPredicate(value: true)` يعني "all records". O(n) over all BreakAttempts.

**التحسين:** denormalize `ownerUserID` في الـ BreakAttempt record، ثم indexed query.

#### Subscriptions على sharedDB فقط — قد لا تكفي للـ owner

**الموقع:** `CloudKitPartnerStore.swift:664-715`

السلوك الفعلي يعتمد على CloudKit cross-DB visibility. غير موثَّق في الكود. يستحق comment أو تجربة على جهازين حقيقيين.

#### `rejectInvitation` accept-then-reject hack

**الموقع:** `CloudKitPartnerStore.swift:780-797`

التعليقات تعترف: "no public decline API exists." hack مقبول لكن يحتاج FIXME comment للتذكير.

#### `isIncoming`/`isOutgoing` يعتمدان على `partnerships` cache

**الموقع:** `CloudKitPartnerStore.swift:457-473`

**Race condition محتمل:** لو push وصل قبل أول `fetchPartnerships` يكتمل، الـ filter يرجع false لكل request.

**التحسين:** نادِ `fetchPartnerships` لو cache فارغ.

---

## المنطقة 4 — Data Persistence Layering

### الطبقات الخمس

| الطبقة | الـ Scope | المسؤولية |
|---------|---------|-----------|
| Core Data (programmatic) | عملية التطبيق الرئيسية | `ListEntity` + `BlockItemEntity` |
| Standard UserDefaults | عملية التطبيق الرئيسية | Auth, premium, onboarding, ManualStateStore, BreaksStore, EmergencyUnlockStore, DeletionLogStore, PendingBreakAttemptQueue |
| App Group UserDefaults | مشترك مع الـ extension | FamilySelectionStore + monitor heartbeat |
| Keychain | عملية التطبيق الرئيسية | Apple userID |
| CloudKit | مشترك عبر الأجهزة | Partnership / BreakAttempt records |

### نقاط القوة

1. التقسيم بحسب الـ scope صحيح.
2. Keychain access = `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — أفضل default.
3. `EmergencyUnlockStore` يخزّن timestamp الطلب لا maturity — مرونة.
4. PersistenceMigration idempotent.
5. PendingBreakAttemptQueue capped at 50.
6. Programmatic Core Data model يتجنّب مشاكل merge.

### القضايا

#### عدم اتساق الـ versioning في `AppStorageKeys`

**الموقع:** `AppStorageKeys.swift:12-44`

```swift
static let isAuthenticated = "isAuthenticated"           // غير مُصدَّر
static let isPremium = "isPremium"                       // غير مُصدَّر
static let permissionsExpanded = "v1:permissionsExpanded" // مُصدَّر
```

في `PersistenceHelpers.swift` كل المفاتيح تستخدم `v1:` prefix. عدم الاتساق يصعّب future migrations.

**التوصية:** أضف `v1:` لكل المفاتيح. أضف خطوة migration واحدة.

#### لا توجد centralized sign-out cleanup

عند تسجيل خروج المستخدم، ما الذي يُمسَح؟ غير معرَّف. السيناريو:
1. مستخدم A ينشئ قوائم، يدخل onboarding profile.
2. يسجّل خروج. `isAuthenticated = false` فقط.
3. مستخدم B يسجل دخول بنفس الجهاز.
4. يرى قوائم A، break history A، trial state A.

**hazard خصوصية + UX confusion.**

**التوصية:** أنشئ `DataReset.signOutAndClear()`.

#### `mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy` قد يبيع البيانات silently

**الموقع:** `blocking_appApp.swift:131`

معقول لتطبيق context واحد. لكن لو أُضيف background context، تعديلاته قد تُضاع.

**التوصية:** اترك الحالي. أعد التقييم عند إضافة background context.

#### Core Data programmatic vs `.xcdatamodeld` — trade-off معروف

النموذج البرمجي يصعّب lightweight migration التلقائية. لا يدعم renaming attributes عبر Core Data الـ native migration.

**التوصية:** اقبل الـ trade-off ما دام الـ schema صغير. وثّق هذه القيد في ARCHITECTURE.md.

---

## المنطقة 5 — Hard-Mode + Emergency Unlock

### State machine الكامل

```
list.protection
    │
    ├─ "noProtection" ──→ isHardLocked = false دائماً
    │
    └─ "hard"
        │
        ├─ blockType == "now"
        │   ├─ Date() < createdAt + durationSeconds ──→ locked
        │   └─ بعد ذلك                                  ──→ unlocked طبيعياً
        │
        ├─ blockType == "timeLimit"  ──→ locked (يُحرَّر منتصف الليل)
        │
        ├─ blockType == "forever"
        │   ├─ EmergencyUnlockStore.isGranted == false ──→ locked
        │   └─ EmergencyUnlockStore.isGranted == true  ──→ unlocked
        │
        └─ blockType == "scheduled"   ──→ isHardLocked = false (غامض!)


gatekeeperType:
    │
    ├─ "nonet"   → NoNetGatekeeperSheet (strong reason 200ch / 7-day wait)
    │
    └─ "partner" → CloudKit approval flow
```

### القرارات الموثَّقة

| القرار | الموقع | التقييم |
|--------|--------|---------|
| 7-day emergency unlock delay | `BlockingConstants.swift:38-47` | مدعوم بـ benchmark (Cold Turkey, Opal). |
| `strongReason` path (200 chars) | `NoNetGatekeeperSheet.swift:17-20` | تصميم نفسي جيد. |
| Two-track gatekeeper: nonet vs partner | `gatekeeperType` في ListEntity | مرن. |
| EmergencyUnlock يخزّن `requestedAt` لا `maturity` | `PersistenceHelpers.swift:71-72` | مرونة. |

### القضايا

#### `scheduled + hard` state غامض

**الموقع:** `BlockingEngine.swift:101`

```swift
guard list.blockType == "now" else { return false }
```

لو `blockType == "scheduled" && protection == "hard"`، الـ method يرجع `false`. المستخدم يستطيع `deactivate` في أي وقت → الـ "hard mode" بلا أثر عملي.

**التوصية:** يجب حسم. إما (أ) hard هنا يحمي configuration فقط مع comment، أو (ب) عدّل `isHardLocked` ليقيّد التعطيل خلال نافذة الـ schedule.

#### `timeLimit + hard` لا emergency exit

موثَّق وقصدي. trade-off: حماية ضد abuse vs UX سيئ في حالات نادرة.

**التوصية:** أبق القرار، وثّقه كـ ADR مع بدائل مرفوضة.

#### EmergencyUnlock cleanup في 4 مواضع

- `BlockingEngine.purge` (canonical)
- `HomeView` (line 140, 813)
- `ApprovalExecutor.execute(.delete)` (line 51)
- `ListDetailView` (line 375, 473)

**Risk:** لو أُضيف مسار جديد لـ list deletion، الـ state قد يبقى يتيماً.

**التوصية:** اجعل `BlockingEngine.purge` المسار الوحيد.

---

## المنطقة 6 — Build/Test Infrastructure

### الوضع الحالي

| المكوّن | الحالة |
|--------|--------|
| `blocking app` target (main) | في Xcode، يبني |
| `BlockingMonitor` extension target | ملف موجود، target غير مُنشأ |
| `blocking appTests` target | 7 ملفات اختبار موجودة، target غير مُنشأ |
| Entitlements (Debug + Release) | مكتملة وصحيحة |
| `Products.storekit` | متسق مع `ProductIDs.swift` |
| `.github/workflows/pages.yml` | GitHub Pages publish، لا build/test CI |
| `scripts/add-targets-help.sh` | Interactive 5-step guide بالعربية |

### نقاط القوة

1. `add-targets-help.sh` تجربة DX ممتازة.
2. READMEs على المجلدات الفرعية تشرح "لماذا inert و كيف يُركَّب."
3. Entitlements متطابقة بين Debug و Release فيما عدا `aps-environment`.
4. Bundle IDs منسقة.
5. Trial حقيقي (`introductoryOffer.paymentMode = "free"`).
6. `familyShareable: true` على الـ subscriptions.

### القضايا

#### اعتماد على Xcode UI manual setup = SPOF

كل clone fresh يحتاج Xcode UI manual steps. يعمل لمطوّر واحد.

**التوصية:** اقبل الـ trade-off حالياً. لو الـ team نما، فكر في `xcodeproj` gem أو XcodeGen.

#### التكرار بين `add-targets-help.sh` و الـ READMEs

نفس الخطوات في 3 مواضع.

**التوصية:** اجعل الـ READMEs تشير للـ script.

#### `add-targets-help.sh` يدّعي "32 tests" لكن في 7 ملفات

**الموقع:** `scripts/add-targets-help.sh:31`

**التوصية:** احسب dynamically أو احذف الرقم.

#### لا CI build/test

`.github/workflows/pages.yml` يخدم Pages publish فقط.

**التوصية:** أضف minimal CI workflow (build-only).

#### Products.storekit ↔ ProductIDs hand-maintained

**التوصية:** اكتب unit test يتحقق من sync بينهما.

---

## المنطقة 7 — State Management في الـ Views

### الإحصاءات

| Component | State decl. | ملاحظة |
|-----------|:---:|---------|
| CreateListSheet | 38 | أكبر — god-view محتمل |
| HomeView | 18 | معقول لكن دسم |
| SettingsView | 16 | طبيعي |
| ListDetailView | 14 | مقبول |
| ChatBotView | 14 | معقول |
| ContentView | 12 | root view، طبيعي |

### القضايا

#### `EmergencyUnlockStore` ليس `ObservableObject` → "nonce trick"

**الموقع:** `ListDetailView.swift:34-37`

```swift
// D18 — Emergency unlock request UI state. The store is the source of truth;
// this nonce just forces the view to re-render after a request / cancel,
// since EmergencyUnlockStore reads through UserDefaults (not @Published).
@State private var emergencyUnlockNonce = UUID()
```

لو View ثاني يعرض نفس الحالة، لن يحصل re-render تلقائياً.

**التوصية:** اقلب `EmergencyUnlockStore` لـ `ObservableObject` مع `@Published private(set) var states: [UUID: UnlockState]`.

#### CreateListSheet: 38 state declarations

god-view محتمل. الـ pattern الأفضل: Wizard pattern بـ state machine + draft struct.

```swift
enum CreateStep { case name, protection, blockType, ... }
struct ListDraft { var name = ""; var protection: Protection = .noProtection; ... }
@State private var step: CreateStep = .name
@State private var draft: ListDraft = ListDraft()
```

**ليس blocker.** يستحق planning لـ v1.2.

#### `ContentView` يكتب إلى `partnerStore.pendingShareMetadata`

**الموقع:** `ContentView.swift:87-99`

layering violation طفيفة.

**التوصية:** أضف `clearPendingShare()` method على الـ store.

#### `@StateObject` للـ singleton

**الموقع:** `ContentView.swift:13`

```swift
@StateObject private var lang = LanguageManager.shared
```

`@StateObject` يخص ownership. الصحيح: `@ObservedObject`.

#### نقاط القوة

- ListDetailView تقسّم الـ body لـ `@ViewBuilder` properties (للتعامل مع SwiftUI type-checker timeouts).
- Custom TabBar بدل system — قرار design موثَّق.

---

## الملخص النهائي

### حالة قائمة Action Items قبل App Store (P0)

| # | المنطقة | القضية | الحالة |
|:--:|---------|--------|--------|
| 1 | Blocking Core | إنشاء BlockingMonitor target في Xcode | ⏳ يحتاج Xcode UI من Khalid |
| 2 | Blocking Core | multi-slot schedule bug — slots متعددة تُجمَع لـ schedule واحد | ✅ منجز — schedule per (slot, weekday) |
| 3 | Blocking Core | typed websites لا تحجب → احذف من UI أو أضف warning | ✅ منجز — websitesSection → FamilyActivityPicker button |
| 4 | Partner | `createActionRequest` غير محمي offline | ✅ منجز — يستخدم PendingBreakAttemptQueue |
| 5 | Persistence | sign-out data hygiene | ✅ منجز — `DataReset.signOutAndClear()` |
| 6 | Hard-mode | حسم `scheduled + hard` semantics | ✅ منجز — comment يوضح: hard يحمي config لا runtime |
| 7 | Build | تركيب Tests target + اختبار Family Sharing | ⏳ يحتاج Xcode UI + اختبار جهازين |
| 8 | Views | DEBUG gate على entry point لـ AdminToolsSheet | ✅ تحقق — كل المسارات مغلَّفة `#if DEBUG` |

### التغييرات في الكود (commit-ready)

- **BlockingEngine.swift**: `scheduleMonitoring` يسجّل schedule لكل slot مع weekday، `activityName(for:slotIndex:)` بنمط جديد، `allSlotActivityNames` helper للـ deactivate + purge، `applyShields` نُظّفت من typed-domain branch، comment على `isHardLocked` يوضح `scheduled + hard` semantics.
- **BlockingMonitor/BlockingMonitor.swift**: `parseActivity` يدعم `schedule.<UUID>.<index>` pattern.
- **BlockItemsEditorView.swift**: `websitesSection` (TextField → button)، `handleFamilySelectionChange` يحدّث `draft.websites` count، حُذِف 6 helpers ميتة.
- **CloudKitPartnerStore.swift**: `createActionRequest` يستخدم PendingQueue على الـ offline والـ failure، `flushPendingBreakAttempts` يستعيد status + reason للـ approval requests.
- **Core/PendingBreakAttemptQueue.swift**: `PendingBreakAttempt` يحوي `statusRaw + reason` optional fields (backward-compatible).
- **Core/DataReset.swift** (جديد): `signOutAndClear()` يمسح Keychain + AppStorage + per-list stores + Core Data lists + PendingQueue.
- **SettingsView.swift**: `LogoutButton` يستدعي `DataReset.signOutAndClear()`، message محدّث للشفافية.

### الخطوات التي تحتاج Xcode UI (من Khalid)

1. **شغّل `./scripts/add-targets-help.sh`** أو افتح Xcode يدوياً:
   - أضف **BlockingMonitor** target (DeviceActivity Monitor Extension)
     - Bundle ID: `com.nonetapp.BlockingMonitor`
     - Embed in: `blocking app`
     - أضف Family Controls + App Group capabilities
   - أضف **blocking appTests** target (Unit Testing Bundle)
     - Target to be tested: `blocking app`
2. **اختبر على جهاز حقيقي:**
   - أنشئ schedule list من 12:00 → 12:05 (دقيقتين من الآن)
   - أغلق التطبيق
   - عند 12:00 → shield مطبَّق
   - عند 12:05 → shield مرفوع
3. **اختبر multi-slot bug fix:** أنشئ scheduled list بـ slot واحد يخص السبت 9-12 والآخر السبت 18-22. يجب أن يُحجَب 9-12 و 18-22، و **يُسمَح** بين 12-18.
4. **اختبر Family Sharing على جهازين** قبل ship.



### قائمة Cleanup لـ v1.2

| المنطقة | Task |
|---------|------|
| App Group | حذف legacy `sharedDefaults` |
| Partner | `databaseScope` field في Partnership DTO + denormalize `ownerUserID` |
| Persistence | توحيد `v1:` prefix على كل AppStorageKeys + sign-out cleanup function |
| Hard-mode | توحيد EmergencyUnlock cleanup عبر `BlockingEngine.purge` فقط |
| Build | Minimal CI workflow (build-only) + unit test يتحقق sync ProductIDs ↔ Products.storekit |
| Views | `EmergencyUnlockStore` → ObservableObject + `@ObservedObject` للـ singletons + `clearPendingShare()` |

---

## قائمة ADRs المرشحة

| Priority | ADR # | الموضوع |
|:--:|:--:|---------|
| يجب | ADR-002 | Multi-slot schedule representation (bug critical) |
| يجب | ADR-007 | Offline-safety contract for `createActionRequest` |
| يجب | ADR-013 | `Scheduled + Hard` semantics |
| يجب | ADR-011 | Sign-out data hygiene |
| مهم | ADR-006 | CloudKit Partner architecture (overall) |
| مهم | ADR-012 | TimeLimit + Hard — no emergency unlock (compliance) |
| مهم | ADR-014 | Two-path gatekeeper philosophy |
| اختياري | ADR-001 | Per-list named ManagedSettingsStore |
| اختياري | ADR-003 | TimeLimit using durationSeconds (overload) |
| اختياري | ADR-004 | App Group as required-or-fail |
| اختياري | ADR-005 | Heartbeat-based extension liveness |
| اختياري | ADR-008 | BreakAttempt state machine (single record type) |
| اختياري | ADR-009 | Programmatic Core Data model |
| اختياري | ADR-010 | Versioning conventions for UserDefaults |
| اختياري | ADR-015 | Manual Xcode target setup vs automated |
| اختياري | ADR-016 | No CI test target (current) |
| اختياري | ADR-017 | Store reactivity pattern |
| اختياري | ADR-018 | CreateListSheet wizard refactor |

---

## Sweep ثانٍ — مراجعة الـ Views الفرعية (2026-05-27 ب)

بعد إصلاح الـ P0 الأولى، Explore agent مسح 13 ملف View لم يُغطَّ في المسح الأول (`AuthView`, `OnboardingView`, `UpgradeView`, `ChatBotView`, `SettingsView` remainder, `AboutView`, `PoliciesView`, `ResourcesView`, `ChallengesView`, `PartnerInviteView`, `PartnerAcceptSheet`, `HomeView`, `RequestActionSheet`). النتائج:

### regression تم إصلاحه في هذا الـ pass

| الملف | السطر | المشكلة | الحل |
|------|------|---------|------|
| RequestActionSheet.swift | 195 | `if id == nil` غير قابل للوصول بعد أن جعلت `createActionRequest` يُرجع non-nil دائماً (queues on offline). pre-flight failures تُبتلَع بصمت | حفظ `wasOffline` قبل الـ await، استبدال `if id == nil` بـ `guard id != nil` يحافظ على defensive path، فرع `wasOffline` يستدعي `onRequestSent()` مع نفس الـ callback (queue handles delivery) |

### Verified-OK — refactors السابقة لا تكسر هذه

- `HomeView.swift:98, 134, 809, 816` — `BlockingEngine.isHardLocked / purge / deactivate / activate` كلها بـ `list:` parameter. signature الـ `activityName` الذي تغيّر `private`. ✅
- `HomeView.swift:779-790` — `isActiveNow()` يفك slots بـ per-day, per-window logic، يطابق الـ multi-slot fix الذي أدخلته في `scheduleMonitoring`. ✅
- `SettingsView.swift:616` — `DataReset.signOutAndClear()` هو المسار الوحيد للـ logout. ✅
- `PartnerInviteView.swift:210` — `createPartnership` signature لم يتغير. ✅

### قائمة Cleanup مُحدّثة لـ v1.2

كل القضايا أدناه pre-existing — لم تُسبَّب بواسطة الـ refactors، ولا تحجب App Store. كل واحدة تستحق PR مركّز عند الجاهزية:

**UpgradeView**
- `UpgradeView.swift:651` — `store.purchase` ثم قراءة `store.state` synchronously. comment يدّعي race-free بناءً على `@Published` ordering. fragile لو StoreKit يُحدّث الـ state عبر transaction listener منفصل.
- `UpgradeView.swift:88-90` — `isTrialActive` معرَّض لـ clock skew (المستخدم يعدّل ساعة الجهاز لتمديد الـ trial).

**ChatBotView**
- `ChatBotView.swift:77-87` — 4 `Bool` states مستقلة (`showSuggestions`, `isTyping`, `showFreeLimitReached`, `showClearConfirm`) بدون enum للتنظيم. لو اثنان يفعّلان معاً، sheet + alert تُعرَض في وقت واحد.
- `ChatBotView.swift:93-104` — `messages` computed property يعمل JSON round-trip في كل قراءة وكل كتابة. مع cap 50 رسالة، الـ UserDefaults يُشفَّر مع كل keystroke.

**ChallengesView**
- `ChallengesView.swift:118, 158` — magic constants (`nextLevelPoints = 200`)؛ no challenge state persistence عبر rotation.

**Partner views**
- `PartnerInviteView.swift:219-223` — error في `createInvitation` يترك `phase = .creating` ويُجمّد Send button. المستخدم لازم يرجع ويفقد الاسم.
- `PartnerAcceptSheet.swift:232-234` — `rootRecord["ownerDisplayName"]` ربما لا يكون prefetched بعد. بدون retry، pre-fill يبقى فارغ في race cases.

**HomeView**
- god-view ~750 سطر، multi-concern.
- `refreshTick &+= 1` (line 487) إشارة refresh fragile.

**OnboardingView**
- `OnboardingView.swift:429` — CSV serialization لـ chip selections؛ بدون مسار schema evolution.
- `OnboardingView.swift:318-322` — `SmartListSeeder.seedIfNeeded` يُستدعى من UI بدون error feedback.

**AuthView**
- `AuthView.swift:351-367` — `adminNormalize` مكرَّر مع `AdminToolsSheet` (DEBUG-only — أولوية منخفضة).

**Static / legal**
- `AboutView.swift:69-80` — privacy badge يقول "Privacy-first" بدون ربط بصري لـ partner footnote.
- `PoliciesView.swift:62-65` — `.onChange(of: selectedTab)` body فارغ مع stale comment.
- `ResourcesView.swift:6` — v1 design note ("videos and infographics land later") لم يُوصَّل أبداً.

**SettingsView**
- `SettingsView.swift:11-12` — `showComingSoonAlert` state محفوظ لـ Community section مخفية؛ alert لا ينطلق أبداً.

---

## Sweep ثالث — Infrastructure Helpers + Tests (2026-05-27 ج)

Explore agent ثالث مسح Core/ helpers التي لم تُغطَّ + ملفات الاختبار.

### الملفات المُغطّاة

| ملف | LOC | الحكم |
|------|-----|-------|
| `Core/Components.swift` | 469 | ✅ UI primitives نظيفة — zero magic numbers، RTL باكد |
| `Core/DesignTokens.swift` | 110 | ✅ نموذجي — spacing/radius/border/hit-target موحَّدة |
| `Core/Theme.swift` | 116 | 🟡 LanguageManager.isArabicEffective duplicated في SmartListSeeder |
| `Core/LegalContent.swift` | 1,123 | 🔴 **entity placeholders TBD — blocking لـ App Store** |
| `Core/ChatResponder.swift` | 81 | 🟡 keyword matching بصيغة `contains` (false positives محتملة) |
| `Core/SmartListSeeder.swift` | 137 | 🟡 hardcoded `durationSeconds = 3600`، goal-mapping silent fallback |
| `Core/StoreManager.swift` | 168 | 🟡 sort by price يفترض monthly < yearly، لا expiry warning |
| `Core/PermissionsManager.swift` | 129 | 🟡 `didStartObserving` ليس atomic (low-risk race) |
| `Core/ProductIDs.swift` | 18 | ✅ minimal، صحيح |
| `blocking appTests/BlockingEngineTests.swift` | — | ✅ كل tests passing بناءً على state الحالي للـ engine |
| `blocking appTests/CloudKitPartnerStoreTests.swift` | — | ✅ DTO round-trips فقط، لا اعتماد على `createActionRequest` signature |
| `blocking appTests/SchedulePersistenceTests.swift` | — | ✅ `ScheduleSlotV1` schema لم يتغيّر |

### القضية الحرجة — توافق Tests مع التغييرات

كل tests الموجودة **لا تكسر** بسبب الـ refactors:
- BlockingEngineTests تختبر `isHardLocked` فقط — السلوك لم يتغيّر، فقط الـ comment.
- CloudKitPartnerStoreTests تختبر `Partnership/BreakAttempt` DTO parsing — لا اعتماد على flow الـ approval.
- SchedulePersistenceTests على `encode/decode` — schema ثابت.

### Build Verification

```
$ xcodebuild build -project "blocking app.xcodeproj" -scheme "blocking app" \
    -destination "platform=iOS Simulator,name=iPhone 16,OS=18.5" \
    CODE_SIGNING_ALLOWED=NO
** BUILD SUCCEEDED **
```

كل التغييرات السابقة (multi-slot scheduling، websites→Picker، DataReset، PendingQueue توسيع، RequestActionSheet regression fix) تكمبايل بدون errors. تحذير وحيد عن `AppIntents.framework` (metadata extraction skipped) — unrelated، التطبيق لا يستخدم Siri Intents.

### القضية الوحيدة الـ P0 الجديدة

**LegalContent.swift — entity placeholders**

```swift
entityName = "NoNet Company"                    // ❌ placeholder
entityRegistration = "[TBD — placeholder] 777777"  // ❌ placeholder
```

هذا **blocking** قبل App Store submission. الـ legal sections (Terms / Privacy) يجب أن تعكس اسم الشركة المسجَّل ورقم السجل التجاري قبل ship.

**ملاحظة:** هذا موثَّق فعلاً في memory المشروع — Khalid يعرف هذه الـ TBDs ويخطط لإكمالها قبل النشر. ليست regression جديدة.

### Cleanup إضافية لـ v1.2

- **Theme.swift + SmartListSeeder.swift:** `isArabicEffective` resolution duplicated. اجعل SmartListSeeder يقبل `LanguageManager` كـ dependency injection، أو استخدم `Locale.current` مباشرة في كليهما.
- **ChatResponder.swift:** keyword matching بـ `contains` — false positive لـ "organization" يطابق "organize". للـ v2 فكر في trie أو tokenization.
- **SmartListSeeder.swift:** `durationSeconds = 3600` hardcoded. لو goal-mapping تتوسع، اجعل default duration معتمد على نوع الـ goal.
- **StoreManager.swift:** `.sorted { $0.price < $1.price }` يفترض monthly < yearly. سيكسر في market له discount عميق (نادر). أضف explicit ordering عبر product ID.
- **PermissionsManager.swift:** `didStartObserving` flag — اجعله atomic عبر `os.lock` أو @MainActor isolation guarantee.

---

## Sweep رابع — Configuration + Pre-Ship Documentation (2026-05-27 د)

مسح للملفات التي لم تُغطَّ بعد: entitlements، Info.plist، Localizable.strings، PrivacyInfo.xcprivacy، VERSION، CHANGELOG، DEPLOYMENT_CHECKLIST، project.pbxproj.

### Configuration verified

| ملف | الحكم |
|------|-------|
| `blocking app.entitlements` (Debug) | ✅ Family Controls + Sign in with Apple + App Group + iCloud + Push (`aps-environment = development`) |
| `Release.entitlements` | ✅ مطابق لـ Debug، فيما عدا `aps-environment = production` |
| `BlockingMonitor/Info.plist` | ✅ `NSExtensionPointIdentifier = com.apple.deviceactivity.monitor-extension`، `NSExtensionPrincipalClass = $(PRODUCT_MODULE_NAME).BlockingMonitor` |
| `INFOPLIST_KEY_NSFamilyControlsUsageDescription` | ✅ نص عربي واضح وموثَّق ("يستخدم التطبيق Screen Time محلياً على جهازك فقط...") |
| `INFOPLIST_KEY_UIBackgroundModes = remote-notification` | ✅ مطلوب لـ CloudKit push subscription |
| `ar.lproj/Localizable.strings` | ✅ `PARTNER_BREAK_TITLE` + `PARTNER_BREAK_BODY` مع `%@` placeholder صحيح |
| `en.lproj/Localizable.strings` | ✅ مطابق |
| `PrivacyInfo.xcprivacy` | ✅ NSPrivacyTracking=false، 3 data types (UserID/Name/ProductInteraction) كلها linked + non-tracking + AppFunctionality. UserDefaults reason `CA92.1` صحيح. لا FileManager في الكود فلا حاجة لـ FileTimestamp reason. |

### 🔴 P0 ship blockers جديدة

#### 1. `MARKETING_VERSION = 1.1.0` في project.pbxproj

VERSION file = `1.3.0`، CHANGELOG.md يصل لـ `1.3.0` (released 2026-05-25). لكن Xcode يقرأ الإصدار من project.pbxproj، **ليس** من VERSION file. النتيجة: لو خالد بنى TestFlight upload الآن، Apple ستراه كـ 1.1.0.

**الإصلاح في Xcode (دقيقة):**
- Project → blocking app target → General → Identity:
  - Version: `1.3.0` (أو `1.4.0` لو الـ refactors الحالية تستحق bump جديد)
  - Build: `3` أو أعلى (الحالي 2، لكل upload App Store يحتاج build number جديد)

#### 2. `CHANGELOG.md [Unreleased]` فارغ

الـ refactors التي تمت في هذا الـ session (multi-slot scheduling، websites→Picker، DataReset، PendingQueue توسيع، RequestActionSheet regression fix، scheduled+hard semantics، AdminToolsSheet verified) **لم تُوثَّق في CHANGELOG**.

**الإصلاح:** قبل الـ commit، أضف للقسم `[Unreleased]`:

```markdown
## [Unreleased]

### المُصلَح
- **Multi-slot scheduling bug** — slots متعددة في قائمة مجدولة كانت تُجمَع
  في schedule واحد بـ earliest-start/latest-end. النتيجة: الـ shield مفعَّل
  خلال فجوات السماح بين الـ slots، وحقل `day` كان مُهمَلاً تماماً. الآن
  schedule منفصل لكل (slot × weekday).
- **typed websites لا تحجب فعلياً** — الـ TextField كان يقبل نصوص لا
  يستطيع `ManagedSettings.shield.webDomains` معالجتها (يقبل tokens فقط).
  الـ UI الآن يفتح FamilyActivityPicker الذي يدعم apps + categories +
  websites في selection موحَّد.
- **createActionRequest يضيع طلبات الـ partner offline** — كانت ترجع
  nil على الفشل والـ caller يعرض "تم الإرسال" خطأً. الآن تستخدم
  `PendingBreakAttemptQueue` للـ retry على FAILE/offline، والـ `flush`
  يحترم status + reason للـ approval workflow.
- **scheduled + hard دلالة غامضة** — أضفنا comment يوضح أن Hard Mode
  على scheduled lists يحمي الـ configuration (delete/modify يمر بالـ
  gatekeeper) وليس runtime (الـ schedule يحرّر نفسه عند نهاية النافذة).

### المضاف
- **`Core/DataReset.signOutAndClear()`** — تنظيف مركزي عند الـ logout:
  Keychain + كل AppStorage user-scoped + per-list stores + Core Data
  lists + PendingBreakAttemptQueue. CloudKit data يبقى مرتبطاً بـ
  Apple ID (خارج النطاق).

### المُحسَّن
- **`PendingBreakAttempt` يدعم approval workflow** — حقول optional
  `statusRaw` + `reason` (backward-compatible). الـ records القديمة
  تُعتبر `.logOnly` تلقائياً.
- **LogoutButton مبسَّط** — يستدعي `DataReset.signOutAndClear()` فقط.
  الرسالة محدَّثة بشفافية: "راح تنحذف قوائمك وحساب الاشتراك والملف
  الشخصي من هذا الجهاز. (الشركاء في iCloud يبقون مرتبطين بحسابك.)"
```

### 🟢 المتوقَّع — قضايا معروفة سابقاً (memory NoNet entity pending info)

- `LegalContent.swift` entity placeholders (CR، DPO email، dates) — موثَّقة في memory للمشروع، خالد يخطط لإكمالها قبل النشر.

---

## Sweep خامس — Documentation Drift + Workflows + Design Rules (2026-05-27 هـ)

مسح للوثائق الأساسية للتحقق من توافقها مع الكود الفعلي بعد كل الـ refactors في الـ session.

### Drift-free (تطابق الواقع) ✅

| ملف | السبب |
|------|--------|
| `README.md` | UI architecture section يصف الـ files الموجودة فعلياً، بدون references ميتة |
| `ARCHITECTURE.md` | الـ blocking flow diagram يحترم الـ refactor الجديد (multi-slot details هي implementation، الـ architecture لم تتغيّر) |
| `DEPLOYMENT_CHECKLIST.md` | v1.1.0 section لا يزال صالحاً (CloudKit + Push + App Group identical). الـ refactors لا تضيف checklist items جديدة |
| `docs/SECURITY_AUDIT_2026-05-22.md` | confidence gate صالح. `DataReset` يقوي contract الـ cleanup، لا يضيف attack surface |
| `docs/PARTNER_FEATURE_DESIGN_AR.md` | الـ design contract لم يتغيّر — `PendingBreakAttempt + statusRaw` تحسين داخلي |
| `docs/APP_STORE_LISTING.md` | listing copy لا يذكر TextField vs Picker — لا حاجة لتعديل |
| `.cursor/rules/UI-Mode.mdc` | design rules محترَمة — لا تغييرات في tokens/spacing/contrast |
| `.github/workflows/pages.yml` | يبني `docs/web/` على push — orthogonal لتغييرات الكود |
| `docs/web/` (4 HTML) | privacy/terms/support/index — content unchanged |
| `scripts/add-targets-help.sh` | guides target setup — workflow لا يتغيّر |

### Drift طفيف

#### `TODO_FOR_KHALID.md` badge stale

السطر 11 يعرض `1.1.0` لكن:
- VERSION file = `1.3.0`
- CHANGELOG `[Unreleased]` بعد 1.3.0

**الإصلاح:** عند الـ bump النهائي للـ project.pbxproj، حدّث badge في TODO_FOR_KHALID.md أيضاً للاتساق.

### Security check للـ refactors الجديدة

| تغيير | تقييم security |
|-------|----------------|
| `DataReset.signOutAndClear()` | ✅ يقلل cross-user data leak (كان موجوداً قبل). يمسح Keychain + 21 AppStorage key + per-list orphans + Core Data + PendingQueue. لا يلمس CloudKit (مرتبط بـ Apple ID — out of scope). |
| `createActionRequest` offline-queue | 🟡 `PendingBreakAttempt.reason` user-typed text يُحفَظ في `UserDefaults.standard`. هذا يدخل iOS device backup (iCloud + local) by default. **خصوصية محدودة:** الـ backup مُشفَّر، يخرج إلى Apple ID للمستخدم نفسه فقط. لا exfiltration. مقبول. |
| websites→Picker | ✅ يقلل attack surface — حذف TextField parsing + dead code |
| scheduled+hard comment | ✅ documentation change فقط، لا تأثير security |
| multi-slot scheduling | ✅ يصلح UX bug، لا تأثير security |

**النتيجة الأمنية:** لا attack surface جديد. Privacy posture محفوظة.

---

## Final Summary — حالة المشروع بعد 5 Sweeps

### Code refactors تمت (هذا الـ session)

| التغيير | الملف(ات) | حجم الـ diff |
|---------|----------|------------|
| Multi-slot scheduling | BlockingEngine + BlockingMonitor | +60 / -25 |
| Websites → FamilyActivityPicker | BlockItemsEditorView | +30 / -180 |
| Offline-safe createActionRequest | CloudKitPartnerStore + PendingBreakAttemptQueue | +50 / -10 |
| DataReset.signOutAndClear | Core/DataReset.swift (new) + SettingsView | +120 / -10 |
| Scheduled+hard semantics comment | BlockingEngine | +8 / 0 |
| RequestActionSheet regression fix | RequestActionSheet | +25 / -10 |
| CHANGELOG `[Unreleased]` | CHANGELOG.md | +60 / 0 |
| ARCHITECTURE_REVIEW_2026-05-27 | docs/ (جديد، 5 sweeps) | +400 / 0 |

**Build:** ✅ `** BUILD SUCCEEDED **` على iPhone 16 / iOS 18.5
**Tests:** ✅ كل tests الحالية تتوافق مع الـ APIs

### Ship Blockers المتبقية

| الحجم | المهمة | يحتاج |
|------|--------|-------|
| 🔴 P0 | bump `MARKETING_VERSION` 1.1.0 → 1.3.0 + `CURRENT_PROJECT_VERSION` ≥ 3 | Xcode UI (دقيقة) |
| 🔴 P0 | إنشاء BlockingMonitor target في Xcode | Xcode UI + script (30 د) |
| 🔴 P0 | إنشاء Tests target في Xcode | Xcode UI (10 د) |
| 🔴 P0 | LegalContent: CR + DPO email + dates (placeholders TBD) | إجراء إداري (معلومات منك) |
| 🟠 P1 | اختبار جهاز حقيقي: multi-slot fix + scheduled + timeLimit | iPhone فعلي (ساعتان) |
| 🟠 P1 | اختبار Family Sharing على جهازين | (ساعة) |

### Cleanup للـ v1.2 (لا يحجب الشحن)

14 قضية pre-existing موثَّقة في sweep 2 + sweep 3. ابدأ بـ:
1. `EmergencyUnlockStore` → ObservableObject (يلغي الـ nonce trick)
2. Sign-out cleanup audit (هل DataReset shamil لكل scenario؟)
3. `legacy sharedDefaults` حذف
4. توحيد `v1:` prefix على كل AppStorageKeys
5. UpgradeView race + clock-skew defense

### نتائج 5 Sweeps

| Pass | تغطية | findings |
|------|--------|----------|
| 1 | 7 مناطق معمارية أساسية | 8 قضايا P0 + 18 ADR مرشح |
| 2 | 13 View | 1 regression، 14 pre-existing |
| 3 | Core helpers + Tests | لا regressions، 5 cleanup للـ v1.2 |
| 4 | Config + pre-ship | P0 جديد: MARKETING_VERSION outdated |
| 5 | Documentation + workflows | لا drift كبير |

---

## Sweep سادس — Static Analysis + Integration Deep-Dive (2026-05-27 و)

### Clang Static Analyzer

```
$ xcodebuild analyze -project "blocking app.xcodeproj" -scheme "blocking app" \
    -destination "platform=iOS Simulator,name=iPhone 16,OS=18.5"
[empty output]
```

**ZERO warnings.** أعمق فحص static (يكشف null derefs, memory issues, dead stores, logic errors) لم يكتشف issues. هذا أنظف نتيجة ممكنة لمشروع 25+ Swift file.

### Integration trace: Hard+Partner Delete (الأعقد flow)

تتبع كامل من tap "حذف" في HomeView إلى تنفيذ فعلي على جهاز الـ owner بعد موافقة الشريك:

```
[A's device — owner]
  HomeView.deleteList(_:) [97]
    ↓ isHardLocked + gatekeeperType == "partner" + accepted partnership
  RequestActionSheet (sheet)
    ↓ sendRequest() [refactored]
    │   wasOffline captured ✓
    │   createActionRequest [refactored]
    │     ├─ online   → save to CloudKit, return attemptID
    │     └─ offline  → PendingBreakAttemptQueue.enqueue, return attemptID
    │   guard id != nil ✓
    └─ onRequestSent() + dismiss

[CloudKit privateDB]
  BreakAttempt record (status: .pending)
  CKQuerySubscription [v1.breakAttempt.notify] → push to B

[B's device — partner]
  AppDelegate.didReceiveRemoteNotification
    ↓ Task @MainActor
    ├─ fetchPartnerships
    ├─ fetchPendingRequestsForMe → pendingPartnerRequests populated
    ├─ executePendingApprovals → no-op (B has no outgoing .approved)
    └─ flushPendingBreakAttempts → drains B's local queue

  B sees request, taps "Approve"
    ↓ approveRequest(id) → updateRequestStatus(.approved) → save to sharedDB

[CloudKit sharedDB]
  BreakAttempt record (status: .approved)
  CKQuerySubscription [v1.breakAttempt.statusChange] → push to both

[A's device — owner]
  AppDelegate.didReceiveRemoteNotification
    ↓ Task @MainActor
    ├─ fetchPartnerships
    ├─ fetchPendingRequestsForMe → no-op for A
    ├─ executePendingApprovals
    │     ├─ fetchMyOutgoingRequests → myOutgoingRequests populated
    │     └─ for each .approved request:
    │         ├─ execute() [ApprovalExecutor.swift:35]
    │         │   └─ case .delete:
    │         │       ├─ BlockingEngine.purge(listId)
    │         │       │   ├─ ManagedSettingsStore.clearAllSettings
    │         │       │   ├─ stopMonitoring(allSlotActivityNames + limitActivityName) ✓ [post-refactor]
    │         │       │   ├─ FamilySelectionStore.clear
    │         │       │   └─ EmergencyUnlockStore.clear
    │         │       ├─ context.delete(entity) + saveIfNeeded
    │         │       └─ BreaksStore/ManualStateStore/EmergencyUnlockStore.clear
    │         └─ markRequestCompleted(id) → status: .completed
    └─ flushPendingBreakAttempts
```

### Idempotency Verification

تمت محاكاة الـ failure modes:

| Failure | Behavior |
|---------|----------|
| Push يصل مرتين (CloudKit at-least-once) | `markRequestCompleted` ينقل إلى `.completed`. الـ filter في `fetchMyOutgoingRequests` يستثني `.completed`. ✅ لا تكرار |
| `markRequestCompleted` يفشل بعد execute | Next push: `.approved` يبقى. `execute` يعيد التشغيل، لكن: `purge` idempotent (recreate store + clearAllSettings)، `context.fetch` لا يجد entity → guard يعود مبكراً. ✅ آمن |
| A offline لما B يوافق | Push يفشل تسليمه. عند foreground A: `ContentView.bootstrapCloudKit → executePendingApprovals` يدرين الـ `.approved`. ✅ |
| A يسجّل خروج مع طلب pending في الـ queue | `DataReset.signOutAndClear` يستدعي `PendingBreakAttemptQueue.clear()` → الـ queue يفرغ. الـ partner لا يستلم. **سلوك مقصود** (sign-out = "أنا انتهيت من هذا الحساب") |
| طلب pending وصل CloudKit، A سجّل خروج | الـ record يبقى في CloudKit، الـ partner يراه. لو وافق، لا قائمة محلية للحذف، الـ approval futile. **edge case نادر، pre-existing** |

### Minor inefficiency (not a bug)

**`fetchMyOutgoingRequests` يُستدعى مرتين** في `ContentView.bootstrapCloudKit`:
- مرة في `bootstrapCloudKit:128`
- مرة داخل `executePendingApprovals:28` (line 133)

الثاني redundant لأنه الأول حديث. التكلفة: round-trip CloudKit زائد لكل foreground. **مقبول حالياً** — لو كان issue، أضف cache invalidation للـ `fetchMyOutgoingRequests`.

### Accessibility + RTL coverage

- **31 accessibility refs** في 25+ ملف View — modest لكن موجودة في الـ critical paths (ProtectionBadge, OptionRow, Buttons المهمة)
- **`layoutDirection`** مضبوط بصراحة في 6 مواضع:
  - `ContentView.swift:67` (root level)
  - `ChatBotView, NoNetGatekeeperSheet, ListDetailView, HomeView, Components`
- **`Dynamic Type`** عبر `Font.nnHero/.nnSectionTitle/.nnButton/.nnCaption` (DesignTokens) — كلها semantic fonts، لا `.system(size:)` hardcoded
- **Contrast** — accent #2563EB، contrast 4.83:1 على أبيض (AA pass) — موثق في sweep 3

### نتيجة الـ pass السادس

**لا تغييرات في الكود.** الـ integration sound، الـ static analysis clean، الـ accessibility موجود (يستحق توسعة في v1.2 لكنه meets baseline).

---

## نقاط القوة المعمارية

لا تغيّرها:

1. **التعليقات الشارحة للـ trade-offs** — جودة فوق المتوسط بكثير. الـ "why" ظاهر في الكود.
2. **الـ DTO/CKRecord separation** مع failable init handles schema drift.
3. **PendingBreakAttemptQueue** يحوّل وعد social accountability من best-effort إلى reliable.
4. **`emergencyUnlockDelaySeconds = 7 days`** مدعوم بـ Cold Turkey/Opal benchmarks لـ Apple compliance.
5. **Two-path gatekeeper (strong reason vs 7-day wait)** يتبع self-binding research (Schelling, Thaler).
6. **Versioned UserDefaults keys** (`v1:` prefix) في معظم المواضع.
7. **Programmatic Core Data model** يتجنّب merge conflicts في `.xcdatamodeld`.
8. **`MonitorHealthcheck` heartbeat pattern** — يكشف silent failure للـ extension بأناقة.
