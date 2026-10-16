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

    var body: some View {
        List(topic.tips, id: \.self) { tip in
            Text(tip)
                .foregroundStyle(AppColors.text)
                .padding(.vertical, Spacing.xs)
        }
        .navigationTitle(Text(topic.title))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { TipsView() }
}
