import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct AvatarApp: App {
    @State private var authManager: AuthManager
    @State private var appRouter = AppRouter()

    init() {
        FirebaseApp.configure()
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        _authManager = State(initialValue: AuthManager())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authManager)
                .environment(appRouter)
                .environment(\.layoutDirection,
                    appRouter.currentLocale == .hebrew ? .rightToLeft : .leftToRight)
        }
    }
}
