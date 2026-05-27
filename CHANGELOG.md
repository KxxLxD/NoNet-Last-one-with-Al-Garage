# Changelog

كل التغييرات البارزة للمشروع موثّقة هنا.

التنسيق مبني على [Keep a Changelog](https://keepachangelog.com/ar/1.0.0/)،
ويتبع المشروع [Semantic Versioning](https://semver.org/lang/ar/).

## [Unreleased]

### المُصلَح (Fixed)

- **ChatResponder kept giving wrong replies on word boundaries** — naïve
  `text.contains(keyword)` matched "organizations" against the stem
  "organization" (false positive) and missed "organizing" against
  "organize" (false negative). Replaced with token-aware matching:
  whitespace + punctuation split, then exact token equality or prefix
  match for stems ≥4 chars. Multi-word keywords still fall back to
  literal contains so phrase triggers ("help me", "7 أيام") still work.
- **ChallengesView lost progress on rotation** — `totalPoints` was a
  plain @State that reset to 0 whenever SwiftUI re-instantiated the view.
  Persisted now under `v1:challenges:totalPoints`. The level-up logic
  also silently zeroed totalPoints at every level boundary, capping
  visible points at perLevel-1 — fixed by deriving `level` from
  `totalPoints / perLevel + 1`.
- **PartnerAcceptSheet pre-fill empty if rootRecord not prefetched** —
  CKShare.Metadata can arrive before CloudKit has pulled the
  rootRecord, leaving the inviter name + suggested partner name blank.
  Added a 1.5s retry that re-pulls the metadata values once the
  record settles. Helper is idempotent — won't clobber a name the
  user already started typing.
- **PartnerInviteView froze on error** — when `createPartnership` threw,
  the sheet's phase stayed at `.creating` (spinner overlay) until the
  user dismissed the error alert. The dismiss button also rolled the
  phase back, but the visual stall remained. Now the catch block rolls
  the phase back immediately, so the alert appears on top of the
  user's editable form, not a stuck spinner.
- **RequestActionSheet error path became unreachable** after
  createActionRequest started queueing offline failures. Captures
  `wasOffline` before the await and keeps a defensive `guard id != nil`
  so genuine pre-flight failures (malformed args) still surface.
- **Free trial extended forever by clock rewind** — `Date()` reading
  *earlier* than the recorded trial-start no longer counts as "trial
  still active". StoreKit's `Transaction.currentEntitlements` was
  always the source of truth for paid Premium, but the trial banner
  used to obey a rewound clock.

### المضاف (Added)

- **`Core/LanguageResolver.swift`** — single source of truth for
  resolving the effective UI language. Replaces a duplicated
  resolution path that lived in both LanguageManager (SwiftUI side)
  and SmartListSeeder (Core/-pure side); previously a tweak to one
  could silently desync the other.
- **`Core/TrialClock.swift`** — centralised trial-elapsed math
  (isTrialActive / daysRemaining / hasTrialExpired) so UpgradeView,
  HomeView, and ContentView don't each implement subtly-different
  arithmetic. Includes the clock-rewind defense above.
- **`Core/AppStorageKeys.challengeTotalPoints`** + a new
  `BlockingConstants.challengePointsPerLevel` (200) — replaces the
  inline magic number in ChallengesView.
- **`Core/BlockingConstants.seederDefaultDurationSeconds`** (3600) —
  replaces the same magic number in SmartListSeeder with rationale
  attached.
- **`Partnership.databaseScope`** + `database(for partnership:)`
  helper — captures the originating CloudKit DB on each Partnership
  DTO at fetch time, so operations route to the right database
  without the previous try-private-then-shared trial pattern.
  revokePartnership uses it directly; remaining call sites
  (updateRequestStatus, fetchMyOutgoingRequests, fetchBreakAttempts)
  are BreakAttempt-level and will be converted in a follow-up.
- **`AdminDigitNormalization`** (DEBUG-only) — consolidates the
  Arabic-Indic / Persian → Latin digit transliteration that was
  duplicated in AuthView and AdminToolsSheet.

### المُحسَّن (Changed)

- **`BlockingEngine.purge` is now the single canonical exit point for
  per-list cleanup.** Previously three call sites (HomeView,
  ListDetailView, ApprovalExecutor) each repeated a stack of
  BreaksStore.clear + ManualStateStore.clear + EmergencyUnlockStore.clear
  after the purge. purge now owns the full contract — shield removal,
  monitoring stop, FamilySelectionStore, EmergencyUnlockStore,
  BreaksStore, ManualStateStore. Adding a new deletion path
  can't accidentally leave orphan UserDefaults entries any more.
- **`EmergencyUnlockStore` is now an `@MainActor ObservableObject`.**
  Was a struct with static methods + UserDefaults reads, which forced
  ListDetailView to maintain a `@State UUID` "nonce" property that
  rotated on every requestUnlock / clear just to force a re-render.
  The nonce churn is gone — views observe @Published requestedAtByID
  directly, and any other view rendering off the store updates in
  the same instant.
- **All `AppStorageKeys` constants now carry the `v1:` schema-version
  prefix.** Pre-v1 installs are migrated on next launch via a new
  rename table in PersistenceMigration. The migrationKey was bumped to
  `v1:migration-done.renames-v2` so installs that ran the old
  (manual/breaks only) migration pick up the new renames.
- **StoreManager.loadProducts orders products by `ProductIDs.all`
  declaration order** instead of ascending price. A promotional
  yearly discount that drops below monthly used to flip the paywall
  layout silently.
- **`HomeView.body` decomposed** — extracted `permissionsCard` (~110
  lines, with `permissionsCardHeader` + `permissionsCardDetail` +
  shared `permissionsRow` helper) and `listsSection` (~65 lines, with
  `activeListsCard` + `inactiveListsDisclosure`). body shrunk from
  ~330 lines to ~160. No behavior change — same logic, same layout.
- **`LogoutButton` simplified** to a single `DataReset.signOutAndClear()`
  call (already in v1.4.0). Bumped from in-place clears in this
  release's prep work; tracked here for completeness.

### الإزالات (Removed)

- **Legacy non-optional `sharedDefaults` global** in
  `FamilySelectionStore` (it fell back to `.standard` when the App
  Group was missing — a documented trap that no caller actually used
  any more).
- **No-op `.onChange(of: selectedTab)` in PoliciesView**, plus its
  stale comment explaining the body was intentionally empty.
- **Unused `showComingSoonAlert` state + alert in SettingsView**
  (the Community section that triggered it has been hidden since v1.3).
- **Six dead helper functions in BlockItemsEditorView**
  (`websiteInput` state, `addWebsite`, `websiteRow`, `removeWebsite`,
  `websiteInputHelper`, `isValidDomain` instance + `isValidDomainStrict`
  static) — left over from the typed-domain TextField removed in v1.4.0.
- **Duplicate `fetchMyOutgoingRequests` call** in
  `ContentView.bootstrapCloudKit`. ApprovalExecutor.executePendingApprovals
  already calls it internally as its first step; the pre-fetch was a
  redundant CloudKit round-trip on every cold launch.

### تحت الفـغـاء (Internal / no user-visible change)

- **`isAppGroupActive` is now a computed `var`** instead of a load-time
  `let` snapshot, so a re-signed entitlement fix is picked up without a
  process restart.

## [1.4.0] — 2026-05-27

### الإصدار الخامس — تصحيحات معمارية عميقة + offline-safety كامل + sign-out cleanup

#### المُصلَح (Fixed)

- **Multi-slot scheduling لم يحترم الـ slots المتعددة** — قائمة بـ slot
  السبت 9-12 + السبت 18-22 كان يُسجَّل كـ schedule واحد من 9-22، فالـ
  shield يبقى مفعَّل خلال فجوة 12-18 رغم سماح المستخدم. والأسوأ: حقل
  `day` كان مُهمَلاً تماماً (`repeats: true` يومياً). الآن
  `BlockingEngine.scheduleMonitoring` يُسجِّل `DeviceActivitySchedule`
  منفصل لكل slot مع `weekday` صحيح (1=Sunday…7=Saturday). الأسماء
  بنمط `schedule.<UUID>.<slotIndex>` لاحترام أبل's per-name uniqueness.
  حد per-list: 14 slot (DeviceActivity per-extension cap ~20).
  `BlockingMonitor.parseActivity` يدعم النمط الجديد.
- **typed websites كانت لا تحجب فعلياً** — الـ TextField في
  `BlockItemsEditorView.websitesSection` كان يقبل نصوص (مثل
  "youtube.com") تُحفَظ في Core Data، لكن `ManagedSettings.shield.webDomains`
  يقبل `WebDomainToken` opaque tokens فقط (لا strings). النتيجة: حجب
  وهمي. الـ UI الآن زر "اختر مواقع من Apple Picker" يفتح
  FamilyActivityPicker (الذي يدعم apps + categories + websites في
  selection موحَّد). `handleFamilySelectionChange` يحدِّث
  `draft.websites` count من `webDomainTokens.count`.
  `BlockingEngine.applyShields` نُظِّفت من branch الـ typed-domain
  warning. حُذِف 6 helpers ميتة (`websiteInput`, `addWebsite`,
  `websiteRow`, `removeWebsite`, `websiteInputHelper`, `isValidDomain`,
  `isValidDomainStrict`).
- **`createActionRequest` يضيع طلبات الشريك في وضع offline أو CloudKit
  failure** — كان يرجع `nil` ويعرض الـ UI خطأ، رغم أن
  `recordBreakAttempt` (المسار الأقل أهمية) يستخدم `PendingBreakAttemptQueue`.
  الآن `createActionRequest` يحفظ في الـ queue على offline أو error،
  ويرجع `attemptID.uuidString` non-nil (queue handles delivery). الـ
  `flushPendingBreakAttempts` يحترم `status + reason` للـ approval
  requests (لا تتحول الـ `.pending` إلى `.logOnly` عند الـ replay).
- **`scheduled + hard` semantics غامضة** — `BlockingEngine.isHardLocked`
  كان يرجع `false` بصمت لـ scheduled+hard، فالـ "Hard Mode" بلا أثر
  عملي. أُضيف comment صريح: Hard Mode على scheduled lists يحمي
  configuration (delete/modify يمر بالـ gatekeeper) وليس runtime
  (الـ schedule يحرّر نفسه عند نهاية النافذة).
- **`RequestActionSheet.sendRequest` كانت تبتلع pre-flight failures**
  بعد أن جعلت `createActionRequest` يُرجع non-nil دائماً. الآن تُلتقط
  `wasOffline` قبل الـ await، الـ `guard id != nil` يحافظ على defensive
  path للـ malformed-arg failures، وفرع `wasOffline` يستدعي
  `onRequestSent()` (queue يضمن التسليم).

### المضاف (Added)

- **`Core/DataReset.signOutAndClear()`** — تنظيف مركزي عند الـ logout
  يمسح: Keychain (Apple userID)، كل AppStorage keys بنطاق المستخدم
  (auth/premium/trial/onboarding profile/admin/chat history)، per-list
  stores (`v1:manual:`, `v1:breaks:`, `v1:emergencyUnlock:` orphans،
  + `v1:deletionLog:entries`)، Core Data lists (force-deactivated عبر
  `BlockingEngine.purge` حتى Hard Mode)، PendingBreakAttemptQueue. الـ
  CloudKit data يبقى مرتبطاً بـ Apple ID — خارج النطاق. النية: مستخدم
  B الذي يدخل بعد A لا يرث قوائمه/بياناته.

### المُحسَّن (Changed)

- **`PendingBreakAttempt` يدعم approval workflow** — حقول optional
  `statusRaw` + `reason` تُضمَّن في الـ queue (backward-compatible:
  الـ records القديمة بدون `statusRaw` تُعتبر `.logOnly` تلقائياً).
  الـ `flush` يبني الـ CKRecord بنفس الـ status الأصلي.
- **`LogoutButton` مبسَّط** — يستدعي `DataReset.signOutAndClear()` فقط
  بدل الـ in-place clears. الـ alert message محدَّث للشفافية: "راح
  تنحذف قوائمك وحساب الاشتراك والملف الشخصي من هذا الجهاز. (الشركاء في
  iCloud يبقون مرتبطين بحسابك.)"

## [1.3.0] — 2026-05-25

### الإصدار الرابع — Home Page أهدأ + شريك التعافي صار جزء من إنشاء القائمة

#### المضاف (Added)

- **خطوة شريك التعافي داخل CreateListSheet** — لمّا تختار الوضع الصارم،
  تظهر بطاقة "شريك التعافي" تلقائياً تحت بطاقة الحماية، فيها ثلاث
  خيارات: "بدون شريك"، اختيار شريك مقبول من الشراكات الموجودة، أو
  إرسال دعوة لشريك جديد. الدعوة الجديدة تستخدم CKShare وتُسلَّم عبر
  iMessage / Mail / AirDrop / نسخ الرابط — نفس آلية HomeView لكن مدمجة
  في تدفق الإنشاء كما كان مخطّطاً في `docs/PARTNER_FEATURE_DESIGN_AR.md`
  منذ إصدار 1.1.0.
- **تذكير بعد الحفظ** — لو حفظت قائمة بوضع صارم بدون اختيار شريك، يظهر
  sheet يقترح إضافة شريك تعافي. خياران: "أضف شريكاً" (يكمل نفس تدفق
  الدعوة)، أو "لاحقاً" (الشراكة تظل ممكنة من تفاصيل القائمة).
- **`CloudKitPartnerStore.attachPartnership(_:toList:)`** — دالة جديدة
  لإلحاق قائمة جديدة بشراكة موجودة (`associatedListIDs`). تجرّب
  privateDB أوّلاً للمالك، وتسقط لـ sharedDB للمدعوّ. تتعامل مع
  double-tap بـ dedup، وتُحدّث الـ cache المحلّي بعد النجاح.

#### المُعَدَّل (Changed)

- **HomeView أُعيد تصميمه بالكامل لتقليل الحشو** — كان المستخدم بثلاث
  قوائم يحتاج 1,134pt من السكرول (شاشتين كاملتين) للوصول للأسفل على
  iPhone SE. التغييرات:
  - الـ Hero (شعار 96×96 + عنوان 28pt + شرح) ↔ مُزال. يظهر اسم
    المستخدم الآن في navigationTitle بشكل مدمج: "أهلاً، [الاسم]".
  - زر مشاركة التقدّم نُقل من زرّ inline 44pt إلى أيقونة في الـ toolbar
    (`square.and.arrow.up`)، ويظهر فقط لمّا تكون فيه قائمة على الأقل.
  - الـ Stats Row (SavedCycle + Level + Challenges، 112pt دائماً) ↔
    استُبدل بسطر footer دقيق يعرض "X قائمة نشطة الآن"، يظهر فقط لمّا
    `activeLists.count > 0` (لا "Level 1" بدون داتا).
  - البنرات (iCloud + Monitor) ↔ دُمجت في `alertsStrip` يعرض **بنر واحد
    فقط** بترتيب أولويّة (Permissions → iCloud → Monitor)، بنمط slim
    44pt يطابق بنر الأذونات الموجود.
  - قائمة الـ Lists ↔ كانت container واحد 430pt+؛ الآن مفصول: "النشطة
    الآن" كبطاقة مستقلّة، و"قوائم أخرى" داخل `DisclosureGroup` مطوي
    افتراضياً (يوفّر ~180pt على الـ first paint).
  - المسافة بين الـ sections: 24pt → 16pt (`NNSpacing.md`). مع تقليل
    عدد الـ blocks، الـ rhythm الجديد طبيعي ولا يحسّ المستخدم بفجوات.
- **`AppStrings` تحت `@MainActor`** — متابعة لتعليم `LanguageManager`
  بـ `@MainActor` في v1.2.0؛ هذه الدوال تقرأ `lang.isArabicEffective`
  وتحتاج نفس actor isolation تحت الـ strict concurrency.

#### المُصلَح (Fixed)

- **Crash عند إلغاء اختيار جميع التطبيقات في FamilyActivityPicker** —
  `BlockItemsEditorView.swift:302` كان يستخدم `for idx in 1...selectedCount`
  (closed range). لمّا `selectedCount == 0` كان يصير `1...0` ويفجّر بـ
  "Range requires lowerBound <= upperBound". تحوّل إلى half-open range
  `(0..<selectedCount).map { ... }` — `0..<0` empty range آمن.
- **Build error: `Cannot find 'gold' in scope`** — في `UpgradeView.swift`
  سطرين 277-278 كانا يشيران لمتغيّر `gold` محلي تم حذفه سابقاً.
  استُبدل بـ `AppColors.trophyGold` (الـ token الموحَّد).

## [1.2.0] — 2026-05-25

### الإصدار الثالث — نظام تصميم موحَّد + موثوقيّة + ميزات تجربة جديدة

#### المضاف (Added)

- **شريك التعافي صار صامداً ضدّ انقطاع الاتصال** — محاولات كسر الحجب
  التي تفشل في الوصول إلى CloudKit (وضع offline، حساب iCloud غير متاح،
  أو CKError مؤقّت) تُحفَظ في طابور محلّي بسعة 50 عنصر، وتُعاد المحاولة
  تلقائياً عند استعادة الاتصال أو تغيّر حالة الحساب. يستلم الشريك
  محاولات الكسر حتى لو كان المستخدم مقطوع الاتصال وقت المحاولة.
- **آلية فك حجب طارئة بعد 72 ساعة** للقوائم Hard + Forever — تحلّ
  متطلّب Apple Review Guideline 5.1.1 (السيطرة للمستخدم) دون كسر مبدأ
  مقاومة الاندفاع. يطلب المستخدم الفك، ينتظر ثلاثة أيام، ثم يستطيع
  تحرير القفل. النمط مطابق لـ Cold Turkey و Opal Hard Mode.
- **بذر قائمة حجب أوّليّة من بيانات Onboarding** — بدل أن يبدأ المستخدم
  الجديد بشاشة فارغة، ينشئ التطبيق قائمة inactive تلقائياً من الفئات
  والأهداف التي اختارها في Onboarding. ضغطة واحدة لتفعيلها.
- **دعم Family Sharing لاشتراك Premium** — أعضاء عائلة المشترك يحصلون
  على Premium تلقائياً (`familyShareable: true` + معالجة
  `.familyShared` ownership type في StoreKit).
- **عدّاد خطوات صريح في Onboarding** — بدل الـ dots وحدها، يظهر الآن
  "خطوة X من 4" أسفل الـ TabView.
- **مكوّن SoftDivider مشترك** في `Core/Components.swift` — يستبدل
  سبع نُسخ مكرّرة كانت مبعثرة في الـ Views، ويتجاوب مع الشاشات
  الصغيرة (لم يعد يفيض على iPhone SE).
- **نظام Design Tokens موحَّد** في `Core/DesignTokens.swift` —
  Typography (Hero / SectionTitle / CardTitle / Button / Caption)،
  Spacing scale، Radius، Border، HitTarget. مصدر حقيقة واحد يطابق
  UI-Mode.mdc.

#### المُصلَح (Fixed)

- **Recovery Partner owner/invitee detection كانت تحصيلَ حاصل** —
  المقارنة كانت مع نصٍّ ثابت `"<self>"` لا يُكتَب في الكود أصلاً،
  فكان المدعوّ يرى دائماً "بانتظار قبول الشريك…" بدل اسم المالك. الآن
  تُقارَن `partnership.partnerUserID` مع `userRecordID` المُخزَّن من
  حساب iCloud للجهاز.
- **App Group misconfig كان يفشل بصمت** — `FamilySelectionStore` كان
  يلجأ إلى `UserDefaults.standard` عندما يكون الـ App Group entitlement
  مفقوداً، فينفصل الـ extension عن الـ main app دون أيّ تحذير. الآن
  الكشف صريح، مع banner للمستخدم و heartbeat من الـ extension يكشف
  الحالة عبر `MonitorHealthcheck`.
- **خطأ حفظ Core Data كان يعرض رسالة تقنيّة للمستخدم** —
  `error.localizedDescription` كان يظهر داخل الـ alert. الآن يُسجَّل في
  Logger داخلياً، ويرى المستخدم رسالة قابلة للتنفيذ بدلاً منها.
- **زر "Upgrade" في limit alert لم يكن مترجَماً** — كان
  `Button("Upgrade")` بالإنجليزية حتى لو الواجهة عربيّة. صار "رقّي
  حسابي".
- **SmartListSeeder كان يقرأ مفتاح UserDefaults الخطأ** — كان يقرأ
  `"v1:lang.selected"` بدل `"AppLanguage"`، والقيم خاطئة أيضاً
  (`"ar"/"en"` بدل `"arabic"/"english"`). نتيجته: القوائم المبذورة بلغة
  مخالفة لكل مستخدم بدّل اللغة من الإعدادات.
- **Emergency Unlock بعد النضوج لم يكن يحرّر فعلياً** — كان الـ banner
  يقول "استخدم الـ toggle" لكن `toggleManual` يخرج مبكّراً (early
  return) في الوضع الصارم. الآن يسمح بالـ deactivate عند نضوج
  الفك، ويُستهلَك الفك المُتاح بعد الاستخدام (إعادة الحجب تتطلّب
  انتظاراً جديداً 72 ساعة).

#### المُعَدَّل (Changed)

- **توحيد Accent Color على #2563EB** — كان `accentDark` (#4DA2FC)
  المستخدَم السائد، لكنه فشل في AA contrast للنصّ الأبيض (3.4:1). صار
  `#2563EB` بـ contrast 4.83:1 ✅. 112 مرجع legacy → 0.
- **استبدال 96 استدعاء `.system(size:)` بـ semantic Fonts** — Dynamic
  Type يشتغل الآن على كل النصوص (متطلّب a11y).
- **توحيد cornerRadius على token scale** (8/12/16/20) — لا قيم
  off-scale.
- **توحيد UX Copy** — أزرار "تأكيد" العامّة → labels وصفيّة ("فعّل
  الوضع الصارم"، "احذف القائمة"، "سجّل الخروج"، "اطلب الفك")، توحيد
  الإملاء "حسناً" و"لاحقاً"، توحيد "تم" المُحمَّل دلالياً → "مُفعَّل" مع
  ✓ green.
- **Permission Card → slim warning banner** عند الـ collapsed (44pt)،
  بحيث لا يتنافس مع الـ Primary CTA. الـ expanded state يحتفظ بنفس
  أزرار Grant/Enable.
- **Share Progress** من primary fill إلى secondary outline، لتبقى
  "ابدأ" هي الـ CTA الوحيد المهيمن.
- **توحيد لغة الواجهة العربيّة** — مَعجم مفاهيم موحَّد (حجب/إلغاء/إذن/
  إشعار)، تنوين منقّى (ـاً)، أرقام Latin متّسقة، نبرة فصحى حديثة
  للتحذيرات الحرجة وعاميّة دافئة للمساعدات.

#### الأمان والموثوقيّة (Reliability)

- `BlockingMonitor` extension يكتب heartbeat عند كل استدعاء
  (`intervalDidStart` / `intervalDidEnd` /
  `eventDidReachThreshold`)، و`MonitorHealthcheck` يقرأها للكشف عن
  انقطاع الـ extension.
- ترقية Xcode 16 لإعدادات البناء + Arabic localization region.

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
