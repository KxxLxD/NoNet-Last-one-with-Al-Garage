import FamilyControls
import SwiftUI

/// "What to block", top to bottom:
/// 1. No Internet mode — everything except the apps you allow.
/// 2. Apps — Apple's list, where a category can be blocked whole or opened to pick some apps.
/// 3. Distractions and Protect Yourself — website categories, each blocked whole with its
///    checkmark or opened to pick single sites (works like Apple's list).
/// 4. Other websites you type in.
/// Categories can only hold websites: Apple doesn't allow apps to be pre-selected.
struct BlockItemsEditorView: View {
    struct Items: Equatable {
        var websites: [String]
        var selection: FamilyActivitySelection
        var blockAdultContent: Bool
        var blocksEverything: Bool
        var allowedSelection: FamilyActivitySelection
    }

    @Environment(ScreenTimeAuthorization.self) private var screenTime
    @Environment(ForeverStore.self) private var forever
    @Environment(\.dismiss) private var dismiss

    @State private var items: Items
    private let initialItems: Items
    @State private var websiteInput = ""
    @State private var expanded: Set<String> = []
    @State private var showPicker = false
    @State private var showAllowedPicker = false
    @State private var showScreenTimeDenied = false
    @State private var showForeverSetup = false
    private let onSave: (Items) -> Void

    init(list: BlockList, onSave: @escaping (Items) -> Void) {
        let items = Items(
            websites: list.websites,
            selection: list.selection,
            blockAdultContent: list.blockAdultContent,
            blocksEverything: list.blocksEverything,
            allowedSelection: list.allowedSelection
        )
        _items = State(initialValue: items)
        initialItems = items
        self.onSave = onSave
    }

    private var foreverActive: Bool { forever.isActive() }
    /// Apple's web filter takes 50 domains in total, and Block Forever already uses some of them.
    private var websiteLimit: Int {
        ShieldEngine.maxFilterDomains - (foreverActive ? ForeverBlock.blockedDomains.count : 0)
    }
    private var isFull: Bool { items.websites.count >= websiteLimit }
    private var normalizedInput: String? { WebsiteInput.normalize(websiteInput) }
    private var appCount: Int { items.selection.applicationTokens.count + items.selection.categoryTokens.count }
    private var customWebsites: [String] { items.websites.filter { !WebsiteCategory.allDomains.contains($0) } }

    var body: some View {
        NavigationStack {
            List {
                noInternetSection
                if !items.blocksEverything {
                    appsSection
                    distractionsSection
                    protectSection
                    customWebsitesSection
                }
            }
            .navigationTitle("What to block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Haptics.success()
                        onSave(items)
                        dismiss()
                    }
                }
            }
            .familyActivityPicker(isPresented: $showPicker, selection: $items.selection)
            .sheet(isPresented: $showForeverSetup) { ForeverSetupView() }
            .alert("Screen Time access needed", isPresented: $showScreenTimeDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Allow Samla to use Screen Time so it can block content.")
            }
        }
        // The allowed-apps picker sits a level above the blocked-apps one: two pickers on one
        // view clash, and a picker on a row swallows that row's taps.
        .familyActivityPicker(isPresented: $showAllowedPicker, selection: $items.allowedSelection)
        // A swipe down must not silently throw away picks: use Cancel or Done.
        .interactiveDismissDisabled(items != initialItems)
    }

    // MARK: - No Internet mode

    private var noInternetSection: some View {
        Section {
            Toggle(isOn: $items.blocksEverything.animation()) {
                rowLabel("No Internet Mode", detail: "Blocks every app and website except the apps you allow.", systemImage: "wifi.slash")
            }

            if items.blocksEverything {
                Button {
                    Task { await openPicker { showAllowedPicker = true } }
                } label: {
                    LabeledContent {
                        Text(allowedSummary)
                    } label: {
                        Label("Allowed Apps", systemImage: "checkmark.app.fill")
                            .foregroundStyle(AppColors.text)
                    }
                }
            }
        } footer: {
            if items.blocksEverything {
                Text("Choose apps only, like Maps or your bank. Phone calls always work, and every website stays blocked.")
            }
        }
    }

    private var allowedSummary: String {
        let count = items.allowedSelection.applicationTokens.count
        return count == 0 ? String(localized: "None") : String(localized: "\(count) apps", locale: .app)
    }

    // MARK: - Apps

    private var appsSection: some View {
        Section {
            Button {
                Task { await openPicker { showPicker = true } }
            } label: {
                Label(appCount == 0 ? "Choose Apps" : "Change Apps", systemImage: "square.grid.2x2.fill")
            }
            ForEach(Array(items.selection.categoryTokens), id: \.self) { token in
                Label(token)
            }
            ForEach(Array(items.selection.applicationTokens), id: \.self) { token in
                Label(token)
            }
            ForEach(Array(items.selection.webDomainTokens), id: \.self) { token in
                Label(token)
            }
        } header: {
            HStack {
                Text("Apps")
                Spacer()
                if appCount > 0 { Text(appCount, format: .number) }
            }
        } footer: {
            Text("In Apple's list, tick a category to block all its apps, or open it and pick only some.")
        }
    }

    // MARK: - Website categories

    private var distractionsSection: some View {
        Section {
            ForEach(WebsiteCategory.distractions) { categoryRow($0) }
        } header: {
            Text("Distractions")
        } footer: {
            Text(isFull
                 ? "You've reached Apple's limit of \(websiteLimit) websites per list."
                 : "Tick a category to block all of it, or open it to pick sites. \(items.websites.count) of \(websiteLimit) websites used.")
        }
    }

    private var protectSection: some View {
        Section {
            adultRow
            ForEach(WebsiteCategory.harmful) { categoryRow($0) }
            if !foreverActive {
                Button { showForeverSetup = true } label: {
                    HStack(spacing: Spacing.m) {
                        IconSquare(systemName: "lock.shield.fill")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Block these for good")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.primary)
                            Text("Block Forever is free and always on, not just while this list runs.")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        } header: {
            Text("Protect Yourself")
        }
    }

    private var adultRow: some View {
        Toggle(isOn: foreverActive ? .constant(true) : $items.blockAdultContent) {
            rowLabel(
                "Adult Websites",
                detail: foreverActive ? "Covered by Block Forever" : "Apple's built-in filter blocks adult sites in every browser.",
                systemImage: "eye.slash.fill"
            )
        }
        .disabled(foreverActive)
    }

    private func categoryRow(_ category: WebsiteCategory) -> some View {
        let covered = category.coveredByForever && foreverActive
        let chosen = category.sites.filter { items.websites.contains($0.domain) }.count
        let fill: SelectionMark.Fill = covered || chosen == category.sites.count ? .all : chosen == 0 ? .none : .some

        return DisclosureGroup(isExpanded: expansion(for: category.id)) {
            ForEach(category.sites) { site in
                siteRow(site, covered: covered)
            }
            if let note = category.note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            }
        } label: {
            HStack(spacing: Spacing.s) {
                Button { toggleAll(category) } label: {
                    SelectionMark(fill: fill)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(covered)
                .accessibilityLabel(fill == .all ? Text("Unblock all") : Text("Block all"))

                Image(systemName: category.systemImage)
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.title)
                        .foregroundStyle(AppColors.text)
                    if covered {
                        Text("Covered by Block Forever")
                            .font(.caption)
                            .foregroundStyle(AppColors.activeText)
                    }
                }
                Spacer(minLength: Spacing.s)
                if !covered && chosen > 0 {
                    Text(String(localized: "\(chosen) of \(category.sites.count)", locale: .app))
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private func siteRow(_ site: WebsiteCategory.Site, covered: Bool) -> some View {
        let isOn = covered || items.websites.contains(site.domain)
        return Button {
            toggle(site.domain)
        } label: {
            HStack(spacing: Spacing.m) {
                SelectionMark(fill: isOn ? .all : .none)
                VStack(alignment: .leading, spacing: 2) {
                    Text(site.title).foregroundStyle(AppColors.text)
                    Text(site.domain)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(covered || (!isOn && isFull))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: - Other websites

    private var customWebsitesSection: some View {
        Section {
            HStack(spacing: Spacing.m) {
                Image(systemName: "globe")
                    .foregroundStyle(AppColors.textSecondary)
                TextField("e.g., example.com", text: $websiteInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.done)
                    .onSubmit(addWebsite)
                Button("Add", action: addWebsite)
                    .buttonStyle(.borderless)
                    .fontWeight(.semibold)
                    .disabled(normalizedInput == nil || isFull)
            }
            // Full-width separator under the input row (it otherwise starts at the "Add" button).
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }

            ForEach(customWebsites, id: \.self) { site in
                Text(site).foregroundStyle(AppColors.text)
            }
            .onDelete { offsets in
                Haptics.tap()
                let removed = offsets.map { customWebsites[$0] }
                items.websites.removeAll { removed.contains($0) }
            }
        } header: {
            Text("Other Websites")
        } footer: {
            if !websiteInput.isEmpty && normalizedInput == nil {
                Text("Enter a website like example.com")
            } else if foreverActive {
                Text("Block Forever uses \(ForeverBlock.blockedDomains.count) of Apple's \(ShieldEngine.maxFilterDomains)-website limit.")
            } else if !customWebsites.isEmpty {
                Text("Swipe a website to remove it.")
            }
        }
    }

    // MARK: - Building blocks

    private func rowLabel(_ title: LocalizedStringKey, detail: LocalizedStringKey, systemImage: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(AppColors.text)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        } icon: {
            Image(systemName: systemImage).foregroundStyle(AppColors.primary)
        }
    }

    private func expansion(for id: String) -> Binding<Bool> {
        Binding {
            expanded.contains(id)
        } set: { isExpanded in
            if isExpanded { expanded.insert(id) } else { expanded.remove(id) }
        }
    }

    // MARK: - Actions

    private func openPicker(_ present: () -> Void) async {
        if !screenTime.isApproved {
            guard await screenTime.request() else {
                showScreenTimeDenied = true
                return
            }
        }
        present()
    }

    /// None or some → all (as many as fit under the limit); all → none.
    private func toggleAll(_ category: WebsiteCategory) {
        Haptics.tap()
        let domains = category.sites.map(\.domain)
        withAnimation {
            if domains.allSatisfy(items.websites.contains) {
                items.websites.removeAll { domains.contains($0) }
            } else {
                for domain in domains where !items.websites.contains(domain) && !isFull {
                    items.websites.append(domain)
                }
            }
        }
    }

    private func toggle(_ domain: String) {
        Haptics.tap()
        withAnimation {
            if let index = items.websites.firstIndex(of: domain) {
                items.websites.remove(at: index)
            } else if !isFull {
                items.websites.append(domain)
            }
        }
    }

    private func addWebsite() {
        guard let domain = normalizedInput, !isFull else { return }
        if !items.websites.contains(domain) {
            Haptics.tap()
            withAnimation { items.websites.insert(domain, at: 0) }
        }
        websiteInput = ""
    }
}

/// Empty circle, minus (some chosen) or checkmark (all chosen) — like Apple's app list.
private struct SelectionMark: View {
    enum Fill { case none, some, all }

    let fill: Fill

    var body: some View {
        Image(systemName: fill == .all ? "checkmark.circle.fill" : fill == .some ? "minus.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(fill == .none ? AppColors.textSecondary : AppColors.primary)
            .accessibilityHidden(true)
    }
}

// MARK: - Helpers

enum WebsiteInput {
    /// Turns "https://www.YouTube.com/watch?v=1" into "youtube.com". Returns nil if not a domain.
    static func normalize(_ raw: String) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for prefix in ["https://", "http://"] where text.hasPrefix(prefix) {
            text.removeFirst(prefix.count)
        }
        if text.hasPrefix("www.") { text.removeFirst(4) }
        if let slash = text.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) {
            text = String(text[..<slash])
        }
        let allowed = CharacterSet.lowercaseLetters.union(.decimalDigits).union(CharacterSet(charactersIn: ".-"))
        guard text.contains("."),
              !text.hasPrefix("."), !text.hasSuffix("."),
              text.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return text
    }
}

#Preview {
    BlockItemsEditorView(list: BlockList(name: "Preview")) { _ in }
        .previewEnvironment()
}
