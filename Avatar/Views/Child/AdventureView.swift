import SwiftUI

struct AdventureView: View {
    @Bindable var viewModel: AdventureViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var appRouter

    private var L: AppLocale { appRouter.currentLocale }

    var body: some View {
        ZStack {
            MissionBackgroundView(theme: viewModel.mission.theme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: close button, scene progress, star counter
                AdventureTopBar(
                    locale: L,
                    starsEarned: viewModel.starsEarned,
                    scenesCompleted: viewModel.scenesCompleted,
                    currentScene: viewModel.adventureState?.sceneIndex ?? 0,
                    onEnd: {
                        Task { await viewModel.endAdventure() }
                    }
                )

                // Story card (main content area)
                StoryCard(
                    viewModel: viewModel,
                    locale: L
                )
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)

                Spacer()

                // Interaction area (choices, voice input, or celebrate)
                InteractionArea(
                    viewModel: viewModel,
                    locale: L
                )
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.md)
            }

            // Loading overlay
            if viewModel.phase == .loading {
                KidLoadingOverlay(
                    locale: L,
                    missionTitle: viewModel.mission.title,
                    emoji: viewModel.mission.emoji,
                    avatarImage: viewModel.avatarImage,
                    theme: viewModel.mission.theme
                )
            }

            // Celebration overlay
            if viewModel.showCelebration {
                AdventureCelebrationView(
                    locale: L,
                    starsEarned: viewModel.starsEarned,
                    collectible: viewModel.earnedCollectible,
                    theme: viewModel.mission.theme,
                    onDismiss: {
                        Task { await viewModel.endAdventure() }
                    }
                )
            }

            // Star earned flash
            if viewModel.justEarnedStar {
                VStack {
                    Spacer()
                    Text("⭐")
                        .font(.system(size: 60))
                        .transition(.scale.combined(with: .opacity))
                    Spacer()
                }
                .allowsHitTesting(false)
            }

            // Mini-game full-screen overlay
            if viewModel.showMiniGame, let config = viewModel.adventureState?.miniGame {
                let gameType = GameThemeConfig.gameType(for: viewModel.mission.theme)
                MiniGameContainerView(
                    gameType: gameType,
                    theme: viewModel.mission.theme,
                    round: config.round,
                    age: viewModel.child.age,
                    onComplete: { result in
                        viewModel.reportGameResult(result)
                    }
                )
                .background(
                    MissionBackgroundView(theme: viewModel.mission.theme)
                        .ignoresSafeArea()
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .environment(\.layoutDirection, L.layoutDirection)
        .navigationBarHidden(true)
        .task {
            await viewModel.startAdventure()
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            if newPhase == .dismissed {
                dismiss()
            }
        }
    }
}

// MARK: - Top Bar

struct AdventureTopBar: View {
    let locale: AppLocale
    let starsEarned: Int
    let scenesCompleted: [Bool]
    let currentScene: Int
    let onEnd: () -> Void

    var body: some View {
        HStack {
            // Close button
            Button(action: onEnd) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.2))
                    .clipShape(Circle())
            }

            Spacer()

            // Scene progress indicator (3 dots)
            SceneProgressBar(
                scenesCompleted: scenesCompleted,
                currentScene: currentScene
            )

            Spacer()

            // Star counter
            HStack(spacing: 3) {
                Text("⭐")
                    .font(.system(size: 14))
                Text("\(starsEarned)/3")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.white.opacity(0.2))
            .clipShape(Capsule())
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.sm)
    }
}

// MARK: - Scene Progress Bar

struct SceneProgressBar: View {
    let scenesCompleted: [Bool]
    let currentScene: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { index in
                // Dot
                ZStack {
                    Circle()
                        .fill(dotColor(for: index))
                        .frame(width: 24, height: 24)

                    if scenesCompleted[index] {
                        Text("⭐")
                            .font(.system(size: 12))
                    } else if index == currentScene {
                        Circle()
                            .stroke(.white, lineWidth: 2)
                            .frame(width: 24, height: 24)
                    }
                }

                // Connecting line (except after last dot)
                if index < 2 {
                    Rectangle()
                        .fill(lineColor(after: index))
                        .frame(width: 30, height: 3)
                }
            }
        }
    }

    private func dotColor(for index: Int) -> Color {
        if scenesCompleted[index] {
            return AppTheme.Colors.accent
        } else if index == currentScene {
            return .white.opacity(0.3)
        } else {
            return .white.opacity(0.15)
        }
    }

    private func lineColor(after index: Int) -> Color {
        if scenesCompleted[index] {
            return AppTheme.Colors.accent.opacity(0.8)
        }
        return .white.opacity(0.2)
    }
}

// MARK: - Story Card

struct StoryCard: View {
    let viewModel: AdventureViewModel
    let locale: AppLocale

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Scene emojis (visual "illustration")
            if let emojis = viewModel.adventureState?.sceneEmojis, !emojis.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(emojis.prefix(5).enumerated()), id: \.offset) { _, emoji in
                        Text(emoji)
                            .font(.system(size: 36))
                    }
                }
                .padding(.top, AppTheme.Spacing.md)
            }

            // Avatar (prominent, 80pt)
            if let friendImage = viewModel.friendImage {
                AnimatedAvatarView(image: friendImage, size: 80)
            }

            // Story text with typewriter
            Group {
                if viewModel.typewriterWaitingForAudio {
                    TypingIndicator()
                } else if viewModel.isAvatarThinking {
                    TypingIndicator()
                } else {
                    Text(viewModel.visibleStoryText)
                        .font(AppTheme.Fonts.childBody)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(6)
                        .animation(.easeOut(duration: 0.15), value: viewModel.typewriterVisibleWords)
                }
            }
            .frame(minHeight: 60)
            .padding(.horizontal, AppTheme.Spacing.md)

            // Scene label
            if let sceneName = viewModel.adventureState?.sceneName, !sceneName.isEmpty {
                Text(sceneName)
                    .font(AppTheme.Fonts.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xl))
    }
}

// MARK: - Interaction Area

struct InteractionArea: View {
    @Bindable var viewModel: AdventureViewModel
    let locale: AppLocale

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            switch viewModel.adventureState?.interactionType {
            case .choice:
                if let choices = viewModel.adventureState?.choices, !choices.isEmpty {
                    ChoiceButtonsView(
                        choices: choices,
                        isEnabled: !viewModel.isProcessing && !viewModel.isPlayingResponse && !viewModel.isAvatarThinking,
                        onSelect: { choice in
                            viewModel.selectChoice(choice)
                        }
                    )
                } else {
                    // Fallback to voice input if choices not yet available
                    voiceInput
                }

            case .miniGame:
                // Mini-game round — shows full-screen game overlay
                EmptyView()

            case .celebrate:
                // Celebration moment - show animation
                CelebrateMomentView(starsEarned: viewModel.starsEarned)

            case .voice, .none:
                voiceInput
            }
        }
    }

    private var voiceInput: some View {
        AdventureChatInputBar(
            viewModel: viewModel,
            locale: locale
        )
    }
}

// MARK: - Choice Buttons

struct ChoiceButtonsView: View {
    let choices: [AdventureChoice]
    let isEnabled: Bool
    let onSelect: (AdventureChoice) -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            ForEach(choices) { choice in
                Button {
                    onSelect(choice)
                } label: {
                    HStack(spacing: 10) {
                        Text(choice.emoji)
                            .font(.system(size: 24))
                        Text(choice.label)
                            .font(AppTheme.Fonts.bodyBold)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg))
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                }
                .buttonStyle(ChoiceButtonStyle())
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.6)
            }
        }
    }
}

struct ChoiceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Celebrate Moment

struct CelebrateMomentView: View {
    let starsEarned: Int
    @State private var showStar = false

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            if showStar {
                HStack(spacing: 6) {
                    ForEach(0..<starsEarned, id: \.self) { _ in
                        Text("⭐")
                            .font(.system(size: 36))
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: 80)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.3)) {
                showStar = true
            }
        }
    }
}

// MARK: - Adventure Chat Input Bar (for voice interactions)

struct AdventureChatInputBar: View {
    @Bindable var viewModel: AdventureViewModel
    let locale: AppLocale
    @State private var textInput = ""
    @FocusState private var isTextFocused: Bool

    private var canInteract: Bool {
        !viewModel.isProcessing && !viewModel.isPlayingResponse && !viewModel.isAvatarThinking
    }

    private var hasText: Bool {
        !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            TextField(locale.typeHere, text: $textInput, axis: .vertical)
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(.black)
                .tint(AppTheme.Colors.primary)
                .focused($isTextFocused)
                .disabled(!canInteract)
                .lineLimit(1...4)
                .submitLabel(.return)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 22))

            if hasText {
                Button(action: sendText) {
                    Circle()
                        .fill(AppTheme.Colors.primary)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "arrow.up")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        )
                }
                .disabled(!canInteract)
            } else {
                MicButton(
                    isListening: viewModel.isListening,
                    isProcessing: viewModel.isProcessing,
                    isPlayingResponse: viewModel.isPlayingResponse,
                    amplitude: viewModel.audioEngine.recordingAmplitude,
                    onPress: { viewModel.onTalkButtonPressed() },
                    onRelease: { viewModel.onTalkButtonReleased() }
                )
            }
        }
    }

    private func sendText() {
        let text = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        textInput = ""
        isTextFocused = false
        viewModel.sendTextMessage(text)
    }
}

// MARK: - Adventure Celebration View

struct AdventureCelebrationView: View {
    let locale: AppLocale
    let starsEarned: Int
    let collectible: AdventureCollectible?
    let theme: String
    let onDismiss: () -> Void

    @State private var showStars = false
    @State private var showCollectible = false
    @State private var showConfetti = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            // Confetti particles
            if showConfetti {
                ConfettiView(theme: theme)
            }

            VStack(spacing: AppTheme.Spacing.lg) {
                Spacer()

                // Stars
                if showStars {
                    HStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { index in
                            Text("⭐")
                                .font(.system(size: 44))
                                .opacity(index < starsEarned ? 1 : 0.3)
                                .scaleEffect(index < starsEarned ? 1 : 0.8)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                Text(locale.adventureComplete)
                    .font(AppTheme.Fonts.title)
                    .foregroundStyle(.white)

                // Collectible reveal
                if showCollectible, let collectible {
                    VStack(spacing: 8) {
                        Text(collectible.emoji)
                            .font(.system(size: 56))
                        Text(collectible.name)
                            .font(AppTheme.Fonts.childBody)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(AppTheme.Spacing.lg)
                    .background(.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg))
                    .transition(.scale.combined(with: .opacity))
                }

                Text(locale.starsEarnedLabel(starsEarned))
                    .font(AppTheme.Fonts.childBody)
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()

                Button(action: onDismiss) {
                    Text(locale.done)
                        .font(AppTheme.Fonts.childBody)
                        .foregroundStyle(AppTheme.Colors.primary)
                        .padding(.horizontal, AppTheme.Spacing.xl)
                        .padding(.vertical, AppTheme.Spacing.md)
                        .background(.white)
                        .clipShape(Capsule())
                }

                Spacer().frame(height: AppTheme.Spacing.xl)
            }
        }
        .onAppear { startAnimations() }
    }

    private func startAnimations() {
        withAnimation(.spring(duration: 0.5).delay(0.3)) {
            showStars = true
        }
        withAnimation(.spring(duration: 0.5).delay(0.8)) {
            showCollectible = true
        }
        withAnimation(.easeIn(duration: 0.3).delay(0.2)) {
            showConfetti = true
        }
    }
}

// MARK: - Confetti

struct ConfettiView: View {
    let theme: String
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.x, y: particle.y)
                        .opacity(particle.opacity)
                }
            }
            .onAppear {
                createParticles(in: geo.size)
            }
        }
        .allowsHitTesting(false)
    }

    private func createParticles(in size: CGSize) {
        let colors: [Color] = [
            AppTheme.Colors.accent,
            AppTheme.Colors.primary,
            AppTheme.Colors.secondary,
            .white,
            Color(hex: "FF6B6B"),
            Color(hex: "4ECDC4"),
        ]

        particles = (0..<25).map { i in
            ConfettiParticle(
                id: i,
                x: CGFloat.random(in: 0...size.width),
                y: -CGFloat.random(in: 20...100),
                size: CGFloat.random(in: 6...12),
                color: colors.randomElement() ?? .white,
                opacity: 0
            )
        }

        // Animate particles falling down
        for i in particles.indices {
            let delay = Double(i) * 0.05
            withAnimation(.easeIn(duration: Double.random(in: 1.5...3.0)).delay(delay)) {
                particles[i].y = size.height + 50
                particles[i].x += CGFloat.random(in: -80...80)
                particles[i].opacity = 1
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id: Int
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var color: Color
    var opacity: Double
}
