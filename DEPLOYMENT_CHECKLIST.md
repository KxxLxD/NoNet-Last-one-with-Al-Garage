# قائمة مراجعة قبل النشر — NoNet

ملف يجب اتباعه خطوة خطوة قبل رفع التطبيق إلى TestFlight أو App Store.

---

## ✅ تم بالفعل (في الكود)

- [x] إعدادات Apple Team ID: `L2T9STCPA5`
- [x] Bundle ID: `com.nonetapp`
- [x] Family Controls entitlement مُضاف في `.entitlements`
- [x] Sign in with Apple entitlement مُضاف
- [x] App Attest مفعّل (development في Debug، production في Release)
- [x] iOS Deployment Target موحّد على 16.0
- [x] Info.plist usage descriptions مُضافة (`NSFamilyControlsUsageDescription`)
- [x] Bundle Display Name: `NoNet`
- [x] StoreKit Configuration File جاهز (`Products.storekit`)
- [x] ProductIDs تطابق Bundle ID (`com.nonetapp.monthly` / `.yearly`)
- [x] StoreKit 2 integration كامل (purchase/restore/redeem)
- [x] سياسة خصوصية وشروط استخدام احترافية (PDPL + GDPR compliant)
- [x] AppIcons موجودة (1024 + كل المقاسات)
- [x] `PrivacyInfo.xcprivacy` — Privacy Manifest (iOS 17+ compliant)
- [x] `VERSION` + `CHANGELOG.md` (Keep-a-Changelog)
- [x] 46 Unit tests في `blocking appTests/` (32 من v1.0.0 + 14 لميزات v1.1.0)
- [x] `BlockingMonitor/` scaffold للـ DeviceActivityMonitor extension
- [x] App Store Listing نصوص جاهزة (`docs/APP_STORE_LISTING.md`)
- [x] صفحات HTML للاستضافة في `docs/web/`
- [x] Engineering Review + Security Audit reports

### 🆕 v1.1.0 — جاهز في الكود

- [x] Forever block type مع تحذيرات ثلاثية
- [x] Time-Limit block type عبر `DeviceActivityEvent` threshold
- [x] Recovery Partner كامل (CloudKit + Apple ID + Push subscription)
- [x] Resources page (3 بطاقات تعليمية static)
- [x] Onboarding personalization (تحية + اقتراحات للقوائم)
- [x] iCloud-unavailable banner في Home
- [x] Monetization gates مُفعَّلة (3 قوائم + 1 Hard Mode للمجاني)
- [x] Privacy Manifest محدَّث بـ CloudKit data types
- [x] Privacy Policy AR + EN فيها قسم 5.1 لشريك التعافي
- [x] Community section في Settings (Coming Soon — لا روابط مكسورة)
- [x] iCloud + Push capabilities مضافة في الـ entitlements XML
- [x] `docs/VERIFICATION_v1.1.0_AR.md` — 96% spec parity audit

---

## 🟠 يجب عمله في Apple Developer Portal

### 1. طلب Family Controls Entitlement
هذه الميزة تحتاج موافقة Apple بشكل صريح:
1. اذهب إلى https://developer.apple.com/contact/request/family-controls-distribution
2. املأ الطلب — اشرح أن التطبيق للرفاهية الرقمية وحجب الإلهاءات
3. انتظر الموافقة (عادة 1-2 أسبوع)
4. بعد الموافقة، فعّل Family Controls في Provisioning Profile

### 2. تفعيل Capabilities في الملف الشخصي
في https://developer.apple.com/account/resources/identifiers:
- Identifier `com.nonetapp` → Capabilities:
  - [ ] Family Controls
  - [ ] Sign in with Apple
  - [ ] In-App Purchase
  - [ ] App Attest

---

## 🟠 يجب عمله في App Store Connect

### 1. إنشاء التطبيق
- https://appstoreconnect.apple.com/apps → "+" → New App
- Bundle ID: `com.nonetapp`
- Primary Language: Arabic
- SKU: `nonet-001`

### 2. إنشاء منتجات الاشتراك
في Apps → NoNet → Subscriptions:

**Subscription Group:** `NoNetPremium`
- مهم: المنتجين في نفس المجموعة ليتمكن المستخدم من الترقية/التراجع.

**المنتج 1: Monthly**
- Reference Name: `Monthly`
- Product ID: `com.nonetapp.monthly`
- Subscription Duration: `1 Month`
- Family Sharing: OFF
- Pricing: 30.00 SAR / متغير بحسب البلد
- Introductory Offer: Free Trial — 1 Week
- Localizations:
  - عربي: "شهري"
  - English: "Monthly"

**المنتج 2: Yearly**
- Reference Name: `Yearly`
- Product ID: `com.nonetapp.yearly`
- Subscription Duration: `1 Year`
- Family Sharing: OFF
- Pricing: 300.00 SAR
- Introductory Offer: Free Trial — 1 Week
- Localizations:
  - عربي: "سنوي — وفّر شهرين"
  - English: "Yearly — Save 2 months"

### 3. App Information
- **Privacy Policy URL**: ضع رابط لصفحة الخصوصية (يمكن استضافة `PoliciesView` كصفحة ويب أو نسخها على Notion/GitHub Pages)
- **Support URL**: ضع رابط للدعم
- **Marketing URL**: اختياري
- **App Category**: Productivity أو Health & Fitness
- **Age Rating**: 4+

### 4. App Privacy
في App Privacy → Data Collection:
- [x] **Data Not Collected** — هذا التطبيق لا يجمع أي بيانات
- اختر "Yes" على هذا السؤال (مع تفسيرك أن StoreKit يديره Apple وليس التطبيق)

### 5. App Review Information
- Contact Information: بياناتك
- Notes for App Review:
```
This app uses Family Controls for digital wellness — blocking distracting apps
chosen by the user. All data stays on the device. The app does NOT have any
backend, analytics, or external tracking.

Testing the Block feature requires a real iOS device (Family Controls
doesn't work in Simulator). Test on iPad/iPhone:
1. Login (Sign in with Apple or use email + any 6+ char password — local only)
2. Complete onboarding
3. Create a blocklist
4. Grant Screen Time when prompted
5. Pick apps via Family Activity Picker
6. Save — the apps should now be blocked
```
- Demo Account: not needed (local-only auth)

---

## 🟠 يجب عمله في Xcode

### قبل أول build على جهاز:

1. **Signing & Capabilities** للهدف "blocking app":
   - فعّل Automatic Signing
   - Team: `L2T9STCPA5`
   - تحقق من Capabilities موجودة:
     - Family Controls
     - Sign in with Apple
     - In-App Purchase
     - App Attest (Production)
     - App Groups (لمشاركة UserDefaults مع BlockingMonitor — راجع أدناه)

2. **Edit Scheme → Run → Options**:
   - StoreKit Configuration: `Products.storekit` (للاختبار المحلي)
   - **مهم**: لا تنسى تعطيلها قبل Archive للنشر

3. **Privacy Manifest** (موجود بالفعل):
   - الملف موجود: `blocking app/PrivacyInfo.xcprivacy`
   - تأكد أنه ضمن "Copy Bundle Resources" build phase

4. **إضافة Tests Target** (لمرة واحدة، 10 ثوانٍ):
   - File → New → Target → Unit Testing Bundle
   - Product Name: `blocking appTests`
   - Target to be Tested: `blocking app`
   - احذف الملف الافتراضي `blocking_appTests.swift`
   - الملفات الموجودة في `blocking appTests/` ستُلتقط تلقائياً
   - راجع `blocking appTests/README.md`

5. **إضافة BlockingMonitor Target** (لمرة واحدة، 30 ثانية):
   - File → New → Target → Device Activity Monitor Extension
   - Product Name: `BlockingMonitor`
   - Bundle Identifier: `com.nonetapp.BlockingMonitor`
   - Embed in: `blocking app`
   - احذف ملف `DeviceActivityMonitor.swift` الافتراضي
   - أضف Family Controls capability للـ extension target
   - راجع `BlockingMonitor/README.md`

6. **إنشاء App Group** (لمشاركة UserDefaults مع BlockingMonitor):
   - https://developer.apple.com/account/resources/identifiers/list/applicationGroup
   - Identifier: `group.com.nonetapp.shared`
   - فعّل App Groups capability في كلا الـ targets (التطبيق + BlockingMonitor)
   - حدّث `FamilySelectionStore.swift` ليستخدم:
     ```swift
     UserDefaults(suiteName: "group.com.nonetapp.shared")
     ```

---

## 🟢 خطوات النشر النهائي

### TestFlight (داخلي أولاً)
1. في Xcode: Product → Archive
2. Organizer → Distribute App → App Store Connect → Upload
3. App Store Connect → TestFlight → Internal Testing → Add Build
4. ادعُ اختبارين داخليين (نفسك على iPhone مختلف، أو زملاء)

### App Store (للجمهور)
1. App Store Connect → App Store → Prepare for Submission
2. أضف:
   - Screenshots (6.7" iPhone، 6.5" iPhone، 5.5" iPhone، 12.9" iPad)
   - وصف عربي + إنجليزي (300 حرف)
   - Keywords (100 حرف، فاصلة بين الكلمات)
   - Promotional Text (170 حرف، يمكن تعديلها بعد النشر)
3. Submit for Review
4. انتظر 24-48 ساعة عادة

---

## 📋 نقاط حرجة قبل Submit

- [ ] جربت التطبيق على **جهاز حقيقي** (ليس Simulator)
- [ ] Family Controls يعمل وتحجب فعلياً (تأكد!)
- [ ] StoreKit Configuration **مُعطّل** في Scheme (وإلا سيرفض Review)
- [ ] Privacy Policy URL يفتح صفحة فعلية
- [ ] Localizations عربي + إنجليزي مكتملة
- [ ] لا يوجد `print()` أو `dbg` في كود الإنتاج (تم — استبدلتها بـ os.Logger)
- [ ] حساب App Store Connect يحتوي بيانات بنكية مكتملة (لاستلام أرباح الاشتراكات)
- [ ] Tax Information محدّثة (W-8BEN للمطورين خارج US)

---

## 🚨 أسباب رفض شائعة لتطبيقات الحجب

1. **عدم استخدام Family Controls API**: ❌ الحجب باستخدام VPN أو DNS مرفوض. ✅ التطبيق يستخدم FamilyControls الصحيحة.
2. **سياسة خصوصية غير واضحة**: ✅ موجودة وشاملة.
3. **شرح غير كافٍ لـ Screen Time**: ✅ `NSFamilyControlsUsageDescription` واضح.
4. **منتج اشتراك بدون مزايا واضحة**: ✅ مزايا Premium مذكورة في UpgradeView.
5. **Subscription بدون Restore Purchases**: ✅ زر Restore موجود.
6. **عدم وجود Cancel Anytime واضح**: ✅ مذكور في الشروط.

---

## 🌐 استضافة صفحات HTML (للـ Privacy/Terms/Support URLs)

App Store Connect يطلب URL لـ Privacy Policy. الصفحات جاهزة في `docs/web/`. اختر طريقة استضافة:

### الخيار 1: GitHub Pages (مجاناً، يدعم نطاق فرعي)
```bash
# في مستودع جديد أو الـ docs branch:
git checkout -b gh-pages
git add docs/web/
git commit -m "Add legal pages"
git push origin gh-pages

# اذهب إلى Settings → Pages → Source: gh-pages branch، /docs/web folder
# الـ URL: https://<username>.github.io/<repo>/
```

### الخيار 2: Vercel (مجاناً، أسرع)
```bash
cd docs/web
npx vercel
# اتبع التعليمات
```

### الخيار 3: نطاق مخصص (nonetapp.com)
1. اشترِ نطاق من Namecheap/Google Domains
2. اربطه بـ Vercel أو GitHub Pages
3. حدّث `https://nonetapp.com/privacy` في App Store Connect

**ملاحظة:** بعد الاستضافة، حدّث URLs في `LegalContent.swift` إن لزم.

---

## 🆕 v1.1.0 — خطوات يدوية إضافية

قبل إرسال v1.1.0 لـ App Store، تأكّد من:

- [ ] **Xcode capabilities** — اضغط `+ Capability` وأضف: **iCloud (CloudKit)** + **Push Notifications** + **Background Modes → Remote notifications**. الـ entitlements XML محدَّث، Xcode يحتاج ربطها يدوياً.
- [ ] **App Store Connect → CloudKit Dashboard** — أنشئ container `iCloud.com.nonetapp` ونوعَي السجلات `Partnership` و `BreakAttempt` (الـ schema في [docs/PARTNER_FEATURE_DESIGN_AR.md](docs/PARTNER_FEATURE_DESIGN_AR.md)). اضغط **Deploy to Production** قبل الإطلاق.
- [ ] **Localizable.strings** — أضف مفتاحَي push: `PARTNER_BREAK_TITLE` و `PARTNER_BREAK_BODY` (مع `%@`) في `en.lproj` و `ar.lproj`.
- [ ] **روابط المجتمع** — استبدل `url: nil` في `SettingsView.swift` بروابط WhatsApp/Telegram الحقيقية لما توفّر (التفاصيل في [TODO_FOR_KHALID.md](TODO_FOR_KHALID.md) قسم 1.4️⃣).
- [ ] **اختبار يدوي على جهازين** — Family Controls و CloudKit Sharing لا يعملان كاملاً في Simulator.
- [ ] **App Store Connect → Privacy Nutrition Label** — صرِّح بـ User ID + Name + Product Interaction (Linked, Not for tracking, App Functionality) — يطابق `PrivacyInfo.xcprivacy`.

تفاصيل كل خطوة في [TODO_FOR_KHALID.md](TODO_FOR_KHALID.md) قسم "v1.1.0".

---

## 📞 جهات اتصال مفيدة

- Apple Developer Support: https://developer.apple.com/contact
- App Review Status: https://developer.apple.com/contact/app-store/?topic=expedite
- Family Controls Request: https://developer.apple.com/contact/request/family-controls-distribution
- CloudKit Dashboard: https://icloud.developer.apple.com/dashboard/
