# 🆘 دليل استعادة المشروع (Recovery Guide)

> ماذا تفعل لو فُقد الجهاز، انحذف المجلد، تغيّر اللابتوب، أو حصل أي كارثة.
> النسخة الكاملة محفوظة على GitHub — اتبع الخطوات أدناه لاستعادتها.

---

## 🔐 معلومات المشروع الأساسية

| الحقل | القيمة |
|---|---|
| **اسم الـ Repo على GitHub** | `KxxLxD/NoNet-Last-one-with-Al-Garage` |
| **الرابط الكامل** | https://github.com/KxxLxD/NoNet-Last-one-with-Al-Garage |
| **الفرع الرئيسي للعمل** | `NoNet-App` ← آخر إصدار v1.4.0 |
| **الفرع الافتراضي على GitHub** | `NoNet-Garage` ← فرع قديم، لا تستخدمه للعمل الجديد |
| **آخر إصدار مُعنون (tag)** | `v1.4.0` |

---

## 📥 السيناريو 1 — استعادة المشروع على جهاز جديد

### الخطوة 1: ثبّت الأدوات الأساسية

```bash
# تأكد إن Git موجود
git --version

# لو غير موجود، نزّل Xcode Command Line Tools:
xcode-select --install
```

ثم سجّل دخولك في GitHub محلياً (مرة وحدة فقط):

```bash
gh auth login
# اختار: GitHub.com → HTTPS → Login with browser
```

### الخطوة 2: انسخ (clone) المشروع

```bash
cd ~/Desktop
git clone https://github.com/KxxLxD/NoNet-Last-one-with-Al-Garage.git nonet-app
cd nonet-app
```

### الخطوة 3: انتقل إلى فرع العمل الصحيح

```bash
git checkout NoNet-App
```

### الخطوة 4: افتح Xcode

```bash
open "blocking app.xcodeproj"
```

✅ خلصت. المشروع كامل وكل التاريخ معك.

---

## 🔁 السيناريو 2 — لقيت نسخة قديمة وتبي تحدّثها

```bash
cd /المسار/الى/المشروع
git fetch origin --tags        # اسحب آخر التحديثات + الـ tags
git checkout NoNet-App         # تأكد إنك على الفرع الصحيح
git pull origin NoNet-App      # اسحب آخر commits
```

---

## 🏷️ السيناريو 3 — تبي ترجع لنسخة قديمة (مثلاً v1.2.0)

```bash
git checkout v1.2.0           # تنتقل لحالة المشروع وقت إصدار v1.2.0
```

للرجوع لآخر نسخة:

```bash
git checkout NoNet-App
```

---

## 📋 الإصدارات المتاحة (Tags)

| Tag | التاريخ | الوصف |
|---|---|---|
| `v1.0.0-pre-launch` | 2026-05-22 | النسخة الأولى قبل الإطلاق |
| `v1.1.0` | 2026-05-22 | Recovery Partner (CloudKit) |
| `v1.2.0` | 2026-05-25 | تحديث build settings + polish |
| `v1.3.0` | 2026-05-25 | Accessibility + FAQ |
| `v1.4.0` | 2026-05-27 | Architecture review + offline-safety |

اعرض كلها:

```bash
git tag -l
```

---

## 🛡️ ممارسات الأمان (للمستقبل)

### بعد كل جلسة عمل مهمة

```bash
git status              # شف وش تغيّر
git add .               # ضيف كل التغييرات
git commit -m "وصف موجز للتغيير"
git push                # ادفع لـ GitHub فوراً
```

### كل أسبوع (روتين بسيط)

```bash
git push --all          # ادفع كل الفروع
git push --tags         # ادفع كل الـ tags
```

### قبل أي تجربة محفوفة بالمخاطر

```bash
git commit -am "WIP: قبل تجربة X"     # احفظ الحالة
git push                              # رفع نسخة احتياطية
```

### لو خربت شي وتبي ترجع

```bash
git stash               # احفظ التغييرات الحالية بعيداً
git checkout .          # ارجع الملفات لآخر commit (تحذير: يمحي تعديلاتك)
git reset --hard HEAD   # نفس الفكرة لكن أقوى
```

---

## ⚠️ ملفات ما تكون على GitHub (وهذا متعمّد)

ملف `.gitignore` يستثني:
- 🔑 شهادات التوقيع (`*.p12`, `*.pem`, `*.mobileprovision`)
- 🔐 ملفات الأسرار (`.env`, `secrets.json`, `GoogleService-Info.plist`)
- 🛠️ ملفات Xcode الشخصية (`xcuserdata/`, `DerivedData/`, `build/`)
- 🤖 ملفات AI tooling (`.claude/`, `.gstack/`)

**هذه الملفات تبقى على جهازك فقط، ولو ضاع الجهاز:**
- شهادات التوقيع → تُستخرج من جديد من Apple Developer Portal
- مفاتيح API → يُعاد إنشاؤها من لوحات تحكم الخدمات (لا تخزّن سواها في Keychain)

---

## 🆘 لو واجهت مشكلة

1. **GitHub لا يقبل الـ push** → سجل دخول من جديد: `gh auth login`
2. **خطأ "diverged branches"** → اسحب أولاً: `git pull --rebase origin NoNet-App`
3. **Xcode ما يفتح المشروع** → امسح `DerivedData`:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
4. **Family Controls ما تشتغل** → طبيعي على Simulator، تحتاج جهاز iPhone حقيقي.

---

## 📞 جهات اتصال الخدمات (إذا احتجت تعيد ضبط شي)

| الخدمة | للوصول |
|---|---|
| Apple Developer | developer.apple.com |
| App Store Connect | appstoreconnect.apple.com |
| CloudKit Dashboard | icloud.developer.apple.com/dashboard |
| GitHub | github.com/KxxLxD |

---

**آخر تحديث:** 2026-05-27
**النسخة:** v1.4.0
