import FamilyControls
import SwiftUI

/// Picks what a list blocks: apps & categories (system picker) and websites.
struct BlockItemsEditorView: View {
    struct Items {
        var websites: [String]
        var selection: FamilyActivitySelection
        var blockAdultContent: Bool
    }

    @Environment(ScreenTimeAuthorization.self) private var screenTime
    @Environment(\.dismiss) private var dismiss

    @State private var items: Items
    @State private var websiteInput = ""
    @State private var showPicker = false
    @State private var showScreenTimeDenied = false
    private let onSave: (Items) -> Void

    /// ManagedSettings accepts at most 50 web domains in a filter.
    private static let maxWebsites = 50

    init(list: BlockList, onSave: @escaping (Items) -> Void) {
        _items = State(initialValue: Items(websites: list.websites, selection: list.selection, blockAdultContent: list.blockAdultContent))
        self.onSave = onSave
    }

    private var normalizedInput: String? { WebsiteInput.normalize(websiteInput) }
    private var hasAnyItem: Bool {
        !items.websites.isEmpty
            || !items.selection.applicationTokens.isEmpty
            || !items.selection.categoryTokens.isEmpty
            || !items.selection.webDomainTokens.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                appsSection
                websitesSection
                quickSitesSection
            }
            .navigationTitle("Apps & Websites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(items)
                        dismiss()
                    }
                    .disabled(!hasAnyItem)
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

    // MARK: - Sections

    private var appsSection: some View {
        Section {
            Button {
                Task { await openPicker() }
            } label: {
                Label("Choose Apps & Categories", systemImage: "square.stack.3d.up.fill")
                    .font(.subheadline.weight(.semibold))
            }

            if !items.selection.categoryTokens.isEmpty {
                ForEach(Array(items.selection.categoryTokens), id: \.self) { token in
                    Label(token).font(.subheadline)
                }
            }
            if !items.selection.applicationTokens.isEmpty {
                ForEach(Array(items.selection.applicationTokens), id: \.self) { token in
                    Label(token).font(.subheadline)
                }
            }
        } header: {
            Text("Apps & Categories")
        } footer: {
            Text("Selected apps open to the Samla block screen while the list is active.")
        }
    }

    private var websitesSection: some View {
        Section {
            HStack {
                TextField("e.g., youtube.com", text: $websiteInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.done)
                    .onSubmit(addWebsite)
                Button("Add", action: addWebsite)
                    .disabled(normalizedInput == nil || items.websites.count >= Self.maxWebsites)
            }
            ForEach(items.websites, id: \.self) { site in
                Label(site, systemImage: "globe")
            }
            .onDelete { items.websites.remove(atOffsets: $0) }
        } header: {
            Text("Websites")
        } footer: {
            if items.websites.count >= Self.maxWebsites {
                Text("You can block up to \(Self.maxWebsites) websites per list.")
            }
        }
    }

    private var quickSitesSection: some View {
        Section {
            ForEach(QuickSite.all) { site in
                Toggle(isOn: quickBinding(site.domain)) {
                    Label(site.title, systemImage: site.icon)
                }
            }
        } header: {
            Text("Quick Websites")
        } footer: {
            Text("To block the apps themselves, pick them with Choose Apps & Categories.")
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
        guard let domain = normalizedInput, items.websites.count < Self.maxWebsites else { return }
        if !items.websites.contains(domain) {
            items.websites.append(domain)
        }
        websiteInput = ""
    }

    private func quickBinding(_ domain: String) -> Binding<Bool> {
        Binding {
            items.websites.contains(domain)
        } set: { isOn in
            if isOn {
                if !items.websites.contains(domain), items.websites.count < Self.maxWebsites {
                    items.websites.append(domain)
                }
            } else {
                items.websites.removeAll { $0 == domain }
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

private struct QuickSite: Identifiable {
    let domain: String
    let title: String
    let icon: String
    var id: String { domain }

    static let all: [QuickSite] = [
        QuickSite(domain: "tiktok.com", title: "TikTok", icon: "play.rectangle"),
        QuickSite(domain: "instagram.com", title: "Instagram", icon: "camera"),
        QuickSite(domain: "snapchat.com", title: "Snapchat", icon: "bolt"),
        QuickSite(domain: "youtube.com", title: "YouTube", icon: "play.circle"),
        QuickSite(domain: "x.com", title: "X (Twitter)", icon: "bubble.left"),
        QuickSite(domain: "facebook.com", title: "Facebook", icon: "person.3"),
        QuickSite(domain: "reddit.com", title: "Reddit", icon: "bubble.right"),
        QuickSite(domain: "twitch.tv", title: "Twitch", icon: "gamecontroller.fill"),
        QuickSite(domain: "netflix.com", title: "Netflix", icon: "film"),
        QuickSite(domain: "primevideo.com", title: "Prime Video", icon: "film.stack"),
        QuickSite(domain: "disneyplus.com", title: "Disney+", icon: "star"),
        QuickSite(domain: "shahid.mbc.net", title: "Shahid", icon: "tv"),
        QuickSite(domain: "osnplus.com", title: "OSN+", icon: "tv"),
    ]
}
