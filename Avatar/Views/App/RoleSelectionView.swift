import SwiftUI

struct RoleSelectionView: View {
    @Environment(AppRouter.self) private var appRouter
    @Environment(AuthManager.self) private var authManager

    @State private var animateCards = false
    @State private var showParentChallenge = false
    @State private var showNewChildFlow = false

    private var L: AppLocale { appRouter.currentLocale }

    /// Uses the pre-fetched children from AppRouter (loaded in RootView)
    /// so there's no extra loading spinner.
    private var hasChildren: Bool {
        guard let cached = appRouter.cachedChildren else { return false }
        return !cached.isEmpty
    }

    var body: some View {
        Group {
            if !hasChildren {
                // No children yet — welcome splash
                welcomeNewUserView
            } else {
                // Has children — show role selection
                roleSelectionContent
            }
        }
    }

    // MARK: - Welcome New User

    private var welcomeNewUserView: some View {
        ZStack {
            // Same gradient as splash
            LinearGradient(
                colors: [
                    Color(hex: "A29BFE"),
                    Color(hex: "6C5CE7")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Language toggle — always pinned to leading edge
                HStack {
                    LanguageToggleButton()
                    Spacer()
                }
                .environment(\.layoutDirection, .leftToRight)
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer()

                // App logo
                Image("SplashLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 20, y: 10)

                Spacer().frame(height: 32)

                // Welcome title
                Text(L.letsStartTitle)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer().frame(height: 12)

                // Subtitle
                Text(L.letsStartSubtitle)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                // CTA button
                Button {
                    showNewChildFlow = true
                } label: {
                    Text(L.createFirstChild)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(.white)
                        .foregroundStyle(Color(hex: "6C5CE7"))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
            }
        }
        .environment(\.layoutDirection, L.layoutDirection)
        .sheet(isPresented: $showNewChildFlow) {
            NewChildFlowView(onChildCreated: {
                // Refresh the cached children list
                Task { await appRouter.prefetchChildren(force: true) }
            })
        }
    }

    // MARK: - Role Selection Content

    private var roleSelectionContent: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hex: "667eea"),
                    Color(hex: "764ba2")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                // Language toggle — always pinned to leading edge
                HStack {
                    LanguageToggleButton()
                    Spacer()
                }
                .environment(\.layoutDirection, .leftToRight)
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer()

                // Welcome text
                VStack(spacing: 12) {
                    Text(L.welcome)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(L.whoIsUsing)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()

                // Role cards
                HStack(spacing: 20) {
                    // Child card
                    RoleCard(
                        icon: "wand.and.stars",
                        title: L.kidRole,
                        subtitle: L.kidSubtitle,
                        gradient: [Color(hex: "74B9FF"), Color(hex: "0984e3")],
                        iconSize: 44
                    ) {
                        withAnimation(.spring(duration: 0.4)) {
                            appRouter.activeRole = .child
                        }
                    }
                    .offset(y: animateCards ? 0 : 40)
                    .opacity(animateCards ? 1 : 0)

                    // Parent card — requires math challenge
                    RoleCard(
                        icon: "shield.checkered",
                        title: L.parentRole,
                        subtitle: L.parentSubtitle,
                        gradient: [Color(hex: "a29bfe"), Color(hex: "6c5ce7")],
                        iconSize: 40
                    ) {
                        showParentChallenge = true
                    }
                    .offset(y: animateCards ? 0 : 40)
                    .opacity(animateCards ? 1 : 0)
                }
                .padding(.horizontal, 24)

                Spacer()
                Spacer()
            }

            // Parent verification overlay
            if showParentChallenge {
                ParentChallengeView(locale: L) {
                    showParentChallenge = false
                    withAnimation(.spring(duration: 0.4)) {
                        appRouter.activeRole = .parent
                    }
                } onCancel: {
                    showParentChallenge = false
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .environment(\.layoutDirection, L.layoutDirection)
        .animation(.easeInOut(duration: 0.25), value: showParentChallenge)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                animateCards = true
            }
        }
    }
}

// MARK: - Parent Challenge (Full-Screen Overlay)

private struct ParentChallengeView: View {
    let locale: AppLocale
    let onSuccess: () -> Void
    let onCancel: () -> Void

    @State private var numberA = 0
    @State private var numberB = 0
    @State private var userInput = ""
    @State private var isWrong = false
    @State private var shakeOffset: CGFloat = 0
    @FocusState private var isFocused: Bool

    private var correctAnswer: Int { numberA + numberB }

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            // Card
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)

                    Text(locale.parentVerification)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(locale.keepKidsSafe)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.top, 28)

                // Math equation — always LTR so numbers read correctly
                // "numberA + numberB = ?"
                HStack(spacing: 12) {
                    Text("\(numberA)")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("+")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))

                    Text("\(numberB)")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("=")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))

                    Text("?")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .environment(\.layoutDirection, .leftToRight)
                .offset(x: shakeOffset)

                // Answer input field
                VStack(spacing: 6) {
                    HStack {
                        TextField("", text: $userInput)
                            .keyboardType(.numberPad)
                            .focused($isFocused)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(isWrong ? Color(hex: "FF6B6B") : .white)
                            .multilineTextAlignment(.center)
                            .onChange(of: userInput) { _, newValue in
                                userInput = String(newValue.filter(\.isNumber).prefix(3))
                                isWrong = false
                            }
                    }
                    .frame(height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.white.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        isWrong ? Color(hex: "FF6B6B").opacity(0.6)
                                        : isFocused ? .white.opacity(0.5) : .clear,
                                        lineWidth: 2
                                    )
                            )
                    )
                    .padding(.horizontal, 60)

                    if isWrong {
                        Text(locale.wrongAnswer)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(hex: "FF6B6B"))
                    }
                }

                // Buttons
                HStack(spacing: 16) {
                    Button {
                        onCancel()
                    } label: {
                        Text(locale.cancel)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.white.opacity(0.15))
                            .foregroundStyle(.white.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Button {
                        checkAnswer()
                    } label: {
                        Text(locale.enter)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.white)
                            .foregroundStyle(Color(hex: "6c5ce7"))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "6c5ce7"), Color(hex: "a29bfe")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
            )
            .padding(.horizontal, 24)
        }
        .onAppear {
            generateChallenge()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }

    private func generateChallenge() {
        numberA = Int.random(in: 2...12)
        numberB = Int.random(in: 2...12)
        userInput = ""
        isWrong = false
    }

    private func checkAnswer() {
        guard let answer = Int(userInput.trimmingCharacters(in: .whitespaces)) else {
            triggerWrong()
            return
        }

        if answer == correctAnswer {
            onSuccess()
        } else {
            triggerWrong()
        }
    }

    private func triggerWrong() {
        isWrong = true
        userInput = ""

        // Shake animation
        withAnimation(.interpolatingSpring(stiffness: 600, damping: 10)) {
            shakeOffset = -12
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.interpolatingSpring(stiffness: 600, damping: 10)) {
                shakeOffset = 12
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.interpolatingSpring(stiffness: 600, damping: 10)) {
                shakeOffset = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            generateChallenge()
        }
    }
}

// MARK: - Role Card

private struct RoleCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [Color]
    let iconSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: iconSize))
                    .foregroundStyle(.white)

                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
            .background(
                LinearGradient(
                    colors: gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: gradient.first!.opacity(0.4), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Language Toggle Button

struct LanguageToggleButton: View {
    @Environment(AppRouter.self) private var appRouter

    var body: some View {
        Menu {
            ForEach(AppLocale.allCases, id: \.self) { locale in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        appRouter.currentLocale = locale
                    }
                } label: {
                    HStack {
                        Text(locale.displayName)
                        if locale == appRouter.currentLocale {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .semibold))
                Text(appRouter.currentLocale.displayName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.white.opacity(0.2))
            .clipShape(Capsule())
        }
    }
}
