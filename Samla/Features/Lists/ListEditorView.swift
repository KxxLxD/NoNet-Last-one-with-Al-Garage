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
    @State private var days: Int
    @State private var hours: Int
    @State private var minutes: Int

    @State private var showItemsEditor = false
    @State private var showScheduleEditor = false
    @State private var showDurationPicker = false
    @State private var showSummary = false
    @State private var showSavedToast = false

    private static let breakLengths = [5, 10, 15, 20]
    /// One-tap "Block Now" lengths; anything else is "Custom".
    private static let durationPresets = [25 * 60, 3600, 2 * 3600, 4 * 3600, 8 * 3600, 86_400]

    init(mode: Mode) {
        self.mode = mode
        var list: BlockList
        switch mode {
        case .create:
            list = BlockList(name: "")
            list.durationSeconds = 60 * 60
        case .edit(let existing, _):
            list = existing
        }
        _draft = State(initialValue: list)
        _days = State(initialValue: list.durationSeconds / 86_400)
        _hours = State(initialValue: (list.durationSeconds % 86_400) / 3600)
        _minutes = State(initialValue: (list.durationSeconds % 3600) / 60 / 5 * 5)
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
    private var totalSeconds: Int { days * 86_400 + hours * 3600 + minutes * 60 }
    private var isTimeValid: Bool {
        draft.kind == .now ? totalSeconds >= 5 * 60 : !draft.slots.isEmpty
    }
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
                    Button(isEditing ? "Save" : "Create") { showSummary = true }
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
            .sheet(isPresented: $showDurationPicker) {
                DurationPickerSheet(days: $days, hours: $hours, minutes: $minutes, maxDays: ListsModel.maxDays(for: draft.protection))
                    .presentationDetents([.height(360)])
            }
            .sheet(isPresented: $showSummary) {
                ListSummarySheet(list: finalized, isEditing: isEditing, addsProtection: addsProtection, startsNow: startsNow) {
                    showSummary = false
                    save()
                }
                .presentationDetents([.medium, .large])
            }
            .successToast(isPresented: showSavedToast, message: isEditing ? "List updated" : "List created")
        }
        .interactiveDismissDisabled(showSavedToast)
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
                LabeledContent("Duration") {
                    Text(totalSeconds >= 5 * 60 ? Formatters.duration(seconds: totalSeconds) : String(localized: "At least 5 minutes"))
                        .foregroundStyle(totalSeconds >= 5 * 60 ? AppColors.textSecondary : AppColors.danger)
                }
                .listRowSeparator(.hidden)
                // Chips instead of inline wheels: wheels in a scrolling form spin when you scroll past them.
                FlowLayout {
                    ForEach(Self.durationPresets, id: \.self) { seconds in
                        ChipToggle(title: Formatters.duration(seconds: seconds), isOn: totalSeconds == seconds) {
                            setDuration(seconds)
                        }
                    }
                    ChipToggle(title: String(localized: "Custom"), isOn: !Self.durationPresets.contains(totalSeconds)) {
                        showDurationPicker = true
                    }
                }
                .padding(.vertical, Spacing.xs)
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
            HStack {
                Text("Breaks per day")
                Spacer()
                counterButton("minus", disabled: draft.breaks.count == 0) { draft.breaks.count -= 1 }
                Text(draft.breaks.count, format: .number)
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .frame(minWidth: 32)
                counterButton("plus", disabled: draft.breaks.count == 5) { draft.breaks.count += 1 }
            }
            if draft.breaks.count > 0 {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Length of each break")
                    HStack(spacing: Spacing.s) {
                        ForEach(Self.breakLengths, id: \.self) { value in
                            ChipToggle(title: Formatters.duration(minutes: value), isOn: draft.breaks.minutes == value) {
                                draft.breaks.minutes = value
                            }
                        }
                    }
                }
                .padding(.vertical, Spacing.xs)
            }
        } header: {
            Text("Breaks")
        } footer: {
            if draft.breaks.count > 0 {
                Text("\(draft.breaks.count.formatted(.number.locale(.app))) × \(Formatters.duration(minutes: draft.breaks.minutes)) per day")
            } else {
                Text("Short breaks let you open blocked apps for a few minutes.")
            }
        }
    }

    private func counterButton(_ systemImage: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 36, height: 36)
                .foregroundStyle(disabled ? AppColors.stopped : AppColors.primary)
                .background(AppColors.primarySoft, in: Circle())
        }
        .buttonStyle(.borderless)
        .disabled(disabled)
    }

    // MARK: - Helpers

    private func setDuration(_ seconds: Int) {
        days = seconds / 86_400
        hours = (seconds % 86_400) / 3600
        minutes = (seconds % 3600) / 60
    }

    private var itemsSummary: String {
        let apps = draft.appCount + draft.categoryCount
        var parts: [String] = []
        if apps > 0 { parts.append(String(localized: "\(apps) apps", locale: .app)) }
        if draft.websiteCount > 0 { parts.append(String(localized: "\(draft.websiteCount) websites", locale: .app)) }
        return parts.isEmpty ? String(localized: "Add") : parts.joined(separator: " · ")
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
            days = min(days, ListsModel.maxDays(for: newValue))
        }
    }

    /// The draft as it will be saved.
    private var finalized: BlockList {
        var list = draft
        list.name = trimmedName
        if list.kind == .now {
            list.slots = []
            list.durationSeconds = totalSeconds
        }
        return list
    }

    /// Adding Hard Mode or partner protection locks the user in, so the summary warns about it.
    private var addsProtection: Bool {
        guard draft.protection != .none else { return false }
        if case .edit(let original, _) = mode { return original.protection != draft.protection }
        return true
    }

    private var startsNow: Bool {
        !isEditing && draft.kind == .now && (startImmediately || draft.protection != .none)
    }

    // MARK: - Actions

    private func save() {
        if isEditing {
            model.update(finalized, partnerApproved: partnerApproved)
        } else {
            model.create(finalized, startNow: startImmediately)
        }
        Haptics.success()
        showSavedToast = true
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            dismiss()
        }
    }
}

/// Days / hours / minutes wheels for a custom "Block Now" length, in their own sheet so
/// scrolling the form can never spin them by accident.
private struct DurationPickerSheet: View {
    @Binding var days: Int
    @Binding var hours: Int
    @Binding var minutes: Int
    let maxDays: Int

    @Environment(\.dismiss) private var dismiss

    private static let minuteOptions = Array(stride(from: 0, through: 55, by: 5))
    private var totalSeconds: Int { days * 86_400 + hours * 3600 + minutes * 60 }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.m) {
                HStack(spacing: 0) {
                    wheel("Days", selection: $days, values: Array(0...maxDays))
                    wheel("Hours", selection: $hours, values: Array(0...23))
                    wheel("Minutes", selection: $minutes, values: Self.minuteOptions)
                }
                Text(totalSeconds >= 5 * 60 ? Formatters.duration(seconds: totalSeconds) : String(localized: "At least 5 minutes"))
                    .font(.headline)
                    .foregroundStyle(totalSeconds >= 5 * 60 ? AppColors.primary : AppColors.danger)
            }
            .padding(.horizontal, Spacing.l)
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle("Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func wheel(_ title: LocalizedStringKey, selection: Binding<Int>, values: [Int]) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
            Picker(title, selection: selection) {
                ForEach(values, id: \.self) { Text($0, format: .number).tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
            .clipped()
        }
        .frame(maxWidth: .infinity)
    }
}

/// Final review before saving: what's blocked, when, and how it's protected.
private struct ListSummarySheet: View {
    let list: BlockList
    let isEditing: Bool
    let addsProtection: Bool
    let startsNow: Bool
    var onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(list.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppColors.primary)
                        .listRowBackground(Color.clear)
                }
                Section("What to block") {
                    LabeledContent("Apps", value: (list.appCount + list.categoryCount).formatted(.number.locale(.app)))
                    LabeledContent("Websites", value: list.websiteCount.formatted(.number.locale(.app)))
                    if list.blockAdultContent {
                        LabeledContent("Adult websites", value: String(localized: "Blocked"))
                    }
                }
                Section("Time") {
                    switch list.kind {
                    case .now:
                        LabeledContent("Duration", value: Formatters.duration(seconds: list.durationSeconds))
                        if startsNow {
                            Label("Starts right away", systemImage: "play.fill")
                        }
                    case .scheduled:
                        LabeledContent("Schedule", value: Formatters.scheduleSummary(list.slots))
                    }
                    if list.allowsBreaks {
                        LabeledContent("Breaks", value: "\(list.breaks.count.formatted(.number.locale(.app))) × \(Formatters.duration(minutes: list.breaks.minutes))")
                    }
                }
                Section {
                    Label(list.protection.title, systemImage: list.protection.systemImage)
                } header: {
                    Text("Protection")
                } footer: {
                    if addsProtection {
                        Text(list.isHard
                             ? "While this list is active you won't be able to stop, edit or delete it, and Samla can't be deleted."
                             : "While this list is active, only your partner's PIN can stop, edit or delete it, and Samla can't be deleted.")
                    }
                }
            }
            .navigationTitle(isEditing ? "Confirm Changes" : "Confirm List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(confirmTitle, action: onConfirm)
                    .buttonStyle(PrimaryButtonStyle(tint: addsProtection ? AppColors.danger : AppColors.primary))
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.m)
            }
        }
    }

    private var confirmTitle: LocalizedStringKey {
        if addsProtection { return "I understand, turn on" }
        return isEditing ? "Save" : "Create"
    }
}

#Preview {
    ListEditorView(mode: .create)
        .previewEnvironment()
}
