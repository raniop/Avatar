import SwiftUI

/// Wraps any mini-game with a consistent HUD (round, timer, score) and manages
/// the countdown → game → score screen flow.
struct MiniGameContainerView: View {
    let gameType: MiniGameType
    let theme: String
    let round: Int
    let age: Int
    let locale: AppLocale
    let onComplete: (GameResult) -> Void

    @State private var phase: GamePhase = .countdown
    @State private var countdownValue = 3
    @State private var score = 0
    @State private var totalItems = 0
    @State private var timeRemaining: Int = 0
    @State private var timerActive = false

    private var difficulty: GameDifficulty {
        GameThemeConfig.difficulty(for: age, round: round)
    }

    enum GamePhase {
        case countdown
        case playing
        case scoreScreen
    }

    var body: some View {
        ZStack {
            // Dark background for ALL phases
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            switch phase {
            case .countdown:
                CountdownView(value: countdownValue, round: round, gameType: gameType, locale: locale)

            case .playing:
                VStack(spacing: 0) {
                    // HUD
                    GameHUD(
                        round: round,
                        timeRemaining: timeRemaining,
                        score: score,
                        starThreshold: difficulty.starThreshold,
                        locale: locale
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // The actual game
                    gameView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

            case .scoreScreen:
                GameScoreView(
                    score: score,
                    total: totalItems,
                    starThreshold: difficulty.starThreshold,
                    earnedStar: score >= difficulty.starThreshold,
                    round: round,
                    locale: locale,
                    onContinue: {
                        let result = GameResult(
                            round: round,
                            score: score,
                            total: totalItems,
                            earnedStar: score >= difficulty.starThreshold
                        )
                        onComplete(result)
                    }
                )
            }
        }
        .onAppear { startCountdown() }
    }

    @ViewBuilder
    private var gameView: some View {
        switch gameType {
        case .footballKick:
            FootballKickGameView(
                theme: theme,
                difficulty: difficulty,
                locale: locale,
                age: age,
                score: $score,
                totalItems: $totalItems,
                timeRemaining: $timeRemaining,
                onTimeUp: { endGame() }
            )
        case .basketballShoot:
            BasketballShootGameView(
                theme: theme,
                difficulty: difficulty,
                locale: locale,
                age: age,
                score: $score,
                totalItems: $totalItems,
                timeRemaining: $timeRemaining,
                onTimeUp: { endGame() }
            )
        case .carRace:
            CarRaceGameView(
                theme: theme,
                difficulty: difficulty,
                locale: locale,
                age: age,
                score: $score,
                totalItems: $totalItems,
                timeRemaining: $timeRemaining,
                onTimeUp: { endGame() }
            )
        case .simonPattern:
            SimonPatternGameView(
                theme: theme,
                difficulty: difficulty,
                score: $score,
                totalItems: $totalItems,
                onGameOver: { endGame() }
            )
        }
    }

    private func startCountdown() {
        countdownValue = 3
        timeRemaining = difficulty.timeLimit

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdownValue > 1 {
                withAnimation(.spring(response: 0.3)) {
                    countdownValue -= 1
                }
            } else {
                timer.invalidate()
                withAnimation(.easeInOut(duration: 0.3)) {
                    phase = .playing
                }
            }
        }
    }

    private func endGame() {
        timerActive = false
        withAnimation(.easeInOut(duration: 0.3)) {
            phase = .scoreScreen
        }
    }
}

// MARK: - Countdown

struct CountdownView: View {
    let value: Int
    let round: Int
    let gameType: MiniGameType
    let locale: AppLocale

    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0
    @State private var emojiScale: CGFloat = 0.5
    @State private var glowOpacity: Double = 0

    private var gameEmoji: String {
        switch gameType {
        case .footballKick: return "⚽"
        case .basketballShoot: return "🏀"
        case .carRace: return "🏎️"
        case .simonPattern: return "🎵"
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Game emoji
            Text(gameEmoji)
                .font(.system(size: 60))
                .scaleEffect(emojiScale)

            // Round label
            Text(locale.gameRoundLabel(round, 3))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            // Big number with glow
            ZStack {
                // Glow
                Text("\(value)")
                    .font(.system(size: 140, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "FDCB6E"))
                    .blur(radius: 20)
                    .opacity(glowOpacity)

                // Number
                Text("\(value)")
                    .font(.system(size: 140, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: Color(hex: "FDCB6E").opacity(0.6), radius: 10)
            }
            .scaleEffect(scale)
            .opacity(opacity)

            // Get ready text
            Text("🎮")
                .font(.system(size: 28))
                .opacity(0.6)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                scale = 1.1
                opacity = 1
                emojiScale = 1.0
                glowOpacity = 0.5
            }
        }
        .onChange(of: value) { _, _ in
            scale = 0.3
            opacity = 0
            glowOpacity = 0
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                scale = 1.1
                opacity = 1
                glowOpacity = 0.5
            }
        }
    }
}

// MARK: - Game HUD

struct GameHUD: View {
    let round: Int
    let timeRemaining: Int
    let score: Int
    let starThreshold: Int
    let locale: AppLocale

    var body: some View {
        HStack {
            // Round
            Text(locale.gameRoundLabel(round, 3))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.white.opacity(0.2))
                .clipShape(Capsule())

            Spacer()

            // Timer
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .font(.system(size: 12))
                Text(locale.gameTimerLabel(timeRemaining))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundStyle(timeRemaining <= 5 ? Color(hex: "FF6B6B") : .white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.white.opacity(0.2))
            .clipShape(Capsule())

            Spacer()

            // Score
            HStack(spacing: 4) {
                Text("⭐")
                    .font(.system(size: 12))
                Text(locale.gameScoreLabel(score, starThreshold))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(score >= starThreshold ? Color(hex: "FDCB6E") : .white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.white.opacity(0.2))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Game Score View

struct GameScoreView: View {
    let score: Int
    let total: Int
    let starThreshold: Int
    let earnedStar: Bool
    let round: Int
    let locale: AppLocale
    let onContinue: () -> Void

    @State private var showStar = false
    @State private var showScore = false
    @State private var starScale: CGFloat = 0.3

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if showStar && earnedStar {
                Text("⭐")
                    .font(.system(size: 100))
                    .scaleEffect(starScale)
                    .transition(.scale.combined(with: .opacity))
            }

            if showScore {
                VStack(spacing: 12) {
                    Text(earnedStar ? "🎉" : "💪")
                        .font(.system(size: 48))

                    Text("\(score) / \(total)")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.3), radius: 8)
                }
                .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            Button(action: onContinue) {
                Text(round < 3 ? "\(locale.gameNextRound) ▶" : "\(locale.gameContinue) ▶")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.primary)
                    .padding(.horizontal, 44)
                    .padding(.vertical, 16)
                    .background(.white)
                    .clipShape(Capsule())
                    .shadow(color: .white.opacity(0.3), radius: 8)
            }
            .padding(.bottom, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(duration: 0.5).delay(0.2)) { showScore = true }
            withAnimation(.spring(duration: 0.6, bounce: 0.4).delay(0.5)) {
                showStar = true
                starScale = 1.0
            }
        }
    }
}
