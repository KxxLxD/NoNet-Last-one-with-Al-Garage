# NoNet — App Store release checklist

Code-side work is done. These steps need your Apple Developer account and can't be done from code.

## 1. Apple Developer portal
- [ ] **Request the Family Controls (Distribution) entitlement** — required to ship any Screen Time app:
      https://developer.apple.com/contact/request/family-controls-distribution
      Request it for all three bundle IDs:
      - `com.databox.nonet.blocking-app`
      - `com.databox.nonet.blocking-app.monitor`
      - `com.databox.nonet.blocking-app.shield`
      (Development builds work without approval; TestFlight/App Store builds don't.)
- [ ] Create the App Group `group.com.databox.nonet.blocking-app` and enable it for the app and the monitor extension.
- [ ] Enable **Sign in with Apple** for the app ID.

## 2. App Store Connect
- [ ] Create the app (bundle ID `com.databox.nonet.blocking-app`, name "NoNet", Arabic name "نونت").
- [ ] Subscription group **NoNet Premium** with two auto-renewable products:
      - `com.databox.nonet.premium.monthly` — 1 month
      - `com.databox.nonet.premium.yearly` — 1 year
      Add a 1-week free-trial introductory offer if you want one, plus English and Arabic display names.
- [ ] To replace the old `nonet` discount code: create **Offer Codes** for the subscriptions (users redeem them via "Redeem Code" in the paywall).
- [ ] Publish `docs/privacy-policy.md` (e.g. GitHub Pages) and paste the URL into App Store Connect.
      Then set `AppLinks.privacyPolicy` in `blocking app/Core/AppLinks.swift`.
- [ ] App Privacy questionnaire: **Data Not Collected**.
- [ ] Age rating: answer the questionnaire (the app mentions adult content/gambling only as things to block).
- [ ] Screenshots: iPhone 6.9" (Arabic + English).
- [ ] Review notes: explain that Screen Time access is needed to block apps, and that Premium can be tested with a sandbox account.

## 3. Assets you need to add
- [ ] **App icon** (1024×1024) in `Resources/Assets.xcassets/AppIcon` — currently empty; upload will fail without it.
- [ ] **Logo** image named `nonet_logo` in the asset catalog (a shield symbol is shown until then).
- [ ] Optional: real WhatsApp/Telegram community links in `AppLinks.swift` (section is hidden while empty).
- [ ] Make sure `support@nonet.app` is a working inbox.

## 4. Local testing
- In Xcode: **Product › Scheme › Edit Scheme › Run › Options › StoreKit Configuration → `Products.storekit`** to test purchases without App Store Connect.
- Blocking (Screen Time) only works on a **real iPhone**, not the simulator.
- Change app language: iOS Settings › NoNet › Language.
