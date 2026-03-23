import SwiftUI
import SpriteKit

// MARK: - SwiftUI Wrapper

struct CarRaceGameView: View {
    let theme: String
    let difficulty: GameDifficulty
    let locale: AppLocale
    let age: Int
    @Binding var score: Int
    @Binding var totalItems: Int
    @Binding var timeRemaining: Int
    let onTimeUp: () -> Void

    @State private var scene: CarRaceScene?
    @State private var challenges: [EducationalChallenge] = []
    @State private var currentIndex = 0
    @State private var letterIndex = 0
    @State private var timerRunning = false
    @State private var feedback: String? = nil

    private var currentChallenge: EducationalChallenge? {
        guard currentIndex < challenges.count else { return nil }
        return challenges[currentIndex]
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let scene {
                    SpriteView(scene: scene)
                        .ignoresSafeArea()
                }

                // HUD overlay
                VStack {
                    promptView
                        .padding(.top, 4)
                    Spacer()
                }

                // Feedback
                if let feedback {
                    Text(feedback)
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 10)
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .onAppear { setupGame(size: geo.size) }
            .onDisappear { timerRunning = false }
        }
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
                Text(locale == .hebrew ? "סע לאות הנכונה!" : "Drive to the right letter!")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(.black.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Setup

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
        timerRunning = true

        let raceScene = CarRaceScene(size: size)
        raceScene.scaleMode = .resizeFill
        raceScene.gameSpeed = difficulty.speed
        raceScene.onCollect = { character, isCorrect in
            handleCollect(character: character, isCorrect: isCorrect)
        }

        // Load first challenge items
        if let ch = challenges.first {
            let correct = ch.correctAnswers.count > 1 ? ch.correctAnswers[0] : ch.correctAnswers[0]
            let distractors = Array(ch.distractors.prefix(difficulty.distractorCount))
            raceScene.pendingCorrect = correct
            raceScene.pendingDistractors = distractors
        }

        self.scene = raceScene
        startTimer()
    }

    private func handleCollect(character: String, isCorrect: Bool) {
        if isCorrect {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            guard let challenge = currentChallenge else { return }

            if challenge.correctAnswers.count > 1 {
                letterIndex += 1
                if letterIndex >= challenge.correctAnswers.count {
                    score += 1
                    showFeedback("🏎️💨")
                    advanceChallenge()
                } else {
                    showFeedback("👍")
                    updateSceneChallenge()
                }
            } else {
                score += 1
                showFeedback("✅")
                advanceChallenge()
            }
        } else {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            showFeedback("💥")
            scene?.shakeCamera()
        }
    }

    private func updateSceneChallenge() {
        guard let challenge = currentChallenge, letterIndex < challenge.correctAnswers.count else { return }
        let correct = challenge.correctAnswers[letterIndex]
        let distractors = Array(challenge.distractors.prefix(difficulty.distractorCount))
        scene?.setChallenge(correct: correct, distractors: distractors)
    }

    private func advanceChallenge() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            currentIndex += 1
            letterIndex = 0
            if currentIndex >= challenges.count {
                timerRunning = false
                onTimeUp()
            } else {
                updateSceneChallenge()
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
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            guard timerRunning else { timer.invalidate(); return }
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer.invalidate()
                timerRunning = false
                onTimeUp()
            }
        }
    }
}

// MARK: - SpriteKit Scene

class CarRaceScene: SKScene {

    // MARK: - Config

    var gameSpeed: Double = 1.0
    var onCollect: ((String, Bool) -> Void)?
    var pendingCorrect: String?
    var pendingDistractors: [String]?

    private var currentCorrect: String = ""
    private var currentDistractors: [String] = []

    // MARK: - Nodes

    private var car: SKNode!
    private var roadNode: SKNode!
    private var cameraNode: SKCameraNode!
    private let laneCount = 3
    private var currentLane = 1
    private var lanePositions: [CGFloat] = []

    // Road scrolling
    private var roadStripes: [SKShapeNode] = []
    private var roadSpeed: CGFloat = 8.0

    // Items
    private var activeItems: [SKNode] = []
    private var spawnInterval: TimeInterval = 1.2
    private var lastSpawnTime: TimeInterval = 0
    private var gameTime: TimeInterval = 0

    // Touch
    private var touchStartX: CGFloat = 0

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = .darkGray
        setupCamera()
        setupRoad()
        setupCar()
        setupSpeedLines()

        roadSpeed = CGFloat(6.0 * gameSpeed)
        spawnInterval = max(0.7, 1.4 / gameSpeed)

        if let correct = pendingCorrect, let distractors = pendingDistractors {
            pendingCorrect = nil; pendingDistractors = nil
            setChallenge(correct: correct, distractors: distractors)
        }
    }

    private func setupCamera() {
        cameraNode = SKCameraNode()
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(cameraNode)
        camera = cameraNode
    }

    private func setupRoad() {
        roadNode = SKNode()
        addChild(roadNode)

        let roadWidth = size.width * 0.84
        let roadLeft = size.width * 0.08
        let laneWidth = roadWidth / CGFloat(laneCount)

        // Calculate lane center positions
        lanePositions = (0..<laneCount).map { i in
            roadLeft + laneWidth * CGFloat(i) + laneWidth / 2
        }

        // Road surface (dark asphalt gradient)
        let roadBg = SKShapeNode(rect: CGRect(x: roadLeft, y: 0, width: roadWidth, height: size.height))
        roadBg.fillColor = UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)
        roadBg.strokeColor = .clear
        roadBg.zPosition = -10
        roadNode.addChild(roadBg)

        // Grass sides
        let leftGrass = SKShapeNode(rect: CGRect(x: 0, y: 0, width: roadLeft, height: size.height))
        leftGrass.fillColor = UIColor(red: 0.18, green: 0.49, blue: 0.2, alpha: 0.7)
        leftGrass.strokeColor = .clear
        leftGrass.zPosition = -10
        roadNode.addChild(leftGrass)

        let rightGrass = SKShapeNode(rect: CGRect(x: size.width - roadLeft, y: 0, width: roadLeft, height: size.height))
        rightGrass.fillColor = UIColor(red: 0.18, green: 0.49, blue: 0.2, alpha: 0.7)
        rightGrass.strokeColor = .clear
        rightGrass.zPosition = -10
        roadNode.addChild(rightGrass)

        // Road edge lines
        for x in [roadLeft, roadLeft + roadWidth] {
            let edge = SKShapeNode(rect: CGRect(x: x - 2, y: 0, width: 4, height: size.height))
            edge.fillColor = .white.withAlphaComponent(0.7)
            edge.strokeColor = .clear
            edge.zPosition = -5
            roadNode.addChild(edge)
        }

        // Dashed lane dividers
        for lane in 1..<laneCount {
            let x = roadLeft + laneWidth * CGFloat(lane)
            for dashY in stride(from: CGFloat(0), to: size.height, by: 50) {
                let dash = SKShapeNode(rect: CGRect(x: x - 1.5, y: dashY, width: 3, height: 28))
                dash.fillColor = .white.withAlphaComponent(0.35)
                dash.strokeColor = .clear
                dash.zPosition = -5
                dash.name = "stripe"
                roadStripes.append(dash)
                roadNode.addChild(dash)
            }
        }
    }

    private func setupCar() {
        car = SKNode()
        car.position = CGPoint(x: lanePositions[currentLane], y: 100)
        car.zPosition = 10

        // Car body
        let carBody = SKShapeNode(rectOf: CGSize(width: 44, height: 70), cornerRadius: 10)
        carBody.fillColor = UIColor(red: 0.9, green: 0.15, blue: 0.15, alpha: 1)
        carBody.strokeColor = UIColor(red: 0.7, green: 0.1, blue: 0.1, alpha: 1)
        carBody.lineWidth = 2
        car.addChild(carBody)

        // Windshield
        let windshield = SKShapeNode(rectOf: CGSize(width: 32, height: 16), cornerRadius: 4)
        windshield.fillColor = UIColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 0.8)
        windshield.strokeColor = .clear
        windshield.position = CGPoint(x: 0, y: 12)
        car.addChild(windshield)

        // Headlights
        for dx: CGFloat in [-16, 16] {
            let light = SKShapeNode(rectOf: CGSize(width: 8, height: 5), cornerRadius: 2)
            light.fillColor = .yellow.withAlphaComponent(0.9)
            light.strokeColor = .clear
            light.position = CGPoint(x: dx, y: 35)
            car.addChild(light)

            // Light glow
            let glow = SKShapeNode(circleOfRadius: 20)
            glow.fillColor = .yellow.withAlphaComponent(0.06)
            glow.strokeColor = .clear
            glow.position = CGPoint(x: dx, y: 50)
            car.addChild(glow)
        }

        // Wheels
        for (dx, dy) in [(-20, -25), (20, -25), (-20, 22), (20, 22)] as [(CGFloat, CGFloat)] {
            let wheel = SKShapeNode(rectOf: CGSize(width: 10, height: 18), cornerRadius: 3)
            wheel.fillColor = UIColor(white: 0.15, alpha: 1)
            wheel.strokeColor = .clear
            wheel.position = CGPoint(x: dx, y: dy)
            wheel.zPosition = -1
            car.addChild(wheel)
        }

        // Exhaust particles
        if let exhaust = SKEmitterNode(fileNamed: "") {
            // We'll create exhaust manually since we can't rely on .sks files
        }
        addExhaustEffect()

        addChild(car)
    }

    private func addExhaustEffect() {
        let exhaust = SKNode()
        exhaust.position = CGPoint(x: 0, y: -40)
        exhaust.name = "exhaust"
        car.addChild(exhaust)

        // Create smoke particles using timer action
        let spawnSmoke = SKAction.run { [weak self] in
            guard let self else { return }
            let smoke = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...6))
            smoke.fillColor = .white.withAlphaComponent(0.3)
            smoke.strokeColor = .clear
            smoke.position = exhaust.convert(CGPoint(x: CGFloat.random(in: -8...8), y: 0), to: self)
            smoke.zPosition = 5
            self.addChild(smoke)

            let moveDown = SKAction.moveBy(x: CGFloat.random(in: -10...10), y: -60, duration: 0.5)
            let fade = SKAction.fadeOut(withDuration: 0.5)
            let scale = SKAction.scale(to: 2.0, duration: 0.5)
            let group = SKAction.group([moveDown, fade, scale])
            smoke.run(SKAction.sequence([group, SKAction.removeFromParent()]))
        }
        let wait = SKAction.wait(forDuration: 0.08)
        run(SKAction.repeatForever(SKAction.sequence([spawnSmoke, wait])), withKey: "exhaust")
    }

    private func setupSpeedLines() {
        let spawnLine = SKAction.run { [weak self] in
            guard let self else { return }
            let x = CGFloat.random(in: 0...self.size.width)
            let line = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 2, height: CGFloat.random(in: 30...80)))
            line.fillColor = .white.withAlphaComponent(CGFloat.random(in: 0.03...0.08))
            line.strokeColor = .clear
            line.position = CGPoint(x: x, y: self.size.height + 40)
            line.zPosition = -3
            self.addChild(line)

            let moveDown = SKAction.moveBy(x: 0, y: -(self.size.height + 120), duration: Double.random(in: 0.4...0.8) / self.gameSpeed)
            line.run(SKAction.sequence([moveDown, SKAction.removeFromParent()]))
        }
        let wait = SKAction.wait(forDuration: 0.05)
        run(SKAction.repeatForever(SKAction.sequence([spawnLine, wait])), withKey: "speedLines")
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        if gameTime == 0 { gameTime = currentTime }
        let dt = currentTime - gameTime
        gameTime = currentTime

        // Scroll road stripes
        for stripe in roadStripes {
            stripe.position.y -= roadSpeed
            if stripe.position.y < -30 {
                stripe.position.y += size.height + 50
            }
        }

        // Scroll items
        for item in activeItems {
            item.position.y -= roadSpeed * 0.9

            // Scale up as it approaches (perspective)
            let progress = 1.0 - (item.position.y / size.height)
            let scale = 0.4 + progress * 0.8
            item.setScale(max(0.3, min(1.2, scale)))

            // Check collision
            if abs(item.position.y - car.position.y) < 35 &&
               abs(item.position.x - car.position.x) < 40 {
                collectItem(item)
            }

            // Remove if off screen
            if item.position.y < -60 {
                item.removeFromParent()
                activeItems.removeAll(where: { $0 === item })
            }
        }

        // Spawn items
        if currentTime - lastSpawnTime > spawnInterval {
            lastSpawnTime = currentTime
            spawnItem()
        }
    }

    // MARK: - Spawning

    func setChallenge(correct: String, distractors: [String]) {
        currentCorrect = correct
        currentDistractors = distractors
        // Clear existing items
        for item in activeItems {
            item.removeFromParent()
        }
        activeItems.removeAll()
    }

    private func spawnItem() {
        guard !currentCorrect.isEmpty else { return }

        // Ensure at least one correct answer is always on screen
        let hasCorrect = activeItems.contains(where: { $0.name == "correct" })
        let isCorrect = !hasCorrect || Bool.random()
        let character = isCorrect ? currentCorrect : (currentDistractors.randomElement() ?? currentCorrect)
        let actuallyCorrect = character == currentCorrect

        let lane = Int.random(in: 0..<laneCount)
        let x = lanePositions[lane]

        let container = SKNode()
        container.position = CGPoint(x: x, y: size.height + 50)
        container.name = actuallyCorrect ? "correct" : "wrong"
        container.userData = NSMutableDictionary()
        container.userData?["character"] = character
        container.userData?["isCorrect"] = actuallyCorrect
        container.zPosition = 8
        container.setScale(0.3) // Start small (far away)

        // Glowing circle
        let glow = SKShapeNode(circleOfRadius: 32)
        glow.fillColor = actuallyCorrect
            ? UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 0.3)
            : UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 0.2)
        glow.strokeColor = .clear
        glow.glowWidth = 8
        container.addChild(glow)

        // Circle background
        let circle = SKShapeNode(circleOfRadius: 28)
        circle.fillColor = actuallyCorrect
            ? UIColor(red: 0.15, green: 0.7, blue: 0.25, alpha: 0.85)
            : UIColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 0.7)
        circle.strokeColor = .white.withAlphaComponent(0.6)
        circle.lineWidth = 2
        container.addChild(circle)

        // Letter
        let label = SKLabelNode(text: character)
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 28
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        container.addChild(label)

        // Pulse animation for correct items
        if actuallyCorrect {
            let pulse = SKAction.sequence([
                SKAction.scale(by: 1.1, duration: 0.4),
                SKAction.scale(by: 1.0/1.1, duration: 0.4)
            ])
            glow.run(SKAction.repeatForever(pulse))
        }

        addChild(container)
        activeItems.append(container)
    }

    private func collectItem(_ item: SKNode) {
        guard let character = item.userData?["character"] as? String,
              let isCorrect = item.userData?["isCorrect"] as? Bool else { return }

        item.removeFromParent()
        activeItems.removeAll(where: { $0 === item })

        if isCorrect {
            spawnCollectParticles(at: item.position, correct: true)
            flashScreen(color: .green)
        } else {
            spawnCollectParticles(at: item.position, correct: false)
            flashScreen(color: .red)
        }

        onCollect?(character, isCorrect)
    }

    // MARK: - Effects

    private func spawnCollectParticles(at position: CGPoint, correct: Bool) {
        let count = correct ? 12 : 6
        for _ in 0..<count {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...8))
            particle.fillColor = correct
                ? [UIColor.green, .yellow, .white, .cyan][Int.random(in: 0...3)]
                : [UIColor.red, .orange][Int.random(in: 0...1)]
            particle.strokeColor = .clear
            particle.position = position
            particle.zPosition = 20
            addChild(particle)

            let angle = CGFloat.random(in: 0...(.pi * 2))
            let dist = CGFloat.random(in: 40...120)
            let dx = cos(angle) * dist
            let dy = sin(angle) * dist

            let move = SKAction.moveBy(x: dx, y: dy, duration: Double.random(in: 0.3...0.6))
            move.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: 0.4)
            let scale = SKAction.scale(to: 0.1, duration: 0.5)
            particle.run(SKAction.sequence([
                SKAction.group([move, fade, scale]),
                SKAction.removeFromParent()
            ]))
        }

        // Star burst for correct
        if correct {
            let star = SKLabelNode(text: "⭐")
            star.fontSize = 40
            star.position = position
            star.zPosition = 25
            addChild(star)
            star.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: 0, y: 80, duration: 0.5),
                    SKAction.fadeOut(withDuration: 0.5),
                    SKAction.scale(to: 2.0, duration: 0.5)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    func shakeCamera() {
        let shake = SKAction.sequence([
            SKAction.moveBy(x: 8, y: 0, duration: 0.03),
            SKAction.moveBy(x: -16, y: 0, duration: 0.03),
            SKAction.moveBy(x: 12, y: 4, duration: 0.03),
            SKAction.moveBy(x: -8, y: -4, duration: 0.03),
            SKAction.moveBy(x: 4, y: 0, duration: 0.03),
            SKAction.moveTo(x: size.width / 2, duration: 0.03),
            SKAction.moveTo(y: size.height / 2, duration: 0.03),
        ])
        cameraNode.run(shake)
    }

    private func flashScreen(color: UIColor) {
        let flash = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        flash.fillColor = color.withAlphaComponent(0.2)
        flash.strokeColor = .clear
        flash.zPosition = 50
        flash.alpha = 0
        addChild(flash)

        flash.run(SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.05),
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        touchStartX = touch.location(in: self).x
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let endX = touch.location(in: self).x
        let dx = endX - touchStartX

        if abs(dx) > 20 {
            // Swipe
            if dx > 0 {
                switchLane(to: min(currentLane + 1, laneCount - 1))
            } else {
                switchLane(to: max(currentLane - 1, 0))
            }
        } else {
            // Tap — move to tapped lane
            let tappedLane = lanePositions.enumerated().min(by: {
                abs($0.element - endX) < abs($1.element - endX)
            })?.offset ?? currentLane
            if tappedLane != currentLane {
                switchLane(to: tappedLane)
            }
        }
    }

    private func switchLane(to lane: Int) {
        guard lane != currentLane, lane >= 0, lane < laneCount else { return }

        // Smooth car movement with tilt
        let tiltDirection: CGFloat = lane > currentLane ? 1 : -1
        currentLane = lane

        let tilt = SKAction.rotate(toAngle: tiltDirection * 0.15, duration: 0.1)
        let move = SKAction.moveTo(x: lanePositions[lane], duration: 0.15)
        move.timingMode = .easeOut
        let untilt = SKAction.rotate(toAngle: 0, duration: 0.1)

        car.run(SKAction.sequence([
            SKAction.group([tilt, move]),
            untilt
        ]))
    }
}
