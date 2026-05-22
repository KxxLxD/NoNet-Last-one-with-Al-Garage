# BlockingMonitor — DeviceActivity Extension

Extension target يستخدمه iOS لتطبيق shields عند بداية/نهاية كل DeviceActivitySchedule المسجَّل عبر `BlockingEngine.scheduleMonitoring(for:)`.

## التثبيت لمرة واحدة في Xcode (~30 ثانية)

1. افتح المشروع في Xcode.
2. `File → New → Target...`
3. اختر **Device Activity Monitor Extension** (تحت iOS).
4. املأ:
   - Product Name: `BlockingMonitor`
   - Team: `L2T9STCPA5`
   - Bundle Identifier: `com.nonetapp.BlockingMonitor`
   - Embed in Application: `blocking app`
5. اضغط Finish.
6. **مهم**: Xcode سينشئ ملف `DeviceActivityMonitor.swift` افتراضي — احذفه. الملف `BlockingMonitor.swift` الموجود هنا سيُلتقط تلقائياً.
7. في Signing & Capabilities للـ BlockingMonitor target:
   - أضف **Family Controls** capability
   - اضبط Team = `L2T9STCPA5`

## مشاركة البيانات بين التطبيق والـ Extension

الـ Extension تعمل في عملية منفصلة ولا تشارك UserDefaults افتراضياً. للوصول للـ FamilyActivitySelection المحفوظة من التطبيق الرئيسي، يجب:

1. **إنشاء App Group** في Apple Developer Portal:
   - Identifier: `group.com.nonetapp.shared`
2. **تفعيل App Groups capability** في كلا الـ targets:
   - `blocking app`
   - `BlockingMonitor`
3. **تحديث `FamilySelectionStore`** ليستخدم `UserDefaults(suiteName: "group.com.nonetapp.shared")`:
   ```swift
   private static let defaults = UserDefaults(suiteName: "group.com.nonetapp.shared") ?? .standard
   ```

## لماذا يحتاج المشروع هذه الـ Extension؟

`BlockingEngine.scheduleMonitoring(for:)` يستدعي `DeviceActivityCenter.startMonitoring(...)` الذي يخبر iOS:
> "ابدأ مراقبة هذا الـ schedule عند الوقت X، استدعِ extension عند البدء/الانتهاء."

بدون extension، iOS لا يجد ما يستدعي → الـ shields لا تُطبَّق تلقائياً في الوقت المحدد للـ scheduled lists. الـ "Block Now" (immediate) يعمل بدون extension لأن BlockingEngine يطبّق الـ shield مباشرة.

## التحقق

بعد التثبيت والبناء، اختبر:
1. أنشئ scheduled list من 14:00 إلى 14:05 (دقيقتين من الآن)
2. أغلق التطبيق
3. عند 14:00: الـ shield يطبَّق
4. عند 14:05: الـ shield يُرفع تلقائياً

Console.app (filter by `app.nonet.blocking`) سيُظهر:
```
[Monitor] intervalDidStart: schedule.<UUID>
[Monitor] intervalDidEnd: schedule.<UUID>
```
