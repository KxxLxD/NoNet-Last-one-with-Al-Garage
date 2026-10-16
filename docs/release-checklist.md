# Samla (الصملة) — App Store release checklist

These steps need your Apple Developer account and can't be done from code. Product decisions live in [PLAN.md](PLAN.md).

## 1. Apple Developer portal
- [ ] **Request the Family Controls (Distribution) entitlement** — required to ship any Screen Time app:
      https://developer.apple.com/contact/request/family-controls-distribution
      Request it for all four bundle IDs:
      - `app.samla`
      - `app.samla.monitor`
      - `app.samla.shield`
      - `app.samla.shield-action` (block screen buttons, new)
      (Development builds work without approval; TestFlight/App Store builds don't.)
- [ ] Create the App Group `group.app.samla` and enable it for the app and all three extensions (monitor, shield, shield-action).
- [ ] Enable **Sign in with Apple** for the app ID.

## 2. App Store Connect
- [ ] Create the app (bundle ID `app.samla`, name "Samla", Arabic name "الصملة").
- [ ] (Later — Premium is "coming soon" in v1) Subscription group **Samla Premium** with two auto-renewable products:
      - `app.samla.premium.monthly` — 1 month
      - `app.samla.premium.yearly` — 1 year
      Add a 1-week free-trial introductory offer if you want one, plus English and Arabic display names.
- [ ] To replace the old `nonet` discount code: create **Offer Codes** for the subscriptions (users redeem them via "Redeem Code" in the paywall).
- [ ] Publish `docs/privacy-policy.md` (e.g. GitHub Pages) and paste the URL into App Store Connect.
      Then set `AppLinks.privacyPolicy` in `blocking app/Core/AppLinks.swift`.
- [ ] App Privacy questionnaire: **Data Not Collected**.
- [ ] Age rating: answer the questionnaire (the app mentions adult content/gambling only as things to block).
- [ ] Screenshots: iPhone 6.9" (Arabic + English).
- [ ] Review notes: explain that Screen Time access is needed to block apps and websites, and that Block Forever / Hard Mode intentionally prevent deleting the app while active.

## 3. Assets you need to add
- [ ] **App icon** (1024×1024, navy shield on white — Icon Composer) in `Resources/Assets.xcassets/AppIcon` — currently empty; upload will fail without it.
- [ ] **Logo** image named `samla_logo` in the asset catalog (a shield symbol is shown until then).
- [ ] Optional: real WhatsApp/Telegram community links in `AppLinks.swift` (section is hidden while empty).
- [ ] Make sure `an official support email (none yet — the in-app support row is hidden until `AppLinks.supportEmail` is set)` is a working inbox.

## 4. Local testing
- In Xcode: **Product › Scheme › Edit Scheme › Run › Options › StoreKit Configuration → `Products.storekit`** to test purchases without App Store Connect.
- Blocking (Screen Time) only works on a **real iPhone**, not the simulator.
- Change app language: iOS Settings › Samla › Language.
