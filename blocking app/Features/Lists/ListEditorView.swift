import FamilyControls
import SwiftUI

/// Creates or edits a block list. One clean screen: the essentials are visible,
/// protection, breaks and adult websites sit under "Extra Options".
struct ListEditorView: View {
    enum Mode {
        case create
        /// `partnerApproved`: the partner already entered their PIN for an active protected list.
        case edit(BlockList, partnerApproved: Bool = false)
    }

    @Environment(ListsModel.self) private var model
    @Environment(PartnerStore.self) private var partner
    @Environment(\.dismiss) private var dismiss

    private let mode: Mode
    @State private var draft: BlockList
    @State private var days: Int
    @State private var hours: Int
    @State private var minutes: Int
    @State private var startImmediately = true
    @State private var showExtraOptions: Bool

    @State private var showItemsEditor = false
    @State private var showScheduleEditor = false
    @State private var confirmProtection = false
    @State private var validationMessage: LocalizedStringKey?
    @State private var showSavedToast = false

    private static let minimumDuration = 5 * 60
    private let minuteOptions = Array(stride(from: 0, through: 55, by: 5))

    init(mode: Mode) {
        self.mode = mode
        let list: BlockList
        switch mode {
        case .create: list = BlockList(name: "")
        case .edit(let existing, _): list = existing
        }
        _draft = State(initialValue: list)
        _days = State(initialValue: list.durationSeconds / 86_400)
        _hours = State(initialValue: (list.durationSeconds % 86_400) / 3600)
        _minutes = State(initialValue: (list.durationSeconds % 3600) / 60 / 5 * 5)
        // Show the extras when editing a list that already uses them.
        _showExtraOptions = State(initialValue: list.protection != .none || list.breaks.count > 0 || list.blockAdultContent)
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var partnerApproved: Bool {
        if case .edit(_, let approved) = mode { return approved }
        return false
    }

    private var totalSeconds: Int { days * 86_400 + hours * 3600 + minutes * 60 }
    private var isNameValid: Bool { draft.name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 }
    private var isDurationValid: Bool { draft.kind == .scheduled || totalSeconds >= Self.minimumDuration }
    private var isFormValid: Bool { isNameValid && draft.hasItems && isDurationValid }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    nameSection
                    itemsSection
                    timingSection
                    if draft.kind == .now { durationSection }
                    extraOptions
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppColors.background)
            .navigationTitle(isEditing ? "Edit List" : "New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { doneBar }
            .sheet(isPresented: $showItemsEditor) {
                BlockItemsEditorView(list: draft) { edited in
                    draft.websites = edited.websites
                    draft.selection = edited.selection
                }
            }
            .sheet(isPresented: $showScheduleEditor) {
                ScheduleEditorSheet(initialSlots: draft.slots) { draft.slots = $0 }
            }
            .alert(protectionAlertTitle, isPresented: $confirmProtection) {
                Button("I understand, turn on", role: .destructive) { save() }
                Button("Back", role: .cancel) {}
            } message: {
                Text(protectionAlertMessage)
            }
            .alert("Check inputs", isPresented: Binding(get: { validationMessage != nil }, set: { if !$0 { validationMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                if let validationMessage { Text(validationMessage) }
            }
            .successToast(isPresented: showSavedToast, message: isEditing ? "List updated" : "List created")
        }
        .interactiveDismissDisabled(showSavedToast)
    }

    // MARK: - Essentials

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Name")
            TextField("e.g., Sleep", text: $draft.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .inputFieldStyle()
            if !isNameValid && !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Name is too short")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "What to block")
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    countLabel("Apps", systemImage: "app.fill", count: draft.appCount + draft.categoryCount)
                    countLabel("Websites", systemImage: "globe", count: draft.websiteCount)
                    Spacer()
                }
                Button(draft.appCount + draft.categoryCount + draft.websiteCount > 0 ? "Edit Apps & Websites" : "Add Apps & Websites") {
                    showItemsEditor = true
                }
                .buttonStyle(SecondaryButtonStyle(height: 44))
            }
            .card(padding: 16)
        }
    }

    private func countLabel(_ title: LocalizedStringKey, systemImage: String, count: Int) -> some View {
        Label {
            HStack(spacing: 4) {
                Text(count, format: .number).fontWeight(.semibold)
                Text(title)
            }
        } icon: {
            Image(systemName: systemImage).foregroundStyle(AppColors.primary)
        }
        .font(.subheadline)
        .foregroundStyle(AppColors.text)
    }

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "When")
            VStack(alignment: .leading, spacing: 12) {
                Picker("When", selection: kindBinding) {
                    Text("Now").tag(BlockKind.now)
                    Text("Schedule").tag(BlockKind.scheduled)
                }
                .pickerStyle(.segmented)

                if draft.kind == .scheduled {
                    Text(draft.slots.isEmpty ? String(localized: "No schedule yet") : Formatters.scheduleSummary(draft.slots))
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                    Button {
                        showScheduleEditor = true
                    } label: {
                        Label("Edit Schedule", systemImage: "calendar")
                    }
                } else if !isEditing && draft.protection == .none {
                    Toggle("Start right away", isOn: $startImmediately)
                        .tint(AppColors.primary)
                }
            }
            .card(padding: 16)
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Duration")
            VStack(spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    wheel("Days", selection: $days, values: Array(0...ListsModel.maxDays(for: draft.protection)))
                    wheel("Hours", selection: $hours, values: Array(0...23))
                    wheel("Minutes", selection: $minutes, values: minuteOptions)
                }
                if !isDurationValid {
                    Text("Select at least 5 minutes")
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .card(padding: 16)
        }
    }

    private func wheel(_ title: LocalizedStringKey, selection: Binding<Int>, values: [Int]) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
            Picker(title, selection: selection) {
                ForEach(values, id: \.self) { Text($0, format: .number).tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Extra options

    private var extraOptions: some View {
        DisclosureGroup(isExpanded: $showExtraOptions) {
            VStack(alignment: .leading, spacing: 20) {
                protectionOptions
                Divider()
                breaksOptions
                Divider()
                Toggle(isOn: $draft.blockAdultContent) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Block adult websites")
                            .foregroundStyle(AppColors.text)
                        Text("Uses Apple's built-in adult content filter.")
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .tint(AppColors.primary)
            }
            .padding(.top, 16)
        } label: {
            Text("Extra Options")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColors.primary)
        }
        .tint(AppColors.primary)
        .card(padding: 16)
    }

    private var protectionOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Protection")
                .font(.headline)
                .foregroundStyle(AppColors.text)
            Picker("Protection", selection: protectionBinding) {
                Text("None").tag(ProtectionMode.none)
                Text("Hard Mode").tag(ProtectionMode.hard)
                Text("Partner").tag(ProtectionMode.partner)
            }
            .pickerStyle(.segmented)
            Group {
                switch draft.protection {
                case .none: Text("Edit, stop or delete anytime.")
                case .hard: Text("Can't be stopped, edited or deleted while active, and Samla can't be deleted. No breaks.")
                case .partner: Text("Only your partner's PIN can stop, edit or delete it while active.")
                }
            }
            .font(.footnote)
            .foregroundStyle(AppColors.textSecondary)
            if !partner.hasPartner {
                Text("To use Partner, add one in Settings › Accountability Partner.")
                    .font(.footnote)
                    .foregroundStyle(AppColors.scheduled)
            }
        }
    }

    private var breaksOptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Breaks")
                .font(.headline)
                .foregroundStyle(AppColors.text)
            if draft.isHard {
                Text("Hard Mode allows no breaks.")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                Stepper(value: $draft.breaks.count, in: 0...5) {
                    Text("Breaks per 24 hours: \(draft.breaks.count)")
                        .font(.subheadline)
                }
                Picker("Length of each break", selection: $draft.breaks.minutes) {
                    ForEach([5, 10, 15], id: \.self) { value in
                        Text(Formatters.duration(minutes: value)).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(draft.breaks.count == 0)
            }
        }
    }

    private var doneBar: some View {
        Button(isEditing ? "Save" : "Create") { attemptSave() }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!isFormValid)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(AppColors.background)
    }

    // MARK: - Bindings

    private var kindBinding: Binding<BlockKind> {
        Binding {
            draft.kind
        } set: { newValue in
            draft.kind = newValue
            if newValue == .scheduled && draft.slots.isEmpty { showScheduleEditor = true }
        }
    }

    private var protectionBinding: Binding<ProtectionMode> {
        Binding {
            draft.protection
        } set: { newValue in
            guard newValue != .partner || partner.hasPartner else { return }
            draft.protection = newValue
            if newValue == .hard { draft.breaks.count = 0 }
            days = min(days, ListsModel.maxDays(for: newValue))
        }
    }

    // MARK: - Actions

    private var protectionAlertTitle: LocalizedStringKey {
        draft.isHard ? "Turn on Hard Mode?" : "Protect with your partner?"
    }

    private var protectionAlertMessage: LocalizedStringKey {
        draft.isHard
            ? "While this list is active you won't be able to stop, edit or delete it, and Samla can't be deleted."
            : "While this list is active, only your partner's PIN can stop, edit or delete it, and Samla can't be deleted."
    }

    private var finalizedDraft: BlockList {
        var list = draft
        list.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        list.durationSeconds = totalSeconds
        if list.kind == .now { list.slots = [] }
        return list
    }

    private func attemptSave() {
        if draft.kind == .scheduled && draft.slots.isEmpty {
            validationMessage = "Add at least one schedule slot"
            return
        }
        guard isFormValid else {
            validationMessage = "Check name, items and duration"
            return
        }
        // Ask before adding protection that locks the user in.
        let wasProtected: Bool = {
            if case .edit(let original, _) = mode { return original.protection == draft.protection }
            return false
        }()
        if draft.protection != .none && !wasProtected {
            confirmProtection = true
        } else {
            save()
        }
    }

    private func save() {
        if isEditing {
            model.update(finalizedDraft, partnerApproved: partnerApproved)
        } else {
            model.create(finalizedDraft, startNow: startImmediately)
        }
        showSavedToast = true
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            dismiss()
        }
    }
}

#Preview {
    ListEditorView(mode: .create)
        .previewEnvironment()
}
