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
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("Tips")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TipTopicView: View {
    let topic: FocusTips.Topic

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(topic.tips, id: \.self) { tip in
                    Text(tip)
                        .font(.body)
                        .foregroundStyle(AppColors.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                }
            }
            .padding(20)
        }
        .background(AppColors.background)
        .navigationTitle(Text(topic.title))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { TipsView() }
}
