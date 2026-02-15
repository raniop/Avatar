import SwiftUI

struct ChildTabView: View {
    @Environment(AppRouter.self) private var appRouter
    @State private var selectedTab: ChildTab = .home

    private var L: AppLocale { appRouter.currentLocale }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(L.home, systemImage: "house.fill", value: .home) {
                ChildHomeView()
            }

            Tab(L.settings, systemImage: "gearshape.fill", value: .settings) {
                SettingsView()
            }
        }
        .environment(\.layoutDirection, L.layoutDirection)
        .tint(AppTheme.Colors.primary)
    }
}

private enum ChildTab: Hashable {
    case home
    case settings
}
