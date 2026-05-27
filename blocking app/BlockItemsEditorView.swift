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
            // `ScrollViewReader` lets the chip navigator at the top of the
            // editor scroll-to specific sections. Without it, users in
            // testing got stuck on Categories and never realised Apps +
            // Websites existed below the fold.
            ScrollViewReader { proxy in
                editorForm(proxy: proxy)
            }
        }
    }

    // Splitting the form into a function keeps `body` short enough for the
    // Swift type-checker; chaining toolbar + 5 onChange + sheet + 2 alerts on
    // a single inline expression broke the inference budget.
    private func editorForm(proxy: ScrollViewProxy) -> some View {
        Form {
            // Section navigator pinned at the top — 4 chips showing every
            // possible way to add items, each with a live selection count
            // and a tap-to-scroll affordance.
            sectionNavigator(proxy: proxy)

            // Order reflects how real users in testing reached for what to
            // block: they think of named brand apps first ("block TikTok"),
            // then specific URLs they want to ban, then the broader
            // categories as a catch-all. The previous "broadest first"
            // ordering forced everyone through the 8-category list before
            // they could surface the specific items they actually came in
            // to block.
            //   1. Popular Apps   — recognisable brands by name (TikTok, IG…)
            //   2. Websites       — explicit URLs to ban
            //   3. Specific Apps  — Family Activity Picker for device apps
            //   4. Categories     — broad fallback buckets
            quickAppsSection.id("sec-quick")
            websitesSection.id("sec-websites")
            specificAppsSection.id("sec-apps")
            categoriesSection.id("sec-categories")
            // (Removed the empty-selection footer card: the chip navigator
            // already shows zero counts on every chip and the Save button
            // is visibly disabled, so the long explainer card was redundant.)
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.uiBackground)
        .navigationTitle(navigationTitleWithCount)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
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
        ToolbarItem(placement: .cancellationAction) {
            Button(lang.isArabicEffective ? "إلغاء" : "Cancel") {
                if hasUnsavedChanges {
                    showDiscardAlert = true
                } else {
                    dismiss()
                }
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(lang.isArabicEffective ? "حفظ" : "Save") { saveAndDismiss() }
                .disabled(!hasAtLeastOneItem())
        }
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
        // Reset the unsaved-changes flag every time the editor opens —
        // the initial state IS the saved state.
        hasUnsavedChanges = false
    }

    private func handleFamilySelectionChange() {
        if #available(iOS 16.0, *) {
            // Apps and websites both come from the same FamilyActivitySelection;
            // they're separated here only for UI count display. The actual
            // shielding uses the full selection via FamilySelectionStore.
            let appCount = familySelection.applicationTokens.count
            let webCount = familySelection.webDomainTokens.count
            // Use half-open `..<` (empty when count is 0) instead of
            // closed `1...count` (which crashes when count is 0).
            draft.apps = (0..<appCount).map { idx in
                let name = lang.isArabicEffective ? "تطبيق محدد #\(idx + 1)" : "Selected App #\(idx + 1)"
                return DraftBlockItem(kind: .app, value: UUID().uuidString, displayName: name)
            }
            draft.websites = (0..<webCount).map { idx in
                let name = lang.isArabicEffective ? "موقع محدد #\(idx + 1)" : "Selected Website #\(idx + 1)"
                return DraftBlockItem(kind: .website, value: UUID().uuidString, displayName: name)
            }
        }
    }

    // ─── Section navigator (4 chips — discoverability anchor) ─────
    //
    // Renders as the first Form section. The 4 chips correspond 1:1 to the
    // sections below; tapping any chip scrolls smoothly to that section.
    // Active state (count > 0) tints the chip with accent + adds a small
    // count badge so users see their progress without scrolling back.
    //
    // Why this exists: user testing showed people stop after Categories and
    // never discover the Apps + Websites sections. The chip row is the
    // single visible affordance that all four methods exist.

    private func sectionNavigator(proxy: ScrollViewProxy) -> some View {
        // Floating chip row (no surrounding card). The four content sections
        // below all use card backgrounds, so dropping the card here gives the
        // navigator a different visual register — reads as a control bar
        // rather than another content block. The label "Pick how to add" is
        // also removed: after Pass 6 cleanup the chips are recognisable as
        // tappable on their own, and an explainer above redundant.
        Section {
            // Chip order mirrors the section render order below: Popular
            // first, then Websites, then My Apps, then Categories. Matches
            // the user-testing path so the leftmost chip is the most
            // common starting point.
            HStack(spacing: NNSpacing.xs) {
                sectionChip(icon: "bolt.fill",
                            titleAr: "شائعة", titleEn: "Popular",
                            count: quickSelected.count,
                            targetID: "sec-quick",
                            proxy: proxy)
                sectionChip(icon: "globe",
                            titleAr: "مواقع", titleEn: "Websites",
                            count: draft.websites.count,
                            targetID: "sec-websites",
                            proxy: proxy)
                sectionChip(icon: "app.fill",
                            titleAr: "تطبيقاتي", titleEn: "My Apps",
                            count: draft.apps.count,
                            targetID: "sec-apps",
                            proxy: proxy)
                sectionChip(icon: "square.grid.2x2.fill",
                            titleAr: "فئات", titleEn: "Categories",
                            count: selectedCategories.count,
                            targetID: "sec-categories",
                            proxy: proxy)
            }
            .padding(.vertical, NNSpacing.xs)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    /// Single chip in the section navigator. Compact icon + label layout;
    /// when the section has at least one selection the chip flips to the
    /// active palette (accent icon, accent border, infoBg fill) and shows a
    /// count badge in the top-trailing corner so the user can see at a
    /// glance "I have 2 categories, 0 websites, 5 popular apps" without
    /// scrolling through the whole form.
    @ViewBuilder
    private func sectionChip(
        icon: String,
        titleAr: String,
        titleEn: String,
        count: Int,
        targetID: String,
        proxy: ScrollViewProxy
    ) -> some View {
        let isActive = count > 0
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(targetID, anchor: .top)
            }
        }) {
            VStack(spacing: NNSpacing.xxs) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(isActive ? AppColors.accent : AppColors.textSecondary)
                        .frame(width: 36, height: 28)
                    if count > 0 {
                        Text("\(count)")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(AppColors.accent)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .offset(x: 8, y: -4)
                    }
                }
                Text(lang.isArabicEffective ? titleAr : titleEn)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(isActive ? AppColors.textPrimary : AppColors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, NNSpacing.xs)
            .padding(.horizontal, NNSpacing.xxs)
            .background(isActive ? AppColors.infoBg : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
            .overlay(
                RoundedRectangle(cornerRadius: NNRadius.control)
                    .stroke(isActive ? AppColors.accent.opacity(0.5) : AppColors.uiBorder,
                            lineWidth: isActive ? NNBorder.input : NNBorder.hairline)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel({
            let label = lang.isArabicEffective ? titleAr : titleEn
            let suffix = count > 0
                ? (lang.isArabicEffective ? " — \(count) محدّد" : " — \(count) selected")
                : ""
            return label + suffix
        }())
        .accessibilityHint(lang.isArabicEffective ? "ينتقل إلى قسم \(titleAr)" : "Scrolls to the \(titleEn) section")
    }

    // ─── Section 1: Categories (broadest, fastest) ────────────────

    private var categoriesSection: some View {
        Section {
            // 2-column grid replaces the previous 8-toggle vertical list.
            // The flat list ran ~400pt tall and pushed everything else off
            // the first viewport; the grid is ~280pt and lets the eye scan
            // all 8 categories in one glance — matching common category-
            // picker conventions (App Store category grid, Settings picker
            // surfaces).
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: NNSpacing.sm),
                    GridItem(.flexible(), spacing: NNSpacing.sm)
                ],
                spacing: NNSpacing.sm
            ) {
                ForEach(categoryOptions, id: \.self) { cat in
                    categoryCard(for: cat)
                }
            }
            .padding(NNSpacing.md)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
            // Section card border removed in Pass 9 — uiSurface bg + corner
            // radius alone defines the section against the gray form bg.
            // Reduces the stacked-borders ("white/gray/white/gray") effect
            // the user flagged.
        } header: {
            sectionHeader(icon: "square.grid.2x2.fill", text: lang.isArabicEffective ? "الفئات" : "Categories")
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    /// One cell in the Categories grid. Redesigned in Pass 5 to feel like a
    /// magazine card rather than a settings row:
    ///   - Large icon (40pt symbol) inside a 56pt accent-tinted circle at top
    ///   - Centered title + caption below
    ///   - Active state: solid accent circle with white icon + checkmark
    ///     badge in top-trailing corner + accent border + tinted background
    ///   - Tap target is the entire card (~130pt tall)
    ///
    /// The previous Pass-4 design used a horizontal toggle-style layout that
    /// the user described as "مرصوصة رص بشكل بايخ" — eight near-identical
    /// rows with the icon shrunk down beside the text. The hero-icon
    /// treatment here gives each cell more visual weight and a clear focal
    /// point.
    @ViewBuilder
    private func categoryCard(for category: String) -> some View {
        let isSelected = selectedCategories.contains(category)
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.18)) {
                if isSelected {
                    selectedCategories.remove(category)
                } else {
                    selectedCategories.insert(category)
                }
            }
        }) {
            VStack(spacing: NNSpacing.xs) {
                ZStack(alignment: .topTrailing) {
                    // Icon hero — big accent-tinted circle at the top of the
                    // card. Diameter (56pt) was picked so the symbol inside
                    // (24pt at .title weight) reads from across the screen
                    // without the circle dominating the card's title.
                    ZStack {
                        Circle()
                            .fill(isSelected ? AppColors.accent : AppColors.accent.opacity(0.12))
                            .frame(width: 56, height: 56)
                        Image(systemName: categoryIcon(for: category))
                            .font(.title2.weight(.semibold))
                            .foregroundColor(isSelected ? .white : AppColors.accent)
                    }

                    // Checkmark badge overlay — only when selected. Sits on
                    // the top-trailing corner of the icon circle and uses a
                    // surface-coloured ring so it stays legible regardless
                    // of the card's background tint underneath.
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(AppColors.accent)
                            .background(
                                Circle()
                                    .fill(AppColors.uiSurface)
                                    .padding(2)
                            )
                            .offset(x: 4, y: -4)
                    }
                }
                .padding(.top, NNSpacing.xs)

                Text(category)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if let example = categoryExamples(for: category) {
                    // Strip the "يشمل: " / "e.g. " prefix so the caption
                    // reads more like a compact tag list in the grid cell.
                    Text(example
                            .replacingOccurrences(of: "يشمل: ", with: "")
                            .replacingOccurrences(of: "e.g. ", with: ""))
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 134, alignment: .top)
            .padding(.horizontal, NNSpacing.sm)
            .padding(.vertical, NNSpacing.sm)
            // Inactive: transparent so the cell blends into the section card
            // (no more "gray cell inside white card" punch-through).
            // Active: keeps the full visual treatment so selections still pop.
            .background(isSelected ? AppColors.infoBg : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: NNRadius.card)
                    .stroke(isSelected ? AppColors.accent : Color.clear,
                            lineWidth: isSelected ? NNBorder.input : 0)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
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
            VStack(alignment: .leading, spacing: NNSpacing.sm) {
                // Three subgroups (Social & Video / Messaging / Entertainment)
                // each rendered as a flow grid of capsule chips by
                // `quickAppsGroup`. The chips communicate "tap to select"
                // visually — no intro paragraph needed.
                ForEach(QuickAppEditor.groups, id: \.title) { group in
                    quickAppsGroup(title: lang.isArabicEffective ? group.titleAr : group.title,
                                  items: group.items)
                }
            }
            .padding(NNSpacing.md)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
            // Section card border removed in Pass 9 — uiSurface bg + corner
            // radius alone defines the section against the gray form bg.
            // Reduces the stacked-borders ("white/gray/white/gray") effect
            // the user flagged.
        } header: {
            sectionHeader(icon: "bolt.fill", text: lang.isArabicEffective ? "تطبيقات شائعة" : "Popular Apps")
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    /// A single Quick Apps subgroup rendered as a flow-grid of capsule chips.
    /// Replaces the previous DisclosureGroup pattern where all 20 apps were
    /// hidden behind 3 collapsed accordions — users in testing didn't know
    /// the apps existed until they tapped each group. With chips, every app
    /// in the group is visible at a glance.
    ///
    /// The grid uses `.adaptive(minimum:)` so chips auto-wrap based on the
    /// device width (≈ 3 columns on iPhone, more on iPad). Each chip toggles
    /// independently and flips to an accent fill + checkmark prefix when
    /// active so selection state is visible without relying on color alone.
    @ViewBuilder
    private func quickAppsGroup(title: String, items: [QuickAppEditor]) -> some View {
        let selectedInGroup = items.filter { quickSelected.contains($0.key) }.count
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.xs) {
            HStack(spacing: NNSpacing.xs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                if selectedInGroup > 0 {
                    Text("\(selectedInGroup)/\(items.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.accent)
                        .monospacedDigit()
                        .padding(.horizontal, NNSpacing.xs - 2)
                        .padding(.vertical, 1)
                        .background(AppColors.accent.opacity(0.12))
                        .clipShape(Capsule())
                } else {
                    Text("\(items.count)")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
            }
            .padding(.top, NNSpacing.xs)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 110), spacing: NNSpacing.xs)],
                alignment: lang.isArabicEffective ? .trailing : .leading,
                spacing: NNSpacing.xs
            ) {
                ForEach(items, id: \.key) { qa in
                    quickAppChip(for: qa)
                }
            }
        }
    }

    /// Single capsule chip for a Quick App. Inactive uses the page-bg fill so
    /// chips visually punch out of the surrounding section card; active uses
    /// the accent fill with a leading checkmark to encode selection without
    /// relying on color alone.
    @ViewBuilder
    private func quickAppChip(for qa: QuickAppEditor) -> some View {
        let isSelected = quickSelected.contains(qa.key)
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.15)) {
                if isSelected {
                    quickSelected.remove(qa.key)
                } else {
                    quickSelected.insert(qa.key)
                }
            }
        }) {
            HStack(spacing: NNSpacing.xxs) {
                Image(systemName: isSelected ? "checkmark" : qa.icon)
                    .font(.caption.weight(isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .white : AppColors.accent)
                    .frame(width: 14, alignment: .center)
                Text(qa.title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, NNSpacing.sm)
            .padding(.vertical, NNSpacing.xs)
            .frame(maxWidth: .infinity, minHeight: NNHitTarget.minimum - 8)
            // Inactive: transparent so the chip doesn't fill with form-bg
            // gray inside the white section card. The hairline outline alone
            // keeps it readable as a tappable capsule. Active stays solid
            // accent + white text.
            .background(isSelected ? AppColors.accent : Color.clear)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : AppColors.uiBorder, lineWidth: NNBorder.hairline)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(qa.title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    // ─── Section 3: Specific Apps via Family Activity Picker ─────

    private var specificAppsSection: some View {
        Section {
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm) {
                if #available(iOS 16.0, *) {
                    Button(action: { handleAppsButtonTap() }) {
                        HStack(spacing: NNSpacing.xs) {
                            Image(systemName: "square.stack.3d.up.fill")
                            Text(draft.apps.isEmpty
                                ? (lang.isArabicEffective ? "اختر تطبيقات من جهازك" : "Pick apps from your device")
                                : (lang.isArabicEffective ? "تعديل الاختيار" : "Edit selection"))
                        }
                        .font(.nnButton)
                        .frame(maxWidth: .infinity)
                        .frame(height: NNHitTarget.minimum)
                        .foregroundColor(AppColors.accent)
                        .background(AppColors.infoBg)
                        .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                    }
                    .buttonStyle(.plain)
                }

                if !draft.apps.isEmpty {
                    // The FamilyActivityPicker returns opaque tokens; we can
                    // only count them, not name them. Previously the UI
                    // rendered "Selected App #1, #2…" which was useless.
                    // Show a single count summary instead.
                    HStack(spacing: NNSpacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.successGreen)
                            .font(.subheadline)
                        Text(lang.isArabicEffective
                            ? "تم اختيار \(draft.apps.count) تطبيق"
                            : "\(draft.apps.count) app\(draft.apps.count == 1 ? "" : "s") selected")
                            .font(.footnote)
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                    }
                }

                // Privacy explainer — compacted to a single line with an
                // inline info icon. Apple doesn't expose chosen app names
                // back to us, so without this hint users think the selection
                // silently failed. Single-line layout keeps the section
                // tighter when the picker hasn't been used yet.
                HStack(alignment: .top, spacing: NNSpacing.xxs) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                    Text(lang.isArabicEffective
                        ? "Apple تخفي أسماء التطبيقات المحدّدة — يظهر العدد فقط."
                        : "Apple hides the chosen app names — only the count is shown.")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                        .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
                }
            }
            .padding(NNSpacing.md)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
            // Section card border removed in Pass 9 — uiSurface bg + corner
            // radius alone defines the section against the gray form bg.
            // Reduces the stacked-borders ("white/gray/white/gray") effect
            // the user flagged.
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

    private var websitesSection: some View {
        Section {
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm) {
                if #available(iOS 16.0, *) {
                    Button(action: { handleAppsButtonTap() }) {
                        HStack(spacing: NNSpacing.xs) {
                            Image(systemName: "globe")
                            Text(draft.websites.isEmpty
                                ? (lang.isArabicEffective ? "اختر مواقع من Apple Picker" : "Pick websites via Apple Picker")
                                : (lang.isArabicEffective ? "تعديل الاختيار" : "Edit selection"))
                        }
                        .font(.nnButton)
                        .frame(maxWidth: .infinity)
                        .frame(height: NNHitTarget.minimum)
                        .foregroundColor(AppColors.accent)
                        .background(AppColors.infoBg)
                        .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                    }
                    .buttonStyle(.plain)
                }

                if !draft.websites.isEmpty {
                    // Same opacity-from-tokens limitation as Specific Apps —
                    // Apple returns opaque WebDomainTokens, so we can only
                    // show a count, not the actual domains.
                    HStack(spacing: NNSpacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.successGreen)
                            .font(.subheadline)
                        Text(lang.isArabicEffective
                            ? "تم اختيار \(draft.websites.count) موقع"
                            : "\(draft.websites.count) website\(draft.websites.count == 1 ? "" : "s") selected")
                            .font(.footnote)
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                    }
                }

                // Privacy explainer mirroring the Specific Apps section —
                // sets expectations that the picker returns opaque tokens.
                HStack(alignment: .top, spacing: NNSpacing.xxs) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                    Text(lang.isArabicEffective
                        ? "اختر من تبويب «مواقع» داخل الـ Picker. تظهر بالعدد فقط لحماية الخصوصية."
                        : "Choose from the picker's \"Websites\" tab. Shown by count only for privacy.")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                        .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
                }
            }
            .padding(NNSpacing.md)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
        } header: {
            sectionHeader(icon: "globe", text: lang.isArabicEffective ? "مواقع" : "Websites")
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
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
        NavigationView {
            ZStack(alignment: .bottom) {
                FamilyActivityPicker(selection: $selection)
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(lang.isArabicEffective ? "إلغاء" : "Cancel") {
                                handleCancel()
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(lang.isArabicEffective ? "تم" : "Done") {
                                onDone(); dismiss()
                            }
                            .font(.headline)
                        }
                    }

                // Bottom sticky Done
                Button(action: { onDone(); dismiss() }) {
                    Text(lang.isArabicEffective ? "تم" : "Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.accent)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                        .padding(.horizontal)
                        .padding(.bottom, NNSpacing.sm)
                }
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