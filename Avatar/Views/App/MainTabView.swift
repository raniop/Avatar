import SwiftUI

struct MainTabView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(AppRouter.self) private var appRouter
    @State private var selectedTab: AppTab = .childHome

    var body: some View {
        @Bindable var router = appRouter

        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: .childHome) {
                ChildHomeView()
            }

            Tab("Dashboard", systemImage: "chart.bar.fill", value: .parentDashboard) {
                ParentDashboardView()
            }

            Tab("Settings", systemImage: "gearshape.fill", value: .settings) {
                SettingsView()
            }
        }
        .tint(AppTheme.Colors.primary)
    }
}

enum AppTab: Hashable {
    case childHome
    case parentDashboard
    case settings
}
