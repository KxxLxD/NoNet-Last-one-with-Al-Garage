import SwiftUI

enum AppTab: Int, CaseIterable {
    case home = 0
    case lists = 1
    case settings = 2

    var title: LocalizedStringKey {
        switch self {
        case .home: "Home"
        case .lists: "Lists"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .lists: "list.bullet"
        case .settings: "gearshape.fill"
        }
    }
}

/// Three tabs with a plain white bar: a hairline on top, the selected tab in navy and
/// the others grey — no glass or shimmer. The system bar is hidden so each tab still
/// keeps its own navigation state.
struct MainTabView: View {
    @AppStorage(StorageKey.selectedTab) private var selectedTab = AppTab.home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tag(AppTab.home)
                .toolbar(.hidden, for: .tabBar)
            ListsView()
                .tag(AppTab.lists)
                .toolbar(.hidden, for: .tabBar)
            SettingsView()
                .tag(AppTab.settings)
                .toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TabBar(selection: $selectedTab)
        }
    }
}

private struct TabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    if selection != tab { Haptics.tap() }
                    selection = tab
                } label: {
                    VStack(spacing: Spacing.xs) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 22, weight: .medium))
                            .frame(height: 26)
                            .accessibilityHidden(true)
                        Text(tab.title)
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(selection == tab ? AppColors.primary : AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.s)
                    .padding(.bottom, Spacing.xs)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == tab ? [.isSelected, .isButton] : .isButton)
                // Like the system tab bar: long-press shows the tab enlarged at big text sizes.
                .accessibilityShowsLargeContentViewer()
            }
        }
        // Capped like the system tab bar, so huge text can't push tabs off screen.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isTabBar)
        .background(alignment: .top) {
            AppColors.surface
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Rectangle().fill(AppColors.border).frame(height: 0.5)
                }
        }
    }
}

#Preview {
    MainTabView()
        .previewEnvironment()
}
