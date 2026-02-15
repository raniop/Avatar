import SwiftUI

struct ParentTabView: View {
    @Environment(AppRouter.self) private var appRouter
    @State private var selectedTab: ParentTab = .dashboard

    private var L: AppLocale { appRouter.currentLocale }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(L.dashboard, systemImage: "chart.bar.fill", value: .dashboard) {
                ParentDashboardView()
            }

            Tab(L.settings, systemImage: "gearshape.fill", value: .settings) {
                SettingsView()
            }
        }
        .environment(\.layoutDirection, L.layoutDirection)
        .tint(AppTheme.Colors.primary)
    }
}

private enum ParentTab: Hashable {
    case dashboard
    case settings
}
