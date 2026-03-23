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

    @State private var challenges: [EducationalChallenge] = []
    @State private var currentIndex = 0
    @State private var targets: [FootballTarget] = []
    @State private var ballPosition: CGPoint = .zero
    @State private var isBallFlying = false
    @State private var flyTarget: CGPoint? = nil
    @State private var feedback: String? = nil
    @State private var letterIndex = 0 // For word spelling: which letter we're on
    @State private var timerRunning = false
    @State private var spelledSoFar = ""

    private var currentChallenge: EducationalChallenge? {
        guard currentIndex < challenges.count else { return nil }
        return challenges[currentIndex]
    }

    private var fieldColor: Color { GameThemeConfig.fieldColor(for: theme) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Field background
                LinearGradient(
                    colors: [fieldColor, fieldColor.opacity(0.7)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                // Field lines
                fieldLines(in: geo.size)

                VStack(spacing: 0) {
                    // Prompt area
                    promptView
                        .padding(.top, 8)

                    Spacer()

                    // Targets (top half)
                    targetGrid(in: geo.size)

                    Spacer()

                    // Ball (bottom)
                    ballView(in: geo.size)
                        .padding(.bottom, 40)
                }

                // Flying ball animation
                if isBallFlying, let target = flyTarget {
                    Text("⚽")
                        .font(.system(size: 40))
                        .position(target)
                        .transition(.scale)
                }

                // Feedback overlay
                if let feedback {
                    Text(feedback)
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .onAppear { setupGame(size: geo.size) }
        }
    }

    // MARK: - Prompt

    @ViewBuilder
    private var promptView: some View {
        if let challenge = currentChallenge {
            VStack(spacing: 6) {
                if let emoji = challenge.promptEmoji {
                    Text(emoji)
                        .font(.system(size: 48))
                }
                if challenge.correctAnswers.count > 1 {
                    // Word spelling — always show blanks
                    HStack(spacing: 4) {
                        ForEach(Array(challenge.correctAnswers.enumerated()), id: \.offset) { i, letter in
                            Text(i < letterIndex ? letter : "⬜")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(i == letterIndex ? Color.yellow : .white)
                        }
                    }
                    Text(locale == .hebrew ? "בעט באות הנכונה! ⚽" : "Kick the right letter! ⚽")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                } else if !challenge.prompt.isEmpty {
                    Text(challenge.prompt)
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                    Text(locale == .hebrew ? "בעט באות! ⚽" : "Kick the letter! ⚽")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Target Grid

    @ViewBuilder
    private func targetGrid(in size: CGSize) -> some View {
        let columns = min(targets.count, 4)
        let spacing: CGFloat = 12
        let targetWidth = (size.width - CGFloat(columns + 1) * spacing) / CGFloat(columns)

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns), spacing: spacing) {
            ForEach(targets) { target in
                Button {
                    kickToTarget(target)
                } label: {
                    Text(target.character)
                        .font(.system(size: age <= 5 ? 40 : 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: targetWidth, height: targetWidth * 0.75)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(target.hit
                                    ? (target.isCorrect ? Color.green.opacity(0.7) : Color.red.opacity(0.5))
                                    : Color.white.opacity(0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.white.opacity(0.4), lineWidth: 2)
                        )
                }
                .disabled(target.hit || isBallFlying)
                .opacity(target.hit ? 0.5 : 1.0)
                .animation(.spring(response: 0.3), value: target.hit)
            }
        }
        .padding(.horizontal, spacing)
    }

    // MARK: - Ball

    @ViewBuilder
    private func ballView(in size: CGSize) -> some View {
        if !isBallFlying {
            Text("⚽")
                .font(.system(size: 56))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        }
    }

    // MARK: - Field Lines

    @ViewBuilder
    private func fieldLines(in size: CGSize) -> some View {
        // Center circle
        Circle()
            .stroke(.white.opacity(0.15), lineWidth: 2)
            .frame(width: 120, height: 120)
            .position(x: size.width / 2, y: size.height / 2)

        // Center line
        Rectangle()
            .fill(.white.opacity(0.1))
            .frame(height: 2)
            .position(x: size.width / 2, y: size.height / 2)
    }

    // MARK: - Logic

    private func setupGame(size: CGSize) {
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
        spelledSoFar = ""
        loadTargets()
        startTimer()
    }

    private func loadTargets() {
        guard let challenge = currentChallenge else { return }

        // For single-letter/single-answer challenges
        let currentCorrect: String
        if challenge.correctAnswers.count > 1 {
            // Word spelling mode - show the current letter needed + distractors
            currentCorrect = challenge.correctAnswers[letterIndex]
        } else {
            currentCorrect = challenge.correctAnswers[0]
        }

        var options = challenge.distractors.shuffled().prefix(difficulty.distractorCount).map { $0 }
        // Make sure the correct answer is included
        if !options.contains(currentCorrect) {
            if options.count >= difficulty.distractorCount + 1 {
                options[0] = currentCorrect
            } else {
                options.append(currentCorrect)
            }
        }
        options.shuffle()

        targets = options.enumerated().map { i, char in
            FootballTarget(
                id: UUID(),
                character: char,
                isCorrect: char == currentCorrect,
                position: .zero
            )
        }
    }

    private func kickToTarget(_ target: FootballTarget) {
        guard !isBallFlying else { return }

        isBallFlying = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Mark target as hit
        if let idx = targets.firstIndex(where: { $0.id == target.id }) {
            withAnimation(.spring(response: 0.3)) {
                targets[idx].hit = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isBallFlying = false

            if target.isCorrect {
                handleCorrectHit()
            } else {
                handleWrongHit()
            }
        }
    }

    private func handleCorrectHit() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        guard let challenge = currentChallenge else { return }

        if challenge.correctAnswers.count > 1 {
            // Word mode: advance to next letter
            letterIndex += 1
            if letterIndex >= challenge.correctAnswers.count {
                // Word complete!
                score += 1
                showFeedback("⚽ גול!")
                advanceChallenge()
            } else {
                // Load new targets for the next letter
                loadTargets()
            }
        } else {
            // Single answer mode
            score += 1
            showFeedback("⚽")
            advanceChallenge()
        }
    }

    private func handleWrongHit() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        showFeedback("✖️")

        // Reload targets (give another chance for this challenge)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            loadTargets()
        }
    }

    private func advanceChallenge() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            currentIndex += 1
            letterIndex = 0
            spelledSoFar = ""
            if currentIndex >= challenges.count {
                onTimeUp()
            } else {
                loadTargets()
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
