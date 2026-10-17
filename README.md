<div align="center">

# Samla · الصملة

**Block distracting apps and websites — calmly, privately, on your own terms.**
**احظر التطبيقات والمواقع المشتتة — بهدوء، وبخصوصية تامة، وبشروطك.**

[![CI](https://github.com/KxxLxD/NoNet-Last-one-with-Al-Garage/actions/workflows/ci.yml/badge.svg)](https://github.com/KxxLxD/NoNet-Last-one-with-Al-Garage/actions/workflows/ci.yml)
![iOS 17+](https://img.shields.io/badge/iOS-17%2B-0F1B3D)
![Swift 6](https://img.shields.io/badge/Swift-6-0F1B3D)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0F1B3D)
![License: Proprietary](https://img.shields.io/badge/license-proprietary-5B6270)

[English](#english) · [العربية](#العربية)

</div>

---

## English

Samla is an iOS app that blocks distracting apps and websites with Apple's Screen Time APIs, and helps people protect themselves from harmful content for good. Everything stays on the device: no servers, no accounts required, no data collected.

### Features
- **Block lists** — block now for a set time or on a weekly schedule, with optional short breaks.
- **What to block** — Apple's app & category picker plus curated website categories (Social Media, Short Videos, Video, Games, **AI Tools**, Shopping, News, Crypto), each blocked whole or site by site.
- **No Internet Mode** — everything is blocked except the apps you allow.
- **Commitment** — *Hard Mode* (can't be stopped, edited or deleted while active) and an *Accountability Partner* whose 4-digit PIN never leaves the phone.
- **Block Forever** — a free, always-on filter for porn, gambling and dating; turning it off takes a 360-day wait or the partner's PIN.
- **Starter lists**, **Skip Today** for unprotected schedules, motivational block screen with breaks.
- **Arabic & English**, full right-to-left support, Western digits, WCAG 2.1 AA accessibility.

### Requirements
| | |
|---|---|
| Xcode | 26 or later |
| Deployment target | iOS 17.0 |
| Device | A real iPhone — Screen Time doesn't block in the Simulator |
| Capabilities | Family Controls (Distribution needs [Apple's approval](https://developer.apple.com/contact/request/family-controls-distribution)), App Group `group.app.samla`, Sign in with Apple |

### Getting started
```bash
git clone https://github.com/KxxLxD/NoNet-Last-one-with-Al-Garage.git
open Samla.xcodeproj
```
1. Select your team under **Signing & Capabilities** for all five targets: `Samla`, `SamlaMonitor`, `SamlaShield`, `SamlaShieldAction`, `SamlaTests`.
2. Make sure the App Group `group.app.samla` is enabled for the app and the three extensions.
3. Run the **Samla** scheme on an iPhone.

Run the tests with **⌘U**, or:
```bash
xcodebuild test -project Samla.xcodeproj -scheme Samla \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### Project structure
```
Samla/                  App target (SwiftUI)
├── App/                Entry point, root and tab navigation
├── Core/               Models and services: lists, partner, Block Forever, store, notifications
├── DesignSystem/       Colors, spacing, components, feedback
├── Features/           Screens: Home, Lists, Settings, Onboarding, Partner, Forever, Tips
└── Resources/          Assets, String Catalog (ar/en), entitlements
Shared/                 Code shared with the extensions: BlockList, ShieldEngine, WakeScheduler…
SamlaMonitor/           DeviceActivity monitor — re-applies shields at schedule boundaries
SamlaShield/            Shield configuration — the block screen
SamlaShieldAction/      Shield action — starts a break from the block screen
SamlaTests/             Swift Testing unit tests
Config/                 Extension Info.plists
docs/                   Product plan, store copy, audits, privacy policy, website generator
```

### Architecture
- **SwiftUI + Observation.** `ListsModel` is the single source of truth; every change is saved and immediately pushed to Screen Time.
- **Storage.** Lists and Block Forever are JSON files in the App Group, so the extensions enforce them without the app running. The partner PIN is a hash in the Keychain.
- **Enforcement.** `ShieldEngine` merges every active list and Block Forever into one `ManagedSettingsStore`; `WakeScheduler` registers `DeviceActivity` schedules so the monitor extension re-applies shields when windows start and end.
- **Privacy by design.** Apple's Screen Time tokens are opaque — Samla never learns which apps someone picks or uses.
- **Localization.** One String Catalog for Arabic and English; a unit test fails if any string is missing Arabic.

### Development workflow
- `main` is the default branch and always builds. Work happens on short-lived branches (`feature/…`, `fix/…`) merged through Pull Requests.
- CI builds and runs the tests on every Pull Request and on `main`.
- Commit messages are imperative and specific (*“Add Skip Today for scheduled lists”*).
- Product decisions are logged in [`docs/PLAN.md`](docs/PLAN.md); user-facing changes go in [`CHANGELOG.md`](CHANGELOG.md).

### Documentation
| Document | |
|---|---|
| [Product plan](docs/PLAN.md) | Decisions, scope and the launch checklist |
| [Release checklist](docs/release-checklist.md) | Apple setup and App Store steps |
| [App Store copy](docs/STORE.md) | Name, description, keywords |
| [Privacy policy](docs/privacy-policy.md) | What Samla does (and doesn't) do with data |
| [UX audit](docs/ux-audit/README.md) · [Accessibility audit](docs/a11y-audit/README.md) | Findings, fixes and screenshots |

### License
Proprietary — all rights reserved. See [LICENSE](LICENSE).

---

<div dir="rtl">

## العربية

الصملة تطبيق iOS يحظر التطبيقات والمواقع المشتتة عبر واجهات «مدة استخدام الجهاز» من Apple، ويساعد الإنسان يحمي نفسه من المحتوى الضار للأبد. كل شيء يبقى على الجهاز: بدون سيرفرات، بدون حساب إلزامي، وبدون جمع أي بيانات.

### المميزات
- **قوائم الحظر** — حظر الآن لمدة محددة أو بجدول أسبوعي، مع استراحات قصيرة اختيارية.
- **ما الذي تريد حظره** — قائمة Apple للتطبيقات والفئات + فئات مواقع جاهزة (التواصل، المقاطع القصيرة، الفيديو، الألعاب، **أدوات الذكاء الاصطناعي**، التسوق، الأخبار، العملات)، تُحظر كاملة أو موقعاً موقعاً.
- **وضع بلا إنترنت** — يحظر كل شيء ما عدا التطبيقات التي تسمح بها.
- **الالتزام** — *الوضع الصارم* (لا يمكن إيقافه أو تعديله أو حذفه أثناء نشاطه) و*شريك المساءلة* برمز من 4 أرقام لا يغادر الجوال.
- **احظر للأبد** — فلتر مجاني دائم للإباحية والقمار والمواعدة؛ إيقافه يحتاج انتظار 360 يوماً أو رمز الشريك.
- **قوائم جاهزة**، و**تخطَّ اليوم** للجداول غير المحمية، وشاشة حظر تحفيزية مع الاستراحات.
- **عربي وإنجليزي** مع دعم كامل للاتجاه من اليمين لليسار، أرقام غربية، وإمكانية وصول وفق WCAG 2.1 AA.

### المتطلبات
- Xcode 26 أو أحدث، والحد الأدنى iOS 17.0.
- آيفون حقيقي للتجربة — الحظر ما يشتغل على المحاكي.
- صلاحية Family Controls (نسخة التوزيع تحتاج [موافقة Apple](https://developer.apple.com/contact/request/family-controls-distribution))، ومجموعة التطبيقات `group.app.samla`، وتسجيل الدخول بـApple.

### البدء
١. افتح `Samla.xcodeproj` واختر فريقك في **Signing & Capabilities** للأهداف الخمسة.
٢. تأكد أن `group.app.samla` مفعّل للتطبيق والإضافات الثلاث.
٣. شغّل مخطط **Samla** على الآيفون، والاختبارات بـ **⌘U**.

### طريقة العمل
- الفرع الافتراضي `main` ويبقى قابلاً للبناء دائماً؛ كل تغيير في فرع قصير ويُدمج عبر Pull Request.
- الـCI يبني ويشغّل الاختبارات على كل Pull Request وعلى `main`.
- قرارات المنتج في [`docs/PLAN.md`](docs/PLAN.md)، والتغييرات الظاهرة للمستخدم في [`CHANGELOG.md`](CHANGELOG.md).

### الترخيص
ملكية خاصة — جميع الحقوق محفوظة. انظر [LICENSE](LICENSE).

</div>
