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

2. **Edit Scheme → Run → Options**:
   - StoreKit Configuration: `Products.storekit` (للاختبار المحلي)
   - **مهم**: لا تنسى تعطيلها قبل Archive للنشر

3. **إضافة Privacy Manifest** (مطلوب من iOS 17+):
   - File → New → File → Privacy → PrivacyInfo.xcprivacy
   - Add Required Reason API entries (إن استخدمت أي):
     - `UserDefaults` → `CA92.1`
     - `FileTimestamp` → غير مستخدم
     - `SystemBootTime` → غير مستخدم

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

## 📞 جهات اتصال مفيدة

- Apple Developer Support: https://developer.apple.com/contact
- App Review Status: https://developer.apple.com/contact/app-store/?topic=expedite
- Family Controls Request: https://developer.apple.com/contact/request/family-controls-distribution
