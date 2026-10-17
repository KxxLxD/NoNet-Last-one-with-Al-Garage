import SwiftUI

/// Settings › Tips: four topics, each opening its tips.
struct TipsView: View {
    var body: some View {
        List(FocusTips.topics) { topic in
            NavigationLink {
                TipTopicView(topic: topic)
            } label: {
                Label {
                    Text(topic.title).foregroundStyle(AppColors.text)
                } icon: {
                    Image(systemName: topic.systemImage).foregroundStyle(AppColors.primary)
                }
            }
        }
        .navigationTitle("Tips")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TipTopicView: View {
    let topic: FocusTips.Topic

    @Environment(ListsModel.self) private var model
    @Environment(SubscriptionStore.self) private var subscriptions
    @State private var pendingStarter: StarterList?
    @State private var showPremium = false

    /// Tips that describe a list come with a button that creates it.
    private var starter: StarterList? {
        switch topic.id {
        case "sleep": .sleep
        case "focus": .focus
        case "habits": .socialMedia
        default: nil
        }
    }

    var body: some View {
        List {
            if let starter {
                Section {
                    Button {
                        if model.canCreateList(isPremium: subscriptions.isPremium) {
                            pendingStarter = starter
                        } else {
                            showPremium = true
                        }
                    } label: {
                        HStack(spacing: Spacing.m) {
                            IconSquare(systemName: starter.systemImage)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Create this list")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppColors.primary)
                                Text(starter.summary)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                    }
                }
            }
            Section {
                ForEach(topic.tips, id: \.self) { tip in
                    Text(tip)
                        .foregroundStyle(AppColors.text)
                        .padding(.vertical, Spacing.xs)
                }
            }
        }
        .navigationTitle(Text(topic.title))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $pendingStarter) { ListEditorView(mode: .starter($0.makeList())) }
        .sheet(isPresented: $showPremium) { NavigationStack { PremiumSoonView(reason: .listLimit) } }
    }
}

#Preview {
    NavigationStack { TipsView() }
        .previewEnvironment()
}
