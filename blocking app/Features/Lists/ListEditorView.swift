import FamilyControls
import SwiftUI

/// Creates or edits a block list in a native form, like adding an alarm in Clock:
/// Name | Blocked | Time | Protection | Breaks, with "Create" at the top trailing edge.
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
    @State private var startImmediately = true

    @State private var showItemsEditor = false
    @State private var showScheduleEditor = false
    @State private var confirmProtection = false

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            var list = BlockList(name: "")
            list.durationSeconds = 60 * 60
            _draft = State(initialValue: list)
        case .edit(let existing, _):
            _draft = State(initialValue: existing)
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var partnerApproved: Bool {
        if case .edit(_, let approved) = mode { return approved }
        return false
    }

    private var trimmedName: String { draft.name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isTimeValid: Bool { draft.kind == .now || !draft.slots.isEmpty }
    private var isFormValid: Bool { trimmedName.count >= 2 && draft.hasItems && isTimeValid }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                blockedSection
                timeSection
                protectionSection
                if !draft.isHard { breaksSection }
            }
            .navigationTitle(isEditing ? "Edit List" : "New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create", action: attemptSave)
                        .disabled(!isFormValid)
                }
            }
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
                Button("I understand, turn on", role: .destructive, action: save)
                Button("Back", role: .cancel) {}
            } message: {
                Text(protectionAlertMessage)
            }
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section("Name") {
            TextField("e.g., Sleep", text: $draft.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
        }
    }

    private var blockedSection: some View {
        Section {
            Button {
                showItemsEditor = true
            } label: {
                LabeledContent {
                    Text(itemsSummary)
                } label: {
                    Label("Apps & Websites", systemImage: "square.stack.3d.up.fill")
                        .foregroundStyle(AppColors.text)
                }
            }
            Toggle(isOn: $draft.blockAdultContent) {
                Label("Block adult websites", systemImage: "checkmark.shield.fill")
            }
        } header: {
            Text("What to block")
        } footer: {
            Text("Adult websites use Apple's built-in content filter.")
        }
    }

    private var timeSection: some View {
        Section {
            Picker("When", selection: kindBinding) {
                Text("Now").tag(BlockKind.now)
                Text("Schedule").tag(BlockKind.scheduled)
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)

            switch draft.kind {
            case .now:
                Picker("Duration", selection: $draft.durationSeconds) {
                    ForEach(durationOptions, id: \.self) { seconds in
                        Text(Formatters.duration(seconds: seconds)).tag(seconds)
                    }
                }
                if !isEditing && draft.protection == .none {
                    Toggle("Start right away", isOn: $startImmediately)
                }
            case .scheduled:
                Button {
                    showScheduleEditor = true
                } label: {
                    LabeledContent {
                        Text(draft.slots.isEmpty ? String(localized: "Add") : Formatters.scheduleSummary(draft.slots))
                    } label: {
                        Label("Schedule", systemImage: "calendar")
                            .foregroundStyle(AppColors.text)
                    }
                }
            }
        } header: {
            Text("Time")
        }
    }

    private var protectionSection: some View {
        Section {
            Picker("Protection", selection: protectionBinding) {
                Label("None", systemImage: ProtectionMode.none.systemImage).tag(ProtectionMode.none)
                Label("Hard Mode", systemImage: ProtectionMode.hard.systemImage).tag(ProtectionMode.hard)
                Label("Partner", systemImage: ProtectionMode.partner.systemImage).tag(ProtectionMode.partner)
                    .disabled(!partner.hasPartner)
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Protection")
        } footer: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                switch draft.protection {
                case .none: Text("Edit, stop or delete anytime.")
                case .hard: Text("Can't be stopped, edited or deleted while active, and Samla can't be deleted. No breaks.")
                case .partner: Text("Only your partner's PIN can stop, edit or delete it while active.")
                }
                if !partner.hasPartner {
                    Text("To use Partner, add one in Settings › Accountability Partner.")
                }
            }
        }
    }

    private var breaksSection: some View {
        Section {
            Stepper(value: $draft.breaks.count, in: 0...5) {
                LabeledContent("Breaks per day") {
                    Text(draft.breaks.count, format: .number)
                }
            }
            if draft.breaks.count > 0 {
                Picker("Length of each break", selection: $draft.breaks.minutes) {
                    ForEach([5, 10, 15], id: \.self) { value in
                        Text(Formatters.duration(minutes: value)).tag(value)
                    }
                }
            }
        } header: {
            Text("Breaks")
        } footer: {
            Text("Short breaks let you open blocked apps for a few minutes.")
        }
    }

    // MARK: - Helpers

    private var itemsSummary: String {
        let apps = draft.appCount + draft.categoryCount
        var parts: [String] = []
        if apps > 0 { parts.append(String(localized: "\(apps) apps", locale: .app)) }
        if draft.websiteCount > 0 { parts.append(String(localized: "\(draft.websiteCount) websites", locale: .app)) }
        return parts.isEmpty ? String(localized: "Add") : parts.joined(separator: " · ")
    }

    /// Preset durations, capped by the protection level (Hard Mode: 30 days).
    private var durationOptions: [Int] {
        let minutes = [15, 30, 45]
        let hours = [1, 2, 3, 4, 6, 8, 12]
        let days = [1, 2, 3, 7, 14, 30, 60, 90, 180, 360]
        let all = minutes.map { $0 * 60 } + hours.map { $0 * 3600 } + days.map { $0 * 86_400 }
        let cap = ListsModel.maxDays(for: draft.protection) * 86_400
        var options = all.filter { $0 <= cap }
        // Keep an edited list's existing custom duration selectable.
        if !options.contains(draft.durationSeconds), draft.durationSeconds <= cap {
            options.append(draft.durationSeconds)
            options.sort()
        }
        return options
    }

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
            let cap = ListsModel.maxDays(for: newValue) * 86_400
            if draft.durationSeconds > cap { draft.durationSeconds = cap }
        }
    }

    private var protectionAlertTitle: LocalizedStringKey {
        draft.isHard ? "Turn on Hard Mode?" : "Protect with your partner?"
    }

    private var protectionAlertMessage: LocalizedStringKey {
        draft.isHard
            ? "While this list is active you won't be able to stop, edit or delete it, and Samla can't be deleted."
            : "While this list is active, only your partner's PIN can stop, edit or delete it, and Samla can't be deleted."
    }

    // MARK: - Actions

    private func attemptSave() {
        // Ask before adding protection that locks the user in.
        let keepsSameProtection: Bool = {
            if case .edit(let original, _) = mode { return original.protection == draft.protection }
            return false
        }()
        if draft.protection != .none && !keepsSameProtection {
            confirmProtection = true
        } else {
            save()
        }
    }

    private func save() {
        var list = draft
        list.name = trimmedName
        if list.kind == .now { list.slots = [] }
        if isEditing {
            model.update(list, partnerApproved: partnerApproved)
        } else {
            model.create(list, startNow: startImmediately)
        }
        dismiss()
    }
}

#Preview {
    ListEditorView(mode: .create)
        .previewEnvironment()
}
