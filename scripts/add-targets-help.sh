#!/usr/bin/env bash
# Interactive guide to add the two manual Xcode targets:
#   1. blocking appTests (Unit Tests)
#   2. BlockingMonitor (DeviceActivity Monitor Extension)
#
# Usage:
#   chmod +x scripts/add-targets-help.sh
#   ./scripts/add-targets-help.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
XCODEPROJ="$PROJECT_DIR/blocking app.xcodeproj"

clear
echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║   NoNet — إعداد Targets المتبقية في Xcode                   ║${NC}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}سيقوم هذا السكريبت بفتح Xcode وإرشادك خطوة بخطوة لإضافة:${NC}"
echo "  1. Tests Target — لتشغيل الـ 32 unit test"
echo "  2. BlockingMonitor Extension — للحجب المجدول"
echo "  3. App Groups capability — لمشاركة البيانات بين الـ targets"
echo ""

read -p "$(echo -e "${YELLOW}اضغط Enter للبدء، أو Ctrl+C للإلغاء...${NC}")"

# ───────────────────────────────────────────────
# Step 1: Open Xcode
# ───────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}الخطوة 1: فتح المشروع${NC}"
echo "جارٍ فتح Xcode..."
open -a Xcode "$XCODEPROJ"
sleep 2

read -p "$(echo -e "${YELLOW}هل فتح المشروع؟ اضغط Enter للمتابعة...${NC}")"

# ───────────────────────────────────────────────
# Step 2: Tests Target
# ───────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}الخطوة 2: إضافة Tests Target${NC}"
cat <<'EOF'

  📱 في Xcode:

  1. File → New → Target...                        (Cmd+Ctrl+N)
  2. اختر iOS → "Unit Testing Bundle"
  3. Next
  4. املأ الحقول:
     • Product Name:        blocking appTests
     • Team:                L2T9STCPA5
     • Organization ID:     com.nonetapp
     • Target to be Tested: blocking app
  5. Finish

  ⚠️  مهم: Xcode أنشأ ملف blocking_appTests.swift افتراضي.
      احذفه (Right-click → Delete → Move to Trash)
      الملفات الموجودة في blocking appTests/ ستظهر تلقائياً.

EOF

read -p "$(echo -e "${YELLOW}بعد إكمال الخطوة 2، اضغط Enter...${NC}")"

# ───────────────────────────────────────────────
# Step 3: BlockingMonitor Target
# ───────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}الخطوة 3: إضافة BlockingMonitor Extension${NC}"
cat <<'EOF'

  📱 في Xcode:

  1. File → New → Target...                        (Cmd+Ctrl+N)
  2. اختر iOS → "Device Activity Monitor Extension"
     (ابحث "Activity" في شريط البحث للوصول السريع)
  3. Next
  4. املأ الحقول:
     • Product Name:        BlockingMonitor
     • Team:                L2T9STCPA5
     • Bundle Identifier:   com.nonetapp.BlockingMonitor
     • Embed in:            blocking app
  5. Finish

  ⚠️  مهم: احذف ملف DeviceActivityMonitor.swift الافتراضي.
      ملف BlockingMonitor.swift الموجود في BlockingMonitor/ سيظهر.

EOF

read -p "$(echo -e "${YELLOW}بعد إكمال الخطوة 3، اضغط Enter...${NC}")"

# ───────────────────────────────────────────────
# Step 4: App Groups for both targets
# ───────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}الخطوة 4: تفعيل App Groups في كلا الـ Targets${NC}"
cat <<'EOF'

  📱 لكل من "blocking app" و "BlockingMonitor":

  1. اختر الـ Target في الـ Project Navigator
  2. اذهب لـ "Signing & Capabilities"
  3. اضغط "+ Capability"
  4. اختر "App Groups"
  5. اضغط "+" تحت App Groups
  6. أضف: group.com.nonetapp.shared
  7. تأكد أنها مفعّلة (✓)

  💡 إذا ظهرت رسالة عن Provisioning Profile:
     - افتح Apple Developer Portal:
       https://developer.apple.com/account/resources/identifiers/list/applicationGroup
     - أنشئ App Group بنفس الـ Identifier: group.com.nonetapp.shared
     - ارجع لـ Xcode → Try Again

EOF

read -p "$(echo -e "${YELLOW}بعد إكمال الخطوة 4، اضغط Enter...${NC}")"

# ───────────────────────────────────────────────
# Step 5: Add Family Controls to BlockingMonitor
# ───────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}الخطوة 5: Family Controls capability للـ BlockingMonitor${NC}"
cat <<'EOF'

  📱 في Xcode:

  1. اختر "BlockingMonitor" Target
  2. Signing & Capabilities → + Capability
  3. أضف "Family Controls"
  4. تأكد أنها مفعّلة

EOF

read -p "$(echo -e "${YELLOW}بعد إكمال الخطوة 5، اضغط Enter...${NC}")"

# ───────────────────────────────────────────────
# Final verification
# ───────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}الخطوة 6: التحقق${NC}"
cat <<'EOF'

  ✅ في Xcode:

  1. Product → Test                                (Cmd+U)
     → يجب أن تنجح كل الـ 32 اختبار

  2. Product → Build                               (Cmd+B)
     → يجب أن يبني بدون errors

  3. تأكد من ظهور 3 Targets في Project Navigator:
     • blocking app
     • blocking appTests
     • BlockingMonitor

EOF

echo ""
echo -e "${BOLD}${GREEN}✅ انتهيت! المشروع جاهز للـ Archive والإرسال لـ App Store.${NC}"
echo ""
echo -e "${CYAN}الخطوة التالية: راجع TODO_FOR_KHALID.md للمراحل المتبقية:${NC}"
echo "  - طلب Family Controls Distribution Entitlement من Apple"
echo "  - استضافة صفحات docs/web/"
echo "  - App Store Connect setup"
echo "  - التقاط Screenshots"
echo "  - Archive + Submit for Review"
echo ""
