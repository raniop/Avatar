import SwiftUI

struct BasketballShootGameView: View {
    let theme: String
    let difficulty: GameDifficulty
    let locale: AppLocale
    let age: Int
    @Binding var score: Int
    @Binding var totalItems: Int
    @Binding var timeRemaining: Int
    let onTimeUp: () -> Void

    @State private var challenges: [EducationalChallenge] = []
    @State private var currentIndex = 0
    @State private var letterIndex = 0
    @State private var balls: [LetterBall] = []
    @State private var feedback: String? = nil
    @State private var hoopScale: CGFloat = 1.0
    @State private var timerRunning = false
    @State private var shootingBallId: UUID? = nil

    private var currentChallenge: EducationalChallenge? {
        guard currentIndex < challenges.count else { return nil }
        return challenges[currentIndex]
    }

    private var courtColor: Color { GameThemeConfig.courtColor(for: theme) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Court background
                LinearGradient(
                    colors: [courtColor, courtColor.opacity(0.6)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                // Court lines
                courtLines(in: geo.size)

                VStack(spacing: 0) {
                    // Hoop area
                    hoopView
                        .padding(.top, 16)

                    // Prompt
                    promptView
                        .padding(.top, 12)

                    Spacer()

                    // Balls
                    ballsView
                        .padding(.bottom, 50)
                }

                // Feedback overlay
                if let feedback {
                    Text(feedback)
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .onAppear { setupGame() }
        }
    }

    // MARK: - Hoop

    @ViewBuilder
    private var hoopView: some View {
        VStack(spacing: 2) {
            // Backboard
            RoundedRectangle(cornerRadius: 4)
                .fill(.white.opacity(0.3))
                .frame(width: 80, height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.white.opacity(0.6), lineWidth: 2)
                )

            // Rim
            Ellipse()
                .stroke(Color.orange, lineWidth: 4)
                .frame(width: 60, height: 16)

            // Net
            Text("🥅")
                .font(.system(size: 20))
                .opacity(0.5)
        }
        .scaleEffect(hoopScale)
        .animation(.spring(response: 0.3), value: hoopScale)
    }

    // MARK: - Prompt

    @ViewBuilder
    private var promptView: some View {
        if let challenge = currentChallenge {
            VStack(spacing: 6) {
                if let emoji = challenge.promptEmoji {
                    Text(emoji)
                        .font(.system(size: 40))
                }
                if challenge.correctAnswers.count > 1 {
                    // Word spelling
                    HStack(spacing: 4) {
                        ForEach(Array(challenge.correctAnswers.enumerated()), id: \.offset) { i, letter in
                            Text(i < letterIndex ? letter : "⬜")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(i == letterIndex ? Color.yellow : .white)
                        }
                    }
                    Text(locale == .hebrew ? "זרוק את האות הנכונה! 🏀" : "Shoot the right letter! 🏀")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                } else if !challenge.prompt.isEmpty {
                    Text(challenge.prompt)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(locale == .hebrew ? "זרוק את האות! 🏀" : "Shoot the letter! 🏀")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Balls

    @ViewBuilder
    private var ballsView: some View {
        let columns = min(balls.count, 4)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columns), spacing: 12) {
            ForEach(balls) { ball in
                Button {
                    shootBall(ball)
                } label: {
                    ZStack {
                        // Basketball
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.orange, Color(hex: "E65100")],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 35
                                )
                            )
                            .frame(width: 70, height: 70)
                            .overlay(
                                Circle()
                                    .stroke(.black.opacity(0.3), lineWidth: 2)
                            )

                        // Letter on ball
                        Text(ball.character)
                            .font(.system(size: age <= 5 ? 32 : 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2)
                    }
                }
                .disabled(ball.thrown || shootingBallId != nil)
                .opacity(ball.thrown ? 0.3 : 1.0)
                .scaleEffect(ball.thrown ? 0.5 : 1.0)
                .offset(y: shootingBallId == ball.id ? -200 : 0)
                .animation(.spring(response: 0.4), value: ball.thrown)
                .animation(.easeOut(duration: 0.3), value: shootingBallId)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Court Lines

    @ViewBuilder
    private func courtLines(in size: CGSize) -> some View {
        // Free-throw semicircle
        Circle()
            .stroke(.white.opacity(0.1), lineWidth: 2)
            .frame(width: 160, height: 160)
            .position(x: size.width / 2, y: size.height * 0.3)
    }

    // MARK: - Logic

    private func setupGame() {
        let contentType = EducationalContent.defaultContentType(locale: locale, age: age)
        challenges = EducationalContent.generate(
            locale: locale,
            age: age,
            contentType: contentType,
            count: difficulty.itemCount
        )
        totalItems = challenges.count
        score = 0
        currentIndex = 0
        letterIndex = 0
        loadBalls()
        startTimer()
    }

    private func loadBalls() {
        guard let challenge = currentChallenge else { return }

        let currentCorrect: String
        if challenge.correctAnswers.count > 1 {
            currentCorrect = challenge.correctAnswers[letterIndex]
        } else {
            currentCorrect = challenge.correctAnswers[0]
        }

        var options = challenge.distractors.shuffled().prefix(difficulty.distractorCount).map { $0 }
        if !options.contains(currentCorrect) {
            options.append(currentCorrect)
        }
        options.shuffle()

        balls = options.map { char in
            LetterBall(
                id: UUID(),
                character: char,
                isCorrect: char == currentCorrect
            )
        }
    }

    private func shootBall(_ ball: LetterBall) {
        guard shootingBallId == nil else { return }

        shootingBallId = ball.id
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if let idx = balls.firstIndex(where: { $0.id == ball.id }) {
                withAnimation(.spring(response: 0.3)) {
                    balls[idx].thrown = true
                    balls[idx].scored = ball.isCorrect
                }
            }
            shootingBallId = nil

            if ball.isCorrect {
                handleCorrectShot()
            } else {
                handleWrongShot()
            }
        }
    }

    private func handleCorrectShot() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.2)) { hoopScale = 1.2 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.2)) { hoopScale = 1.0 }
        }

        guard let challenge = currentChallenge else { return }

        if challenge.correctAnswers.count > 1 {
            letterIndex += 1
            if letterIndex >= challenge.correctAnswers.count {
                score += 1
                showFeedback("🏀")
                advanceChallenge()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    loadBalls()
                }
            }
        } else {
            score += 1
            showFeedback("🏀")
            advanceChallenge()
        }
    }

    private func handleWrongShot() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        showFeedback("✖️")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            loadBalls()
        }
    }

    private func advanceChallenge() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            currentIndex += 1
            letterIndex = 0
            if currentIndex >= challenges.count {
                onTimeUp()
            } else {
                loadBalls()
            }
        }
    }

    private func showFeedback(_ text: String) {
        withAnimation(.spring(response: 0.3)) { feedback = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation { feedback = nil }
        }
    }

    private func startTimer() {
        timerRunning = true
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if timeRemaining > 0 && timerRunning {
                timeRemaining -= 1
            } else {
                timer.invalidate()
                if timerRunning { onTimeUp() }
            }
        }
    }
}
