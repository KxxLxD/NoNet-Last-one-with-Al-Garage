# 📋 قائمتك الشخصية — ما عليك فعله بنفسك

> **الملخّص:** كل الكود جاهز ✅. تبقّى **9 إجراءات** تحتاج تسجيل دخولك الشخصي على Apple أو فتح Xcode UI. لا يستطيع أي AI تنفيذها نيابة عنك.
>
> **الزمن المتوقع للإجراءات اليدوية:** ~3-4 ساعات موزعة على 1-2 أسبوع (الانتظار من Apple).

---

## 🆕 v1.1.0 — إعداد ميزات الإصدار الثاني (~20 دقيقة)

> **متى:** بعد ميرج الـ PR رقم 1 (`feat: v1.1.0`). 4 إجراءات يدوية لتفعيل
> شريك التعافي (CloudKit) و push notifications. الكود جاهز بالكامل، هذه فقط
> capabilities + container + سلاسل ترجمة.

### 1.1️⃣ Xcode — تفعيل CloudKit + Push (~2 دقيقة)

**لماذا؟** ميزة شريك التعافي تعتمد على CloudKit، والإشعارات للشريك تعتمد
على Push Notifications. الـ entitlements XML محدَّث لكن Xcode يحتاج
ربطها بالـ Capability في UI.

**كيف؟**
1. افتح Xcode → اختر هدف **blocking app** → تبويب **Signing & Capabilities**.
2. اضغط `+ Capability` → اختر **iCloud** → فعّل خانة **CloudKit** →
   في قسم Containers ستجد `iCloud.com.nonetapp` (اضغط `+` لتُنشئها إن
   لم تكن موجودة).
3. اضغط `+ Capability` → اختر **Push Notifications**.
4. اضغط `+ Capability` → اختر **Background Modes** → فعّل
   **Remote notifications**.

⏱️ **الوقت:** دقيقتان.

---

### 1.2️⃣ App Store Connect — إنشاء CloudKit Container (~5 دقائق)

**لماذا؟** Container هو "قاعدة البيانات" التي تستضيف سجلات الشراكات. بدونه
الـ store لا يستطيع الكتابة. مجاني تماماً ضمن حصة CloudKit المجانية.

**كيف؟**
1. افتح https://icloud.developer.apple.com/dashboard/
2. سجّل دخول بـ Apple Developer Account.
3. Containers → `+` → اكتب `iCloud.com.nonetapp` → Create.
4. داخل الـ container → Schema → Record Types → أنشئ نوعين:
   - **Partnership** (الحقول موثّقة في
     [docs/PARTNER_FEATURE_DESIGN_AR.md](docs/PARTNER_FEATURE_DESIGN_AR.md)
     قسم "PartnershipRecord").
   - **BreakAttempt** (الحقول في نفس الوثيقة، قسم "BreakAttemptRecord").
5. Deploy Schema to Production (زر في أعلى الـ dashboard) قبل الإطلاق.

⏱️ **الوقت:** 5 دقائق.

---

### 1.3️⃣ Localizable.strings — نصوص إشعارات الـ Push (~2 دقيقة)

**لماذا؟** الـ push notification body يستخدم localization keys (هذا أفضل
ممارسة من Apple — النصوص تظهر بلغة جهاز الشريك تلقائياً). بدون هذه
السطور، الـ push يعرض المفاتيح كنص خام.

**كيف؟**

في كل من `en.lproj/Localizable.strings` و `ar.lproj/Localizable.strings` (أنشئها إذا لم تكن موجودة)، أضف:

```
"PARTNER_BREAK_TITLE" = "Break attempt logged";
"PARTNER_BREAK_BODY"  = "%@ tried to break a Hard Mode block.";
```

(والنسخة العربية في `ar.lproj`):

```
"PARTNER_BREAK_TITLE" = "تم تسجيل محاولة كسر";
"PARTNER_BREAK_BODY"  = "%@ حاول كسر حجب بوضع صارم.";
```

⏱️ **الوقت:** دقيقتان.

---

### 1.4️⃣ اختبار يدوي على جهازين iPhone (~10 دقائق)

**لماذا؟** Family Controls و CloudKit Sharing لا يعملان بشكل كامل في
Simulator. تحتاج جهازين بـ Apple ID مختلفين لاختبار end-to-end.

**سيناريوهات الاختبار:**

- [ ] **Forever:** إنشاء قائمة Forever → تأكّد من شاشة التحذير الثلاثية
      (banner أحمر + alert أول + alert تأكيد نهائي).
- [ ] **Time-Limit:** إنشاء قائمة بـ 5 دقائق → استخدم تطبيقاً 5 دقائق →
      تأكّد من ظهور الـ shield بقية اليوم → جرّب reset عند منتصف الليل.
- [ ] **Partner invitation:** من جهاز A، أرسل دعوة → استلمها على جهاز B →
      اقبلها بـ Apple ID مختلف → تأكّد أن الشراكة تظهر في الـ Detail.
- [ ] **Break attempt:** على جهاز A حاول حذف قائمة Hard Mode → تأكّد من
      أن الجهاز B استلم push notification خلال 5 ثوان.

⏱️ **الوقت:** 10 دقائق (مع زمن انتظار الـ push).

---

> **تذكير بعد ميرج الـ PR:**
> ```bash
> git checkout NoNet-Garage && git pull
> git tag -a v1.1.0 -m "Recovery Partner + Forever/Time-Limit + Resources"
> git push origin v1.1.0
> ```
> الـ tag على merge commit، ليس على الـ feature branch (مقاوم لـ rebase/squash).

---

## ⚡ الأولوية القصوى — افعلها اليوم

> هذه الثلاثة تأخذ وقتاً (Apple تنتظر)، فابدأها فوراً.

### 1️⃣ طلب Family Controls Distribution Entitlement
**لماذا؟** بدون هذا الـ entitlement، Apple ترفض التطبيق لأنه يستخدم FamilyControls API.

**كيف؟**
1. افتح: https://developer.apple.com/contact/request/family-controls-distribution
2. سجّل دخول بـ Apple Developer Account
3. املأ النموذج:
   - **App Name:** NoNet
   - **Bundle ID:** `com.nonetapp`
   - **Description:** Digital wellness app that helps users build healthier habits by blocking distracting apps and websites they choose. All blocking is local on the user's device. Uses FamilyControls for system-level shielding via FamilyActivityPicker + ManagedSettingsStore.
   - **Use Case:** Personal productivity, focus, sleep hygiene
   - **NOT a Parental Control app** (التطبيق للبالغين لإدارة عاداتهم الرقمية الشخصية)
4. **انتظر 1-2 أسبوع** للرد من Apple

**ملاحظة:** بدون هذا، التطبيق يبني ويعمل محلياً، لكن لا يُقبل في App Store.

---

### 2️⃣ إنشاء App Group في Apple Developer Portal
**لماذا؟** ليتمكّن BlockingMonitor extension من قراءة بيانات التطبيق الرئيسي.

**كيف؟**
1. افتح: https://developer.apple.com/account/resources/identifiers/list/applicationGroup
2. سجّل دخول
3. اضغط زر "+" → App Groups → Continue
4. املأ:
   - **Description:** NoNet Shared
   - **Identifier:** `group.com.nonetapp.shared`
5. Continue → Register

⏱️ **الوقت:** دقيقتان.

---

### 3️⃣ استضافة صفحات HTML
**لماذا؟** App Store Connect يطلب URL لسياسة الخصوصية والشروط والدعم.

**اختر طريقة واحدة:**

#### الخيار A: GitHub Pages (مجاني، الأسهل)
1. ادفع المشروع لـ GitHub: `git push origin NoNet-App`
2. اذهب لـ: `https://github.com/khalidnonet/<repo>/settings/pages`
3. Source: **GitHub Actions** (وليس Branch)
4. عند الـ push التالي، الـ workflow `.github/workflows/pages.yml` سينشر تلقائياً
5. URLs:
   - `https://khalidnonet.github.io/<repo>/` → index
   - `https://khalidnonet.github.io/<repo>/privacy.html`
   - `https://khalidnonet.github.io/<repo>/terms.html`
   - `https://khalidnonet.github.io/<repo>/support.html`

#### الخيار B: Vercel (أسرع، URLs أنظف)
```bash
cd "/Users/khalidkhamis/Desktop/مشروعي/blocking app الاصلي"
npx vercel
```
اتبع التعليمات. ستحصل على URL مثل `nonet-app.vercel.app`.
الـ rewrites موجودة في `vercel.json` — `/privacy` يعمل بدون `.html`.

#### الخيار C: نطاق مخصص (nonetapp.com)
1. اشترِ نطاق (Namecheap, Google Domains, ~10$ سنوياً)
2. اربطه بـ Vercel أو GitHub Pages
3. النتيجة: `https://nonetapp.com/privacy`

⏱️ **الوقت:** 5-30 دقيقة حسب الخيار.

---

## 🛠️ داخل Xcode — افعله بعد الانتهاء أعلاه

### 4️⃣ إضافة Tests + BlockingMonitor Targets
**استعمل السكريبت المساعد:**
```bash
cd "/Users/khalidkhamis/Desktop/مشروعي/blocking app الاصلي"
./scripts/add-targets-help.sh
```

السكريبت يفتح Xcode ويرشدك خطوة بخطوة. يأخذ ~10 دقائق.

النتيجة:
- ✅ Tests Target يضم الـ 32 اختبار
- ✅ BlockingMonitor extension يعمل في الخلفية
- ✅ App Groups capability في كلا الـ targets
- ✅ Family Controls capability للـ extension

---

### 5️⃣ ربط StoreKit Configuration بالـ Scheme
**كيف؟**
1. Xcode → Product → Scheme → Edit Scheme... (`Cmd+<`)
2. Run → Options → StoreKit Configuration → `Products.storekit`
3. هذا للاختبار **المحلي فقط**. **عطّله قبل Archive**.

⏱️ **الوقت:** دقيقة.

---

## 📱 اختبار على جهاز حقيقي

### 6️⃣ اختبار التطبيق على iPhone
**لماذا؟** FamilyControls **لا يعمل في Simulator** — يجب جهاز حقيقي.

**خطوات الاختبار:**
1. وصّل iPhone بالـ Mac
2. في Xcode → Scheme → Destination → اختر جهازك
3. `Cmd+R` للتشغيل
4. على الـ iPhone:
   - أكمل Onboarding
   - أنشئ قائمة جديدة
   - اضغط "Apps" — اقبل طلب Screen Time
   - اختر تطبيقين (مثلاً Instagram, TikTok)
   - احفظ القائمة
   - افتح Instagram → يجب أن يظهر شاشة الحجب
5. اختبر Hard Mode — حاول إيقاف القائمة → يجب أن يُرفض

✅ **معيار النجاح:** التطبيقات المختارة محجوبة فعلياً.

---

## 📸 لقطات الشاشة (App Store Connect يتطلبها)

### 7️⃣ التقاط Screenshots
**المقاسات المطلوبة:**
- **iPhone 6.7"** (iPhone 15 Pro Max) — 1290 × 2796 — **مطلوب 3-10 لقطات**
- **iPhone 6.5"** (iPhone 11 Pro Max) — 1242 × 2688 — اختياري لكن موصى به
- **iPad Pro 12.9"** (3rd-6th gen) — 2048 × 2732 — مطلوب إذا دعمت iPad

**كيف؟**
1. شغّل التطبيق في Simulator (`iPhone 15 Pro Max`)
2. اذهب للشاشة المرادة
3. `File → Save Screen Shot` أو `Cmd+S`
4. اللقطات تُحفظ على Desktop

**اللقطات المقترحة (5 على iPhone):**
1. HomeView مع قوائم متعددة
2. CreateListSheet — وضع Hard Mode
3. FamilyActivityPicker مع تطبيقات محددة (التقطها على جهاز حقيقي)
4. ScheduleEditorSheet
5. ChatBotView مع رد بالعربية

💡 **اختياري:** عدّل اللقطات في Figma أو Canva لإضافة عناوين تسويقية.

⏱️ **الوقت:** 30-60 دقيقة.

---

## 🍎 App Store Connect

### 8️⃣ إنشاء التطبيق والمنتجين
**يحتاج:** Apple Developer Program ($99/سنة).

**خطوات:**
1. https://appstoreconnect.apple.com → My Apps → "+"
2. New App → املأ:
   - **Platforms:** iOS
   - **Name:** NoNet
   - **Primary Language:** Arabic (Saudi Arabia)
   - **Bundle ID:** `com.nonetapp`
   - **SKU:** `nonet-001`

3. **Subscriptions** → Create Subscription Group: `NoNetPremium`
4. أنشئ منتجين داخل الـ group:
   - Reference Name: Monthly | Product ID: `com.nonetapp.monthly` | Duration: 1 Month | Free Trial: 1 Week
   - Reference Name: Yearly | Product ID: `com.nonetapp.yearly` | Duration: 1 Year | Free Trial: 1 Week

5. **App Information** → ملء:
   - Privacy Policy URL: `https://your-domain.com/privacy` (من الخطوة 3️⃣)
   - Support URL: `https://your-domain.com/support`
   - Marketing URL: `https://your-domain.com` (اختياري)

6. **App Privacy** → Data Collection: **None** (لا تجمع بيانات شخصية)

7. **انسخ النصوص من [docs/APP_STORE_LISTING.md](docs/APP_STORE_LISTING.md):**
   - Subtitle
   - Promotional Text
   - Description (AR + EN)
   - Keywords
   - What's New
   - Notes for App Review

⏱️ **الوقت:** 1-2 ساعة (متضمن قراءة وملء الحقول).

---

## 🚀 النشر النهائي

### 9️⃣ Archive + Upload + TestFlight + Submit
**الخطوات بالترتيب:**

1. **في Xcode:**
   - تأكد من Scheme = `blocking app` (مش Tests)
   - عطّل StoreKit Configuration (Edit Scheme → Run → Options → None)
   - Destination: `Any iOS Device (arm64)`
   - Product → Archive

2. **في Organizer (يفتح تلقائياً):**
   - Validate App → التحقق من المتطلبات
   - Distribute App → App Store Connect → Upload
   - أدخل Apple ID + password

3. **في App Store Connect:**
   - انتظر معالجة الـ build (5-15 دقيقة)
   - TestFlight → Internal Testing → ضع نفسك كـ tester
   - حمّل التطبيق على iPhone عبر TestFlight app
   - **اختبر كل شيء على جهاز حقيقي**

4. **عند الجاهزية:**
   - App Store → Prepare for Submission
   - أضف Screenshots من الخطوة 7️⃣
   - أضف Build من القائمة
   - **Submit for Review**

5. **انتظر:**
   - Apple Review: 24-48 ساعة عادة
   - في حال Rejection: اقرأ الرد، اصلح، أعد الإرسال
   - في حال Approval: 🎉 التطبيق على App Store!

⏱️ **الوقت:** 2-3 ساعات للإجراءات + 24-48 ساعة للـ Review.

---

## 🌐 اختياري — إضافة Community Links

تم **إخفاء** قسم Community (WhatsApp / Telegram) من SettingsView في v1.0 لأن:
- الروابط placeholders (`example.com`)
- App Store يرفض روابط لا تعمل

### لإعادة تفعيلها لاحقاً:
1. أنشئ مجموعة WhatsApp واحصل على invite link (`https://chat.whatsapp.com/XXXXXX`)
2. أنشئ قناة Telegram واحصل على رابطها (`https://t.me/your_channel`)
3. افتح [`blocking app/SettingsView.swift`](blocking app/SettingsView.swift)
4. ابحث عن التعليق `// Community section is hidden for v1.0`
5. استبدله بـ block جديد فيه الروابط الحقيقية
6. أعد البناء واختبر

---

## 📊 المتابعة بعد الإطلاق

### الأسبوع الأول:
- [ ] راقب App Store Connect Reviews وردّ على المستخدمين
- [ ] راقب StoreKit metrics (Subscriptions, Trials)
- [ ] راقب Crash reports في Xcode Organizer
- [ ] جمّع feedback لـ v1.1

### الشهر الأول:
- [ ] حدّث Keywords حسب أداء الـ ASO
- [ ] أضف Promotional Text موسمي
- [ ] اعمل Marketing campaign (مواقع تواصل، YouTube، Product Hunt)

### v1.1 المقترح:
- [ ] Auto-deactivation للقوائم المنتهية في الخلفية
- [ ] استخدام Onboarding data لتخصيص الاقتراحات
- [ ] Localizable.strings (نقل النصوص inline)
- [ ] Server-side receipt validation
- [ ] Widget Extension

---

## 🆘 إذا واجهت مشكلة

### Apple رفض الـ entitlement Family Controls
- اقرأ سبب الرفض بعناية
- في 90% الحالات: السبب هو وصف غامض. أعد الطلب مع تفصيل أكثر:
  - "هذا تطبيق رفاهية رقمية للمستخدم البالغ لإدارة عاداته الشخصية، ليس تطبيق رقابة أبوية"
  - "يستخدم FamilyActivityPicker لاختيار التطبيقات + ManagedSettings لتطبيق الحجب"

### App Store رفض الإصدار
**أسباب شائعة:**
- "Insufficient app functionality" → أضف ميزات أكثر أو شاشات
- "Privacy Policy missing details" → حدّث الـ HTML pages
- "Subscription lacks restoring" → ✅ موجود في UpgradeView
- "Crashes during review" → اختبر أكثر على جهاز حقيقي

### StoreKit لا يحمل المنتجات في Sandbox
- تأكد من Bundle ID في الـ build يطابق App Store Connect: `com.nonetapp`
- تأكد من المنتجات في حالة "Ready to Submit" أو "Approved"
- StoreKit Configuration في Scheme **معطّل** (للاختبار الحقيقي عبر Sandbox)
- استخدم Sandbox Tester account (يُنشأ في App Store Connect → Users)

### الـ Web Pages لا تظهر
- GitHub Pages: اذهب لـ repo Settings → Pages → تأكد من Source = GitHub Actions
- Vercel: تأكد من `vercel.json` موجود + commit ودفع
- DNS: انتظر ساعة لانتشار الـ DNS records

---

## 📞 الدعم والمراجع

- **Apple Developer Forums:** https://developer.apple.com/forums/
- **App Store Review Guidelines:** https://developer.apple.com/app-store/review/guidelines/
- **TestFlight Guide:** https://developer.apple.com/testflight/
- **StoreKit 2 Documentation:** https://developer.apple.com/documentation/storekit
- **FamilyControls Documentation:** https://developer.apple.com/documentation/familycontrols

---

## ✅ Checklist سريعة للطباعة

ضع علامة ✓ عند الإنجاز:

- [ ] طلب Family Controls Distribution Entitlement
- [ ] إنشاء App Group في Apple Developer
- [ ] استضافة web pages على GitHub Pages أو Vercel
- [ ] إضافة Tests Target + BlockingMonitor Target في Xcode
- [ ] تفعيل App Groups في كلا الـ targets
- [ ] ربط Products.storekit بـ Scheme
- [ ] اختبار التطبيق على iPhone حقيقي
- [ ] التقاط 5+ Screenshots للـ App Store
- [ ] إنشاء التطبيق في App Store Connect
- [ ] إنشاء المنتجين (Monthly + Yearly)
- [ ] ملء App Information + Privacy + URLs
- [ ] نسخ النصوص من docs/APP_STORE_LISTING.md
- [ ] Archive في Xcode
- [ ] Upload إلى App Store Connect
- [ ] اختبار عبر TestFlight
- [ ] Submit for Review
- [ ] الإطلاق 🚀

---

**حظاً موفقاً يا خالد! المشروع جاهز فعلياً، باقي عليك فقط الأمور الإدارية والتوقيع.** 💪

— تم بناء كل هذا بمنهجية gstack وفق أفضل الممارسات.
