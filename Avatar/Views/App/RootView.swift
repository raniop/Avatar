import SwiftUI

struct RootView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(AppRouter.self) private var appRouter

    /// Show splash while auth is loading OR children haven't been fetched yet.
    private var showSplash: Bool {
        if case .loading = authManager.state { return true }
        if case .authenticated = authManager.state, !appRouter.hasCheckedChildren { return true }
        return false
    }

    var body: some View {
        ZStack {
            // Main content underneath
            Group {
                switch authManager.state {
                case .loading:
                    Color.clear
                case .unauthenticated:
                    AuthFlowView()
                case .authenticated:
                    if let role = appRouter.activeRole {
                        switch role {
                        case .child:
                            if appRouter.selectedChild != nil {
                                ChildTabView()
                            } else {
                                ChildPickerView()
                            }
                        case .parent:
                            ParentTabView()
                        }
                    } else {
                        RoleSelectionView()
                    }
                }
            }

            // Single splash overlay — one instance, no jump
            if showSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSplash)
        // Re-run whenever auth state changes so we catch the loading→authenticated transition
        .task(id: authManager.state) {
            if case .authenticated = authManager.state, !appRouter.hasCheckedChildren {
                await appRouter.prefetchChildren()
            }
        }
    }
}
