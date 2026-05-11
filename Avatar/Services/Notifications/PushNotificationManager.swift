import Foundation
import FirebaseMessaging
import UserNotifications
import UIKit

@Observable
final class PushNotificationManager: NSObject {
    static let shared = PushNotificationManager()

    var fcmToken: String?

    /// Role to register once the FCM token arrives (handles the race condition
    /// where registerToken is called before the token is ready).
    private var pendingRole: UserRole?

    private let apiClient = APIClient.shared

    private override init() {
        super.init()
        Messaging.messaging().delegate = self
    }

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            print("[Push] Permission error: \(error)")
            return false
        }
    }

    /// Register current FCM token with the backend for the given role.
    /// If the token isn't ready yet, waits up to 10 seconds for it.
    func registerToken(role: UserRole) async {
        // Try immediately
        if let token = fcmToken ?? Messaging.messaging().fcmToken {
            await sendTokenToBackend(token: token, role: role)
            return
        }

        // Token not ready yet — save the role so the delegate callback can register it
        print("[Push] FCM token not ready yet, waiting...")
        pendingRole = role

        // Also actively wait up to 10 seconds
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(500))
            if let token = fcmToken {
                pendingRole = nil
                await sendTokenToBackend(token: token, role: role)
                return
            }
        }
        print("[Push] Timed out waiting for FCM token")
    }

    /// Unregister token on logout.
    func unregisterToken() async {
        guard let token = fcmToken else { return }
        do {
            try await apiClient.unregisterDeviceToken(token: token)
        } catch {
            print("[Push] Failed to unregister: \(error)")
        }
    }

    private func sendTokenToBackend(token: String, role: UserRole) async {
        do {
            try await apiClient.registerDeviceToken(token: token, platform: "ios", role: role.rawValue)
            print("[Push] ✅ Token registered for role=\(role.rawValue)")
        } catch {
            print("[Push] Failed to register token: \(error)")
        }
    }
}

extension PushNotificationManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        self.fcmToken = fcmToken
        print("[Push] FCM token received: \(fcmToken?.prefix(20) ?? "nil")...")

        // If registerToken was called before the token was ready, register now
        if let role = pendingRole, let token = fcmToken {
            pendingRole = nil
            Task {
                await sendTokenToBackend(token: token, role: role)
            }
        }
    }
}
