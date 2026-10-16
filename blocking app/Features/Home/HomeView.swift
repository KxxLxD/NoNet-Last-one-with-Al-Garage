import SwiftUI

/// Home, top to bottom: the active list, Block Forever, missing permissions, then all lists.
struct HomeView: View {
    @Environment(ListsModel.self) private var model
    @Environment(SubscriptionStore.self) private var subscriptions

    @State private var showCreate = false
    @State private var showPremium = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        ActiveListCard(now: context.date, onStart: startTapped)
                    }
                    ForeverCard()
                    PermissionsCard()
                    ListsSection(onCreate: createTapped)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .background(AppColors.background)
            .navigationTitle("Samla")
            .navigationDestination(for: UUID.self) { id in
                ListDetailView(listID: id)
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .forever: ForeverStatusView()
                }
            }
            .sheet(isPresented: $showCreate) {
                ListEditorView(mode: .create)
            }
            .sheet(isPresented: $showPremium) {
                NavigationStack { PremiumSoonView(reason: .listLimit) }
            }
        }
    }

    /// "Start Blocking": runs the last-used Block Now list, or opens the editor when there's none.
    private func startTapped() {
        if let list = model.quickStartList {
            model.start(list.id)
        } else {
            createTapped()
        }
    }

    private func createTapped() {
        if model.canCreateList(isPremium: subscriptions.isPremium) {
            showCreate = true
        } else {
            showPremium = true
        }
    }
}

enum HomeRoute: Hashable {
    case forever
}

#Preview {
    HomeView()
        .previewEnvironment()
}
