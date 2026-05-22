# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## سياق المشروع (Project Context)

**NoNet** — تطبيق iOS Swift للرفاهية الرقمية. يحجب التطبيقات والمواقع عبر `FamilyControls` + `ManagedSettings` + `DeviceActivity` من Apple. iOS 16+، SwiftUI، Core Data، StoreKit 2، Sign in with Apple. محلي بالكامل (لا backend، لا analytics خارجي).

**اللغة:** التواصل مع المستخدم بالعربية. التعليقات في الكود بالإنجليزية.

## البناء والتشغيل

```bash
open "blocking app.xcodeproj"
```

- المخطط (scheme): `blocking app` — هو الـ scheme الوحيد المشترك.
- الـ Bundle ID: `com.nonetapp` (التطبيق الرئيسي)، `com.nonetapp.BlockingMonitor` (الـ extension المستقبلي).
- App Group مشترك: `group.com.nonetapp.shared` — يُستخدم في `FamilySelectionStore` لمشاركة البيانات مع الـ extension. الكود يسقط إلى `UserDefaults.standard` تلقائياً إذا الـ App Group غير ممنوح بعد.
- **Family Controls لا يعمل في Simulator** — يجب الاختبار على جهاز iPhone/iPad حقيقي.
- لاختبار StoreKit محلياً: Edit Scheme → Run → Options → StoreKit Configuration = `blocking app/Products.storekit`.

### الاختبار

```bash
xcodebuild test \
  -project "blocking app.xcodeproj" \
  -scheme "blocking app" \
  -destination "platform=iOS Simulator,name=iPhone 15"
```

⚠️ **ملفات الاختبار في `blocking appTests/` موجودة لكن الـ Test Target نفسه غير مضاف للـ Xcode project بعد.** الأمر أعلاه سيفشل حتى تُضاف الـ target يدوياً من Xcode UI. التعليمات الكاملة في [blocking appTests/README.md](blocking appTests/README.md) أو شغّل `./scripts/add-targets-help.sh`.

نفس الشيء ينطبق على **`BlockingMonitor`** — السكافولد موجود في المجلد لكن الـ DeviceActivityMonitor extension target غير مضاف بعد. الجدولة لن تطبّق shields حقيقية في الخلفية حتى تُضاف هذه الـ target مع App Group capability.

## المعمارية (high-level)

التطبيق محلي بالكامل (offline-first). كل البيانات في Core Data، UserDefaults، أو Keychain على جهاز المستخدم.

**تدفق الحجب الحرج** (يحتاج فهم ملفات متعددة):

1. المستخدم ينشئ قائمة في `CreateListSheet` → `BlockItemsEditorView`.
2. `PermissionsManager.requestScreenTime()` يطلب إذن Family Controls.
3. `FamilyActivityPicker` (UI من Apple) يُرجع `FamilyActivitySelection` تحتوي على opaque tokens.
4. عند الحفظ: `ListEntity` + `BlockItemEntity` في Core Data، و `FamilySelectionStore.save(...)` يخزّن الرموز في App Group UserDefaults كـ JSON.
5. `BlockingEngine.shared.activate(list)`:
   - **فوري (now):** ينشئ `ManagedSettingsStore(named: "blocklist.<UUID>")` لكل قائمة (وليس store عام واحد — هذا متعمّد للسماح بحجب قوائم متعددة بشكل مستقل) ويطبّق `shield.applications/webDomains` فوراً.
   - **مجدول (scheduled):** يسجّل `DeviceActivitySchedule` في `DeviceActivityCenter`. عند بدء النافذة الزمنية، iOS تستدعي `BlockingMonitor` extension الذي يقرأ الرموز من App Group ويطبّق الـ shields. عند النهاية يستدعي `clearAllSettings()`.

**نقطة مهمة:** auto-deactivation للقوائم المنتهية يحدث عند فتح التطبيق فقط، لا في الخلفية. الحجب يُحرَّر منطقياً عبر `isActiveNow` لكن الـ shield الفعلي يبقى مطبَّقاً حتى يفتح المستخدم التطبيق (يُحلّ مع تفعيل extension).

**ContentView routing:** `isAuthenticated` → AuthView، ثم `showOnboardingAfterLogin` → OnboardingView، وإلا TabView (Home/Chat/Settings).

## اصطلاحات مهمة (Code Conventions)

- **`Core/` يحتوي كل البنية التحتية** (Engine, Permissions, Store, Keychain, Coordinators). الـ Views في الجذر `blocking app/`.
- **`AppStorageKeys.swift`** هو المصدر الوحيد لكل سلاسل `@AppStorage`. لا تضف key كسلسلة inline — أضفه هنا أولاً.
- **`BlockingConstants.swift`** للقيم الثابتة (مدد، حدود) — لا hardcode أرقام في الـ Views.
- **`ProductIDs.swift`** لـ IDs اشتراكات StoreKit. عند إضافة منتج: أضِف في `ProductIDs.swift` + `Products.storekit` + App Store Connect + `UpgradeView.planCard`.
- **Versioning في UserDefaults:** المفاتيح الجديدة تستخدم prefix `v1:` (مثل `v1:permissionsExpanded`). الـ schedule slots في Core Data تُخزَّن كـ JSON بشكل `{"version": 1, "slots": [...]}` مع fallback للنسخة القديمة في `SchedulePersistence`.
- **Logging:** `os.Logger(subsystem: "app.nonet.blocking", category: "...")`. لا تستخدم `print`. السجلات تظهر في Console.app وتُحجب تلقائياً في Release.
- **حفظ Core Data:** استخدم `context.saveIfNeeded() -> Result<Void, Error>` من `CoreDataExtensions.swift`، لا `save()` المباشر.
- **Core Data programmatic model** (لا `.xcdatamodeld`) — معرَّف في `blocking_appApp.swift`. الهجرة (migration) يدوية عبر `PersistenceMigration` في `PersistenceHelpers.swift`.

## الـ Capabilities المطلوبة

في `blocking app/blocking app.entitlements`:
- `com.apple.developer.family-controls` — للوصول لـ Screen Time API
- `com.apple.developer.applesignin` — Sign in with Apple
- `com.apple.security.application-groups` = `group.com.nonetapp.shared` — لمشاركة UserDefaults مع الـ extension

Family Controls entitlement يحتاج موافقة Apple يدوية (Request Form). بدونها التطبيق يعمل في dev signing فقط.

## تعديلات UI (Design System)

عند العمل على UI، الـ design tokens موثقة في `.cursor/rules/UI-Mode.mdc`:
- ثيم فاتح فقط (لا dark mode)، بدون أنيميشن، accent واحد ثابت.
- مساحات لمس ≥ 44×44، تباين AA، أحجام خط ديناميكية.
- `Theme.swift` يحتوي الألوان و `LanguageManager` للتبديل RTL/LTR.

## gstack (REQUIRED — global install)

**Before doing ANY work, verify gstack is installed:**

```bash
test -d ~/.claude/skills/gstack/bin && echo "GSTACK_OK" || echo "GSTACK_MISSING"
```

If `GSTACK_MISSING`: STOP. Tell the user to install it:

```bash
git clone --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack
cd ~/.claude/skills/gstack && ./setup --team
```

Then restart the AI tool. Do not skip skills, ignore gstack errors, or work around missing gstack.

After install, use skills like `/qa`, `/ship`, `/review`, `/investigate`, and `/browse`. Use `/browse` for all web browsing.

## أهم الملفات للقراءة

- [README.md](README.md) — overview، بنية المشروع، خطوات البناء
- [ARCHITECTURE.md](ARCHITECTURE.md) — تدفقات تفصيلية ومخططات
- [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) — قبل النشر على App Store
- [TODO_FOR_KHALID.md](TODO_FOR_KHALID.md) — مهام App Store المتبقية (إجراءات إدارية)
- [GSTACK_GUIDE_AR.md](GSTACK_GUIDE_AR.md) — دليل gstack بالعربية
- [BlockingMonitor/README.md](BlockingMonitor/README.md) — كيفية إضافة DeviceActivity extension
- [blocking appTests/README.md](blocking appTests/README.md) — كيفية إضافة Tests target
