import SwiftUI

/// Wraps any mini-game with a consistent HUD (round, timer, score) and manages
/// the countdown → game → score screen flow.
struct MiniGameContainerView: View {
    let gameType: MiniGameType
    let theme: String
    let round: Int
    let age: Int
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
            switch phase {
            case .countdown:
                CountdownView(value: countdownValue, round: round)

            case .playing:
                VStack(spacing: 0) {
                    // HUD
                    GameHUD(
                        round: round,
                        timeRemaining: timeRemaining,
                        score: score,
                        starThreshold: difficulty.starThreshold
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
        case .catchGame:
            CatchGameView(
                theme: theme,
                difficulty: difficulty,
                score: $score,
                totalItems: $totalItems,
                timeRemaining: $timeRemaining,
                onTimeUp: { endGame() }
            )
        case .matchGame:
            MatchGameView(
                theme: theme,
                difficulty: difficulty,
                score: $score,
                totalItems: $totalItems,
                timeRemaining: $timeRemaining,
                onTimeUp: { endGame() },
                onAllMatched: { endGame() }
            )
        case .sortGame:
            SortGameView(
                theme: theme,
                difficulty: difficulty,
                score: $score,
                totalItems: $totalItems,
                timeRemaining: $timeRemaining,
                onTimeUp: { endGame() },
                onAllSorted: { endGame() }
            )
        case .sequenceGame:
            SequenceGameView(
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

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("Round \(round)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))

            Text("\(value)")
                .font(.system(size: 100, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.2
                opacity = 1
            }
        }
        .onChange(of: value) { _, _ in
            scale = 0.5
            opacity = 0
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.2
                opacity = 1
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

    var body: some View {
        HStack {
            // Round
            Text("Round \(round)/3")
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
                Text("\(timeRemaining)s")
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
                Text("\(score)/\(starThreshold)")
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
    let onContinue: () -> Void

    @State private var showStar = false
    @State private var showScore = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if showStar && earnedStar {
                Text("⭐")
                    .font(.system(size: 80))
                    .transition(.scale.combined(with: .opacity))
            }

            if showScore {
                VStack(spacing: 8) {
                    Text(earnedStar ? "!" : "...")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("\(score) / \(total)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            Button(action: onContinue) {
                Text(round < 3 ? "Next Round" : "Continue")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.primary)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(.white)
                    .clipShape(Capsule())
            }
            .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5).delay(0.2)) { showScore = true }
            withAnimation(.spring(duration: 0.5).delay(0.5)) { showStar = true }
        }
    }
}
