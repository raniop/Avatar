import SwiftUI

struct ChildTabView: View {
    @Environment(AppRouter.self) private var appRouter
    @State private var selectedTab: ChildTab = .home
    @State private var showAvatarSetup = false

    private var L: AppLocale { appRouter.currentLocale }

    private var needsAvatarSetup: Bool {
        guard let child = appRouter.selectedChild else { return false }
        return !UserDefaults.standard.bool(forKey: "avatar_setup_done_\(child.id)")
    }

    var body: some View {
        ZStack {
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

            // Avatar setup covers entire screen including tab bar
            if showAvatarSetup, let child = appRouter.selectedChild {
                AvatarSetupView(
                    child: child,
                    locale: L,
                    onComplete: {
                        UserDefaults.standard.set(true, forKey: "avatar_setup_done_\(child.id)")
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showAvatarSetup = false
                        }
                    }
                )
                .ignoresSafeArea(.container, edges: .bottom)
                .transition(.opacity)
            }
        }
        .onAppear {
            if needsAvatarSetup {
                showAvatarSetup = true
            }
        }
    }
}

private enum ChildTab: Hashable {
    case home
    case settings
}
