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

    @State private var websiteInput: String = ""
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
            Form {
                // Order intentionally goes fast → specific:
                //   1. Categories     — broadest, fastest selection (8 toggles)
                //   2. Quick Apps     — popular shortcuts (one flat list, no
                //                       Recommended/Others split)
                //   3. Specific Apps  — Family Activity Picker for fine control
                //   4. Websites       — manual URL entry (slowest path)
                // Previous order had Websites first and Categories last,
                // which forced the most tedious path on every user.
                categoriesSection
                quickAppsSection
                specificAppsSection
                websitesSection
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.uiBackground)
            .navigationTitle(lang.isArabicEffective ? "عناصر الحجب" : "Block Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            .onAppear {
                selectedCategories = Set(draft.categories.map { $0.displayName ?? $0.value })
                // Reset the unsaved-changes flag every time the editor opens —
                // the initial state IS the saved state.
                hasUnsavedChanges = false
            }
            .onChange(of: selectedCategories) { _ in hasUnsavedChanges = true }
            .onChange(of: quickSelected)      { _ in hasUnsavedChanges = true }
            .onChange(of: draft.websites)     { _ in hasUnsavedChanges = true }
            .onChange(of: draft.apps)         { _ in hasUnsavedChanges = true }
            .sheet(isPresented: $showAppPicker) {
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
            .onChange(of: familySelection) { _ in
                if #available(iOS 16.0, *) {
                    let selectedCount = familySelection.applicationTokens.count
                    // Use half-open `..<` (empty when count is 0) instead of
                    // closed `1...count` (which crashes when count is 0).
                    let newApps: [DraftBlockItem] = (0..<selectedCount).map { idx in
                        let name = lang.isArabicEffective ? "تطبيق محدد #\(idx + 1)" : "Selected App #\(idx + 1)"
                        let value = UUID().uuidString
                        return DraftBlockItem(kind: .app, value: value, displayName: name)
                    }
                    draft.apps = newApps
                }
            }
        }
    }

    // ─── Section 1: Categories (broadest, fastest) ────────────────

    private var categoriesSection: some View {
        Section {
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 0) {
                ForEach(Array(categoryOptions.enumerated()), id: \.element) { idx, cat in
                    if idx > 0 { Divider().background(AppColors.uiBorder.opacity(0.4)) }
                    Toggle(isOn: Binding(
                        get: { selectedCategories.contains(cat) },
                        set: { newVal in
                            if newVal { selectedCategories.insert(cat) }
                            else { selectedCategories.remove(cat) }
                        }
                    )) {
                        Text(cat)
                            .font(.subheadline)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                    }
                    .tint(AppColors.accent)
                    .padding(.vertical, NNSpacing.xs)
                }
            }
            .padding(NNSpacing.md)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.uiBorder, lineWidth: 0.5))
        } header: {
            sectionHeader(icon: "square.grid.2x2.fill", text: lang.isArabicEffective ? "الفئات" : "Categories")
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    // ─── Section 2: Quick Apps (popular shortcuts, one flat list) ─

    private var quickAppsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: NNSpacing.sm) {
                Text(lang.isArabicEffective
                    ? "اختصارات للتطبيقات الأكثر إدماناً — يُضاف كلٌّ منها كموقع وتطبيق."
                    : "Shortcuts for the most addictive apps — each adds both a website and an app entry.")
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                    .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)

                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 0) {
                    ForEach(Array(quickApps.enumerated()), id: \.element.key) { idx, qa in
                        if idx > 0 { Divider().background(AppColors.uiBorder.opacity(0.4)) }
                        Toggle(isOn: Binding(
                            get: { quickSelected.contains(qa.key) },
                            set: { v in
                                if v { quickSelected.insert(qa.key) } else { quickSelected.remove(qa.key) }
                            }
                        )) {
                            HStack(spacing: NNSpacing.xs) {
                                Image(systemName: qa.icon)
                                    .foregroundColor(AppColors.accent)
                                Text(qa.title)
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.textPrimary)
                            }
                        }
                        .tint(AppColors.accent)
                        .padding(.vertical, NNSpacing.xs)
                    }
                }
            }
            .padding(NNSpacing.md)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.uiBorder, lineWidth: 0.5))
        } header: {
            sectionHeader(icon: "bolt.fill", text: lang.isArabicEffective ? "تطبيقات شائعة" : "Popular Apps")
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
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
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundColor(AppColors.accent)
                        .background(AppColors.infoBg)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
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
            }
            .padding(NNSpacing.md)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.uiBorder, lineWidth: 0.5))
        } header: {
            sectionHeader(icon: "app.fill", text: lang.isArabicEffective ? "تطبيقات محدّدة" : "Specific Apps")
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    // ─── Section 4: Websites (manual URL entry) ───────────────────

    private var websitesSection: some View {
        Section {
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm) {
                HStack(spacing: NNSpacing.xs) {
                    TextField(lang.isArabicEffective ? "مثال: youtube.com" : "e.g., youtube.com", text: $websiteInput)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .padding(12)
                        .background(AppColors.uiBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.uiBorder, lineWidth: 0.5))

                    Button(action: addWebsite) {
                        Image(systemName: "plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(isValidDomain(websiteInput) ? AppColors.accent : AppColors.textDisabled)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!isValidDomain(websiteInput))
                    .accessibilityLabel(lang.isArabicEffective ? "إضافة" : "Add")
                }

                if draft.websites.isEmpty {
                    Text(lang.isArabicEffective ? "لا توجد مواقع بعد" : "No websites yet")
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, NNSpacing.xs)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(draft.websites.enumerated()), id: \.element.id) { idx, item in
                            if idx > 0 { Divider().background(AppColors.uiBorder.opacity(0.4)) }
                            HStack(spacing: NNSpacing.xs) {
                                Image(systemName: "globe").foregroundColor(AppColors.textSecondary)
                                Text(item.value)
                                    .font(.footnote)
                                    .foregroundColor(AppColors.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button(action: {
                                    if let realIdx = draft.websites.firstIndex(where: { $0.id == item.id }) {
                                        draft.websites.remove(at: realIdx)
                                    }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(AppColors.textDisabled)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(lang.isArabicEffective ? "حذف" : "Remove")
                            }
                            .padding(.vertical, NNSpacing.xs)
                        }
                    }
                }
            }
            .padding(NNSpacing.md)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.uiBorder, lineWidth: 0.5))
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
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(AppColors.accent)
            Text(text)
                .font(.nnCardTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, NNSpacing.sm)
        .textCase(nil)
    }

    private func dismissPickerAndApply() {
        showAppPicker = false
    }

    private func hasAtLeastOneItem() -> Bool {
        !draft.websites.isEmpty || !draft.apps.isEmpty || !selectedCategories.isEmpty || !quickSelected.isEmpty
    }

    private func addWebsite() {
        let domain = websiteInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isValidDomain(domain) else { return }
        draft.websites.append(DraftBlockItem(kind: .website, value: domain, displayName: domain))
        websiteInput = ""
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

    private func isValidDomain(_ s: String) -> Bool {
        return BlockItemsEditorView.isValidDomainStrict(s)
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

    /// Stricter domain validation than the previous `contains(".")` check.
    /// Allows e.g. "example.com", "sub.example.co.uk"; rejects "a.b" with single-char labels,
    /// URLs, spaces, or trailing slashes.
    fileprivate static func isValidDomainStrict(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, trimmed.count <= 253 else { return false }
        if trimmed.contains(" ") || trimmed.contains("://") || trimmed.contains("/") { return false }
        let labels = trimmed.split(separator: ".")
        guard labels.count >= 2 else { return false }
        let labelRegex = #"^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$"#
        for label in labels {
            if String(label).range(of: labelRegex, options: .regularExpression) == nil { return false }
        }
        // Require TLD to be at least 2 chars and letters-only.
        guard let tld = labels.last, tld.count >= 2,
              tld.allSatisfy({ $0.isLetter }) else { return false }
        return true
    }
}

private struct QuickAppEditor: Equatable {
    let key: String
    let title: String
    let domain: String
    let icon: String
    static let defaultSet: [QuickAppEditor] = [
        // Most addictive → less (approx.)
        .init(key: "tiktok",     title: "TikTok",      domain: "tiktok.com",      icon: "play.rectangle"),
        .init(key: "instagram",  title: "Instagram",   domain: "instagram.com",   icon: "camera"),
        .init(key: "snapchat",   title: "Snapchat",    domain: "snapchat.com",    icon: "bolt"),
        .init(key: "youtube",    title: "YouTube",     domain: "youtube.com",     icon: "play.circle"),
        .init(key: "twitter",    title: "X (Twitter)", domain: "twitter.com",     icon: "bubble.left"),
        .init(key: "facebook",   title: "Facebook",    domain: "facebook.com",    icon: "person.3"),
        .init(key: "whatsapp",   title: "WhatsApp",    domain: "whatsapp.com",    icon: "phone.circle"),
        .init(key: "messenger",  title: "Messenger",   domain: "messenger.com",   icon: "message"),
        .init(key: "discord",    title: "Discord",     domain: "discord.com",     icon: "gamecontroller"),
        .init(key: "telegram",   title: "Telegram",    domain: "telegram.org",    icon: "paperplane"),
        .init(key: "wechat",     title: "WeChat",      domain: "wechat.com",      icon: "bubble.left.and.bubble.right"),
        .init(key: "reddit",     title: "Reddit",      domain: "reddit.com",      icon: "bubble.right"),
        .init(key: "twitch",     title: "Twitch",      domain: "twitch.tv",       icon: "gamecontroller.fill"),
        // Entertainment services
        .init(key: "netflix",    title: "Netflix",     domain: "netflix.com",     icon: "film"),
        .init(key: "primevideo", title: "Prime Video",  domain: "primevideo.com",  icon: "film.stack"),
        .init(key: "disneyplus", title: "Disney+",     domain: "disneyplus.com",  icon: "star"),
        .init(key: "hbo",        title: "Max (HBO)",   domain: "max.com",         icon: "star.circle"),
        .init(key: "hulu",       title: "Hulu",        domain: "hulu.com",        icon: "play.rectangle.on.rectangle"),
        .init(key: "shahid",     title: "Shahid",      domain: "shahid.mbc.net",  icon: "rectangle.fill.on.rectangle.fill"),
        .init(key: "osnplus",    title: "OSN+",        domain: "osnplus.com",     icon: "tv"),
    ]
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
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
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