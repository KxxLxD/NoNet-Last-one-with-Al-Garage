## سياق المشروع (Project Context)

**NoNet** — تطبيق iOS Swift للرفاهية الرقمية. يحجب التطبيقات والمواقع عبر `FamilyControls` + `ManagedSettings` من Apple. iOS 16+، SwiftUI، Core Data، StoreKit 2، Sign in with Apple. محلي بالكامل (لا backend).

**معمارية:** `blocking app/Core/` يحتوي كل البنية التحتية (BlockingEngine, PermissionsManager, StoreManager, KeychainStore, …). الـ Views في `blocking app/`.

**أهم الملفات:** [README.md](README.md) • [ARCHITECTURE.md](ARCHITECTURE.md) • [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) • [GSTACK_GUIDE_AR.md](GSTACK_GUIDE_AR.md)

**اللغة:** التواصل مع المستخدم بالعربية. التعليقات في الكود بالإنجليزية.

**الاختبار:** Family Controls **لا يعمل في Simulator** — يجب اختباره على جهاز حقيقي.

---

## gstack (REQUIRED — global install)

**Before doing ANY work, verify gstack is installed:**

```bash
test -d ~/.claude/skills/gstack/bin && echo "GSTACK_OK" || echo "GSTACK_MISSING"
```

If GSTACK_MISSING: STOP. Do not proceed. Tell the user:

> gstack is required for all AI-assisted work in this repo.
> Install it:
> ```bash
> git clone --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack
> cd ~/.claude/skills/gstack && ./setup --team
> ```
> Then restart your AI coding tool.

Do not skip skills, ignore gstack errors, or work around missing gstack.

Using gstack skills: After install, skills like /qa, /ship, /review, /investigate,
and /browse are available. Use /browse for all web browsing.
Use ~/.claude/skills/gstack/... for gstack file paths (the global path).
