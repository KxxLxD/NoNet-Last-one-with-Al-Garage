# تصميم ميزة شريك التعافي — CloudKit + Apple ID

> **الحالة:** تصميم معتمد (لم يُنفّذ بعد)
> **التاريخ:** 2026-05-22
> **المؤلّف:** بعد نقاش 6 خيارات معمارية
> **التنفيذ:** Sprint 4 (4-5 أيام)

---

## 🎯 الهدف

ميزة قوية جداً، متوافقة 100% مع سياسات Apple، تخدم المحتوى الحساس (إدمان إباحي، قمار، إدمان حقيقي) حيث يكون "شرف المستخدم" غير كافٍ.

### المتطلبات الوظيفية
1. **Verification حقيقي** — لا تكفي إضافة إيميل بدون تأكيد.
2. **متوافق مع سياسات Apple** — لا يصطدم بـ App Store Review Guidelines.
3. **خصوصية عالية** — لا نسرّب بيانات الشريك لطرف ثالث.
4. **تجربة شريك جيدة** — الشريك يستلم إشعار محاولات الكسر، يقدر يرفض/يقبل.
5. **يفضّل: لا backend خاص بنا** — للحفاظ على معمارية offline-first قدر الإمكان.

---

## 📋 المقارنة بين الخيارات الست (للمرجعية)

| # | الخيار | القوة | تطوير | تكلفة | Apple | Offline | Push | القرار |
|---|--------|------|------|------|------|---------|------|--------|
| 1 | شراكة شرف | ⭐⭐ | 1 يوم | $0 | ✅ | ✅ | ❌ | مرفوض — ضعيف |
| **2** | **CloudKit + Apple ID** | **⭐⭐⭐⭐⭐** | **4-5 أيام** | **$0** | **✅** | **⚠️** | **✅** | ✅ **مختار** |
| 3 | Backend خاص (OTP) | ⭐⭐⭐ | 7-10 أيام | $5-15/شهر | ✅ | ❌ | يحتاج دمج | مرفوض — تكلفة + صيانة |
| 4 | Sign in with Apple + Universal Links | ⭐⭐ | 3 أيام | $0 | ✅ | ⚠️ | ❌ | مرفوض — يحتاج backend للتخزين |
| 5 | iMessage Extension | ⭐⭐⭐ | 6-8 أيام | $0 | ✅ | ✅ | iMessage فقط | مرفوض — تعقيد كبير |
| 6 | Hybrid (1+2) | ⭐⭐⭐⭐ | 6 أيام | $0 | ✅ | ✅/⚠️ | ✅ للموثّقة | مؤجّل — بدائل أبسط متاحة |

---

## 🏆 لماذا الخيار 2 فاز

### مقارنة مع backend خاص (الخيار 3)

| المعيار | CloudKit | Backend خاص |
|--------|----------|------------|
| التكلفة | $0 | $5-15/شهر |
| الصيانة | Apple يديرها | علينا |
| الأمان | Apple يضمنه | علينا |
| Verification | Apple ID (لا يُزوّر) | OTP عبر إيميل (قابل للتجاوز) |
| Push Notifications | مجانية، مدمجة | يحتاج FCM/APNs setup |
| Privacy | E2E encryption مدمج | يجب بناؤه |
| App Store Review | Apple تروّج له | محايد |
| **المجموع** | **7 نقاط** | **0 نقاط** |

### المخاطر المعروفة
| الخطر | الحدة | التخفيف |
|------|------|---------|
| الشريك ليس عنده iCloud | منخفض (~5% من مستخدمي iPhone) | عرض رسالة واضحة + اقتراح Honor partnership كـ fallback |
| CloudKit downtime | نادر جداً | الشراكة الحالية cached محلياً، لا تتأثر بـ downtime |
| تجاوز quotas CloudKit | مستحيل عملياً (10 PB مجاناً) | — |
| الشريك يحذف حسابه iCloud | متوسط | نكتشف عبر `CKAccountStatus` change، نُبلغ المستخدم |

---

## 🔄 تدفق الاستخدام (User Flow)

### السيناريو 1: إضافة شريك جديد

```
المستخدم
  │
  ├─ يفتح CreateListSheet
  ├─ يختار Hard Mode
  └─ تظهر خطوة جديدة "شريك التعافي"
          │
          ├─ "بدون شريك" → يكمل بدون شريك
          ├─ "اختر شريكاً موجوداً" → قائمة الشركاء المسجّلين سابقاً
          └─ "إضافة شريك جديد" ▼

المستخدم يضغط "دعوة شريك جديد"
  │
  ├─ ⚙️ الكود ينشئ CKShare للـ PartnershipRecord
  └─ يعرض UICloudSharingController (واجهة Apple أصلية)
          │
          ├─ يختار "إرسال عبر iMessage" / "Mail" / "Copy Link" / "AirDrop"
          └─ Apple يدير الإرسال للشريك ✉️

الشريك (في جهازه)
  │
  ├─ يفتح الرابط → iOS يفتح NoNet (أو يطلب تثبيتها)
  ├─ يسجّل دخول بـ Apple ID (إن لم يكن مسجّلاً)
  └─ يرى شاشة "فلان دعاك لتكون شريك تعافيه — قبول/رفض"
          │
          ├─ قبول → الشراكة تصبح active
          └─ رفض → الشراكة تُحذف، المستخدم يستلم إشعار "رُفضت دعوتك"
```

### السيناريو 2: محاولة كسر Hard Mode

```
المستخدم يحاول كسر حجب Hard Mode
  │
  ├─ التطبيق يمنع الكسر فعلياً (Hard Mode لا يُكسر)
  ├─ لكن نسجّل المحاولة في CloudKit
  └─ ينشئ BreakAttemptRecord
          │
          └─ CloudKit ترسل push notification للشريك تلقائياً 📲

الشريك يستلم إشعار
  │
  └─ "محاولة كسر — فلان حاول كسر حجب 'وقت التركيز'"
          │
          ├─ يفتح NoNet → يرى التاريخ الكامل
          └─ يقدر يرسل رسالة تشجيع (Optional في v2)
```

### السيناريو 3: حالة حافة — الشريك ليس عنده iCloud

```
المستخدم يضغط "دعوة شريك"
  │
  └─ CKContainer.accountStatus → .noAccount

النظام يعرض:
  │
  ├─ "الشريك يحتاج Apple ID مع iCloud مفعّل"
  ├─ "هل تريد بدلاً من ذلك إنشاء شراكة شرف (بدون verification)؟"
  └─ Honor Partnership كـ fallback (إن وافق)
```

---

## 🗄️ تصميم البيانات (CloudKit Schema)

### قاعدة CloudKit: Private + Shared

نستخدم **Shared Database** للشراكات (يتيح المشاركة بين مستخدمين مختلفين عبر `CKShare`).

### Records

#### 1. `PartnershipRecord`
```
recordType: "Partnership"
zone: SharedZone (في Shared Database)

Fields:
  - ownerUserID: String (CKRecord.ID.recordName من Apple ID للمستخدم)
  - partnerUserID: String? (يُملأ بعد القبول)
  - ownerDisplayName: String (الاسم الذي يكتبه المستخدم لنفسه)
  - partnerDisplayName: String? (الاسم الذي يدخله الشريك عند القبول)
  - status: String ("pending" | "accepted" | "rejected" | "revoked")
  - createdAt: Date
  - acceptedAt: Date?
  - associatedListIDs: [String] (UUIDs لقوائم Hard Mode المرتبطة)

Indexes:
  - status (queryable)
  - ownerUserID (queryable)
```

#### 2. `BreakAttemptRecord`
```
recordType: "BreakAttempt"
zone: SharedZone (نفس Partnership)

Fields:
  - partnershipID: CKRecord.Reference (إلى PartnershipRecord)
  - listID: String (UUID)
  - listName: String
  - attemptedAt: Date
  - attemptType: String ("disable" | "delete" | "modify" | "uninstall_attempt")
  - reachedThrough: String? ("settings_screen" | "block_screen" | …)

Notifications:
  - CKSubscription على Shared Zone → push للشريك عند insert
```

#### 3. `PartnerProfileRecord` (في Private Database للشريك)
```
recordType: "PartnerProfile"
zone: PrivateZone (في Private Database للشريك نفسه)

Fields:
  - displayName: String
  - acceptedPartnerships: [CKRecord.Reference]
  - notificationPreference: String ("all" | "important" | "muted")
```

---

## 🏗️ معمارية الكود (الملفات الجديدة)

### `blocking app/Core/CloudKitPartnerStore.swift`
**الغرض:** Wrapper على CloudKit للعمليات الأساسية.

```swift
import CloudKit

@MainActor
final class CloudKitPartnerStore: ObservableObject {
    static let shared = CloudKitPartnerStore()

    private let container: CKContainer
    private let sharedDB: CKDatabase

    @Published var partnerships: [Partnership] = []
    @Published var accountStatus: CKAccountStatus = .couldNotDetermine

    init(containerID: String = "iCloud.com.nonetapp") {
        self.container = CKContainer(identifier: containerID)
        self.sharedDB = container.sharedCloudDatabase
    }

    // العمليات الأساسية
    func checkAccountStatus() async throws -> CKAccountStatus { ... }
    func createPartnership(ownerName: String, associatedListID: UUID) async throws -> CKShare { ... }
    func acceptInvitation(metadata: CKShare.Metadata) async throws -> Partnership { ... }
    func recordBreakAttempt(partnershipID: CKRecord.ID, list: ListEntity, type: BreakAttemptType) async throws { ... }
    func revokePartnership(id: CKRecord.ID) async throws { ... }
    func fetchAttempts(partnershipID: CKRecord.ID) async throws -> [BreakAttempt] { ... }

    // Subscriptions
    func setupSubscriptions() async throws { ... }
}
```

### `blocking app/Core/PartnerEntity.swift`
**الغرض:** Core Data entity للـ cache المحلي (نتجنّب فتح CloudKit في كل refresh).

```swift
// Programmatic Core Data entity مثل ListEntity.swift
@objc(PartnerEntity)
final class PartnerEntity: NSManagedObject {
    @NSManaged var cloudRecordID: String
    @NSManaged var displayName: String
    @NSManaged var status: String
    @NSManaged var createdAt: Date
    @NSManaged var associatedListID: UUID?
}
```

### `blocking app/PartnerInviteView.swift`
**الغرض:** UI لدعوة شريك جديد عبر `UICloudSharingController`.

### `blocking app/PartnerStatusView.swift`
**الغرض:** عرض حالة الشركاء + قائمة محاولات الكسر للشريك.

### `blocking app/Core/PartnerNotificationHandler.swift`
**الغرض:** معالج push notifications عند insert في `BreakAttemptRecord`.

---

## ⚙️ Capabilities المطلوبة

في `blocking app/blocking app.entitlements`:

```xml
<!-- إضافات جديدة -->
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>

<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.nonetapp</string>
</array>

<key>aps-environment</key>
<string>development</string>  <!-- production في Release.entitlements -->
```

### في App Store Connect
- إنشاء **CloudKit Container**: `iCloud.com.nonetapp`
- تفعيل **Push Notifications** capability
- إضافة Container إلى App ID

### في Xcode
- Signing & Capabilities → إضافة:
  - iCloud (CloudKit checked)
  - Push Notifications
  - Background Modes (Remote notifications checked)

---

## 🔐 حالات الحافة (Edge Cases)

### 1. الشريك ليس عنده iCloud
- **اكتشاف:** `CKContainer.accountStatus == .noAccount`
- **استجابة:** اعرض شاشة تشرح المشكلة + خيار Honor Partnership كـ fallback.

### 2. الشريك ليس عنده NoNet
- **اكتشاف:** الرابط يفتح Safari بدل التطبيق.
- **استجابة:** الرابط يحتوي Universal Link مع fallback لـ App Store.

### 3. رفض الشريك بعد القبول (revoke)
- **اكتشاف:** الشريك يحذف partnership من قائمته → `PartnershipRecord.status` يتحول لـ `"revoked"` → subscription يُبلغ المستخدم.
- **استجابة:** المستخدم يستلم إشعار "الشريك انسحب — هل تريد إيجاد شريك جديد؟"

### 4. حذف الشريك لحسابه iCloud
- **اكتشاف:** عند fetch، `CKRecord` يُرجع `.unknownRecord`.
- **استجابة:** اعتبر الشراكة لاغية، اعرض رسالة "الشريك لم يعد متاحاً".

### 5. المستخدم نفسه يلغي اشتراك iCloud
- **اكتشاف:** `accountStatus` يتغير من `.available` إلى `.noAccount`.
- **استجابة:** الشراكات تبقى في Core Data cache، لكن لا تستطيع تسجيل محاولات كسر جديدة. اعرض banner دائم في `HomeView`.

### 6. عدم وجود اتصال إنترنت
- **اكتشاف:** `CKError.networkUnavailable`.
- **استجابة:** اعمل queue محلية في Core Data، أعد المحاولة عند عودة الاتصال (مرتبط بـ `CKModifyRecordsOperation` مع `isAtomic = true`).

### 7. حذف القائمة المرتبطة
- **اكتشاف:** `ListEntity.delete()`.
- **استجابة:** أزل الـ list ID من `Partnership.associatedListIDs`. لا تحذف الشراكة (قد تُربط بقائمة أخرى).

### 8. CloudKit Quota تجاوز (مستحيل عملياً لكن نتعامل معه)
- **اكتشاف:** `CKError.quotaExceeded`.
- **استجابة:** حذف `BreakAttemptRecord` أقدم من 90 يوم تلقائياً (cleanup job).

---

## 📅 خطة التنفيذ — 5 أيام

### يوم 1: البنية التحتية
- [ ] إضافة CloudKit capability في entitlements.
- [ ] إنشاء CloudKit Container في App Store Connect.
- [ ] إنشاء `CloudKitPartnerStore.swift` (هيكل + check account status).
- [ ] إنشاء `PartnerEntity` في Core Data programmatic model.
- [ ] إعداد `CKSubscription` للـ Shared Zone.
- [ ] اختبار: التطبيق يبني ويتصل بـ CloudKit بدون errors.

### يوم 2: تدفق الدعوة (Inviter)
- [ ] `PartnerInviteView.swift` — UI الأساسي.
- [ ] دمج `UICloudSharingController`.
- [ ] إنشاء `PartnershipRecord` + share.
- [ ] إضافة خطوة "شريك التعافي" في `CreateListSheet` (تظهر فقط لـ Hard Mode).
- [ ] اختبار: المستخدم يقدر يدعو شريك ويرى الـ share sheet.

### يوم 3: تدفق القبول (Invitee)
- [ ] Universal Links setup في `Info.plist`.
- [ ] معالج `application(_:userDidAcceptCloudKitShareWith:)` في `blocking_appApp`.
- [ ] `PartnerAcceptInvitationView.swift` — شاشة قبول/رفض.
- [ ] حفظ الشراكة في `PartnerEntity` بعد القبول.
- [ ] اختبار: الشريك يقدر يقبل/يرفض (يحتاج جهازين أو حسابي iCloud).

### يوم 4: محاولات الكسر + Notifications
- [ ] دمج `recordBreakAttempt` في كل نقاط الكسر المحتملة:
  - محاولة حذف قائمة Hard Mode (في `HomeView`).
  - محاولة تعديل قائمة Hard Mode.
  - محاولة uninstall (عبر background task لا يمكن — نسجّل عند launch بعد reinstall).
- [ ] `PartnerNotificationHandler.swift` — معالج push عند insert.
- [ ] `PartnerStatusView.swift` — عرض محاولات الكسر.
- [ ] اختبار: محاولة كسر → الشريك يستلم push في 1-2 ثانية.

### يوم 5: حالات الحافة + Polish
- [ ] معالجة كل الحالات الـ 8 المذكورة أعلاه.
- [ ] إضافة banner في `HomeView` عند `accountStatus != .available`.
- [ ] رسائل localized بالعربية والإنجليزية.
- [ ] اختبار end-to-end على جهازين حقيقيين.
- [ ] توثيق المستخدم: شرح كيف يعمل الشريك في FAQ.

---

## 🧪 خطة الاختبار

### اختبارات Unit (في `blocking appTests/`)
- `CloudKitPartnerStoreTests.swift`:
  - mock `CKContainer` للاختبار بدون اتصال شبكة.
  - test `recordBreakAttempt` queueing عند `networkUnavailable`.
  - test parsing `PartnershipRecord` ↔ `Partnership` struct.

### اختبارات Integration (يدوية على أجهزة حقيقية)
- جهازين iPhone مع حسابي iCloud مختلفين.
- اختبر كل سيناريوهات User Flow أعلاه.
- اختبر كل Edge Cases الـ 8.
- قِس latency push notification (يجب < 5 ثوان).

### قبل الشحن
- [ ] اختبار على iOS 16 (أقدم نسخة مدعومة) — CloudKit APIs قد تختلف.
- [ ] مراجعة Privacy Policy — إضافة قسم CloudKit data sharing.
- [ ] مراجعة Terms — إضافة بند موافقة الشريك.

---

## 🎓 المراجع

- [CloudKit Documentation](https://developer.apple.com/documentation/cloudkit) — Apple
- [Sharing CloudKit Data with Other iCloud Users](https://developer.apple.com/documentation/cloudkit/shared_records) — Apple
- [UICloudSharingController](https://developer.apple.com/documentation/uikit/uicloudsharingcontroller) — Apple
- [CKShare Lifecycle](https://developer.apple.com/videos/play/wwdc2021/10086/) — WWDC 2021

---

## ❓ أسئلة معلّقة (للنقاش قبل التنفيذ)

1. هل نسمح بأكثر من شريك واحد لكل قائمة Hard Mode؟ (التوصية: لا — يكفي شريك واحد لتجنّب الإرباك.)
2. هل الشريك يقدر "يفك الحجب" برضاه (مثلاً في حالة طارئة)؟ (التوصية: نعم في v2، حالياً Hard Mode = لا فك حتى للشريك.)
3. كم يوم نحتفظ بـ `BreakAttemptRecord` قبل الحذف التلقائي؟ (التوصية: 90 يوم.)
4. هل نعرض اسم الشريك في `HomeView` كـ "محمي بواسطة فلان" أم نخفيه للخصوصية؟ (التوصية: عرض مع toggle خصوصية.)

هذه الأسئلة تُحسم في بداية يوم 1 من التنفيذ.
