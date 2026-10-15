# Tests Setup

## كيفية إضافة الـ Tests Target في Xcode

> ⚠️ هذه الملفات تبقى inert (لا تُجمَّع) حتى تضيف Tests Target من Xcode UI.

### الخطوات (10 ثواني)
1. افتح المشروع في Xcode.
2. `File → New → Target...`
3. اختر **Unit Testing Bundle** (تحت iOS).
4. املأ:
   - Product Name: `blocking appTests`
   - Team: `L2T9STCPA5` (نفس الـ app)
   - Target to be Tested: `blocking app`
5. اضغط Finish.
6. Xcode سيُنشئ مجلد `blocking appTests/` تلقائياً.
7. **مهم**: احذف الملف الافتراضي `blocking_appTests.swift` الذي ينشئه Xcode، لأن ملفاتنا موجودة بالفعل.
8. اسحب الملفات الموجودة (`BlockingEngineTests.swift` إلخ) من Finder إلى الـ Tests Target في Xcode إذا لم تظهر تلقائياً.
9. `Cmd+U` لتشغيل الاختبارات.

### تشغيل من Terminal
```bash
xcodebuild test \
  -project "blocking app.xcodeproj" \
  -scheme "blocking app" \
  -destination "platform=iOS Simulator,name=iPhone 15"
```

## ملفات الاختبار

| الملف | يفحص |
|------|------|
| `SchedulePersistenceTests.swift` | encode/decode v1، legacy fallback، unknown version |
| `BlockingConstantsTests.swift` | sanity على القيم الثابتة |
| `LocalChatResponderTests.swift` | keyword matching بالعربية والإنجليزية |
| `PersistenceMigrationTests.swift` | migration من unversioned إلى v1: |
| `KeychainStoreTests.swift` | Keychain CRUD |
| `BlockingEngineTests.swift` | isHardLocked logic |
