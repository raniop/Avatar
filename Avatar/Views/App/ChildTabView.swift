import SwiftUI

struct ChildTabView: View {
    @Environment(AppRouter.self) private var appRouter
    @State private var selectedTab: ChildTab = .home
    @State private var showAvatarSetup = false

    private var L: AppLocale { appRouter.currentLocale }

    /// Show friend-selection if no friend has been chosen yet (new or old flow)
    private var needsAvatarSetup: Bool {
        guard let child = appRouter.selectedChild else { return false }
        let hasFriend = UserDefaults.standard.object(forKey: "friend_preset_\(child.id)") != nil
        let completedOldFlow = UserDefaults.standard.bool(forKey: "avatar_setup_done_\(child.id)")
        // Check if friend was set up on another device (backend has the name)
        let hasBackendFriend: Bool = {
            guard let name = child.avatar?.name else { return false }
            return ChildHomeViewModel.presetIdForName(name) != nil
        }()
        return !hasFriend && !completedOldFlow && !hasBackendFriend
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
                        // Friend preset is already saved in AvatarSetupView.saveAndFinish()
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
        .onChange(of: appRouter.shouldRestartAvatarSetup) { _, restart in
            if restart {
                appRouter.shouldRestartAvatarSetup = false
                withAnimation(.easeInOut(duration: 0.3)) {
                    showAvatarSetup = true
                }
            }
        }
    }
}

private enum ChildTab: Hashable {
    case home
    case settings
}
