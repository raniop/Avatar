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

    // MARK: - Game State

    @State private var challenges: [EducationalChallenge] = []
    @State private var currentIndex = 0
    @State private var letterIndex = 0
    @State private var carLane = 1  // 0, 1, 2
    @State private var roadItems: [RoadItem] = []
    @State private var feedback: String? = nil
    @State private var timerRunning = false
    @State private var spawnTimer: Timer? = nil
    @State private var moveTimer: Timer? = nil

    // MARK: - Animation State

    @State private var roadStripeOffset: CGFloat = 0
    @State private var carTilt: Double = 0
    @State private var speedLines = false
    @State private var collectFlash = false

    private let laneCount = 3

    private var currentChallenge: EducationalChallenge? {
        guard currentIndex < challenges.count else { return nil }
        return challenges[currentIndex]
    }

    private var roadColor: Color { GameThemeConfig.roadColor(for: theme) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Scrolling road background
                roadBackground(in: geo.size)

                // Road items (letters coming toward the car)
                ForEach(roadItems) { item in
                    if !item.collected {
                        roadItemView(item, in: geo.size)
                    }
                }

                // Car
                carView(in: geo.size)

                // Prompt (top overlay)
                VStack {
                    promptView
                        .padding(.top, 4)
                    Spacer()
                }

                // Left/Right tap zones
                tapZones(in: geo.size)

                // Collect flash
                if collectFlash {
                    Color.green.opacity(0.15)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                // Feedback
                if let feedback {
                    Text(feedback)
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 8)
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .onAppear { setupGame(size: geo.size) }
            .onDisappear { cleanup() }
        }
    }

    // MARK: - Road Background

    @ViewBuilder
    private func roadBackground(in size: CGSize) -> some View {
        ZStack {
            // Grass/environment on sides
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color(hex: "2E7D32").opacity(0.6))
                    .frame(width: size.width * 0.08)
                Spacer()
                Rectangle()
                    .fill(Color(hex: "2E7D32").opacity(0.6))
                    .frame(width: size.width * 0.08)
            }
            .ignoresSafeArea()

            // Road surface
            Rectangle()
                .fill(roadColor)
                .padding(.horizontal, size.width * 0.08)
                .ignoresSafeArea()

            // Road edge lines (solid white)
            let roadLeft = size.width * 0.08
            let roadRight = size.width * 0.92

            Rectangle()
                .fill(.white.opacity(0.6))
                .frame(width: 3)
                .position(x: roadLeft, y: size.height / 2)
                .frame(height: size.height)

            Rectangle()
                .fill(.white.opacity(0.6))
                .frame(width: 3)
                .position(x: roadRight, y: size.height / 2)
                .frame(height: size.height)

            // Animated lane divider stripes
            let laneWidth = (roadRight - roadLeft) / CGFloat(laneCount)
            ForEach(1..<laneCount, id: \.self) { i in
                let x = roadLeft + laneWidth * CGFloat(i)
                ScrollingDashes(offset: roadStripeOffset)
                    .stroke(.white.opacity(0.4), style: StrokeStyle(lineWidth: 3, dash: [24, 18]))
                    .frame(width: 3, height: size.height)
                    .position(x: x, y: size.height / 2)
            }
        }
    }

    // MARK: - Road Item

    @ViewBuilder
    private func roadItemView(_ item: RoadItem, in size: CGSize) -> some View {
        let roadLeft = size.width * 0.08
        let roadRight = size.width * 0.92
        let laneWidth = (roadRight - roadLeft) / CGFloat(laneCount)
        let x = roadLeft + laneWidth * CGFloat(item.laneIndex) + laneWidth / 2

        // Scale items: smaller at top (far), bigger at bottom (near)
        let progress = item.yOffset / size.height
        let itemScale = 0.5 + progress * 0.6

        ZStack {
            // Glowing circle behind letter
            Circle()
                .fill(
                    item.isCorrect
                        ? Color.green.opacity(0.4)
                        : Color.red.opacity(0.25)
                )
                .frame(width: 54, height: 54)
                .blur(radius: 4)

            // Letter bubble
            Circle()
                .fill(
                    item.isCorrect
                        ? Color.green.opacity(0.7)
                        : Color.white.opacity(0.2)
                )
                .frame(width: 50, height: 50)
                .overlay(
                    Circle().stroke(.white.opacity(0.6), lineWidth: 2)
                )

            Text(item.character)
                .font(.system(size: age <= 5 ? 28 : 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 2)
        }
        .scaleEffect(itemScale)
        .position(x: x, y: item.yOffset)
    }

    // MARK: - Car

    @ViewBuilder
    private func carView(in size: CGSize) -> some View {
        let roadLeft = size.width * 0.08
        let roadRight = size.width * 0.92
        let laneWidth = (roadRight - roadLeft) / CGFloat(laneCount)
        let carX = roadLeft + laneWidth * CGFloat(carLane) + laneWidth / 2

        VStack(spacing: 0) {
            Text("🏎️")
                .font(.system(size: 56))
                .rotationEffect(.degrees(carTilt))
        }
        .shadow(color: .black.opacity(0.4), radius: 6, y: 4)
        .position(x: carX, y: size.height - 90)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: carLane)
        .animation(.spring(response: 0.15), value: carTilt)
    }

    // MARK: - Tap Zones

    @ViewBuilder
    private func tapZones(in size: CGSize) -> some View {
        HStack(spacing: 0) {
            // Left zone
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { steerLeft() }
                .frame(width: size.width / 2)

            // Right zone
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { steerRight() }
                .frame(width: size.width / 2)
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.width > 30 {
                        steerRight()
                    } else if value.translation.width < -30 {
                        steerLeft()
                    }
                }
        )
    }

    // MARK: - Prompt

    @ViewBuilder
    private var promptView: some View {
        if let challenge = currentChallenge {
            VStack(spacing: 3) {
                HStack(spacing: 6) {
                    if let emoji = challenge.promptEmoji {
                        Text(emoji)
                            .font(.system(size: 28))
                    }
                    if challenge.correctAnswers.count > 1 {
                        HStack(spacing: 3) {
                            ForEach(Array(challenge.correctAnswers.enumerated()), id: \.offset) { i, letter in
                                Text(i < letterIndex ? letter : "⬜")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(i == letterIndex ? Color.yellow : .white)
                            }
                        }
                    } else if !challenge.prompt.isEmpty {
                        Text(challenge.prompt)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                Text(locale == .hebrew ? "סע לאות הנכונה! 🏎️" : "Drive to the right letter!")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(.black.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Steering

    private func steerLeft() {
        let newLane = max(carLane - 1, 0)
        guard newLane != carLane else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        carTilt = -8
        carLane = newLane
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { carTilt = 0 }
    }

    private func steerRight() {
        let newLane = min(carLane + 1, laneCount - 1)
        guard newLane != carLane else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        carTilt = 8
        carLane = newLane
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { carTilt = 0 }
    }

    // MARK: - Game Logic

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
        startRoadAnimation()
        startTimer()
    }

    private func startRoadAnimation() {
        // Animate road stripe scrolling
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            guard timerRunning else { timer.invalidate(); return }
            roadStripeOffset += 3 * difficulty.speed
            if roadStripeOffset > 42 { roadStripeOffset = 0 }
        }
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

        // Make sure there's always a correct option on screen
        let hasCorrectOnScreen = roadItems.contains(where: { !$0.collected && $0.isCorrect })
        let isCorrect = !hasCorrectOnScreen || Bool.random()
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
            yOffset: -50
        )
        roadItems.append(item)
    }

    private func startMoving(size: CGSize) {
        let moveSpeed = 2.8 * difficulty.speed
        moveTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            let carY = size.height - 90
            let roadLeft = size.width * 0.08
            let roadRight = size.width * 0.92
            let laneWidth = (roadRight - roadLeft) / CGFloat(laneCount)

            for i in roadItems.indices.reversed() {
                guard i < roadItems.count else { continue }
                if roadItems[i].collected { continue }
                roadItems[i].yOffset += CGFloat(moveSpeed)

                // Check collision with car
                let itemX = roadLeft + laneWidth * CGFloat(roadItems[i].laneIndex) + laneWidth / 2
                let carX = roadLeft + laneWidth * CGFloat(carLane) + laneWidth / 2

                if abs(roadItems[i].yOffset - carY) < 40 && abs(itemX - carX) < laneWidth * 0.6 {
                    roadItems[i].collected = true
                    if roadItems[i].isCorrect {
                        handleCollect()
                    } else {
                        handleWrongCollect()
                    }
                }

                // Remove if off screen
                if roadItems[i].yOffset > size.height + 60 {
                    roadItems.remove(at: i)
                }
            }
        }
    }

    private func handleCollect() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Flash effect
        withAnimation(.easeOut(duration: 0.15)) { collectFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeIn(duration: 0.15)) { collectFlash = false }
        }

        guard let challenge = currentChallenge else { return }

        if challenge.correctAnswers.count > 1 {
            letterIndex += 1
            if letterIndex >= challenge.correctAnswers.count {
                score += 1
                showFeedback("🏎️💨")
                advanceChallenge()
            } else {
                showFeedback("👍")
            }
        } else {
            score += 1
            showFeedback("✅")
            advanceChallenge()
        }
    }

    private func handleWrongCollect() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        showFeedback("💥")
    }

    private func advanceChallenge() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            currentIndex += 1
            letterIndex = 0
            roadItems.removeAll(where: { $0.collected || $0.yOffset > 0 })
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

// MARK: - Scrolling Dashes Shape

private struct ScrollingDashes: Shape {
    var offset: CGFloat

    var animatableData: CGFloat {
        get { offset }
        set { offset = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: -offset))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

// MARK: - Dashed Line Shape (kept for compatibility)

struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: 0))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}
