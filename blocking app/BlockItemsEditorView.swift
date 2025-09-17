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
}

struct BlockItemsEditorView: View {
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @State var draft: BlockItemsDraft
    var onSave: (BlockItemsDraft) -> Void

    @State private var websiteInput: String = ""
    @State private var selectedCategories: Set<String> = []

    @State private var showAppPicker = false
    @State private var familySelection = FamilyActivitySelection()

    private var categoryOptionsAr: [String] { ["وسائل التواصل الاجتماعي","الشورتس والريلز","الألعاب","تطبيقات التسوق","تطبيقات التوصيل","تطبيقات المواعدة","محتوى للبالغين"] }
    private var categoryOptionsEn: [String] { ["Social Media","Shorts & Reels","Games","Shopping Apps","Delivery Apps","Dating Apps","Adult Content"] }

    private var categoryOptions: [String] { lang.isArabicEffective ? categoryOptionsAr : categoryOptionsEn }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(AppColors.accentDark)
                    Text(lang.isArabicEffective ? "إضافة موقع للحجب" : "Add Website to Block")
                        .font(.system(size: 20, weight: .semibold))
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
                                    .background(isValidDomain(websiteInput) ? AppColors.accentDark : AppColors.accentDark.opacity(0.5))
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
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(AppColors.accentDark)
                    Text(lang.isArabicEffective ? "إضافة تطبيقات للحجب" : "Add Apps to Block")
                        .font(.system(size: 20, weight: .semibold))
                }) {
                    VStack(spacing: 12) {
                    if #available(iOS 16.0, *) {
                        Button(action: {
                            requestFamilyControlsPermission()
                            showAppPicker = true
                        }) {
                            HStack {
                                    Image(systemName: "square.stack.3d.up.fill")
                                    Text(lang.isArabicEffective ? "اختر التطبيقات من الجهاز" : "Pick Apps from Device")
                                }
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .foregroundColor(AppColors.accentDark)
                                .background(Color.clear)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.accentDark, lineWidth: 1.5))
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

                Section(header: HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(AppColors.accentDark)
                    Text(lang.isArabicEffective ? "إضافة فئات للحجب" : "Add Categories to Block")
                        .font(.system(size: 20, weight: .semibold))
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
            .onChange(of: familySelection) { _ in
                if #available(iOS 16.0, *) {
                    // نحفظ اختيارات التطبيقات بشكل مؤقت كعناصر عرض فقط دون خصائص داخلية للـ Token
                    let selectedCount = familySelection.applicationTokens.count
                    var newApps: [DraftBlockItem] = []
                    for idx in 1...selectedCount {
                        let name = lang.isArabicEffective ? "تطبيق محدد #\(idx)" : "Selected App #\(idx)"
                        let value = UUID().uuidString
                        newApps.append(DraftBlockItem(kind: .app, value: value, displayName: name))
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
        !draft.websites.isEmpty || !draft.apps.isEmpty || !selectedCategories.isEmpty
    }

    private func addWebsite() {
        let domain = websiteInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isValidDomain(domain) else { return }
        draft.websites.append(DraftBlockItem(kind: .website, value: domain, displayName: domain))
        websiteInput = ""
    }

    private func saveAndDismiss() {
        draft.categories = selectedCategories.map { DraftBlockItem(kind: .category, value: $0, displayName: $0) }
        onSave(draft)
        dismiss()
    }

    private func isValidDomain(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.contains(".") else { return false }
        let invalid = trimmed.contains(" ") || trimmed.contains("http://") || trimmed.contains("https://")
        return !invalid
    }

    private func requestFamilyControlsPermission() {
        if #available(iOS 16.0, *) {
            Task { _ = try? await AuthorizationCenter.shared.requestAuthorization(for: .individual) }
        }
    }
}

private struct SoftDivider: View {
    let width: CGFloat
    let opacity: Double
    var body: some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(AppColors.uiBorder.opacity(opacity))
                .frame(width: width, height: 1)
            Spacer()
        }
        .padding(.vertical, 8)
    }
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
                        .background(AppColors.primaryBlue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }
            }
            .interactiveDismissDisabled(hasChanges)
            .onAppear { initialSelection = selection }
            .alert(lang.isArabicEffective ? "تجاهل التعديلات؟" : "Discard changes?", isPresented: $showCancelAlert) {
                Button(lang.isArabicEffective ? "نعم" : "Yes", role: .destructive) {
                    // revert
                    selection = initialSelection
                    onCancel(); dismiss()
                }
                Button(lang.isArabicEffective ? "لا" : "No", role: .cancel) {}
            } message: {
                Text(lang.isArabicEffective ? "سيتم تجاهل تغييراتك." : "Your changes will be discarded.")
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