import SwiftUI

/// Three ready-made lists so a new user gets to a first block in one tap. They're built from the
/// website catalog and stay within 25 websites, so they still fit Apple's limit when Block Forever
/// is on. Apps can't be pre-selected (Apple), so the editor reminds people to add them.
struct StarterList: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let summary: LocalizedStringKey
    let systemImage: String
    let makeList: () -> BlockList

    static let all = [sleep, focus, socialMedia]

    static let sleep = StarterList(id: "sleep", title: "Sleep", summary: "Every night, 10 PM–7 AM", systemImage: "moon.zzz.fill") {
        var list = BlockList(name: String(localized: "Sleep"))
        list.kind = .scheduled
        list.slots = (0..<7).map { ScheduleSlot(day: $0, fromMinutes: 22 * 60, toMinutes: 7 * 60) }
        list.websites = StarterList.websites(in: ["social", "short-video", "video"])
        return list
    }

    static let focus = StarterList(id: "focus", title: "Focus", summary: "1 hour · social media, videos and news", systemImage: "scope") {
        var list = BlockList(name: String(localized: "Focus"))
        list.durationSeconds = 3600
        list.websites = StarterList.websites(in: ["social", "short-video", "video", "news"])
        return list
    }

    static let socialMedia = StarterList(id: "social", title: "Social Media", summary: "2 hours · social media and short videos", systemImage: "bubble.left.and.bubble.right.fill") {
        var list = BlockList(name: String(localized: "Social Media"))
        list.durationSeconds = 2 * 3600
        list.websites = StarterList.websites(in: ["social", "short-video"])
        return list
    }

    private static func websites(in categoryIDs: [String]) -> [String] {
        WebsiteCategory.all
            .filter { categoryIDs.contains($0.id) }
            .flatMap { $0.sites.map(\.domain) }
    }
}

/// "Start with a ready list": the starters plus "Create your own", for empty Home and Lists.
struct StarterListsSection: View {
    var onPick: (StarterList) -> Void
    var onCustom: () -> Void

    var body: some View {
        Section {
            ForEach(StarterList.all) { starter in
                Button { onPick(starter) } label: {
                    HStack(spacing: Spacing.m) {
                        IconSquare(systemName: starter.systemImage)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(starter.title).foregroundStyle(AppColors.text)
                            Text(starter.summary)
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppColors.textSecondary)
                            .accessibilityHidden(true)
                    }
                }
            }
            Button(action: onCustom) {
                Label("Create your own", systemImage: "plus")
            }
        } header: {
            Text("Start with a ready list")
                .sectionCaption()
        } footer: {
            Text("You can change everything before saving.")
                .sectionCaption()
        }
    }
}
