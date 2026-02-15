import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(AppRouter.self) private var appRouter
    @Binding var showRegister: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var L: AppLocale { appRouter.currentLocale }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                Spacer()
                    .frame(height: 80)

                // Logo
                VStack(spacing: AppTheme.Spacing.sm) {
                    Image("SplashLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)

                    Text("Avatar")
                        .font(AppTheme.Fonts.title)
                        .foregroundStyle(.white)

                    Text(L.appTagline)
                        .font(AppTheme.Fonts.body)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()
                    .frame(height: 10)

                // Social Login Buttons
                VStack(spacing: AppTheme.Spacing.sm) {
                    // Sign in with Apple
                    Button {
                        Task { await signInWithApple() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 18, weight: .semibold))
                            Text(L.continueWithApple)
                                .font(AppTheme.Fonts.bodyBold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
                    }

                    // Sign in with Google
                    Button {
                        Task { await signInWithGoogle() }
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 20, height: 20)
                                Text("G")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.red, .yellow, .green, .blue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            Text(L.continueWithGoogle)
                                .font(AppTheme.Fonts.bodyBold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white.opacity(0.15))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.lg)

                // Divider
                HStack {
                    Rectangle()
                        .fill(.white.opacity(0.3))
                        .frame(height: 1)
                    Text(L.or)
                        .font(AppTheme.Fonts.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 12)
                    Rectangle()
                        .fill(.white.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.horizontal, AppTheme.Spacing.lg)

                // Email Login Form
                VStack(spacing: AppTheme.Spacing.md) {
                    TextField(L.email, text: $email)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
                        .foregroundStyle(.white)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField(L.password, text: $password)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
                        .foregroundStyle(.white)
                        .textContentType(.password)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppTheme.Fonts.caption)
                            .foregroundStyle(AppTheme.Colors.accent)
                    }

                    Button {
                        Task { await login() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.purple)
                            } else {
                                Text(L.logIn)
                                    .font(AppTheme.Fonts.bodyBold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .foregroundStyle(AppTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)

                    Button {
                        withAnimation { showRegister = true }
                    } label: {
                        Text(L.dontHaveAccount)
                            .font(AppTheme.Fonts.body)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.lg)

                Spacer()
                    .frame(height: 40)
            }
        }
        .environment(\.layoutDirection, L.layoutDirection)
        .scrollBounceBehavior(.basedOnSize)
        .background(AppTheme.Colors.backgroundGradient)
        .ignoresSafeArea()
    }

    private func login() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authManager.login(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func signInWithApple() async {
        isLoading = true
        errorMessage = nil

        let nonce = authManager.randomNonceString()
        authManager.currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = authManager.sha256(nonce)

        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else {
            errorMessage = "Cannot find window"
            isLoading = false
            return
        }

        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AppleSignInDelegate { result in
            Task {
                do {
                    try await authManager.handleAppleSignIn(result: result)
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                    }
                }
                await MainActor.run {
                    isLoading = false
                }
            }
        } onError: { error in
            Task { @MainActor in
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }

        controller.delegate = delegate
        controller.presentationContextProvider = AppleSignInPresentationContext(window: window)
        controller.performRequests()

        // Keep delegate alive
        objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
    }

    private func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Cannot find root view controller"
            isLoading = false
            return
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Missing Google ID token"
                isLoading = false
                return
            }
            let accessToken = result.user.accessToken.tokenString
            try await authManager.signInWithGoogle(idToken: idToken, accessToken: accessToken)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Apple Sign-In Helpers

class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    let onSuccess: (ASAuthorization) -> Void
    let onError: (Error) -> Void

    init(onSuccess: @escaping (ASAuthorization) -> Void, onError: @escaping (Error) -> Void) {
        self.onSuccess = onSuccess
        self.onError = onError
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        onSuccess(authorization)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onError(error)
    }
}

class AppleSignInPresentationContext: NSObject, ASAuthorizationControllerPresentationContextProviding {
    let window: UIWindow

    init(window: UIWindow) {
        self.window = window
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        window
    }
}
