#!/usr/bin/env python3
"""Builds the Samla website (GitHub Pages, `gh-pages` branch).

Usage:  python3 docs/site/build_site.py <output-dir>

Arabic (RTL) and English pages are generated separately with a language switch.
The root /privacy.html and /support.html redirect to the visitor's language, so the
links inside the app never break. Edit the CONTENT dict below, then rebuild.
"""
import html
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ICON = HERE.parent.parent / "Samla/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

BASE = "/NoNet-Last-one-with-Al-Garage"  # GitHub Pages project path
UPDATED = {"ar": "16 أكتوبر 2026", "en": "October 16, 2026"}
PAGES = ["index", "privacy", "support", "terms"]

CONTENT = {
    "ar": {
        "dir": "rtl", "name": "الصملة", "other": "en", "other_label": "English",
        "nav": {"index": "الرئيسية", "privacy": "الخصوصية", "support": "الدعم", "terms": "الشروط"},
        "skip": "تخطَّ إلى المحتوى",
        "tagline": "احظر التطبيقات والمواقع التي تسرق وقتك، واحمِ نفسك إلى الأبد.",
        "store": ("قريبًا على", "App Store"),
        "ayah": ("﴿قُل لِّلْمُؤْمِنِينَ يَغُضُّوا مِنْ أَبْصَارِهِمْ﴾", "النور: 30"),
        "features_title": "كل ما تحتاجه للتركيز والعفة",
        "features": [
            ("🛡️", "احظر للأبد", "حماية دائمة من الإباحية والقمار والمواعدة بضغطة واحدة — مجانًا إلى الأبد.", True),
            ("📋", "قوائم الحظر", "اختر التطبيقات والمواقع، وابدأ الحظر الآن أو وفق جدول.", False),
            ("🗓️", "الجدولة", "يبدأ الحظر ويتوقف تلقائيًا حتى عندما يكون التطبيق مغلقًا.", False),
            ("🔒", "الوضع الصارم", "لا يمكن إيقاف القائمة ولا حذف التطبيق حتى تنتهي.", False),
            ("🤝", "شريك المساءلة", "شخص تثق به يضع رمزًا، ولا تُلغى القائمة إلا به.", False),
            ("☕", "استراحات محسوبة", "استراحات قصيرة محدودة بدل التصفح بلا نهاية.", False),
        ],
        "privacy_note": ("خصوصيتك محفوظة", "كل شيء على جهازك. لا خوادم، ولا تحليلات، ولا جمع لأي بيانات."),
        "footer": "© 2026 الصملة. صُنع بعناية لحياة أهدأ وتركيز أعمق.",
        "updated": "آخر تحديث",
        "privacy": {
            "title": "سياسة الخصوصية",
            "callout": ("باختصار:", "لا نجمع أي بيانات. كل شيء يبقى على جهازك."),
            "sections": [
                ("ما الذي نجمعه", ["<strong>لا شيء.</strong> لا يملك الصملة خوادم ولا أدوات تحليلات أو إعلانات، ولا نبيع أي بيانات شخصية ولا نشاركها."]),
                ("ما يُحفظ على جهازك", ["قوائم الحظر والجداول والاستراحات.", "إعدادات «احظر للأبد» وأي طلب إلغاء.", "اسم شريك المساءلة، ورمزه محفوظًا مشفّرًا في سلسلة المفاتيح فقط.", "يمكنك حذف كل ذلك من <strong>الإعدادات ‹ الحساب ‹ حذف الحساب والبيانات</strong> أو بحذف التطبيق. تبقى القوائم المقفلة حاليًا و«احظر للأبد» حتى تنتهي."]),
                ("مدة استخدام الجهاز", ["تتعامل خدمة «مدة استخدام الجهاز» من Apple مع التطبيقات والفئات والمواقع التي تختارها كرموز خاصة، ولا يستطيع الصملة معرفة ماهيتها أو كيفية استخدامك لها."]),
                ("تسجيل الدخول بحساب Apple (اختياري)", ["يعمل الصملة بالكامل بدون حساب. إذا سجّلت الدخول، يحفظ الصملة على جهازك فقط معرّف Apple المجهول والاسم الذي تختار مشاركته. ويمكنك إيقاف ذلك من <strong>الإعدادات ‹ حساب Apple ‹ تسجيل الدخول باستخدام Apple</strong>."]),
                ("المدفوعات", ["إذا قُدّمت ميزات مدفوعة مستقبلًا، فتتم المدفوعات عبر Apple، ولا نتلقى إلا حالة الاشتراك اللازمة لتفعيلها."]),
                ("التواصل", ["سيُضاف بريد التواصل قبل النشر. حتى ذلك الحين راجع <a href=\"support.html\">صفحة الدعم</a>."]),
            ],
        },
        "support": {
            "title": "الدعم",
            "intro": "إجابات الأسئلة الأكثر شيوعًا. سيُضاف بريد للتواصل قريبًا.",
            "faq": [
                ("لماذا لا أستطيع حذف التطبيق؟", "لديك قائمة نشطة في الوضع الصارم أو محمية بالشريك، أو أن «احظر للأبد» مفعّل. ينتهي الوضع الصارم بانتهاء القائمة، وينتهي «احظر للأبد» بعد 360 يومًا من طلب الإلغاء، أو قبل ذلك برمز شريكك."),
                ("ما هو «احظر للأبد»؟", "فلتر مجاني ودائم لمواقع الإباحية والقمار والمواعدة، ويمكنك أيضًا قفل جميع تطبيقات 17+. لإيقافه تطلب الإلغاء وتنتظر 360 يومًا، أو يُدخل شريكك رمزه."),
                ("نسيت رمز شريكي، ماذا أفعل؟", "افتح الإعدادات ‹ شريك المساءلة واضغط «هل نسيت الرمز؟». سيُزال شريكك بعد 7 أيام. لا يتأثر «احظر للأبد» ويبقى انتظاره 360 يومًا."),
                ("الحظر لا يعمل؟", "تأكد من السماح للصملة بالوصول إلى «مدة استخدام الجهاز» من إعدادات iOS. لا يعمل الحظر إلا على جهاز iPhone حقيقي."),
                ("كيف تعمل القوائم المجدولة؟", "اختر «جدولة» ضمن «الوقت»، ثم أضف الأيام والأوقات. يبدأ الحظر ويتوقف تلقائيًا حتى عندما يكون الصملة مغلقًا."),
                ("هل توجد استراحات؟", "نعم، إلا في الوضع الصارم. اختر عدد الاستراحات خلال اليوم ومدة كل منها، وابدأها من صفحة القائمة أو من شاشة الحظر."),
                ("كم قائمة يمكنني إنشاؤها؟", "تتيح النسخة المجانية 3 قوائم، وسيُلغي الاشتراك المميز — قريبًا — هذا الحد. ويبقى «احظر للأبد» مجانيًا إلى الأبد."),
                ("أين تذهب بياناتي؟", "تبقى جميع بياناتك على جهازك. لا يجمع الصملة أي بيانات."),
            ],
        },
        "terms": {
            "title": "شروط الاستخدام",
            "callout": ("مهم:", "الوضع الصارم و«احظر للأبد» التزامات اختيارية لا يمكن إيقافها مبكرًا. اختر بعناية."),
            "sections": [
                ("الغرض", ["الصملة أداة تساعدك على بناء عادات رقمية أصح بحظر التطبيقات والمواقع التي تختارها."]),
                ("الالتزامات الاختيارية", ["<strong>الوضع الصارم:</strong> لا يمكن إيقاف القائمة أو تعديلها أو حذفها أثناء نشاطها، ولا يمكن حذف التطبيق.", "<strong>حماية الشريك:</strong> لا تُلغى القائمة أثناء نشاطها إلا برمز شريكك. عند نسيان الرمز يُزال الشريك بعد 7 أيام.", "<strong>احظر للأبد:</strong> يبقى مفعّلًا حتى تمر 360 يومًا على طلب الإلغاء، أو يُدخل شريكك رمزه."]),
                ("حدود الخدمة", ["يعتمد الحظر على خدمة «مدة استخدام الجهاز» من Apple، وقد لا يغطي كل محتوى أو كل حالة. يُقدَّم التطبيق «كما هو» دون ضمانات."]),
                ("الترخيص", ["يخضع استخدامك للتطبيق لـ<a href=\"https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\">اتفاقية الترخيص القياسية من Apple</a>."]),
                ("التعديلات", ["قد نحدّث هذه الشروط، وسيظهر تاريخ آخر تحديث أعلى الصفحة."]),
            ],
        },
    },
    "en": {
        "dir": "ltr", "name": "Samla", "other": "ar", "other_label": "العربية",
        "nav": {"index": "Home", "privacy": "Privacy", "support": "Support", "terms": "Terms"},
        "skip": "Skip to content",
        "tagline": "Block the apps and websites that steal your time, and protect yourself for good.",
        "store": ("Coming soon on the", "App Store"),
        "ayah": ("“Tell the believing men to lower their gaze.”", "Quran, An-Nur 24:30"),
        "features_title": "Everything you need to stay focused",
        "features": [
            ("🛡️", "Block Forever", "Lasting protection from porn, gambling and dating in one tap — free forever.", True),
            ("📋", "Block lists", "Pick apps and websites, then block them now or on a schedule.", False),
            ("🗓️", "Scheduling", "Blocking starts and stops automatically, even when the app is closed.", False),
            ("🔒", "Hard Mode", "No stopping the list or deleting the app until it ends.", False),
            ("🤝", "Accountability partner", "Someone you trust sets a PIN that only they know.", False),
            ("☕", "Measured breaks", "A few short breaks instead of endless scrolling.", False),
        ],
        "privacy_note": ("Private by design", "Everything stays on your device. No servers, no analytics, no data collection."),
        "footer": "© 2026 Samla. Made with care for a calmer, more focused life.",
        "updated": "Last updated",
        "privacy": {
            "title": "Privacy Policy",
            "callout": ("In short:", "We collect no data. Everything stays on your device."),
            "sections": [
                ("What we collect", ["<strong>Nothing.</strong> Samla has no servers, no analytics and no advertising SDKs. We do not collect, sell or share personal data."]),
                ("Data stored on your device", ["Block lists, schedules and breaks.", "Block Forever settings and any unlock request.", "Your accountability partner's name, and their PIN stored only as a protected hash in the iOS Keychain.", "Delete it anytime from <strong>Settings › Account › Delete Account &amp; Data</strong>, or by deleting the app. Lists that are locked right now, and Block Forever, keep their rules until they end."]),
                ("Screen Time", ["Apps, categories and websites you pick are handled by Apple's Screen Time framework as private tokens. Samla cannot see which apps they are or how you use them."]),
                ("Sign in with Apple (optional)", ["Samla works fully without an account. If you sign in, Samla stores only Apple's anonymous user identifier and the name you choose to share, on your device. You can stop this in <strong>Settings › Apple Account › Sign in with Apple</strong>."]),
                ("Purchases", ["If paid features are offered in the future, payments are processed by Apple. Samla would only receive the subscription status needed to unlock them."]),
                ("Contact", ["A contact email will be added before publishing. Until then, see the <a href=\"support.html\">Support page</a>."]),
            ],
        },
        "support": {
            "title": "Support",
            "intro": "Answers to the most common questions. A contact email is coming soon.",
            "faq": [
                ("Why can't I delete the app?", "A list in Hard Mode or protected by your partner is active, or Block Forever is on. Hard Mode ends when the list ends. Block Forever ends 360 days after you request an unlock, or sooner with your partner's PIN."),
                ("What is Block Forever?", "A free, permanent filter for porn, gambling and dating websites. You can also lock every 17+ app. To turn it off you request an unlock and wait 360 days, or your partner enters their PIN."),
                ("I forgot my partner's PIN. What now?", "Open Settings › Accountability Partner and tap Forgot PIN. Your partner is removed after 7 days. Block Forever isn't affected and keeps its 360-day wait."),
                ("Blocking isn't working?", "Make sure Samla is allowed to use Screen Time in iOS Settings. Blocking only works on a real iPhone."),
                ("How do scheduled lists work?", "Choose Schedule under Time, then add days and times. Blocking starts and stops automatically, even when Samla is closed."),
                ("Are breaks allowed?", "Yes, except in Hard Mode. Choose how many breaks you get per day and how long each lasts, then start one from the list's page or the block screen."),
                ("How many lists can I create?", "The free version holds 3 lists. Premium, coming soon, will remove the limit. Block Forever stays free forever."),
                ("Where does my data go?", "Everything stays on your device. Samla collects no data."),
            ],
        },
        "terms": {
            "title": "Terms of Use",
            "callout": ("Important:", "Hard Mode and Block Forever are voluntary commitments that can't be turned off early. Choose carefully."),
            "sections": [
                ("Purpose", ["Samla is a tool that helps you build healthier digital habits by blocking the apps and websites you choose."]),
                ("Voluntary commitments", ["<strong>Hard Mode:</strong> while active, the list can't be stopped, edited or deleted, and the app can't be deleted.", "<strong>Partner protection:</strong> while active, the list only unlocks with your partner's PIN. If the PIN is forgotten, the partner is removed after 7 days.", "<strong>Block Forever:</strong> stays on until 360 days pass after you request an unlock, or your partner enters their PIN."]),
                ("Service limits", ["Blocking relies on Apple's Screen Time and may not cover every piece of content or every situation. The app is provided “as is” without warranties."]),
                ("License", ["Your use of the app is governed by <a href=\"https://www.apple.com/legal/internet-services/itunes/dev/stdeula/\">Apple's Standard End User License Agreement</a>."]),
                ("Changes", ["We may update these terms. The date of the latest update appears at the top of this page."]),
            ],
        },
    },
}

TITLES = {"ar": {"index": "الصملة — احظر المشتتات واحمِ نفسك"}, "en": {"index": "Samla — Block distractions for good"}}


def layout(lang: str, page: str, title: str, body: str) -> str:
    c = CONTENT[lang]
    other = c["other"]
    current = ' aria-current="page"'
    nav = "".join(f'<a href="{p}.html"{current if p == page else ""}>{c["nav"][p]}</a>' for p in PAGES)
    foot = "".join(f'<a href="{p}.html">{c["nav"][p]}</a>' for p in PAGES[1:])
    return f"""<!doctype html>
<html lang="{lang}" dir="{c['dir']}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<meta name="description" content="{html.escape(c['tagline'])}">
<meta property="og:title" content="{html.escape(title)}">
<meta property="og:description" content="{html.escape(c['tagline'])}">
<meta property="og:image" content="{BASE}/assets/icon.png">
<meta name="theme-color" content="#0F1B3D">
<link rel="icon" href="{BASE}/assets/favicon.png">
<link rel="apple-touch-icon" href="{BASE}/assets/apple-touch-icon.png">
<link rel="alternate" hreflang="{other}" href="{BASE}/{other}/{page}.html">
<link rel="stylesheet" href="{BASE}/assets/style.css">
</head>
<body>
<a class="skip" href="#main">{c['skip']}</a>
<header class="site-header"><div class="wrap">
  <a class="brand" href="index.html"><img src="{BASE}/assets/icon.png" alt="" width="34" height="34">{c['name']}</a>
  <nav class="nav" aria-label="{c['nav']['index']}">{nav}</nav>
  <a class="lang" href="{BASE}/{other}/{page}.html" hreflang="{other}" lang="{other}">{c['other_label']}</a>
</div></header>
<main id="main">
{body}
</main>
<footer class="site-footer"><div class="wrap"><span>{c['footer']}</span><nav>{foot}</nav></div></footer>
</body>
</html>
"""


def landing(lang: str) -> str:
    c = CONTENT[lang]
    cards = "".join(
        f'<article class="card{" featured" if featured else ""}"><div class="icon" aria-hidden="true">{icon}</div>'
        f"<h3>{t}</h3><p>{d}</p></article>"
        for icon, t, d, featured in c["features"]
    )
    pn_t, pn_d = c["privacy_note"]
    return f"""<section class="hero"><div class="wrap">
  <img class="app-icon" src="{BASE}/assets/icon.png" alt="{c['name']}" width="120" height="120">
  <h1>{c['name']}</h1>
  <p class="lead">{c['tagline']}</p>
  <a class="badge-store" aria-disabled="true" role="link"><span><small>{c['store'][0]}</small>{c['store'][1]}</span></a>
  <p class="ayah">{c['ayah'][0]}<cite>{c['ayah'][1]}</cite></p>
</div></section>
<section class="section"><div class="wrap">
  <h2>{c['features_title']}</h2>
  <div class="grid">{cards}</div>
</div></section>
<section class="section"><div class="wrap">
  <div class="card" style="text-align:center"><h3>{pn_t}</h3><p>{pn_d} <a href="privacy.html">{c['nav']['privacy']}</a></p></div>
</div></section>"""


def document(lang: str, key: str) -> str:
    c = CONTENT[lang]
    d = c[key]
    head = f'<h1>{d["title"]}</h1><p class="updated">{c["updated"]}: {UPDATED[lang]}</p>'
    callout = ""
    if "callout" in d:
        callout = f'<div class="callout"><strong>{d["callout"][0]}</strong><span>{d["callout"][1]}</span></div>'
    if key == "support":
        items = "".join(f"<details><summary>{q}</summary><p>{a}</p></details>" for q, a in d["faq"])
        return f'<div class="wrap doc">{head}<p>{d["intro"]}</p>{items}</div>'
    panels = ""
    for title, paras in d["sections"]:
        content = f"<p>{paras[0]}</p>" if len(paras) == 1 else "<ul>" + "".join(f"<li>{p}</li>" for p in paras) + "</ul>"
        panels += f'<section class="panel"><h2>{title}</h2>{content}</section>'
    return f'<div class="wrap doc">{head}{callout}{panels}</div>'


def redirect(page: str) -> str:
    """Language-neutral URL used by the app: sends Arabic browsers to /ar/, others to /en/."""
    return f"""<!doctype html>
<html><head><meta charset="utf-8"><title>Samla</title>
<meta name="robots" content="noindex">
<script>
var ar = (navigator.languages || [navigator.language || ""]).some(function (l) {{ return /^ar/i.test(l); }});
location.replace("{BASE}/" + (ar ? "ar" : "en") + "/{page}.html");
</script>
<meta http-equiv="refresh" content="1; url={BASE}/en/{page}.html">
</head><body><a href="{BASE}/ar/{page}.html">العربية</a> · <a href="{BASE}/en/{page}.html">English</a></body></html>
"""


def assets(out: Path) -> None:
    folder = out / "assets"
    folder.mkdir(parents=True, exist_ok=True)
    shutil.copy(HERE / "style.css", folder / "style.css")
    shutil.copy(ICON, folder / "icon.png")
    try:
        from PIL import Image
        icon = Image.open(ICON)
        icon.resize((180, 180), Image.LANCZOS).save(folder / "apple-touch-icon.png")
        icon.resize((64, 64), Image.LANCZOS).save(folder / "favicon.png")
    except ImportError:
        shutil.copy(ICON, folder / "apple-touch-icon.png")
        shutil.copy(ICON, folder / "favicon.png")


def main(out: Path) -> None:
    assets(out)
    for lang in CONTENT:
        (out / lang).mkdir(parents=True, exist_ok=True)
        for page in PAGES:
            if page == "index":
                body, title = landing(lang), TITLES[lang]["index"]
            else:
                body = document(lang, page)
                title = f'{CONTENT[lang][page]["title"]} — {CONTENT[lang]["name"]}'
            (out / lang / f"{page}.html").write_text(layout(lang, page, title, body), encoding="utf-8")
    for page in PAGES:
        (out / f"{page}.html").write_text(redirect(page), encoding="utf-8")
    (out / ".nojekyll").write_text("", encoding="utf-8")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: build_site.py <output-dir>")
    main(Path(sys.argv[1]))
