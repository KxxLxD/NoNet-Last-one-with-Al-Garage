import FamilyControls
import SwiftUI

/// "What to block", in three clear steps:
/// 1. Apps & categories (Apple's picker; chosen apps show with their icons)
/// 2. Websites (type to add; swipe to remove)
/// 3. Suggestions grouped by category — one tap adds the website.
/// Suggestions can only be websites: Apple doesn't allow apps to be pre-selected.
struct BlockItemsEditorView: View {
    struct Items {
        var websites: [String]
        var selection: FamilyActivitySelection
    }

    @Environment(ScreenTimeAuthorization.self) private var screenTime
    @Environment(\.dismiss) private var dismiss

    @State private var items: Items
    @State private var websiteInput = ""
    @State private var showPicker = false
    @State private var showScreenTimeDenied = false
    @FocusState private var isInputFocused: Bool
    private let onSave: (Items) -> Void

    /// ManagedSettings accepts at most 50 web domains in a filter.
    private static let maxWebsites = 50

    init(list: BlockList, onSave: @escaping (Items) -> Void) {
        _items = State(initialValue: Items(websites: list.websites, selection: list.selection))
        self.onSave = onSave
    }

    private var normalizedInput: String? { WebsiteInput.normalize(websiteInput) }
    private var isFull: Bool { items.websites.count >= Self.maxWebsites }
    private var appCount: Int { items.selection.applicationTokens.count + items.selection.categoryTokens.count }

    var body: some View {
        NavigationStack {
            List {
                appsSection
                websitesSection
                ForEach(SuggestionGroup.all) { group in
                    suggestionSection(group)
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
    }

    // MARK: - 1. Apps

    private var appsSection: some View {
        Section {
            Button {
                Task { await openPicker() }
            } label: {
                Label(appCount == 0 ? "Choose Apps" : "Change Apps", systemImage: "square.grid.2x2.fill")
            }

            ForEach(Array(items.selection.categoryTokens), id: \.self) { token in
                Label(token)
            }
            ForEach(Array(items.selection.applicationTokens), id: \.self) { token in
                Label(token)
            }
        } header: {
            HStack {
                Text("Apps & Categories")
                Spacer()
                if appCount > 0 { Text(appCount, format: .number) }
            }
        } footer: {
            Text("Chosen apps open to the Samla block screen while the list is active.")
        }
    }

    // MARK: - 2. Websites

    private var websitesSection: some View {
        Section {
            HStack(spacing: Spacing.m) {
                Image(systemName: "globe")
                    .foregroundStyle(AppColors.textSecondary)
                TextField("e.g., youtube.com", text: $websiteInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.done)
                    .focused($isInputFocused)
                    .onSubmit(addWebsite)
                Button("Add", action: addWebsite)
                    .buttonStyle(.borderless)
                    .fontWeight(.semibold)
                    .disabled(normalizedInput == nil || isFull)
            }

            ForEach(items.websites, id: \.self) { site in
                Text(site)
                    .foregroundStyle(AppColors.text)
            }
            .onDelete { offsets in
                Haptics.tap()
                items.websites.remove(atOffsets: offsets)
            }
        } header: {
            HStack {
                Text("Websites")
                Spacer()
                if !items.websites.isEmpty { Text(items.websites.count, format: .number) }
            }
        } footer: {
            if isFull {
                Text("You can block up to \(Self.maxWebsites) websites per list.")
            } else if !websiteInput.isEmpty && normalizedInput == nil {
                Text("Enter a website like example.com")
            } else if !items.websites.isEmpty {
                Text("Swipe a website to remove it.")
            }
        }
    }

    // MARK: - 3. Suggestions

    private func suggestionSection(_ group: SuggestionGroup) -> some View {
        Section {
            FlowLayout {
                ForEach(group.sites) { site in
                    ChipToggle(title: site.title, isOn: items.websites.contains(site.domain)) {
                        toggle(site.domain)
                    }
                }
            }
            .padding(.vertical, Spacing.xs)
        } header: {
            Label(group.title, systemImage: group.systemImage)
        } footer: {
            if group.id == SuggestionGroup.all.last?.id {
                Text("Suggestions block the website. To block the app itself, choose it in Apps & Categories.")
            }
        }
    }

    // MARK: - Actions

    private func openPicker() async {
        if !screenTime.isApproved {
            guard await screenTime.request() else {
                showScreenTimeDenied = true
                return
            }
        }
        showPicker = true
    }

    private func addWebsite() {
        guard let domain = normalizedInput, !isFull else { return }
        if !items.websites.contains(domain) {
            Haptics.tap()
            withAnimation { items.websites.insert(domain, at: 0) }
        }
        websiteInput = ""
    }

    private func toggle(_ domain: String) {
        withAnimation {
            if let index = items.websites.firstIndex(of: domain) {
                items.websites.remove(at: index)
            } else if !isFull {
                items.websites.insert(domain, at: 0)
            }
        }
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

/// Popular websites grouped by category for one-tap blocking.
private struct SuggestionGroup: Identifiable {
    struct Site: Identifiable {
        let title: String
        let domain: String
        var id: String { domain }
    }

    let id: String
    let title: LocalizedStringKey
    let systemImage: String
    let sites: [Site]

    static let all: [SuggestionGroup] = [
        SuggestionGroup(id: "social", title: "Social", systemImage: "bubble.left.and.bubble.right.fill", sites: [
            Site(title: "TikTok", domain: "tiktok.com"),
            Site(title: "Instagram", domain: "instagram.com"),
            Site(title: "Snapchat", domain: "snapchat.com"),
            Site(title: "X", domain: "x.com"),
            Site(title: "Facebook", domain: "facebook.com"),
            Site(title: "Reddit", domain: "reddit.com"),
        ]),
        SuggestionGroup(id: "video", title: "Video", systemImage: "play.rectangle.fill", sites: [
            Site(title: "YouTube", domain: "youtube.com"),
            Site(title: "Netflix", domain: "netflix.com"),
            Site(title: "Shahid", domain: "shahid.mbc.net"),
            Site(title: "OSN+", domain: "osnplus.com"),
            Site(title: "Prime Video", domain: "primevideo.com"),
            Site(title: "Disney+", domain: "disneyplus.com"),
        ]),
        SuggestionGroup(id: "games", title: "Games", systemImage: "gamecontroller.fill", sites: [
            Site(title: "Twitch", domain: "twitch.tv"),
            Site(title: "Roblox", domain: "roblox.com"),
            Site(title: "Steam", domain: "steampowered.com"),
            Site(title: "Epic Games", domain: "epicgames.com"),
            Site(title: "Chess.com", domain: "chess.com"),
        ]),
        SuggestionGroup(id: "shopping", title: "Shopping", systemImage: "bag.fill", sites: [
            Site(title: "Amazon", domain: "amazon.sa"),
            Site(title: "noon", domain: "noon.com"),
            Site(title: "SHEIN", domain: "shein.com"),
            Site(title: "AliExpress", domain: "aliexpress.com"),
            Site(title: "Temu", domain: "temu.com"),
        ]),
    ]
}

#Preview {
    BlockItemsEditorView(list: BlockList(name: "Preview")) { _ in }
        .previewEnvironment()
}
