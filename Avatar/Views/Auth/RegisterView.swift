import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct RegisterView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(AppRouter.self) private var appRouter
    @Binding var showRegister: Bool

    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var L: AppLocale { appRouter.currentLocale }

    private var isValid: Bool {
        !displayName.isEmpty && !email.isEmpty && !password.isEmpty
        && password == confirmPassword && password.count >= 6
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                Spacer()
                    .frame(height: 60)

                VStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 50))
                        .foregroundStyle(.white)

                    Text(L.createAccount)
                        .font(AppTheme.Fonts.heading)
                        .foregroundStyle(.white)
                }

                // Social Sign-Up Buttons
                VStack(spacing: AppTheme.Spacing.sm) {
                    // Sign up with Apple
                    Button {
                        Task { await signUpWithApple() }
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

                    // Sign up with Google
                    Button {
                        Task { await signUpWithGoogle() }
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

                // Email Registration Form
                VStack(spacing: AppTheme.Spacing.md) {
                    TextField(L.yourName, text: $displayName)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
                        .foregroundStyle(.white)
                        .textContentType(.name)

                    TextField(L.email, text: $email)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
                        .foregroundStyle(.white)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField(L.passwordMinChars, text: $password)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
                        .foregroundStyle(.white)
                        .textContentType(.newPassword)

                    SecureField(L.confirmPassword, text: $confirmPassword)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
                        .foregroundStyle(.white)
                        .textContentType(.newPassword)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppTheme.Fonts.caption)
                            .foregroundStyle(AppTheme.Colors.accent)
                    }

                    if !confirmPassword.isEmpty && password != confirmPassword {
                        Text(L.passwordsDontMatch)
                            .font(AppTheme.Fonts.caption)
                            .foregroundStyle(AppTheme.Colors.accent)
                    }

                    Button {
                        Task { await register() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.purple)
                            } else {
                                Text(L.createAccount)
                                    .font(AppTheme.Fonts.bodyBold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .foregroundStyle(AppTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
                    }
                    .disabled(!isValid || isLoading)

                    Button {
                        withAnimation { showRegister = false }
                    } label: {
                        Text(L.alreadyHaveAccount)
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

    private func register() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authManager.register(
                email: email,
                password: password,
                displayName: displayName
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func signUpWithApple() async {
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

    private func signUpWithGoogle() async {
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
