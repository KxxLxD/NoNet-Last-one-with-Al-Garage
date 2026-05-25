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

    var body: some View {
        NavigationStack {
            Form {
                Section(header: HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.nnCardBody)
                        .foregroundColor(AppColors.accent)
                    Text(lang.isArabicEffective ? "إضافة موقع للحجب" : "Add Website to Block")
                        .font(.nnCardTitle)
                }) {
                    VStack(spacing: 12) {
                    HStack {
                        TextField(lang.isArabicEffective ? "مثال: youtube.com" : "e.g., youtube.com", text: $websiteInput)
                            .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .padding(12)
                                .background(AppColors.uiSurface)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.uiBorder, lineWidth: 0.5))

                            Button(action: addWebsite) {
                                Text(lang.isArabicEffective ? "إضافة" : "Add")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 16)
                                    .frame(height: 44)
                                    .background(isValidDomain(websiteInput) ? AppColors.accent : AppColors.accent.opacity(0.5))
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                        }
                        .disabled(!isValidDomain(websiteInput))
                    }

                    if !draft.websites.isEmpty {
                            ForEach(Array(draft.websites.enumerated()), id: \.element.id) { idx, item in
                                VStack(spacing: 0) {
                                    if idx > 0 {
                                        SoftDivider(width: 280, opacity: 0.7)
                                    }
                            HStack {
                                Image(systemName: "globe")
                                Text(item.value)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                Spacer()
                            }
                                    .padding(.vertical, 4)
                                }
                        }
                        .onDelete { indexSet in
                            draft.websites.remove(atOffsets: indexSet)
                        }
                    }
                }
                    .padding(20)
                    .background(AppColors.uiSurface)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section(header: HStack(spacing: 8) {
                    Image(systemName: "app.fill")
                        .font(.nnCardBody)
                        .foregroundColor(AppColors.accent)
                    Text(lang.isArabicEffective ? "إضافة تطبيقات للحجب" : "Add Apps to Block")
                        .font(.nnCardTitle)
                }) {
                    VStack(spacing: 12) {
                    if #available(iOS 16.0, *) {
                        Button(action: {
                            handleAppsButtonTap()
                        }) {
                            HStack {
                                    Image(systemName: "square.stack.3d.up.fill")
                                    Text(lang.isArabicEffective ? "اختر التطبيقات من الجهاز" : "Pick Apps from Device")
                                }
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .foregroundColor(AppColors.accent)
                                .background(Color.clear)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.accent, lineWidth: 1.5))
                            }
                            .cornerRadius(12)
                    }
                        
                    if !draft.apps.isEmpty {
                            ForEach(Array(draft.apps.enumerated()), id: \.element.id) { idx, item in
                                VStack(spacing: 0) {
                                    if idx > 0 {
                                        SoftDivider(width: 280, opacity: 0.7)
                                    }
                            HStack {
                                Image(systemName: "app")
                                Text(item.displayName ?? item.value)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                Spacer()
                            }
                                    .padding(.vertical, 4)
                                }
                        }
                        .onDelete { indexSet in
                            draft.apps.remove(atOffsets: indexSet)
                        }
                    }
                }
                    .padding(20)
                    .background(AppColors.uiSurface)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                // Quick Apps after Apps
                Section(header: HStack(spacing: 8) { Image(systemName: "bolt.fill").foregroundColor(AppColors.accent); Text(lang.isArabicEffective ? "Quick Apps Blocking" : "Quick Apps Blocking").font(.nnCardTitle) }) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(lang.isArabicEffective ? "اختر الأكثر إدماناً أولاً — سيتم إضافة الحجب كمواقع وتطبيقات." : "Pick the most addictive first — we’ll add both website and app entries.")
                            .font(.footnote)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.bottom, 4)
                        // Recommended top
                        Text(lang.isArabicEffective ? "مقترح" : "Recommended")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.textSecondary)
                        VStack(spacing: 0) {
                            ForEach(quickApps.prefix(6), id: \.key) { qa in
                                VStack(spacing: 0) {
                                    if qa.key != quickApps.prefix(6).first?.key { SoftDivider(width: 280, opacity: 0.7) }
                                    Toggle(isOn: Binding(get: { quickSelected.contains(qa.key) }, set: { v in if v { quickSelected.insert(qa.key) } else { quickSelected.remove(qa.key) } })) {
                                        HStack(spacing: 8) {
                                            Image(systemName: qa.icon).foregroundColor(AppColors.accent)
                                            Text(qa.title)
                                        }
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                        }

                        // Others
                        Text(lang.isArabicEffective ? "بقية التطبيقات" : "Others")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.textSecondary)
                        VStack(spacing: 0) {
                            ForEach(Array(quickApps.dropFirst(6)), id: \.key) { qa in
                                VStack(spacing: 0) {
                                    if qa.key != quickApps.dropFirst(6).first?.key { SoftDivider(width: 280, opacity: 0.7) }
                                    Toggle(isOn: Binding(get: { quickSelected.contains(qa.key) }, set: { v in if v { quickSelected.insert(qa.key) } else { quickSelected.remove(qa.key) } })) {
                                        HStack(spacing: 8) {
                                            Image(systemName: qa.icon).foregroundColor(AppColors.accent)
                                            Text(qa.title)
                                        }
                                    }
                                    .padding(.vertical, 6)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(AppColors.uiSurface)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
                }

                Section(header: HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.nnCardBody)
                        .foregroundColor(AppColors.accent)
                    Text(lang.isArabicEffective ? "إضافة فئات للحجب" : "Add Categories to Block")
                        .font(.nnCardTitle)
                }) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(categoryOptions.enumerated()), id: \.element) { idx, cat in
                            VStack(spacing: 0) {
                                if idx > 0 {
                                    SoftDivider(width: 280, opacity: 0.7)
                                }
                        Toggle(isOn: Binding(get: { selectedCategories.contains(cat) }, set: { newVal in
                            if newVal { selectedCategories.insert(cat) } else { selectedCategories.remove(cat) }
                        })) {
                            Text(cat)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(20)
                    .background(AppColors.uiSurface)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.uiSurface)
            .padding(.bottom, 24)
            .navigationTitle(lang.isArabicEffective ? "تحرير عناصر الحجب" : "Edit Blocking Items")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.isArabicEffective ? "رجوع" : "Back") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.isArabicEffective ? "حفظ" : "Save") { saveAndDismiss() }
                        .disabled(!hasAtLeastOneItem())
                }
            }
            .onAppear {
                selectedCategories = Set(draft.categories.map { $0.displayName ?? $0.value })
                UITableView.appearance().backgroundColor = UIColor.systemBackground
                UITableViewHeaderFooterView.appearance().tintColor = UIColor.systemBackground
            }
            .onDisappear {
                UITableView.appearance().backgroundColor = nil
                UITableViewHeaderFooterView.appearance().tintColor = nil
            }
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
                    // Use half-open `..<` (empty when count is 0) instead of closed
                    // `1...count` (which crashes when count is 0). The previous
                    // `1...selectedCount` crashed with "Range requires
                    // lowerBound <= upperBound" whenever the user deselected every
                    // app in the FamilyActivityPicker.
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