import SwiftUI

enum AppTab: Int {
    case home = 0
    case lists = 1
    case settings = 2
}

struct MainTabView: View {
    @AppStorage(StorageKey.selectedTab) private var selectedTab = AppTab.home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)

            ListsView()
                .tabItem { Label("Lists", systemImage: "list.bullet") }
                .tag(AppTab.lists)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
    }
}

#Preview {
    MainTabView()
        .previewEnvironment()
}
