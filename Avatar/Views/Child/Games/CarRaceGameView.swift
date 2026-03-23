import SwiftUI

struct CarRaceGameView: View {
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
    @State private var carLane = 1  // 0, 1, 2
    @State private var roadItems: [RoadItem] = []
    @State private var feedback: String? = nil
    @State private var timerRunning = false
    @State private var roadOffset: CGFloat = 0
    @State private var spawnTimer: Timer? = nil
    @State private var moveTimer: Timer? = nil

    private let laneCount = 3

    private var currentChallenge: EducationalChallenge? {
        guard currentIndex < challenges.count else { return nil }
        return challenges[currentIndex]
    }

    private var roadColor: Color { GameThemeConfig.roadColor(for: theme) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Road background
                roadBackground(in: geo.size)

                // Road items
                ForEach(roadItems) { item in
                    if !item.collected {
                        let laneWidth = geo.size.width / CGFloat(laneCount)
                        let x = laneWidth * CGFloat(item.laneIndex) + laneWidth / 2

                        ZStack {
                            Circle()
                                .fill(item.isCorrect ? Color.green.opacity(0.3) : Color.white.opacity(0.15))
                                .frame(width: 56, height: 56)
                            Text(item.character)
                                .font(.system(size: age <= 5 ? 32 : 26, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .position(x: x, y: item.yOffset)
                        .transition(.scale)
                    }
                }

                // Car
                let laneWidth = geo.size.width / CGFloat(laneCount)
                let carX = laneWidth * CGFloat(carLane) + laneWidth / 2
                VStack(spacing: 0) {
                    Text("🏎️")
                        .font(.system(size: 52))
                        .scaleEffect(x: locale == .hebrew ? -1 : 1) // flip for RTL
                }
                .position(x: carX, y: geo.size.height - 80)
                .animation(.spring(response: 0.25), value: carLane)

                // Prompt (top)
                VStack {
                    promptView
                        .padding(.top, 4)
                    Spacer()
                }

                // Lane buttons (invisible tap zones)
                HStack(spacing: 0) {
                    ForEach(0..<laneCount, id: \.self) { lane in
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                switchToLane(lane)
                            }
                    }
                }

                // Swipe gesture overlay
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                if value.translation.width > 30 {
                                    switchToLane(min(carLane + 1, laneCount - 1))
                                } else if value.translation.width < -30 {
                                    switchToLane(max(carLane - 1, 0))
                                }
                            }
                    )

                // Feedback
                if let feedback {
                    Text(feedback)
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 8)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .onAppear { setupGame(size: geo.size) }
            .onDisappear { cleanup() }
        }
    }

    // MARK: - Prompt

    @ViewBuilder
    private var promptView: some View {
        if let challenge = currentChallenge {
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    if let emoji = challenge.promptEmoji {
                        Text(emoji)
                            .font(.system(size: 32))
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
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                Text(locale == .hebrew ? "אסוף את האות הנכונה! 🏎️" : "Collect the right letter! 🏎️")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(.black.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Road Background

    @ViewBuilder
    private func roadBackground(in size: CGSize) -> some View {
        ZStack {
            roadColor.ignoresSafeArea()

            // Lane dividers
            let laneWidth = size.width / CGFloat(laneCount)
            ForEach(1..<laneCount, id: \.self) { i in
                DashedLine()
                    .stroke(.white.opacity(0.3), style: StrokeStyle(lineWidth: 3, dash: [20, 15]))
                    .frame(width: 3)
                    .position(x: laneWidth * CGFloat(i), y: size.height / 2)
                    .frame(height: size.height)
            }

            // Road edges
            Rectangle()
                .fill(.white.opacity(0.4))
                .frame(width: 4)
                .position(x: 2, y: size.height / 2)

            Rectangle()
                .fill(.white.opacity(0.4))
                .frame(width: 4)
                .position(x: size.width - 2, y: size.height / 2)
        }
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
        carLane = 1

        startSpawning(size: size)
        startMoving(size: size)
        startTimer()
    }

    private func startSpawning(size: CGSize) {
        spawnNextItem(size: size)

        let interval = max(0.8, 2.0 / difficulty.speed)
        spawnTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            spawnNextItem(size: size)
        }
    }

    private func spawnNextItem(size: CGSize) {
        guard let challenge = currentChallenge else { return }

        let currentCorrect: String
        if challenge.correctAnswers.count > 1 {
            guard letterIndex < challenge.correctAnswers.count else { return }
            currentCorrect = challenge.correctAnswers[letterIndex]
        } else {
            currentCorrect = challenge.correctAnswers[0]
        }

        // Randomly decide: correct or distractor
        let isCorrect = Bool.random() || roadItems.filter({ !$0.collected && $0.isCorrect }).isEmpty
        let character: String
        if isCorrect {
            character = currentCorrect
        } else {
            character = challenge.distractors.randomElement() ?? currentCorrect
        }

        let item = RoadItem(
            id: UUID(),
            character: character,
            isCorrect: character == currentCorrect,
            laneIndex: Int.random(in: 0..<laneCount),
            yOffset: -40
        )
        roadItems.append(item)
    }

    private func startMoving(size: CGSize) {
        let moveSpeed = 2.5 * difficulty.speed
        moveTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            let carY = size.height - 80

            for i in roadItems.indices.reversed() {
                if roadItems[i].collected { continue }
                roadItems[i].yOffset += CGFloat(moveSpeed)

                // Check collision with car
                let laneWidth = size.width / CGFloat(laneCount)
                let itemX = laneWidth * CGFloat(roadItems[i].laneIndex) + laneWidth / 2
                let carX = laneWidth * CGFloat(carLane) + laneWidth / 2

                if abs(roadItems[i].yOffset - carY) < 35 && abs(itemX - carX) < laneWidth * 0.6 {
                    roadItems[i].collected = true
                    if roadItems[i].isCorrect {
                        handleCollect()
                    } else {
                        handleWrongCollect()
                    }
                }

                // Remove if off screen
                if roadItems[i].yOffset > size.height + 50 {
                    roadItems.remove(at: i)
                }
            }
        }
    }

    private func switchToLane(_ lane: Int) {
        guard lane != carLane else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.25)) {
            carLane = lane
        }
    }

    private func handleCollect() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        guard let challenge = currentChallenge else { return }

        if challenge.correctAnswers.count > 1 {
            letterIndex += 1
            if letterIndex >= challenge.correctAnswers.count {
                score += 1
                showFeedback("🏎️💨")
                advanceChallenge()
            }
        } else {
            score += 1
            showFeedback("✅")
            advanceChallenge()
        }
    }

    private func handleWrongCollect() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        showFeedback("✖️")
    }

    private func advanceChallenge() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            currentIndex += 1
            letterIndex = 0
            roadItems.removeAll(where: { !$0.collected })
            if currentIndex >= challenges.count {
                cleanup()
                onTimeUp()
            }
        }
    }

    private func showFeedback(_ text: String) {
        withAnimation(.spring(response: 0.3)) { feedback = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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
                if timerRunning {
                    cleanup()
                    onTimeUp()
                }
            }
        }
    }

    private func cleanup() {
        timerRunning = false
        spawnTimer?.invalidate()
        moveTimer?.invalidate()
        spawnTimer = nil
        moveTimer = nil
    }
}

// MARK: - Dashed Line Shape

struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: 0))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}
