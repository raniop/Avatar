import SwiftUI

struct FootballKickGameView: View {
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
    @State private var targets: [FootballTarget] = []
    @State private var timerRunning = false
    @State private var feedback: String? = nil

    // MARK: - Animation State

    @State private var goalkeeperX: CGFloat = 0      // -1 (left) to 1 (right)
    @State private var ballFlying = false
    @State private var ballTargetIndex: Int? = nil    // which target the ball is flying toward
    @State private var ballScale: CGFloat = 1.0
    @State private var ballY: CGFloat = 0             // 0 = resting, 1 = at goal
    @State private var goalkeeperDiveX: CGFloat = 0   // dive direction on kick
    @State private var goalCelebration = false
    @State private var netShake = false

    private var currentChallenge: EducationalChallenge? {
        guard currentIndex < challenges.count else { return nil }
        return challenges[currentIndex]
    }

    private var fieldColor: Color { GameThemeConfig.fieldColor(for: theme) }

    var body: some View {
        GeometryReader { geo in
            let goalWidth = geo.size.width * 0.85
            let goalHeight = geo.size.height * 0.28
            let goalY = geo.size.height * 0.18

            ZStack {
                // Field background
                fieldBackground(in: geo.size)

                // Goal + targets + goalkeeper
                VStack(spacing: 0) {
                    // Prompt area
                    promptView
                        .padding(.top, 4)

                    // Goal area
                    ZStack {
                        // Net background
                        netView(width: goalWidth, height: goalHeight)
                            .scaleEffect(netShake ? 1.05 : 1.0)

                        // Letter targets inside goal
                        targetGrid(width: goalWidth, height: goalHeight)

                        // Goal posts (frame)
                        goalFrame(width: goalWidth, height: goalHeight)

                        // Goalkeeper
                        goalkeeperView(goalWidth: goalWidth, goalHeight: goalHeight)
                    }
                    .frame(width: goalWidth, height: goalHeight + 30)
                    .padding(.top, 8)

                    Spacer()

                    // Ball
                    ballView(in: geo.size, goalY: goalY, goalHeight: goalHeight)

                    Spacer().frame(height: 30)
                }

                // Feedback overlay
                if let feedback {
                    feedbackOverlay(feedback)
                }

                // Goal celebration particles
                if goalCelebration {
                    goalCelebrationView(in: geo.size)
                }
            }
            .onAppear { setupGame() }
        }
    }

    // MARK: - Field Background

    @ViewBuilder
    private func fieldBackground(in size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [fieldColor.opacity(0.9), fieldColor],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Penalty box lines
            let boxWidth = size.width * 0.7
            let boxHeight = size.height * 0.35
            Rectangle()
                .stroke(.white.opacity(0.12), lineWidth: 2)
                .frame(width: boxWidth, height: boxHeight)
                .position(x: size.width / 2, y: boxHeight / 2 + 60)

            // Penalty spot
            Circle()
                .fill(.white.opacity(0.2))
                .frame(width: 8, height: 8)
                .position(x: size.width / 2, y: size.height * 0.65)

            // Penalty arc
            Arc(startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                .stroke(.white.opacity(0.1), lineWidth: 2)
                .frame(width: 100, height: 40)
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
                        .font(.system(size: 40))
                }
                if challenge.correctAnswers.count > 1 {
                    // Word spelling — show blanks
                    HStack(spacing: 3) {
                        ForEach(Array(challenge.correctAnswers.enumerated()), id: \.offset) { i, letter in
                            Text(i < letterIndex ? letter : "⬜")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(i == letterIndex ? Color.yellow : .white)
                        }
                    }
                } else if !challenge.prompt.isEmpty {
                    Text(challenge.prompt)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                }
                Text(locale == .hebrew ? "בעט לאות הנכונה!" : "Kick to the right letter!")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.black.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Goal Frame

    @ViewBuilder
    private func goalFrame(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Top bar (crossbar)
            Rectangle()
                .fill(.white)
                .frame(width: width + 8, height: 6)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                .offset(y: -height / 2)

            // Left post
            Rectangle()
                .fill(.white)
                .frame(width: 6, height: height)
                .shadow(color: .black.opacity(0.3), radius: 2, x: -1)
                .offset(x: -width / 2)

            // Right post
            Rectangle()
                .fill(.white)
                .frame(width: 6, height: height)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 1)
                .offset(x: width / 2)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Net

    @ViewBuilder
    private func netView(width: CGFloat, height: CGFloat) -> some View {
        // Net pattern (grid of thin lines)
        Canvas { context, size in
            let spacing: CGFloat = 14
            let cols = Int(size.width / spacing)
            let rows = Int(size.height / spacing)

            for col in 0...cols {
                let x = CGFloat(col) * spacing
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.white.opacity(0.08)), lineWidth: 1)
            }
            for row in 0...rows {
                let y = CGFloat(row) * spacing
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.white.opacity(0.08)), lineWidth: 1)
            }
        }
        .frame(width: width, height: height)
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Target Grid (inside goal)

    @ViewBuilder
    private func targetGrid(width: CGFloat, height: CGFloat) -> some View {
        let columns = targets.count <= 4 ? 2 : 3
        let rows = (targets.count + columns - 1) / columns
        let padding: CGFloat = 8
        let spacing: CGFloat = 8
        let cellW = (width - padding * 2 - CGFloat(columns - 1) * spacing) / CGFloat(columns)
        let cellH = min(cellW * 0.7, (height - 40 - padding * 2 - CGFloat(rows - 1) * spacing) / CGFloat(rows))

        VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { col in
                        let idx = row * columns + col
                        if idx < targets.count {
                            targetButton(targets[idx], width: cellW, height: cellH)
                        }
                    }
                }
            }
        }
        .padding(padding)
        .offset(y: -10) // Move targets up inside goal
    }

    @ViewBuilder
    private func targetButton(_ target: FootballTarget, width: CGFloat, height: CGFloat) -> some View {
        Button {
            kickToTarget(target)
        } label: {
            Text(target.character)
                .font(.system(size: age <= 5 ? 36 : 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: width, height: height)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(targetColor(target))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.white.opacity(0.5), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
        }
        .disabled(target.hit || ballFlying)
        .scaleEffect(target.hit && target.isCorrect ? 1.15 : 1.0)
        .opacity(target.hit && !target.isCorrect ? 0.4 : 1.0)
        .animation(.spring(response: 0.3), value: target.hit)
    }

    private func targetColor(_ target: FootballTarget) -> Color {
        if target.hit {
            return target.isCorrect ? Color.green.opacity(0.8) : Color.red.opacity(0.6)
        }
        return Color.white.opacity(0.2)
    }

    // MARK: - Goalkeeper

    @ViewBuilder
    private func goalkeeperView(goalWidth: CGFloat, goalHeight: CGFloat) -> some View {
        let moveRange = goalWidth * 0.3
        let xOffset = ballFlying ? goalkeeperDiveX * moveRange * 1.5 : goalkeeperX * moveRange

        Text("🧤")
            .font(.system(size: 44))
            .offset(x: xOffset, y: goalHeight / 2 - 10)
            .animation(
                ballFlying
                    ? .easeOut(duration: 0.25)
                    : .easeInOut(duration: 1.2),
                value: ballFlying ? goalkeeperDiveX : goalkeeperX
            )
            .onAppear { startGoalkeeperSway() }
            .allowsHitTesting(false)
    }

    // MARK: - Ball

    @ViewBuilder
    private func ballView(in size: CGSize, goalY: CGFloat, goalHeight: CGFloat) -> some View {
        let restingY = size.height * 0.75

        Text("⚽")
            .font(.system(size: ballFlying ? 28 : 52))
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            .offset(y: ballFlying ? -(restingY - goalY - goalHeight * 0.3) : 0)
            .scaleEffect(ballFlying ? 0.5 : 1.0)
            .opacity(ballFlying ? 0.0 : 1.0)
            .animation(.easeOut(duration: 0.35), value: ballFlying)
    }

    // MARK: - Feedback

    @ViewBuilder
    private func feedbackOverlay(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 64, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 8)
            .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Goal Celebration

    @ViewBuilder
    private func goalCelebrationView(in size: CGSize) -> some View {
        ForEach(0..<8, id: \.self) { i in
            Text(["⚽", "🎉", "⭐", "🔥", "💥", "✨", "🏆", "👏"][i])
                .font(.system(size: CGFloat.random(in: 20...36)))
                .offset(
                    x: CGFloat.random(in: -size.width/2 + 30...size.width/2 - 30),
                    y: CGFloat.random(in: -size.height/3...0)
                )
                .opacity(goalCelebration ? 0 : 1)
                .animation(
                    .easeOut(duration: Double.random(in: 0.6...1.2))
                    .delay(Double(i) * 0.05),
                    value: goalCelebration
                )
        }
        .allowsHitTesting(false)
    }

    // MARK: - Goalkeeper Sway

    private func startGoalkeeperSway() {
        let interval = max(1.0, 2.0 / difficulty.speed)
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            guard !ballFlying, timerRunning else {
                if !timerRunning { timer.invalidate() }
                return
            }
            withAnimation {
                goalkeeperX = CGFloat.random(in: -1...1)
            }
        }
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
        loadTargets()
        startTimer()
    }

    private func loadTargets() {
        guard let challenge = currentChallenge else { return }

        let currentCorrect: String
        if challenge.correctAnswers.count > 1 {
            currentCorrect = challenge.correctAnswers[letterIndex]
        } else {
            currentCorrect = challenge.correctAnswers[0]
        }

        var options = challenge.distractors.shuffled().prefix(difficulty.distractorCount).map { $0 }
        if !options.contains(currentCorrect) {
            if options.count >= difficulty.distractorCount + 1 {
                options[0] = currentCorrect
            } else {
                options.append(currentCorrect)
            }
        }
        options.shuffle()

        targets = options.map { char in
            FootballTarget(
                id: UUID(),
                character: char,
                isCorrect: char == currentCorrect,
                position: .zero
            )
        }
    }

    private func kickToTarget(_ target: FootballTarget) {
        guard !ballFlying else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Determine goalkeeper dive direction (opposite of ball for correct, toward for wrong)
        let targetIdx = targets.firstIndex(where: { $0.id == target.id }) ?? 0
        let columns = targets.count <= 4 ? 2 : 3
        let targetCol = targetIdx % columns
        let targetSide: CGFloat = targetCol < columns / 2 ? -1 : 1 // left or right

        if target.isCorrect {
            // Goalkeeper dives WRONG way
            goalkeeperDiveX = -targetSide
        } else {
            // Goalkeeper dives TOWARD ball (catches it)
            goalkeeperDiveX = targetSide
        }

        ballFlying = true

        // Mark target after ball arrives
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if let idx = targets.firstIndex(where: { $0.id == target.id }) {
                withAnimation(.spring(response: 0.3)) {
                    targets[idx].hit = true
                }
            }

            if target.isCorrect {
                handleGoal()
            } else {
                handleSave()
            }
        }
    }

    private func handleGoal() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Net shake
        withAnimation(.spring(response: 0.15, dampingFraction: 0.3)) {
            netShake = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            netShake = false
        }

        // Celebration
        goalCelebration = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            goalCelebration = true
        }

        guard let challenge = currentChallenge else { return }

        if challenge.correctAnswers.count > 1 {
            letterIndex += 1
            if letterIndex >= challenge.correctAnswers.count {
                score += 1
                showFeedback("⚽ גול!")
                advanceChallenge()
            } else {
                showFeedback("👍")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    ballFlying = false
                    goalkeeperDiveX = 0
                    loadTargets()
                }
            }
        } else {
            score += 1
            showFeedback("⚽ גול!")
            advanceChallenge()
        }
    }

    private func handleSave() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        showFeedback("🧤")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            ballFlying = false
            goalkeeperDiveX = 0
            loadTargets()
        }
    }

    private func advanceChallenge() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            ballFlying = false
            goalkeeperDiveX = 0
            goalCelebration = false
            currentIndex += 1
            letterIndex = 0
            if currentIndex >= challenges.count {
                onTimeUp()
            } else {
                loadTargets()
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

// MARK: - Arc Shape

private struct Arc: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let clockwise: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: rect.width / 2,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: clockwise
        )
        return path
    }
}
