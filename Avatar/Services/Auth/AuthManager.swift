import Foundation
import Observation
import FirebaseAuth
import FirebaseCore
import AuthenticationServices
import CryptoKit

@Observable
final class AuthManager {
    enum AuthState: Equatable {
        case loading
        case unauthenticated
        case authenticated(User)
    }

    var state: AuthState = .loading
    private(set) var currentUser: User?
    private(set) var firebaseUser: FirebaseAuth.User?

    private let apiClient: APIClient
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    // For Apple Sign-In nonce
    var currentNonce: String?

    init() {
        self.apiClient = APIClient.shared
        listenToAuthState()
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Firebase Auth State Listener

    private func listenToAuthState() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                if let user {
                    self.firebaseUser = user
                    await self.syncWithBackend(firebaseUser: user)
                } else {
                    self.firebaseUser = nil
                    self.currentUser = nil
                    self.state = .unauthenticated
                }
            }
        }
    }

    // MARK: - Sync Firebase user with our backend

    private func syncWithBackend(firebaseUser: FirebaseAuth.User) async {
        do {
            let idToken = try await firebaseUser.getIDToken()
            apiClient.setAuthToken(idToken)

            let user = try await apiClient.firebaseAuth(
                idToken: idToken,
                displayName: firebaseUser.displayName ?? "User"
            )
            currentUser = user
            state = .authenticated(user)
        } catch {
            // If backend sync fails, use Firebase user info directly
            let user = User(
                id: firebaseUser.uid,
                email: firebaseUser.email ?? "",
                displayName: firebaseUser.displayName ?? "User",
                locale: .english,
                createdAt: Date(),
                updatedAt: Date()
            )
            currentUser = user
            state = .authenticated(user)
        }
    }

    // MARK: - Email/Password

    func login(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        firebaseUser = result.user
        await syncWithBackend(firebaseUser: result.user)
    }

    func register(email: String, password: String, displayName: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)

        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        try await changeRequest.commitChanges()

        firebaseUser = result.user
        await syncWithBackend(firebaseUser: result.user)
    }

    // MARK: - Apple Sign-In

    func handleAppleSignIn(result: ASAuthorization) async throws {
        guard let appleIDCredential = result.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        let authResult = try await Auth.auth().signIn(with: credential)

        // Apple only provides name on first sign-in
        if let fullName = appleIDCredential.fullName {
            let displayName = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            if !displayName.isEmpty, authResult.user.displayName == nil {
                let changeRequest = authResult.user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try? await changeRequest.commitChanges()
            }
        }

        firebaseUser = authResult.user
        await syncWithBackend(firebaseUser: authResult.user)
    }

    // MARK: - Google Sign-In

    func signInWithGoogle(idToken: String, accessToken: String) async throws {
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: accessToken
        )
        let authResult = try await Auth.auth().signIn(with: credential)
        firebaseUser = authResult.user
        await syncWithBackend(firebaseUser: authResult.user)
    }

    // MARK: - Logout

    func logout() {
        try? Auth.auth().signOut()
        currentUser = nil
        firebaseUser = nil
        state = .unauthenticated
    }

    // MARK: - Apple Sign-In Helpers

    func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce.")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case invalidCredential
    case noRootViewController

    var errorDescription: String? {
        switch self {
        case .invalidCredential: return "Invalid sign-in credential"
        case .noRootViewController: return "Cannot find root view controller"
        }
    }
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: User
}
