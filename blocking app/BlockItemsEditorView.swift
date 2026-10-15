import SwiftUI
import CoreData
import FamilyControls

struct DraftBlockItem: Identifiable, Hashable {
    enum Kind { case website, app, category }
    let id = UUID()
    var kind: Kind
    var value: String // domain | category key | app token placeholder
    var displayName: String? // optional label
}

struct BlockItemsDraft {
    var name: String = ""
    var websites: [DraftBlockItem] = []
    var apps: [DraftBlockItem] = []
    var categories: [DraftBlockItem] = []
    /// FamilyControls picker selection — must be passed to BlockingEngine via FamilySelectionStore.
    var familySelection: FamilyActivitySelection = FamilyActivitySelection()
}

/// Trailing accessory style for `editorRow`. Determines whether the row
/// behaves like a multi-select toggle (`.checkmark`), an action that
/// opens another sheet (`.chevron`), or an action that also displays
/// the selection count (`.count(Int)`).
private enum EditorRowTrailing {
    case checkmark
    case chevron
    case count(Int)
}

struct BlockItemsEditorView: View {
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @State var draft: BlockItemsDraft
    var onSave: (BlockItemsDraft) -> Void

    init(draft: BlockItemsDraft, onSave: @escaping (BlockItemsDraft) -> Void) {
        self._draft = State(initialValue: draft)
        self.onSave = onSave
        self._familySelection = State(initialValue: draft.familySelection)
    }

    @State private var selectedCategories: Set<String> = []

    @State private var showAppPicker = false
    @State private var familySelection: FamilyActivitySelection
    // D13 — surfaces Family Controls denial with a Settings deep-link instead
    // of silently failing to open the picker.
    @State private var showPermissionAlert = false

    // Manual website entries — string domains the user typed directly. Kept
    // separate from picker-selected websites because `handleFamilySelectionChange`
    // rebuilds the picker-side entries from `familySelection.webDomainTokens`
    // every time the picker fires. Manual entries persist across picker runs.
    @State private var manualWebsites: [String] = []
    @State private var websiteURLInput: String = ""

    // Quick Apps in editor
    private let quickApps: [QuickAppEditor] = QuickAppEditor.defaultSet
    @State private var quickSelected: Set<String> = []

    private var categoryOptionsAr: [String] { ["وسائل التواصل الاجتماعي","الشورتس والريلز","الألعاب","تطبيقات التسوق","تطبيقات التوصيل","تطبيقات المقامرة","تطبيقات المواعدة","محتوى للبالغين"] }
    private var categoryOptionsEn: [String] { ["Social Media","Shorts & Reels","Games","Shopping Apps","Delivery Apps","Gambling Apps","Dating Apps","Adult Content"] }

    private var categoryOptions: [String] { lang.isArabicEffective ? categoryOptionsAr : categoryOptionsEn }

    /// Tracks whether the user has made any changes since opening the editor —
    /// used to prompt "discard changes?" when they tap Back without saving.
    @State private var hasUnsavedChanges: Bool = false
    /// "Are you sure you want to discard?" confirmation when backing out
    /// after touching anything.
    @State private var showDiscardAlert: Bool = false

    var body: some View {
        NavigationStack {
            editorForm()
        }
    }

    // Splitting the form into a function keeps `body` short enough for the
    // Swift type-checker; chaining toolbar + 5 onChange + sheet + 2 alerts on
    // a single inline expression broke the inference budget.
    //
    // ScrollViewReader + chip navigator removed: section headers are big
    // enough to orient users on their own, and the chip row duplicated their
    // function while adding ~80pt of vertical noise.
    private func editorForm() -> some View {
        Form {
            // Single privacy banner at the top — replaces the two
            // per-section info-icon rows under Apps + Websites. Apple's
            // tokens are opaque across the whole sheet (apps, websites,
            // and categories from the picker all return tokens), so one
            // shared explainer is more honest about scope.
            privacyBanner

            // Order (post-user-feedback): Specific Apps → Websites →
            // Popular Apps → Categories. The user wanted Specific Apps
            // (Apple picker) at the top because that's how they think
            // about "what apps do I want to block right now" — the
            // device's own apps. Popular Apps drops to third (still
            // surfaced, but as a quick-pick layer after the primary
            // device picker). Categories stays last as the catch-all.
            //   1. Specific Apps  — Apple Family Activity Picker (device apps)
            //   2. Websites       — manual URL entry (with iOS constraint note)
            //   3. Popular Apps   — quick toggles for TikTok, Instagram, etc.
            //   4. Categories     — broad fallback buckets
            specificAppsSection
            websitesSection
            quickAppsSection
            categoriesSection
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.uiBackground)
        .navigationTitle(navigationTitleWithCount)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        // Match CreateListSheet's breathing-room: section footer text in
        // the last section (currently Categories) gets some space above
        // the sticky Save bar rather than crowding straight up to it.
        .padding(.bottom, NNSpacing.xl)
        .safeAreaInset(edge: .bottom) { saveBar }
        .onAppear(perform: handleOnAppear)
        .onChange(of: selectedCategories) { _ in hasUnsavedChanges = true }
        .onChange(of: quickSelected)      { _ in hasUnsavedChanges = true }
        .onChange(of: draft.websites)     { _ in hasUnsavedChanges = true }
        .onChange(of: draft.apps)         { _ in hasUnsavedChanges = true }
        .onChange(of: familySelection)    { _ in handleFamilySelectionChange() }
        .sheet(isPresented: $showAppPicker) { pickerSheet }
        // Block swipe-to-dismiss while there are unsaved changes — otherwise
        // a casual downward swipe silently throws away every selection. The
        // explicit Cancel button still surfaces the discard confirmation.
        .interactiveDismissDisabled(hasUnsavedChanges)
        .alert(
            lang.isArabicEffective ? "تجاهل التعديلات؟" : "Discard changes?",
            isPresented: $showDiscardAlert
        ) {
            Button(lang.isArabicEffective ? "تجاهلها" : "Discard", role: .destructive) { dismiss() }
            Button(lang.isArabicEffective ? "متابعة التعديل" : "Keep editing", role: .cancel) {}
        } message: {
            Text(lang.isArabicEffective ? "ستضيع تعديلاتك ولن يمكن استرجاعها." : "Your changes will be lost and can't be recovered.")
        }
        .alert(
            lang.isArabicEffective ? "يحتاج إذن Screen Time" : "Screen Time permission needed",
            isPresented: $showPermissionAlert
        ) {
            Button(lang.isArabicEffective ? "فتح الإعدادات" : "Open Settings") {
                PermissionsManager.shared.openAppSettings()
            }
            Button(lang.isArabicEffective ? "لاحقاً" : "Later", role: .cancel) {}
        } message: {
            Text(lang.isArabicEffective
                ? "لاختيار التطبيقات للحجب، فعّل Screen Time من الإعدادات > Screen Time. NoNet يعمل محلياً على جهازك فقط."
                : "To pick apps to block, enable Screen Time in Settings > Screen Time. NoNet runs locally on your device only.")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Only Cancel lives in the toolbar now. Save moved to a sticky
        // safeAreaInset bar at the bottom of the form — bigger, shows the
        // selection count, harder to miss than a small toolbar link.
        ToolbarItem(placement: .cancellationAction) {
            Button(lang.isArabicEffective ? "إلغاء" : "Cancel") {
                if hasUnsavedChanges {
                    showDiscardAlert = true
                } else {
                    dismiss()
                }
            }
        }
    }

    /// Sticky Save bar — full-width accent button at the bottom of the
    /// editor, shows the live selection count in the label so the user
    /// knows exactly what they're about to save. Disabled (40% opacity)
    /// when nothing's picked yet, matching CreateListSheet's Done bar.
    @ViewBuilder
    private var saveBar: some View {
        let count = totalSelectionCount
        let isEnabled = count > 0
        let saveLabelAr = count > 0 ? "حفظ (\(count) محدّد)" : "حفظ"
        let saveLabelEn = count > 0 ? "Save (\(count) selected)" : "Save"
        Button(action: { if isEnabled { saveAndDismiss() } }) {
            Text(lang.isArabicEffective ? saveLabelAr : saveLabelEn)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: NNHitTarget.minimum + 6)
                .background(isEnabled ? AppColors.accent : AppColors.accent.opacity(0.4))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(lang.isArabicEffective ? "حفظ" : "Save")
        .accessibilityHint(isEnabled
                            ? (lang.isArabicEffective ? "حفظ \(count) عنصر" : "Save \(count) item\(count == 1 ? "" : "s")")
                            : (lang.isArabicEffective ? "أضف عنصراً واحداً على الأقل لتفعيل الحفظ" : "Add at least one item to enable save"))
        .padding(.horizontal, NNSpacing.md)
        .padding(.top, NNSpacing.xs)
        .padding(.bottom, NNSpacing.md)
        .background(AppColors.uiBackground)
    }

    @ViewBuilder
    private var pickerSheet: some View {
        if #available(iOS 16.0, *) {
            PickerSheetWrapper(
                selection: $familySelection,
                title: lang.isArabicEffective ? "اختر الأنشطة" : "Choose Activities",
                onDone: { dismissPickerAndApply() },
                onCancel: { showAppPicker = false }
            )
            .environmentObject(lang)
        }
    }

    private func handleOnAppear() {
        selectedCategories = Set(draft.categories.map { $0.displayName ?? $0.value })
        // Restore manually-typed websites from a previous edit session.
        // We distinguish manual entries from picker entries by the value
        // shape: picker entries start with "picker:" (UUID-shaped legacy
        // entries from earlier builds also count as picker), while manual
        // entries are bare domain strings.
        manualWebsites = draft.websites
            .map { $0.value }
            .filter { !$0.hasPrefix("picker:") && $0.contains(".") && !$0.contains("-") }
        // Reset the unsaved-changes flag every time the editor opens —
        // the initial state IS the saved state.
        hasUnsavedChanges = false
    }

    private func handleFamilySelectionChange() {
        if #available(iOS 16.0, *) {
            // Apps come from FamilyActivitySelection only — no manual path
            // for those, so straight replacement is fine.
            let appCount = familySelection.applicationTokens.count
            draft.apps = (0..<appCount).map { idx in
                let name = lang.isArabicEffective ? "تطبيق محدد #\(idx + 1)" : "Selected App #\(idx + 1)"
                return DraftBlockItem(kind: .app, value: UUID().uuidString, displayName: name)
            }
            // Websites have two sources (manual entries + picker tokens), so
            // delegate to the merge function rather than replacing the array.
            rebuildWebsitesDraft()
        }
    }

    // ─── Top-of-form privacy banner ────────────────────────────────
    //
    // One unified explainer for the whole editor. Replaces the previous
    // pair of per-section info-icon rows (one under Apps, one under
    // Websites) which duplicated the same "Apple hides chosen names"
    // message. Categories selected via picker have the same opacity
    // constraint, so banner at top is the honest scope.
    private var privacyBanner: some View {
        Section {
            HStack(alignment: .top, spacing: NNSpacing.sm) {
                Image(systemName: "lock.shield.fill")
                    .font(.body)
                    .foregroundColor(AppColors.accent)
                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 2) {
                    Text(lang.isArabicEffective ? "خصوصيتك محفوظة" : "Your privacy is protected")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(lang.isArabicEffective
                         ? "Apple تخفي أسماء التطبيقات والمواقع المحدّدة. يظهر العدد فقط."
                         : "Apple hides the chosen app and website names. Only the count is shown.")
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
            }
            .padding(NNSpacing.md)
            .background(AppColors.infoBg)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    // ─── Unified row helper used by every section ─────────────────
    //
    // ONE visual register for every selectable item across the editor.
    // Previously each section had its own treatment (hero cards for
    // Categories, capsule chips for Quick Apps, full-width buttons for
    // Apps + Websites). That visual sprawl was the "ugly" the user
    // called out. Compact 56pt rows give the editor a flat, scannable
    // list register and shrink the form's height by roughly half.
    @ViewBuilder
    private func editorRow(
        icon: String,
        title: String,
        subtitle: String? = nil,
        isSelected: Bool,
        trailing: EditorRowTrailing = .checkmark,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: NNSpacing.sm) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(isSelected ? AppColors.accent : AppColors.textSecondary)
                    .frame(width: 24, height: 24, alignment: .center)
                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    if let subtitle = subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
                trailingView(for: trailing, isSelected: isSelected)
            }
            .padding(.horizontal, NNSpacing.sm)
            .padding(.vertical, NNSpacing.xs)
            .frame(minHeight: NNHitTarget.minimum + 12)
            .background(isSelected ? AppColors.infoBg : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    @ViewBuilder
    private func trailingView(for style: EditorRowTrailing, isSelected: Bool) -> some View {
        switch style {
        case .checkmark:
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundColor(isSelected ? AppColors.accent : AppColors.textSecondary.opacity(0.4))
        case .chevron:
            Image(systemName: lang.isArabicEffective ? "chevron.left" : "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundColor(AppColors.textSecondary)
        case .count(let n):
            HStack(spacing: NNSpacing.xxs) {
                Text("\(n)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundColor(AppColors.accent)
                Image(systemName: lang.isArabicEffective ? "chevron.left" : "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    // ─── Section 1: Categories (broadest, fastest) ────────────────

    private var categoriesSection: some View {
        Section {
            VStack(spacing: 0) {
                ForEach(Array(categoryOptions.enumerated()), id: \.element) { idx, cat in
                    editorRow(
                        icon: categoryIcon(for: cat),
                        title: cat,
                        subtitle: categoryExamples(for: cat),
                        isSelected: selectedCategories.contains(cat),
                        action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if selectedCategories.contains(cat) {
                                    selectedCategories.remove(cat)
                                } else {
                                    selectedCategories.insert(cat)
                                }
                            }
                        }
                    )
                    if idx < categoryOptions.count - 1 {
                        Divider()
                            .padding(.leading, NNSpacing.lg)
                    }
                }
            }
            .padding(.vertical, NNSpacing.xxs)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
        } header: {
            sectionHeader(icon: "square.grid.2x2.fill", text: lang.isArabicEffective ? "الفئات" : "Categories")
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    /// SF Symbol icon for each category. Bilingual keys map to the same icon
    /// since the category meaning doesn't change with language. Falls back
    /// to a generic grid icon if an unknown category is passed in (keeps
    /// the layout stable if the category list changes upstream).
    private func categoryIcon(for category: String) -> String {
        switch category {
        case "وسائل التواصل الاجتماعي", "Social Media":
            return "bubble.left.and.bubble.right.fill"
        case "الشورتس والريلز", "Shorts & Reels":
            return "play.rectangle.fill"
        case "الألعاب", "Games":
            return "gamecontroller.fill"
        case "تطبيقات التسوق", "Shopping Apps":
            return "bag.fill"
        case "تطبيقات التوصيل", "Delivery Apps":
            return "shippingbox.fill"
        case "تطبيقات المقامرة", "Gambling Apps":
            return "dice.fill"
        case "تطبيقات المواعدة", "Dating Apps":
            return "heart.fill"
        case "محتوى للبالغين", "Adult Content":
            return "eye.slash.fill"
        default:
            return "square.grid.2x2.fill"
        }
    }

    /// Localized example apps/sites for each category — shown as a quiet
    /// preview under the category name. Defensive nil-return so unknown
    /// categories don't render an empty caption line.
    private func categoryExamples(for category: String) -> String? {
        let examplesAr: [String: String] = [
            "وسائل التواصل الاجتماعي": "يشمل: Instagram، Facebook، Snapchat",
            "الشورتس والريلز": "يشمل: TikTok، YouTube Shorts، Reels",
            "الألعاب": "يشمل: ألعاب الجوال والمتصفح",
            "تطبيقات التسوق": "يشمل: Amazon، نون، AliExpress",
            "تطبيقات التوصيل": "يشمل: Talabat، HungerStation، Careem",
            "تطبيقات المقامرة": "كل تطبيقات ومواقع القمار",
            "تطبيقات المواعدة": "يشمل: Tinder، Bumble، Hinge",
            "محتوى للبالغين": "كل المحتوى الإباحي والمشكوك فيه"
        ]
        let examplesEn: [String: String] = [
            "Social Media": "e.g. Instagram, Facebook, Snapchat",
            "Shorts & Reels": "e.g. TikTok, YouTube Shorts, Reels",
            "Games": "Mobile and browser games",
            "Shopping Apps": "e.g. Amazon, AliExpress",
            "Delivery Apps": "e.g. Uber Eats, DoorDash",
            "Gambling Apps": "All gambling apps and sites",
            "Dating Apps": "e.g. Tinder, Bumble, Hinge",
            "Adult Content": "All adult and questionable content"
        ]
        return lang.isArabicEffective ? examplesAr[category] : examplesEn[category]
    }

    // ─── Section 2: Quick Apps (popular shortcuts, one flat list) ─

    private var quickAppsSection: some View {
        Section {
            VStack(spacing: 0) {
                ForEach(Array(QuickAppEditor.groups.enumerated()), id: \.element.title) { groupIdx, group in
                    // Tiny group label between subgroups — quieter than the
                    // previous bold subheaders + count chip.
                    if groupIdx > 0 {
                        Divider()
                            .padding(.horizontal, NNSpacing.sm)
                            .padding(.vertical, NNSpacing.xxs)
                    }
                    HStack {
                        Text(lang.isArabicEffective ? group.titleAr : group.title)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .textCase(.uppercase)
                        Spacer()
                    }
                    .padding(.horizontal, NNSpacing.md)
                    .padding(.top, NNSpacing.xs)
                    .padding(.bottom, NNSpacing.xxs)

                    ForEach(Array(group.items.enumerated()), id: \.element.key) { idx, qa in
                        editorRow(
                            icon: qa.icon,
                            title: qa.title,
                            subtitle: nil,
                            isSelected: quickSelected.contains(qa.key),
                            action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    if quickSelected.contains(qa.key) {
                                        quickSelected.remove(qa.key)
                                    } else {
                                        quickSelected.insert(qa.key)
                                    }
                                }
                            }
                        )
                        if idx < group.items.count - 1 {
                            Divider()
                                .padding(.leading, NNSpacing.lg)
                        }
                    }
                }
            }
            .padding(.vertical, NNSpacing.xxs)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
        } header: {
            sectionHeader(icon: "bolt.fill", text: lang.isArabicEffective ? "تطبيقات شائعة" : "Popular Apps")
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    // ─── Section 3: Specific Apps via Family Activity Picker ─────

    private var specificAppsSection: some View {
        Section {
            if #available(iOS 16.0, *) {
                editorRow(
                    icon: "square.stack.3d.up.fill",
                    title: lang.isArabicEffective
                        ? (draft.apps.isEmpty ? "اختر تطبيقات من جهازك" : "تعديل الاختيار")
                        : (draft.apps.isEmpty ? "Pick apps from your device" : "Edit selection"),
                    subtitle: draft.apps.isEmpty
                        ? nil
                        : (lang.isArabicEffective
                            ? "\(draft.apps.count) تطبيق محدّد"
                            : "\(draft.apps.count) app\(draft.apps.count == 1 ? "" : "s") selected"),
                    isSelected: !draft.apps.isEmpty,
                    trailing: draft.apps.isEmpty ? .chevron : .count(draft.apps.count),
                    action: { handleAppsButtonTap() }
                )
                .padding(.vertical, NNSpacing.xxs)
                .background(AppColors.uiSurface)
                .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
            }
        } header: {
            sectionHeader(icon: "app.fill", text: lang.isArabicEffective ? "تطبيقات محدّدة" : "Specific Apps")
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    // ─── Section 4: Websites (via Family Activity Picker) ──────────
    //
    // ManagedSettings.shield.webDomains only accepts opaque WebDomainTokens
    // produced by FamilyActivityPicker, not raw URL strings. The previous
    // TextField-driven UX accepted user-typed domains that the blocking engine
    // could never actually shield — silently broken. This section now opens
    // the same picker as `specificAppsSection` so the user adds websites by
    // tapping the picker's "Websites" tab. One picker, three input modes
    // (Apps / Categories / Websites) — matches Apple's own pattern.

    // Websites section — manual URL entry (primary) + Apple Picker (secondary).
    //
    // Why manual entry is primary: the user feedback said they couldn't find
    // a "Pick Websites" affordance in Apple's picker and wanted to type URLs
    // directly. The HONEST truth is that iOS's ManagedSettings.Shield.webDomains
    // only accepts opaque WebDomainTokens which come from FamilyActivityPicker
    // (which surfaces sites the user has visited in Safari). So:
    //   1. Manual URLs are accepted into the list (matches user mental model)
    //   2. A short helper line tells the user that iOS may need them to visit
    //      the URL in Safari before the actual shield engages — no silent lies
    //   3. The Apple Picker stays available for sites already in Safari history
    private var websitesSection: some View {
        Section {
            VStack(spacing: 0) {
                // Manual URL input — TextField + Add button as one row.
                manualURLInputRow

                if !manualWebsites.isEmpty {
                    Divider().padding(.leading, NNSpacing.lg)
                    ForEach(Array(manualWebsites.enumerated()), id: \.element) { idx, domain in
                        manualWebsiteRow(domain: domain)
                        if idx < manualWebsites.count - 1 {
                            Divider().padding(.leading, NNSpacing.lg)
                        }
                    }
                }

                // Honest constraint note — only shows when the user has at
                // least one manual URL or the picker has at least one site,
                // so it doesn't preempt the empty state.
                if !manualWebsites.isEmpty {
                    Divider().padding(.leading, NNSpacing.lg)
                    iOSConstraintNote
                }

                // Apple Picker as secondary option — visible always so users
                // who DO have sites in Safari history can use that path.
                if #available(iOS 16.0, *) {
                    Divider().padding(.leading, NNSpacing.lg)
                    let pickerWebsiteCount = max(0, draft.websites.count - manualWebsites.count)
                    editorRow(
                        icon: "safari",
                        title: lang.isArabicEffective ? "اختر من سجل Safari" : "Pick from Safari history",
                        subtitle: pickerWebsiteCount > 0
                            ? (lang.isArabicEffective
                                ? "\(pickerWebsiteCount) موقع من الـ picker"
                                : "\(pickerWebsiteCount) site\(pickerWebsiteCount == 1 ? "" : "s") via picker")
                            : (lang.isArabicEffective ? "للمواقع اللي زرتها مؤخراً" : "For sites you've visited recently"),
                        isSelected: pickerWebsiteCount > 0,
                        trailing: pickerWebsiteCount > 0 ? .count(pickerWebsiteCount) : .chevron,
                        action: { handleAppsButtonTap() }
                    )
                }
            }
            .padding(.vertical, NNSpacing.xxs)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
        } header: {
            sectionHeader(icon: "globe", text: lang.isArabicEffective ? "مواقع" : "Websites")
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    /// TextField + Add row at the top of the Websites section. Validates the
    /// typed string as a plausible domain (has a dot, no spaces) before
    /// accepting; otherwise the Add button stays disabled.
    @ViewBuilder
    private var manualURLInputRow: some View {
        HStack(spacing: NNSpacing.sm) {
            Image(systemName: "link")
                .font(.body)
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 24, height: 24, alignment: .center)
            TextField(lang.isArabicEffective ? "مثلاً: tiktok.com" : "e.g., tiktok.com",
                      text: $websiteURLInput)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .keyboardType(.URL)
                .submitLabel(.done)
                .onSubmit { addManualWebsite() }
            Button(action: { addManualWebsite() }) {
                Text(lang.isArabicEffective ? "أضف" : "Add")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(canAddManualWebsite ? .white : AppColors.textSecondary)
                    .padding(.horizontal, NNSpacing.md)
                    .padding(.vertical, NNSpacing.xs)
                    .background(canAddManualWebsite ? AppColors.accent : AppColors.uiBorder)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canAddManualWebsite)
        }
        .padding(.horizontal, NNSpacing.sm)
        .padding(.vertical, NNSpacing.sm)
        .frame(minHeight: NNHitTarget.minimum + 12)
    }

    /// Row for a manually-added website. Tap-target is the whole row; the
    /// trailing icon is an X that removes the entry. Visual register matches
    /// the unified editorRow shape used by every other selectable item.
    @ViewBuilder
    private func manualWebsiteRow(domain: String) -> some View {
        HStack(spacing: NNSpacing.sm) {
            Image(systemName: "globe")
                .font(.body)
                .foregroundColor(AppColors.accent)
                .frame(width: 24, height: 24, alignment: .center)
            Text(domain)
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
            Button(action: { removeManualWebsite(domain) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(AppColors.textSecondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(lang.isArabicEffective ? "حذف \(domain)" : "Remove \(domain)")
        }
        .padding(.horizontal, NNSpacing.sm)
        .padding(.vertical, NNSpacing.xs)
        .frame(minHeight: NNHitTarget.minimum + 12)
    }

    /// Honest helper note about Apple's iOS API constraint. Doesn't pretend
    /// — tells the user that manual URLs are captured in the list but may
    /// require visiting in Safari before the shield engages, which is how
    /// the underlying ManagedSettings.shield.webDomains API actually behaves.
    @ViewBuilder
    private var iOSConstraintNote: some View {
        HStack(alignment: .top, spacing: NNSpacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 24, height: 24, alignment: .center)
                .padding(.top, 1)
            Text(lang.isArabicEffective
                 ? "iOS يحجب المواقع اللي زرتها في Safari فقط. للحجب الفعلي: افتح الموقع مرة في Safari، ثم استخدم \"اختر من سجل Safari\" تحت."
                 : "iOS can only shield sites you've visited in Safari. For real blocking: open the site once in Safari, then use \"Pick from Safari history\" below.")
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
        }
        .padding(.horizontal, NNSpacing.sm)
        .padding(.vertical, NNSpacing.xs)
    }

    /// Validates the typed input as a plausible domain — has at least one
    /// dot and no whitespace. Doesn't validate TLD or DNS; that's the iOS
    /// runtime's job once the shield engages.
    private var canAddManualWebsite: Bool {
        let trimmed = websiteURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard !trimmed.contains(" ") else { return false }
        guard trimmed.contains(".") else { return false }
        let cleaned = cleanDomain(trimmed)
        return !manualWebsites.contains(cleaned)
    }

    /// Strips http://, https://, www., trailing slash, and lowercases. Stable
    /// representation so duplicates ("Tiktok.com" + "tiktok.com/") don't both
    /// end up in the list.
    private func cleanDomain(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for prefix in ["https://", "http://", "www."] {
            if s.hasPrefix(prefix) { s.removeFirst(prefix.count) }
        }
        if s.hasSuffix("/") { s.removeLast() }
        return s
    }

    private func addManualWebsite() {
        guard canAddManualWebsite else { return }
        let cleaned = cleanDomain(websiteURLInput)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.15)) {
            manualWebsites.append(cleaned)
            websiteURLInput = ""
        }
        rebuildWebsitesDraft()
        hasUnsavedChanges = true
    }

    private func removeManualWebsite(_ domain: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeInOut(duration: 0.15)) {
            manualWebsites.removeAll { $0 == domain }
        }
        rebuildWebsitesDraft()
        hasUnsavedChanges = true
    }

    /// Rebuilds `draft.websites` from the current `manualWebsites` + picker
    /// websites. Called whenever either source changes. The save-time path
    /// already iterates `draft.websites` so manual + picker entries both
    /// reach Core Data; the BlockingEngine integration for actually
    /// shielding manual URLs is a known iOS API gap, documented in
    /// iOSConstraintNote.
    private func rebuildWebsitesDraft() {
        var rebuilt: [DraftBlockItem] = manualWebsites.map {
            DraftBlockItem(kind: .website, value: $0, displayName: $0)
        }
        if #available(iOS 16.0, *) {
            let pickerCount = familySelection.webDomainTokens.count
            for idx in 0..<pickerCount {
                let name = lang.isArabicEffective ? "موقع محدد #\(idx + 1)" : "Selected Website #\(idx + 1)"
                rebuilt.append(DraftBlockItem(kind: .website, value: "picker:\(idx)", displayName: name))
            }
        }
        draft.websites = rebuilt
    }

    /// Single section-header style shared by all four sections — icon +
    /// text in the section's natural list-header position. Replaces the
    /// previous pattern of duplicating HStack header bodies in every section.
    @ViewBuilder
    private func sectionHeader(icon: String, text: String) -> some View {
        HStack(spacing: NNSpacing.xs) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(AppColors.accent)
            Text(text)
                .font(.nnCardTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, NNSpacing.xxs)
        .padding(.top, NNSpacing.sm)
        .textCase(nil)
    }

    private func dismissPickerAndApply() {
        showAppPicker = false
    }

    private func hasAtLeastOneItem() -> Bool {
        !draft.websites.isEmpty || !draft.apps.isEmpty || !selectedCategories.isEmpty || !quickSelected.isEmpty
    }

    /// Sum of every selection across all four sections — drives the
    /// "Block Items (N)" navigation title so users see progress as they
    /// pick items without having to scroll to verify each section.
    private var totalSelectionCount: Int {
        draft.websites.count + draft.apps.count + selectedCategories.count + quickSelected.count
    }

    /// Title with count suffix when there's at least one selection. Hides
    /// the parentheses when empty so the title doesn't read "Block Items (0)".
    private var navigationTitleWithCount: String {
        let base = lang.isArabicEffective ? "عناصر الحجب" : "Block Items"
        let count = totalSelectionCount
        guard count > 0 else { return base }
        return "\(base) (\(count))"
    }

    private func saveAndDismiss() {
        // Apply quick selections to websites + app placeholders
        for qa in quickApps where quickSelected.contains(qa.key) {
            if !draft.websites.contains(where: { $0.value == qa.domain }) {
                draft.websites.append(DraftBlockItem(kind: .website, value: qa.domain, displayName: qa.title))
            }
            if !draft.apps.contains(where: { ($0.displayName ?? $0.value).caseInsensitiveCompare(qa.title) == .orderedSame }) {
                draft.apps.append(DraftBlockItem(kind: .app, value: "quickapp:\(qa.key)", displayName: qa.title))
            }
        }
        draft.categories = selectedCategories.map { DraftBlockItem(kind: .category, value: $0, displayName: $0) }
        draft.familySelection = familySelection
        onSave(draft)
        dismiss()
    }

    private func requestFamilyControlsPermission() {
        Task { await PermissionsManager.shared.requestScreenTime() }
    }

    /// D13 — Apps button handler.
    ///
    /// Requests Family Controls, then opens the picker only if authorization
    /// succeeded. If the user (or device policy) denies, we surface an alert
    /// with a Settings deep-link rather than letting the picker silently fail
    /// to open — that silent failure was a high-friction onboarding drop point.
    private func handleAppsButtonTap() {
        Task {
            await PermissionsManager.shared.requestScreenTime()
            await MainActor.run {
                if PermissionsManager.shared.isScreenTimeGranted {
                    showAppPicker = true
                } else {
                    showPermissionAlert = true
                }
            }
        }
    }

}

private struct QuickAppEditor: Equatable {
    let key: String
    let title: String
    let domain: String
    let icon: String

    struct Group {
        let title: String   // EN
        let titleAr: String
        let items: [QuickAppEditor]
    }

    /// Grouped layout for the Quick Apps section — splits the 20-item flat
    /// list into three semantic buckets so users can mentally scope by
    /// "which kind of app." Each group renders as a DisclosureGroup.
    static let groups: [Group] = [
        Group(
            title: "Social & Video",
            titleAr: "السوشيال والفيديو",
            items: [
                .init(key: "tiktok",    title: "TikTok",      domain: "tiktok.com",    icon: "play.rectangle"),
                .init(key: "instagram", title: "Instagram",   domain: "instagram.com", icon: "camera"),
                .init(key: "snapchat",  title: "Snapchat",    domain: "snapchat.com",  icon: "bolt"),
                .init(key: "youtube",   title: "YouTube",     domain: "youtube.com",   icon: "play.circle"),
                .init(key: "twitter",   title: "X (Twitter)", domain: "twitter.com",   icon: "bubble.left"),
                .init(key: "facebook",  title: "Facebook",    domain: "facebook.com",  icon: "person.3"),
                .init(key: "reddit",    title: "Reddit",      domain: "reddit.com",    icon: "bubble.right"),
            ]
        ),
        Group(
            title: "Messaging",
            titleAr: "المراسلة",
            items: [
                .init(key: "whatsapp",  title: "WhatsApp",  domain: "whatsapp.com",  icon: "phone.circle"),
                .init(key: "messenger", title: "Messenger", domain: "messenger.com", icon: "message"),
                .init(key: "telegram",  title: "Telegram",  domain: "telegram.org",  icon: "paperplane"),
                .init(key: "discord",   title: "Discord",   domain: "discord.com",   icon: "gamecontroller"),
                .init(key: "wechat",    title: "WeChat",    domain: "wechat.com",    icon: "bubble.left.and.bubble.right"),
            ]
        ),
        Group(
            title: "Entertainment",
            titleAr: "الترفيه والبث",
            items: [
                .init(key: "twitch",     title: "Twitch",      domain: "twitch.tv",       icon: "gamecontroller.fill"),
                .init(key: "netflix",    title: "Netflix",     domain: "netflix.com",     icon: "film"),
                .init(key: "primevideo", title: "Prime Video", domain: "primevideo.com",  icon: "film.stack"),
                .init(key: "disneyplus", title: "Disney+",     domain: "disneyplus.com",  icon: "star"),
                .init(key: "hbo",        title: "Max (HBO)",   domain: "max.com",         icon: "star.circle"),
                .init(key: "hulu",       title: "Hulu",        domain: "hulu.com",        icon: "play.rectangle.on.rectangle"),
                .init(key: "shahid",     title: "Shahid",      domain: "shahid.mbc.net",  icon: "rectangle.fill.on.rectangle.fill"),
                .init(key: "osnplus",    title: "OSN+",        domain: "osnplus.com",     icon: "tv"),
            ]
        )
    ]

    /// Flattened list of every Quick App across all groups — preserved as
    /// `defaultSet` so call sites that iterate over every entry (e.g. the
    /// save-time fan-out in `saveAndDismiss`) keep working without change.
    static let defaultSet: [QuickAppEditor] = groups.flatMap { $0.items }
}

#Preview {
    BlockItemsEditorView(draft: BlockItemsDraft(), onSave: { _ in })
        .environmentObject(LanguageManager.shared)
}

// MARK: - Picker Wrapper
@available(iOS 16.0, *)
private struct PickerSheetWrapper: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var lang: LanguageManager
    @Binding var selection: FamilyActivitySelection

    let title: String
    var onDone: () -> Void
    var onCancel: () -> Void

    @State private var initialSelection = FamilyActivitySelection()
    @State private var showCancelAlert = false

    var body: some View {
        // Previously used ZStack(alignment: .bottom) to overlay the Done
        // button on top of FamilyActivityPicker. That caused the last items
        // in the picker's scroll list to be hidden BEHIND the floating Done
        // button — the user's complaint ("text is hidden between them").
        //
        // safeAreaInset properly reserves space in the picker's scroll area
        // for the bottom Done bar, so the last item can scroll fully into
        // view above the button instead of getting masked by it.
        NavigationView {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(lang.isArabicEffective ? "إلغاء" : "Cancel") {
                            handleCancel()
                        }
                    }
                    // Top toolbar Done kept for users who reach for Apple's
                    // standard navigation pattern. The bottom Done below is
                    // for thumb reach after scrolling.
                    ToolbarItem(placement: .confirmationAction) {
                        Button(lang.isArabicEffective ? "تم" : "Done") {
                            onDone(); dismiss()
                        }
                        .font(.headline)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Button(action: { onDone(); dismiss() }) {
                        Text(lang.isArabicEffective ? "تم" : "Done")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: NNHitTarget.minimum + 6)
                            .background(AppColors.accent)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, NNSpacing.md)
                    .padding(.top, NNSpacing.xs)
                    .padding(.bottom, NNSpacing.sm)
                    .background(AppColors.uiBackground)
                }
                .interactiveDismissDisabled(hasChanges)
                .onAppear { initialSelection = selection }
                .alert(lang.isArabicEffective ? "تجاهل التعديلات؟" : "Discard changes?", isPresented: $showCancelAlert) {
                    Button(lang.isArabicEffective ? "تجاهلها" : "Discard", role: .destructive) {
                        // revert
                        selection = initialSelection
                        onCancel(); dismiss()
                    }
                    Button(lang.isArabicEffective ? "متابعة التعديل" : "Keep editing", role: .cancel) {}
                } message: {
                    Text(lang.isArabicEffective ? "ستضيع تعديلاتك ولن يمكن استرجاعها." : "Your changes will be lost and can't be recovered.")
                }
        }
    }

    private var hasChanges: Bool {
        selection != initialSelection
    }
    private func handleCancel() {
        if hasChanges { showCancelAlert = true } else { onCancel(); dismiss() }
    }
} 