import SwiftUI
import FirebaseCore
import FirebaseMessaging
import GoogleSignIn
import UserNotifications

@main
struct AvatarApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
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

// MARK: - AppDelegate for Push Notifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Initialize PushNotificationManager early so MessagingDelegate is set
        // before Firebase delivers the FCM token
        _ = PushNotificationManager.shared
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Bridge APNS token to Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
    }

    // Handle foreground notifications — show banner
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap — deep link to live monitor
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        NotificationCenter.default.post(
            name: .pushNotificationTapped,
            object: nil,
            userInfo: userInfo
        )
        completionHandler()
    }
}

extension Notification.Name {
    static let pushNotificationTapped = Notification.Name("pushNotificationTapped")
}
