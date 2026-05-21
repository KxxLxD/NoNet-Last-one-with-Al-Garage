# 📚 دليل gstack الكامل بالعربية

دليلك الشخصي لاستعمال **gstack** على مشروع NoNet — افتح هذا الملف في أي وقت كمرجع.

> 💡 **gstack** = مجموعة 30+ أداة (Skills) تحوّل Claude Code إلى فريق هندسي افتراضي (مدير منتج، مهندس، مصمم، مراجع، QA، أمن، نشر) — كلها مجانية ومفتوحة المصدر.

---

## 📌 جدول المحتويات

1. [ما هو gstack ولماذا؟](#1-ما-هو-gstack-ولماذا)
2. [حالة التثبيت عندك](#2-حالة-التثبيت-عندك)
3. [القاعدة الذهبية](#3-القاعدة-الذهبية)
4. [سير العمل النموذجي (Sprint)](#4-سير-العمل-النموذجي-sprint)
5. [دليل الـ Skills بالتفصيل](#5-دليل-الـ-skills-بالتفصيل)
6. [سير عمل مخصّص لـ iOS Swift](#6-سير-عمل-مخصّص-لـ-ios-swift)
7. [Power Tools (أدوات الأمان والمساعدة)](#7-power-tools)
8. [4 سيناريوهات كاملة محلولة](#8-سيناريوهات-كاملة)
9. [استكشاف الأخطاء](#9-استكشاف-الأخطاء)
10. [مرجع سريع — جدول كل الأوامر](#10-مرجع-سريع)
11. [GBrain — الذاكرة الدائمة (متقدم)](#11-gbrain-اختياري)

---

## 1) ما هو gstack ولماذا؟

**gstack** هو 30+ "skill" (مهارة) تضاف إلى Claude Code، كل واحدة منها تلعب دور متخصص محترف:

- **`/office-hours`** = مستشار Y Combinator يسألك أسئلة صعبة قبل أن تبني
- **`/plan-eng-review`** = مدير هندسي يراجع معماريتك
- **`/review`** = مهندس أول يبحث عن bugs في diff الفرع
- **`/qa`** = QA Lead يفتح المتصفح ويختبر تطبيقك
- **`/cso`** = ضابط أمن يفحص OWASP/STRIDE
- **`/ship`** = مهندس نشر يدفع PR إلى GitHub

بدل أن تجلس وحدك مع Claude عشوائياً، تستعمل أوامر مرتّبة تلعب أدواراً مختلفة على نفس الكود.

### لماذا يستحق التعلّم؟
- **عمل أسرع 10×** — وفقاً لـ Garry Tan (مؤسس gstack ورئيس Y Combinator)، يشحن كود بمعدل ~810× ما كان عليه عام 2013.
- **جودة أعلى** — كل skill يطبّق ممارسة فضلى محددة (تجنّب الافتراضات، فحص race conditions، توثيق تلقائي).
- **عدم النسيان** — gstack يتذكّر بين الجلسات (gbrain) ويحدّث الوثائق تلقائياً.

---

## 2) حالة التثبيت عندك

### الإصدار المثبَّت
```
~/.claude/skills/gstack/  →  v1.40.0.0 (أحدث إصدار وقت كتابة الملف)
```

### الوضع
**Team Mode (Required)** — تعني:
- يتحدّث تلقائياً عند بدء كل جلسة Claude Code (مرة كل ساعة)
- مفعّل لمشروع NoNet عبر `.claude/hooks/check-gstack.sh`
- لو فتحت المشروع على جهاز آخر بدون تثبيت gstack → Claude سيرفض العمل ويطلب التثبيت

### الـ Skills المتاحة لك (38 skill)
**Planning & Strategy:** `/office-hours`, `/plan-ceo-review`, `/plan-eng-review`, `/plan-design-review`, `/plan-devex-review`, `/autoplan`

**Design:** `/design-consultation`, `/design-shotgun`, `/design-html`, `/design-review`

**Build & Review:** `/review`, `/codex`, `/investigate`, `/learn`

**Testing & QA:** `/qa`, `/qa-only`, `/devex-review`, `/canary`, `/benchmark`

**Browser:** `/browse`, `/open-gstack-browser`, `/setup-browser-cookies`, `/pair-agent`

**Documentation:** `/document-release`, `/document-generate`

**Release:** `/ship`, `/land-and-deploy`

**Security:** `/cso`

**Reflection:** `/retro`

**Safety:** `/careful`, `/freeze`, `/guard`, `/unfreeze`

**Maintenance:** `/gstack-upgrade`, `/setup-gbrain`, `/sync-gbrain`, `/setup-deploy`

**Memory:** `/context-save`, `/context-restore`, `/scrape`, `/skillify`

---

## 3) القاعدة الذهبية

**استعمل الأمر المناسب في الوقت المناسب — لا تستعملهم كلهم على كل مهمة.**

| المرحلة | الأمر |
|--------|-----|
| فكرة جديدة | `/office-hours` |
| تخطيط ميزة | `/plan-eng-review` (أو `/autoplan` للكل دفعة واحدة) |
| كتابة كود | (لا أمر — اطلب من Claude مباشرة) |
| مراجعة قبل merge | `/review` |
| اختبار يدوي | `/qa` (للويب) أو يدوياً (لـ iOS) |
| نشر | `/ship` |
| بعد الإطلاق | `/document-release` + `/retro` |

**في مشروع iOS مثل NoNet:** بعض الأوامر لا تنطبق (مثل `/qa` و `/design-review` و `/canary` — صُمّمت للويب). راجع [القسم 6](#6-سير-عمل-مخصّص-لـ-ios-swift) لمعرفة المنطبقة.

---

## 4) سير العمل النموذجي (Sprint)

```
🧠 Think  →  📋 Plan  →  🛠️ Build  →  🔍 Review  →  🧪 Test  →  🚀 Ship  →  📝 Reflect
   |          |           |             |            |          |          |
/office-   /autoplan    Claude         /review     /qa (web)   /ship    /document-
hours      أو 3 منفصلة   (يدوي)        أو /codex   يدوي (iOS)            release
                                                                          /retro
```

كل أمر يكتب output يستفيد منه الأمر التالي. هذا "compounding" — كل skill يبني على عمل سابق.

### مثال مختصر للسير الكامل

```
You:  أبغى أضيف ميزة "إيقاف فوري لـ 24 ساعة"
You:  /office-hours
Claude: [يسألك 6 أسئلة استفزازية]
You:  [تجاوب]
Claude: [يكتب design doc في docs/]

You:  /autoplan  ← يشغل CEO + Eng + Design + DX reviews تلقائياً
Claude: [بعد 4-5 دقائق] خطة جاهزة في docs/PLAN-XXX.md

You:  نفّذ الخطة
Claude: [يكتب الكود]

You:  /review
Claude: [يفحص الـ diff ويحدد مشاكل]

You:  /ship
Claude: [يبني، يدفع، يفتح PR]
```

---

## 5) دليل الـ Skills بالتفصيل

### 🧠 Skills التخطيط

#### `/office-hours`
**ما هو؟** مستشار Y Combinator. يسألك 6 أسئلة استفزازية قبل أي بناء.

**متى تستعمله؟**
- لديك فكرة منتج جديدة لكن لست متأكداً منها
- تشعر أن المشكلة غامضة
- قبل /autoplan لأي ميزة كبيرة

**مثال على NoNet:**
```
أبغى أضيف ميزة Family Mode للآباء يتحكمون بأطفالهم
/office-hours
```
gstack يسأل:
1. مَن الذي يعاني فعلاً من هذه المشكلة؟ صف شخصاً واحداً بالتفصيل.
2. ما الـ status quo اليوم؟ كيف يحلّون المشكلة بدون منتجك؟
3. ما الـ specific behavior الذي ستغيّره؟
4. ما الـ narrowest wedge (أصغر ميزة فعّالة)؟
5. ماذا لاحظت بنفسك يدفعك لبناء هذا؟
6. كيف يتطوّر هذا في 5 سنوات؟

النتيجة: design doc في `docs/` يُستخدم في كل الـ skills التالية.

---

#### `/plan-ceo-review`
**ما هو؟** CEO/مؤسس يعيد التفكير في النطاق. هل تبني نسخة 10/10 أم نسخة 5/10؟

**متى تستعمله؟**
- بعد `/office-hours` أو عندك خطة جاهزة
- تشعر أن الخطة ضيقة جداً أو واسعة جداً

**4 أوضاع:**
- **Expansion** — احلم كبير (10-star product)
- **Selective Expansion** — احتفظ بالنطاق + اختر إضافات
- **Hold Scope** — صرامة في النطاق الحالي
- **Reduction** — اقطع الزائد، احتفظ بالأساس

**مثال:**
```
الخطة: إضافة تنبيه عند انتهاء الحجب
/plan-ceo-review
```
gstack يسأل: لماذا تنبيه فقط؟ هل يمكن أن يكون لحظة احتفال (animation + statistics + share)؟

---

#### `/plan-eng-review`
**ما هو؟** Engineering Manager يقفل المعمارية قبل البناء.

**متى تستعمله؟**
- خطة جاهزة، قبل كتابة الكود
- معمارية معقدة (data flow، state machine، concurrency)

**يطلب:**
- ASCII diagrams لتدفق البيانات
- Test matrix
- Failure modes
- Security concerns

**مثال على NoNet:**
```
سأضيف schedule recurrence (تكرار أسبوعي)
/plan-eng-review
```
gstack يطلب: ارسم state machine لـ "مجدول/نشط/منتهي/متوقف". ماذا يحدث لو غيّر المستخدم وقت الجهاز؟

---

#### `/plan-design-review`
**ما هو؟** مصمم محترف يقيّم خطة الواجهة 0-10 لكل بُعد.

**متى تستعمله؟**
- خطة فيها UI/UX
- قبل أن يكتب Claude الـ Views

**مثال:**
```
الخطة: شاشة جديدة لإحصائيات الاستخدام
/plan-design-review
```
يقيّم: تسلسل بصري (8/10)، تباين (6/10)، حركة (5/10)، RTL (10/10). ويشرح ماذا يلزم لكل بُعد ليصبح 10.

---

#### `/autoplan`
**ما هو؟** يشغّل /plan-ceo-review + /plan-eng-review + /plan-design-review + /plan-devex-review **تلقائياً** ويتخذ القرارات بدلاً منك.

**متى تستعمله؟**
- خطة جاهزة، لا تريد 30 سؤال
- تثق في الـ defaults
- وقتك ضيق

**مثال:**
```
docs/PLAN-feature-x.md جاهزة
/autoplan
```
gstack يشغّل كل المراجعات، يحلّ الاختلافات تلقائياً، ويسألك فقط في القرارات الفنية الذوقية.

---

### 🛠️ Skills البناء والمراجعة

#### `/review`
**ما هو؟** مهندس أول يراجع الـ diff قبل merge. يبحث عن:
- SQL safety issues
- LLM trust boundary violations
- Conditional side effects
- Race conditions
- Force unwraps
- Missing tests

**متى تستعمله؟**
- قبل `/ship`
- بعد تغييرات كبيرة
- على أي فرع فيه commits

**مثال على NoNet:**
```
أنهيت BlockingEngine + تكاملاته
/review
```
gstack يفحص الـ diff ويقترح: "في BlockingEngine.deactivate، الـ Hard Mode check يحدث على main thread. هل تأكدت من concurrency؟"

---

#### `/codex`
**ما هو؟** رأي ثاني من OpenAI Codex CLI (موديل مختلف عن Claude). 3 أوضاع:
- `/codex review` — مراجعة مستقلة بـ pass/fail
- `/codex challenge` — محاولة كسر كودك
- `/codex consult` — استشارة مفتوحة

**متى تستعمله؟**
- بعد `/review` لرأي ثاني
- لكسر تحيّز Claude
- قبل قرار معماري كبير

**يحتاج:** Codex CLI مثبت + OpenAI API key.

---

#### `/investigate`
**ما هو؟** Debugger ممنهج. الـ Iron Law: **لا إصلاح بدون root cause**.

**4 مراحل:** investigate → analyze → hypothesize → implement.

**متى تستعمله؟**
- خطأ معقد، يصعب فهمه
- bug يحدث أحياناً فقط
- "كان يعمل أمس، تعطّل اليوم"

**مثال:**
```
ListEntity scheduleSlots ترجع nil أحياناً لكن في الـ DB موجودة
/investigate
```
gstack: 
1. يقرأ كود الـ encode/decode
2. يفحص migration history
3. يجرب decode على بيانات حقيقية
4. يحدد السبب الجذري (مثلاً: version mismatch في JSON)
5. يقترح الإصلاح

---

#### `/learn`
**ما هو؟** ذاكرة المشروع. يتذكّر patterns ودروس بين الجلسات.

**متى تستعمله؟**
- "هل واجهنا هذا قبل؟"
- لمشاركة دروس مع زميل
- لتنظيف ذاكرة قديمة

**أوامر فرعية:**
- `/learn list` — كل الدروس
- `/learn search <keyword>` — بحث
- `/learn add <text>` — أضف يدوياً
- `/learn prune` — احذف القديم

---

### 🧪 Skills الاختبار

> ⚠️ **`/qa`, `/qa-only`, `/design-review`, `/canary`, `/browse`, `/benchmark`** كلها مخصصة **للويب**. لن تعمل على NoNet لأنه iOS app. لاختبار iOS اعتمد على Xcode + جهاز حقيقي.

#### `/devex-review`
**ما هو؟** اختبار حي لتجربة المطوّر. هل README واضح؟ هل التشغيل سريع؟ هل الأخطاء مفهومة؟

**مفيد لـ NoNet؟** نعم — يفحص README.md ويختبره. (لكنه يفترض onboarding flow عبر CLI/docs، فمحدود في iOS.)

---

### 🚀 Skills النشر

#### `/ship`
**ما هو؟** Release Engineer:
1. يفحص git status
2. يبني المشروع
3. يحدّث VERSION + CHANGELOG (لو موجودين)
4. ينشئ commit
5. يدفع للـ remote
6. يفتح PR على GitHub

**متى تستعمله؟**
- تغييرات جاهزة، تبيها merge
- لا تريد عمل ship يدوياً

**مثال على NoNet:**
```
أنهيت Phase 8، أبغى ship
/ship
```
gstack: 
- يبني `xcodebuild` — يتأكد لا errors
- يلخّص الـ diff
- يقترح PR title + body
- يدفع للـ remote
- يفتح PR

> ⚠️ NoNet على GitHub Private. تأكد أن `gh` CLI مسجل دخوله: `gh auth status`.

---

#### `/land-and-deploy`
**ما هو؟** بعد PR approval: يدمج، ينتظر CI، ينشر، يتحقق من الإنتاج.

**مفيد لـ NoNet؟** جزئياً — NoNet ليس deployed كـ web service. لكن لو لاحقاً أضفت TestFlight CI، يصبح مفيداً.

---

### 📜 Skills التوثيق

#### `/document-release`
**ما هو؟** بعد ship: يقرأ كل docs ويحدّث ما تغيّر.

**متى تستعمله؟**
- بعد ميزة كبيرة
- README/ARCHITECTURE قديم

**مثال:**
```
أضفنا BlockingEngine جديد
/document-release
```
gstack: يحدّث README.md (قسم البناء)، ARCHITECTURE.md (إضافة diagram للحجب)، CHANGELOG.md.

---

#### `/document-generate`
**ما هو؟** يكتب وثائق من الصفر باستخدام Diataxis (tutorial/how-to/reference/explanation).

**متى تستعمله؟**
- مشروع بدون docs
- إضافة tutorial لميزة

---

### 🔐 Skills الأمن

#### `/cso`
**ما هو؟** Chief Security Officer. يطبّق OWASP Top 10 + STRIDE threat model. **زيرو نويز** (يستبعد 17 false positive).

**وضعان:**
- `daily` — فحص سريع، confidence 8/10+
- `comprehensive` — فحص شهري شامل، confidence 2/10+

**متى تستعمله؟**
- قبل أول إطلاق
- شهرياً
- بعد إضافة integration خارجي

**مثال على NoNet:**
```
/cso
```
gstack: يفحص:
- Hardcoded secrets ✅ لا يوجد
- StoreKit verification — هل التحقق من Receipt على server؟ ⚠️ TODO
- Sign in with Apple — هل تستخدم nonce؟ ✅ نعم
- UserDefaults حساسة؟ ✅ تم نقلها لـ Keychain
- Family Controls — هل تحجب فعلياً؟ ✅ نعم

---

### 🪞 Skills الانعكاس

#### `/retro`
**ما هو؟** Retrospective أسبوعي. يحلّل commits، يقترح تحسينات.

**متى تستعمله؟**
- نهاية الأسبوع
- بعد ميزة كبيرة
- شهرياً

**مثال:**
```
/retro
```
gstack: 
- "هذا الأسبوع: 47 commit، 12,000 سطر"
- "تركيز رئيسي: Phases 1-8 لإعادة هيكلة"
- "نقاط القوة: separation of concerns ممتاز في Core/"
- "مجالات للنمو: لا اختبارات بعد"

---

## 6) سير عمل مخصّص لـ iOS Swift

### ✅ Skills تنطبق على NoNet
- `/office-hours` — يصلح لأي منتج
- `/plan-ceo-review` — يصلح لأي منتج
- `/plan-eng-review` — يصلح لأي architecture
- `/autoplan` — يصلح
- `/review` — يصلح على diff
- `/codex` — يصلح لرأي ثاني
- `/investigate` — يصلح لأي bug
- `/learn` — يصلح
- `/cso` — يصلح للأمن
- `/document-release` — يصلح
- `/document-generate` — يصلح
- `/retro` — يصلح
- `/ship` — يصلح (يبني عبر xcodebuild)
- `/careful`, `/freeze`, `/guard`, `/unfreeze` — يصلحون
- `/context-save`, `/context-restore` — يصلحون
- `/gstack-upgrade` — يصلح
- `/setup-gbrain` — يصلح

### ⚠️ Skills لا تنطبق (web-only)
- `/qa`, `/qa-only` — للمتصفح
- `/design-review`, `/plan-design-review` — جزئياً يصلح لـ SwiftUI لكن مصمّم للويب
- `/canary` — مراقبة post-deploy للويب
- `/benchmark` — Web Vitals
- `/browse`, `/open-gstack-browser` — للمتصفح
- `/setup-browser-cookies`, `/scrape`, `/skillify` — للويب
- `/setup-deploy`, `/land-and-deploy` — للويب
- `/pair-agent` — للمتصفح
- `/design-shotgun`, `/design-html`, `/design-consultation` — للويب

### 💡 توصيتي لروتين NoNet الأسبوعي

**يومياً (إن عملت):**
- `/review` قبل أي merge

**نهاية كل ميزة:**
1. `/document-release`
2. `/ship`

**أسبوعياً:**
- `/retro` (السبت/الأحد)
- `/learn list` (لتذكير نفسك بالـ patterns)

**شهرياً:**
- `/cso comprehensive`
- `/gstack-upgrade`

---

## 7) Power Tools

### `/careful`
يحذّرك قبل أي أمر مدمّر: `rm -rf`, `git reset --hard`, `git push --force`, `DROP TABLE`, إلخ.

**استعمله عند:** العمل على فرع main، تعديل بيانات إنتاج، أي عمل يقلقك.

**مثال:**
```
/careful
[تشتغل، تكتب أمر force-push]
gstack: ⚠️ هذا يكتب فوق سجل remote. هل أنت متأكد؟ [y/n]
```

---

### `/freeze [path]`
يمنع Claude من تعديل ملفات خارج مسار محدّد. مفيد للـ debugging.

**مثال:**
```
أبغى أصلح bug في BlockingEngine فقط، لا تلمس باقي الكود
/freeze "blocking app/Core/BlockingEngine.swift"
```
أي محاولة تعديل ملف آخر → يُرفض.

---

### `/guard`
`/careful` + `/freeze` معاً. للحالات الحرجة.

---

### `/unfreeze`
يلغي `/freeze`.

---

### `/context-save` / `/context-restore`
يحفظ ويستعيد سياق الجلسة (decisions، work in progress).

**مثال:**
```
أنا في منتصف debug، أبغى أنام
/context-save
[في الصباح]
/context-restore
gstack: [يلخّص أين كنت + ما المتبقي]
```

---

### `/gstack-upgrade`
ترقية gstack لأحدث إصدار. (تحدث تلقائياً في team mode كل ساعة، لكن يدوياً متاح.)

---

## 8) سيناريوهات كاملة

### 🎬 السيناريو 1: إضافة ميزة جديدة من الصفر

**الهدف:** إضافة Widget Extension لعرض حالة الحجب على الـ Home Screen.

```
You:  أبغى Widget للحجب
You:  /office-hours
gstack: [يسأل 6 أسئلة عن المستخدم، الـ pain، الـ wedge]
You:  [تجاوب]
gstack: [يكتب docs/PLAN-widget.md]

You:  /autoplan
gstack: [يشغّل CEO + Eng + Design + DX reviews]
        يسأل: "Widget يعرض المؤقت لـ list واحدة فقط، أم آخر 3؟"
You:   3
gstack: [يحدّث docs/PLAN-widget.md النهائية]

You:  نفّذ
Claude: [يضيف Widget Extension target، يكتب الـ View، يربط بـ shared App Group]

You:  /review
gstack: ⚠️ App Group ID غير موجود في الـ entitlements. أضفته في الـ Widget لكن
        ليس في التطبيق الرئيسي. الـ shared UserDefaults لن يعمل.
You:  أصلح
Claude: [يضيف]

You:  /document-release
gstack: [يحدّث README.md + ARCHITECTURE.md]

You:  /ship
gstack: [يبني xcodebuild → ينجح → يدفع → يفتح PR]
```

---

### 🎬 السيناريو 2: إصلاح bug في الإنتاج

**الهدف:** المستخدمون يبلغون أن "delete list يتعطل أحياناً".

```
You:  مستخدم بلّغ crash عند delete list
You:  /investigate

gstack: 
[Phase 1: investigate]
- يقرأ HomeView.deleteList
- يقرأ BlockingEngine.purge
- يقرأ Core Data context

[Phase 2: analyze]
- يلاحظ: ManualStateStore.clear يحدث بعد context.delete
- لو الـ delete رمى exception، الـ clear لن يحدث
- => orphan data

[Phase 3: hypothesize]
- "أعتقد المشكلة في تسلسل العمليات"

[Phase 4: implement]
- يقترح: نقل clear قبل delete، أو try-catch مع defer

You:  نفّذ
Claude: [يطبّق defer]

You:  /review
gstack: ✅ نظيف

You:  /ship
```

---

### 🎬 السيناريو 3: مراجعة كود زميل (PR)

**الهدف:** زميل أرسل PR، تريد مراجعته بعمق.

```
You:  راجع PR #42

You:  /review
gstack: [يقرأ git diff main..feature-x]
        [يفحص SQL, LLM, race, force unwraps, tests]
        [يكتب التقرير]

You:  /codex review
gstack: [يطلب رأي OpenAI Codex على نفس الـ diff]
        [يقارن findings — هل overlap؟]

You:  [الـ findings 80% متطابقة → عالية الثقة]
You:  [الـ findings المختلفة → تحقّق يدوياً]

You:  /cso
gstack: [فحص أمني سريع على الـ diff فقط]
```

---

### 🎬 السيناريو 4: استكشاف فكرة جديدة

**الهدف:** فكرة جديدة "تطبيق Pomodoro مدمج بـ NoNet". هل يستحق؟

```
You:  /office-hours
gstack: [6 أسئلة]
You:  [تجاوب — تكتشف أن المستخدم الحقيقي ليس واضحاً]
gstack: قبل البناء، شوف Forest و Flora. ابدأ بـ wedge صغير.

You:  /plan-ceo-review
gstack: 4 خيارات:
1. EXPANSION: Pomodoro + analytics + AI coach (3 شهور)
2. SELECTIVE: Pomodoro + integration مع blocklist (شهر)
3. HOLD: Pomodoro بسيط (أسبوعين)
4. REDUCTION: لا تبنيه — ميزة `now-block-for-25-min` كافية (يوم)

You:  4 — REDUCTION
[تنفذ في يوم بدل 3 شهور — أفضل قرار]
```

---

## 9) استكشاف الأخطاء

### Claude لا يرى الـ skills
```bash
# تحقق من gstack
test -d ~/.claude/skills/gstack/bin && echo OK || echo MISSING

# تحقق من CLAUDE.md في المشروع
cat CLAUDE.md | grep gstack

# إعادة setup
cd ~/.claude/skills/gstack && ./setup --team
```

### `/ship` يفشل
```bash
# تأكد من gh CLI
gh auth status

# أو نفّذ يدوياً
git push -u origin <branch>
gh pr create
```

### `/review` بطيء
- طبيعي على diffs كبيرة (>1000 سطر)
- استخدم: راجع جزء فقط
  ```
  /review blocking app/Core/
  ```

### gstack قديم
```bash
/gstack-upgrade
# أو يدوياً:
cd ~/.claude/skills/gstack && git pull && ./setup --team
```

### Hook يمنع الأوامر
الـ check-gstack.sh يفحص وجود gstack. لو حُذف:
```bash
git clone --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack
cd ~/.claude/skills/gstack && ./setup --team
```

---

## 10) مرجع سريع

### الأوامر الأكثر استعمالاً (Top 10)
| الأمر | الغرض | متى |
|------|------|------|
| `/office-hours` | استفسار قبل البناء | فكرة جديدة |
| `/autoplan` | كل المراجعات دفعة واحدة | خطة جاهزة |
| `/review` | مراجعة diff | قبل merge |
| `/investigate` | debug ممنهج | bug معقد |
| `/cso` | فحص أمني | شهرياً |
| `/ship` | بناء + دفع + PR | تغييرات جاهزة |
| `/document-release` | تحديث docs | بعد ميزة كبيرة |
| `/retro` | retrospective | أسبوعياً |
| `/learn list` | الدروس | "هل واجهنا هذا؟" |
| `/gstack-upgrade` | ترقية gstack | شهرياً |

### كل الـ Skills (للمسح السريع)
| Skill | الغرض |
|-------|------|
| `/office-hours` | YC Office Hours — 6 أسئلة استفزازية |
| `/plan-ceo-review` | CEO/founder review (4 modes) |
| `/plan-eng-review` | Engineering Manager review |
| `/plan-design-review` | Design rating 0-10 |
| `/plan-devex-review` | Developer experience review |
| `/design-consultation` | بناء نظام تصميم من الصفر |
| `/design-shotgun` | 4-6 mockups + iteration |
| `/design-html` | mockup → production HTML |
| `/design-review` | live design audit (web) |
| `/autoplan` | كل المراجعات تلقائياً |
| `/review` | code review قبل merge |
| `/codex` | رأي ثاني من OpenAI Codex |
| `/investigate` | root cause debugging |
| `/learn` | ذاكرة المشروع |
| `/qa` | QA testing + fixing (web) |
| `/qa-only` | report only (web) |
| `/devex-review` | live DX audit |
| `/canary` | post-deploy monitoring |
| `/benchmark` | Web Vitals (web) |
| `/browse` | browser automation |
| `/open-gstack-browser` | يفتح GStack Browser |
| `/setup-browser-cookies` | استيراد cookies |
| `/pair-agent` | تعاون متعدد الوكلاء |
| `/cso` | فحص أمني OWASP+STRIDE |
| `/ship` | build + push + PR |
| `/land-and-deploy` | merge + deploy + verify |
| `/document-release` | تحديث docs بعد ship |
| `/document-generate` | docs من الصفر |
| `/retro` | retrospective أسبوعي |
| `/careful` | تحذيرات قبل المدمّر |
| `/freeze` | قفل التعديلات لـ path |
| `/guard` | careful + freeze |
| `/unfreeze` | إلغاء freeze |
| `/gstack-upgrade` | ترقية gstack |
| `/setup-gbrain` | تهيئة gbrain (ذاكرة) |
| `/sync-gbrain` | فهرسة الكود في gbrain |
| `/setup-deploy` | تهيئة deploy config |
| `/context-save` | حفظ سياق الجلسة |
| `/context-restore` | استعادة سياق |
| `/scrape` | جلب بيانات من صفحة |
| `/skillify` | تحويل scrape إلى script دائم |

---

## 11) GBrain (اختياري)

**ما هو؟** GBrain = قاعدة بيانات معرفة دائمة للوكيل. يتذكّر patterns، decisions، code structure بين الجلسات.

### الفائدة على NoNet
- "كيف نفذنا BlockingEngine؟" — يرد بدون قراءة الكود من جديد
- "ما هو الـ ProductIDs convention؟" — يتذكّر
- search سريع للكود

### التثبيت السريع
```
/setup-gbrain
```
يسألك:
1. PGLite (محلي، 30 ثانية، لا حساب) — الأبسط
2. Supabase (سحابي) — لو تبيه عبر أجهزة

اختر PGLite للبداية.

### الاستخدام بعد التثبيت
```
/sync-gbrain   ← يفهرس الكود الحالي
```
بعدها Claude يقدر يستخدم:
- `gbrain search "BlockingEngine"`
- `gbrain code-def "PermissionsManager"`

أسرع 10× من Grep على مشاريع كبيرة.

---

## 🎓 ملاحظات أخيرة

1. **لا تستعمل skills عشوائياً** — كل واحد له وقت.
2. **ابدأ بـ `/office-hours` قبل أي ميزة جديدة** — تكتشف افتراضات مدفونة.
3. **`/review` قبل كل merge** — لو لا تفعل غيرها، افعل هذه.
4. **`/retro` كل سبت** — تحسّن تدريجياً.
5. **`/learn list` شهرياً** — يذكّرك بالـ patterns التي اكتشفتها.

### للتعمّق أكثر
- `~/.claude/skills/gstack/SKILL.md` — أوامر تفصيلية لكل skill
- `~/.claude/skills/gstack/docs/` — مقالات معمقة
- https://github.com/garrytan/gstack — أحدث إصدار، issues، discussions

---

**🎁 تذكّر: gstack مجاني ومفتوح المصدر (MIT). فورك واحفظ نسختك المخصصة.**

تم آخر تحديث للدليل: 2026-05-22
