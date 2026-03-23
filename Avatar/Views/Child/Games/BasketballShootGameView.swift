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

    // MARK: - Game State

    @State private var challenges: [EducationalChallenge] = []
    @State private var currentIndex = 0
    @State private var letterIndex = 0
    @State private var hoops: [BasketballHoop] = []
    @State private var timerRunning = false
    @State private var feedback: String? = nil

    // MARK: - Animation State

    @State private var ballShooting = false
    @State private var ballTargetX: CGFloat = 0
    @State private var ballArcPhase: CGFloat = 0     // 0→1 for arc animation
    @State private var scoredHoopId: UUID? = nil
    @State private var missedHoopId: UUID? = nil
    @State private var showSwoosh = false
    @State private var ballBounceAngle: CGFloat = 0

    private var currentChallenge: EducationalChallenge? {
        guard currentIndex < challenges.count else { return nil }
        return challenges[currentIndex]
    }

    private var courtColor: Color { GameThemeConfig.courtColor(for: theme) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Court background
                courtBackground(in: geo.size)

                VStack(spacing: 0) {
                    // Prompt
                    promptView
                        .padding(.top, 4)

                    // Hoops area — multiple hoops with letters
                    hoopsArea(in: geo.size)
                        .padding(.top, 12)

                    Spacer()

                    // Ball at bottom
                    ballView(in: geo.size)

                    Spacer().frame(height: 24)
                }

                // Swoosh effect
                if showSwoosh {
                    swooshEffect(in: geo.size)
                }

                // Feedback overlay
                if let feedback {
                    Text(feedback)
                        .font(.system(size: 60, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .onAppear { setupGame() }
        }
    }

    // MARK: - Court Background

    @ViewBuilder
    private func courtBackground(in size: CGSize) -> some View {
        ZStack {
            // Main court gradient
            LinearGradient(
                colors: [courtColor, courtColor.opacity(0.6)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Court floor (wooden look at bottom half)
            VStack {
                Spacer()
                LinearGradient(
                    colors: [Color(hex: "8D6E63").opacity(0.3), Color(hex: "5D4037").opacity(0.4)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: size.height * 0.45)
            }
            .ignoresSafeArea()

            // Three-point arc
            HalfCircleArc()
                .stroke(.white.opacity(0.12), lineWidth: 2)
                .frame(width: size.width * 0.75, height: size.height * 0.25)
                .position(x: size.width / 2, y: size.height * 0.58)

            // Free throw line
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(width: size.width * 0.5, height: 2)
                .position(x: size.width / 2, y: size.height * 0.55)
        }
    }

    // MARK: - Prompt

    @ViewBuilder
    private var promptView: some View {
        if let challenge = currentChallenge {
            VStack(spacing: 4) {
                if let emoji = challenge.promptEmoji {
                    Text(emoji)
                        .font(.system(size: 36))
                }
                if challenge.correctAnswers.count > 1 {
                    HStack(spacing: 3) {
                        ForEach(Array(challenge.correctAnswers.enumerated()), id: \.offset) { i, letter in
                            Text(i < letterIndex ? letter : "⬜")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(i == letterIndex ? Color.yellow : .white)
                        }
                    }
                } else if !challenge.prompt.isEmpty {
                    Text(challenge.prompt)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                }
                Text(locale == .hebrew ? "זרוק לסל הנכון!" : "Shoot the right hoop!")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.black.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Hoops Area

    @ViewBuilder
    private func hoopsArea(in size: CGSize) -> some View {
        let columns = hoops.count <= 3 ? hoops.count : (hoops.count <= 4 ? 2 : 3)
        let rows = (hoops.count + columns - 1) / columns
        let spacing: CGFloat = 16
        let hoopWidth = min(110, (size.width - spacing * CGFloat(columns + 1)) / CGFloat(columns))

        VStack(spacing: spacing + 10) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { col in
                        let idx = row * columns + col
                        if idx < hoops.count {
                            hoopView(hoops[idx], width: hoopWidth)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func hoopView(_ hoop: BasketballHoop, width: CGFloat) -> some View {
        let isScored = scoredHoopId == hoop.id
        let isMissed = missedHoopId == hoop.id

        Button {
            shootAtHoop(hoop)
        } label: {
            VStack(spacing: 0) {
                // Backboard with letter
                ZStack {
                    // Backboard
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(isScored ? 0.5 : 0.25))
                        .frame(width: width * 0.85, height: width * 0.55)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(.white.opacity(0.5), lineWidth: 2)
                        )

                    // Letter on backboard
                    Text(hoop.character)
                        .font(.system(size: age <= 5 ? 34 : 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 2)
                }

                // Rim
                Ellipse()
                    .stroke(
                        isScored ? Color.green : (isMissed ? Color.red : Color.orange),
                        lineWidth: 4
                    )
                    .frame(width: width * 0.55, height: 14)
                    .shadow(color: isScored ? .green.opacity(0.5) : .clear, radius: 6)

                // Net (lines hanging down)
                netLines(width: width * 0.5)
                    .frame(height: 20)
            }
            .scaleEffect(isScored ? 1.1 : (isMissed ? 0.95 : 1.0))
            .animation(.spring(response: 0.3), value: isScored)
            .animation(.spring(response: 0.3), value: isMissed)
        }
        .disabled(ballShooting)
    }

    @ViewBuilder
    private func netLines(width: CGFloat) -> some View {
        Canvas { context, size in
            let strings = 5
            let spacing = size.width / CGFloat(strings - 1)
            for i in 0..<strings {
                let x = CGFloat(i) * spacing
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                // Slight curve inward
                let midX = size.width / 2
                let pull = (x - midX) * -0.3
                path.addQuadCurve(
                    to: CGPoint(x: x + pull, y: size.height),
                    control: CGPoint(x: x + pull * 0.5, y: size.height * 0.5)
                )
                context.stroke(path, with: .color(.white.opacity(0.2)), lineWidth: 1)
            }
        }
        .frame(width: width)
    }

    // MARK: - Ball

    @ViewBuilder
    private func ballView(in size: CGSize) -> some View {
        ZStack {
            // Basketball
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "FF8F00"), Color(hex: "E65100")],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 40
                    )
                )
                .frame(width: 56, height: 56)
                .overlay(
                    // Ball lines
                    ZStack {
                        // Horizontal line
                        Rectangle()
                            .fill(.black.opacity(0.15))
                            .frame(height: 2)
                        // Vertical line
                        Rectangle()
                            .fill(.black.opacity(0.15))
                            .frame(width: 2)
                    }
                    .clipShape(Circle())
                )
                .overlay(
                    Circle().stroke(.black.opacity(0.2), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.3), radius: 4, y: 3)
        }
        .scaleEffect(ballShooting ? 0.3 : 1.0)
        .offset(y: ballShooting ? -(size.height * 0.5) : 0)
        .opacity(ballShooting ? 0.0 : 1.0)
        .animation(.easeOut(duration: 0.4), value: ballShooting)
    }

    // MARK: - Swoosh Effect

    @ViewBuilder
    private func swooshEffect(in size: CGSize) -> some View {
        Text("💫")
            .font(.system(size: 44))
            .position(x: size.width / 2, y: size.height * 0.3)
            .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Game Logic

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
        loadHoops()
        startTimer()
    }

    private func loadHoops() {
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

        hoops = options.map { char in
            BasketballHoop(
                id: UUID(),
                character: char,
                isCorrect: char == currentCorrect
            )
        }

        scoredHoopId = nil
        missedHoopId = nil
    }

    private func shootAtHoop(_ hoop: BasketballHoop) {
        guard !ballShooting else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        ballShooting = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if hoop.isCorrect {
                handleScore(hoop)
            } else {
                handleMiss(hoop)
            }
        }
    }

    private func handleScore(_ hoop: BasketballHoop) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        scoredHoopId = hoop.id
        withAnimation(.spring(response: 0.3)) { showSwoosh = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation { showSwoosh = false }
        }

        guard let challenge = currentChallenge else { return }

        if challenge.correctAnswers.count > 1 {
            letterIndex += 1
            if letterIndex >= challenge.correctAnswers.count {
                score += 1
                showFeedback("🏀 סל!")
                advanceChallenge()
            } else {
                showFeedback("👍")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    ballShooting = false
                    loadHoops()
                }
            }
        } else {
            score += 1
            showFeedback("🏀 סל!")
            advanceChallenge()
        }
    }

    private func handleMiss(_ hoop: BasketballHoop) {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        missedHoopId = hoop.id
        showFeedback("🧱")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            ballShooting = false
            missedHoopId = nil
            loadHoops()
        }
    }

    private func advanceChallenge() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            ballShooting = false
            scoredHoopId = nil
            currentIndex += 1
            letterIndex = 0
            if currentIndex >= challenges.count {
                onTimeUp()
            } else {
                loadHoops()
            }
        }
    }

    private func showFeedback(_ text: String) {
        withAnimation(.spring(response: 0.3)) { feedback = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
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

// MARK: - Basketball Hoop Model

struct BasketballHoop: Identifiable {
    let id: UUID
    let character: String
    let isCorrect: Bool
}

// MARK: - Half Circle Arc Shape

private struct HalfCircleArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: 0),
            radius: rect.width / 2,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )
        return path
    }
}
