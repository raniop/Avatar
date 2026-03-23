import SwiftUI
import SpriteKit

// MARK: - SwiftUI Wrapper

struct FootballKickGameView: View {
    let theme: String
    let difficulty: GameDifficulty
    let locale: AppLocale
    let age: Int
    @Binding var score: Int
    @Binding var totalItems: Int
    @Binding var timeRemaining: Int
    let onTimeUp: () -> Void

    @State private var scene: PenaltyKickScene?
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

                // Prompt overlay (top)
                VStack {
                    promptView.padding(.top, 4)
                    Spacer()
                }

                // Feedback
                if let feedback {
                    feedbackView(feedback, in: geo.size)
                }
            }
            .onAppear { setupGame(size: geo.size) }
            .onDisappear { timerRunning = false }
        }
    }

    @ViewBuilder
    private func feedbackView(_ text: String, in size: CGSize) -> some View {
        Text(text)
            .font(.system(size: 64, weight: .black, design: .rounded))
            .foregroundStyle(
                LinearGradient(colors: [.white, .yellow], startPoint: .top, endPoint: .bottom)
            )
            .shadow(color: .black, radius: 8)
            .shadow(color: .orange.opacity(0.5), radius: 20)
            .transition(.scale.combined(with: .opacity))
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var promptView: some View {
        if let challenge = currentChallenge {
            VStack(spacing: 4) {
                if let emoji = challenge.promptEmoji {
                    Text(emoji).font(.system(size: 36))
                }
                if challenge.correctAnswers.count > 1 {
                    HStack(spacing: 4) {
                        ForEach(Array(challenge.correctAnswers.enumerated()), id: \.offset) { i, letter in
                            Text(i < letterIndex ? letter : "⬜")
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundStyle(i == letterIndex ? .yellow : .white)
                        }
                    }
                } else if !challenge.prompt.isEmpty {
                    Text(challenge.prompt)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4)
                }
                Text(locale == .hebrew ? "בעט לאות הנכונה!" : "Kick the right letter!")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.3), radius: 8)
        }
    }

    private func setupGame(size: CGSize) {
        let contentType = EducationalContent.defaultContentType(locale: locale, age: age)
        challenges = EducationalContent.generate(locale: locale, age: age, contentType: contentType, count: difficulty.itemCount)
        totalItems = challenges.count
        score = 0; currentIndex = 0; letterIndex = 0; timerRunning = true

        let kickScene = PenaltyKickScene(size: size)
        kickScene.scaleMode = .resizeFill
        kickScene.gameSpeed = difficulty.speed
        kickScene.distractorCount = difficulty.distractorCount
        kickScene.onKickResult = { _, isCorrect in handleKick(isCorrect: isCorrect) }

        if let ch = challenges.first {
            let correct = ch.correctAnswers[0]
            kickScene.pendingCorrect = correct
            kickScene.pendingDistractors = Array(ch.distractors.prefix(difficulty.distractorCount))
        }
        self.scene = kickScene
        startTimer()
    }

    private func handleKick(isCorrect: Bool) {
        if isCorrect {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            guard let challenge = currentChallenge else { return }
            if challenge.correctAnswers.count > 1 {
                letterIndex += 1
                if letterIndex >= challenge.correctAnswers.count {
                    score += 1; showFeedback("⚽ גול!")
                    advanceChallenge()
                } else { showFeedback("👍"); updateScene() }
            } else {
                score += 1; showFeedback("⚽ גול!")
                advanceChallenge()
            }
        } else {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            showFeedback("🧤 נתפס!")
        }
    }

    private func updateScene() {
        guard let ch = currentChallenge, letterIndex < ch.correctAnswers.count else { return }
        scene?.setChallenge(correct: ch.correctAnswers[letterIndex],
                            distractors: Array(ch.distractors.prefix(difficulty.distractorCount)))
    }

    private func advanceChallenge() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            currentIndex += 1; letterIndex = 0
            if currentIndex >= challenges.count { timerRunning = false; onTimeUp() }
            else { updateScene() }
        }
    }

    private func showFeedback(_ text: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { feedback = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { withAnimation { feedback = nil } }
    }

    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            guard timerRunning else { timer.invalidate(); return }
            if timeRemaining > 0 { timeRemaining -= 1 }
            else { timer.invalidate(); timerRunning = false; onTimeUp() }
        }
    }
}

// MARK: - SpriteKit Penalty Kick Scene

class PenaltyKickScene: SKScene {

    var gameSpeed: Double = 1.0
    var distractorCount: Int = 3
    var onKickResult: ((String, Bool) -> Void)?
    var pendingCorrect: String?
    var pendingDistractors: [String]?

    private var currentCorrect = ""
    private var currentDistractors: [String] = []

    // Nodes
    private var ball: SKSpriteNode!
    private var goalkeeper: SKNode!
    private var goalNode: SKNode!
    private var cameraNode: SKCameraNode!
    private var targetNodes: [(node: SKNode, character: String, isCorrect: Bool)] = []
    private var canKick = true

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.15, green: 0.42, blue: 0.15, alpha: 1)
        setupCamera()
        setupField()
        setupGoal()
        setupGoalkeeper()
        setupBall()

        if let correct = pendingCorrect, let distractors = pendingDistractors {
            pendingCorrect = nil; pendingDistractors = nil
            setChallenge(correct: correct, distractors: distractors)
        }
    }

    private func setupCamera() {
        cameraNode = SKCameraNode()
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(cameraNode); camera = cameraNode
    }

    private func setupField() {
        // Grass texture
        let grass = SKSpriteNode(texture: GameTexture.grassField(size: size))
        grass.position = CGPoint(x: size.width / 2, y: size.height / 2)
        grass.size = size; grass.zPosition = -20
        addChild(grass)

        // Penalty box
        let boxW = size.width * 0.75, boxH = size.height * 0.38
        let boxY = size.height * 0.50
        let box = SKShapeNode(rect: CGRect(x: (size.width - boxW)/2, y: boxY, width: boxW, height: boxH))
        box.strokeColor = .white.withAlphaComponent(0.25); box.lineWidth = 2.5
        box.fillColor = .clear; box.zPosition = -15
        addChild(box)

        // Penalty spot
        let spot = SKShapeNode(circleOfRadius: 5)
        spot.fillColor = .white.withAlphaComponent(0.6); spot.strokeColor = .clear
        spot.position = CGPoint(x: size.width / 2, y: size.height * 0.28); spot.zPosition = -15
        addChild(spot)

        // Penalty arc
        let arcPath = CGMutablePath()
        arcPath.addArc(center: CGPoint(x: size.width / 2, y: boxY),
                       radius: 65, startAngle: .pi * 0.2, endAngle: .pi * 0.8, clockwise: false)
        let arc = SKShapeNode(path: arcPath)
        arc.strokeColor = .white.withAlphaComponent(0.2); arc.lineWidth = 2.5; arc.zPosition = -15
        addChild(arc)

        // Vignette overlay (subtle darkening at edges for depth)
        let vignette = SKEffectNode()
        let vignetteShape = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        vignetteShape.fillColor = .clear; vignetteShape.strokeColor = .clear
        vignette.addChild(vignetteShape)
        vignette.zPosition = 30; vignette.alpha = 0.3
        // Skip heavy filter for performance
    }

    private func setupGoal() {
        goalNode = SKNode()
        goalNode.position = CGPoint(x: size.width / 2, y: size.height * 0.76)
        goalNode.zPosition = 5
        addChild(goalNode)

        let goalW = size.width * 0.72, goalH = size.height * 0.17
        let postW: CGFloat = 8

        // Net
        let net = SKSpriteNode(texture: GameTexture.goalNet(size: CGSize(width: goalW, height: goalH)))
        net.size = CGSize(width: goalW, height: goalH)
        net.position = CGPoint(x: 0, y: goalH / 2)
        net.zPosition = -2; net.name = "net"
        goalNode.addChild(net)

        // Left post
        let leftTex = GameTexture.goalPost(size: CGSize(width: postW, height: goalH + 10))
        let leftPost = SKSpriteNode(texture: leftTex)
        leftPost.size = CGSize(width: postW, height: goalH + 10)
        leftPost.position = CGPoint(x: -goalW/2, y: goalH/2)
        goalNode.addChild(leftPost)

        // Right post
        let rightPost = SKSpriteNode(texture: leftTex)
        rightPost.size = CGSize(width: postW, height: goalH + 10)
        rightPost.position = CGPoint(x: goalW/2, y: goalH/2)
        goalNode.addChild(rightPost)

        // Crossbar
        let crossTex = GameTexture.goalPost(size: CGSize(width: goalW + postW, height: postW))
        let crossbar = SKSpriteNode(texture: crossTex)
        crossbar.size = CGSize(width: goalW + postW, height: postW)
        crossbar.position = CGPoint(x: 0, y: goalH)
        goalNode.addChild(crossbar)
    }

    private func setupGoalkeeper() {
        goalkeeper = SKNode()
        goalkeeper.position = CGPoint(x: size.width / 2, y: size.height * 0.77)
        goalkeeper.zPosition = 6

        // Simple but clean goalkeeper using layers
        // Jersey
        let jersey = SKShapeNode(rectOf: CGSize(width: 34, height: 44), cornerRadius: 8)
        jersey.fillColor = UIColor(red: 0.95, green: 0.75, blue: 0.1, alpha: 1)
        jersey.strokeColor = UIColor(red: 0.7, green: 0.55, blue: 0.05, alpha: 1)
        jersey.lineWidth = 2
        goalkeeper.addChild(jersey)

        // Shorts
        let shorts = SKShapeNode(rectOf: CGSize(width: 30, height: 16), cornerRadius: 4)
        shorts.fillColor = UIColor(white: 0.15, alpha: 1)
        shorts.strokeColor = .clear
        shorts.position = CGPoint(x: 0, y: -26)
        goalkeeper.addChild(shorts)

        // Head
        let head = SKShapeNode(circleOfRadius: 14)
        head.fillColor = UIColor(red: 0.92, green: 0.78, blue: 0.6, alpha: 1)
        head.strokeColor = UIColor(red: 0.7, green: 0.55, blue: 0.4, alpha: 1)
        head.lineWidth = 1
        head.position = CGPoint(x: 0, y: 32)
        goalkeeper.addChild(head)

        // Hair
        let hair = SKShapeNode(rectOf: CGSize(width: 22, height: 8), cornerRadius: 4)
        hair.fillColor = UIColor(red: 0.2, green: 0.15, blue: 0.1, alpha: 1)
        hair.strokeColor = .clear
        hair.position = CGPoint(x: 0, y: 40)
        goalkeeper.addChild(hair)

        // Gloves
        for dx: CGFloat in [-24, 24] {
            let glove = SKShapeNode(circleOfRadius: 9)
            glove.fillColor = UIColor(red: 0.2, green: 0.75, blue: 0.25, alpha: 1)
            glove.strokeColor = UIColor(red: 0.1, green: 0.5, blue: 0.15, alpha: 1)
            glove.lineWidth = 1.5
            glove.position = CGPoint(x: dx, y: 8)
            glove.name = "glove"
            goalkeeper.addChild(glove)
        }

        // Shadow under goalkeeper
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 50, height: 14))
        shadow.fillColor = UIColor(white: 0, alpha: 0.2)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -38)
        shadow.zPosition = -1
        goalkeeper.addChild(shadow)

        addChild(goalkeeper)
        startGoalkeeperSway()
    }

    private func setupBall() {
        let ballTexture = GameTexture.football(radius: 26)
        ball = SKSpriteNode(texture: ballTexture)
        ball.size = CGSize(width: 52, height: 52)
        ball.position = CGPoint(x: size.width / 2, y: size.height * 0.20)
        ball.zPosition = 15

        // Shadow
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 44, height: 12))
        shadow.fillColor = UIColor(white: 0, alpha: 0.25)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -28)
        shadow.zPosition = -1
        shadow.name = "ballShadow"
        ball.addChild(shadow)

        addChild(ball)
    }

    // MARK: - Goalkeeper Sway

    private func startGoalkeeperSway() {
        let sway = SKAction.repeatForever(SKAction.sequence([
            SKAction.wait(forDuration: Double.random(in: 0.8...1.5)),
            SKAction.run { [weak self] in
                guard let self, self.canKick else { return }
                let range = self.size.width * 0.12
                let newX = self.size.width / 2 + CGFloat.random(in: -range...range)
                self.goalkeeper.run(SKAction.moveTo(x: newX, duration: 0.7))
            }
        ]))
        goalkeeper.run(sway, withKey: "sway")
    }

    // MARK: - Challenge

    func setChallenge(correct: String, distractors: [String]) {
        currentCorrect = correct
        currentDistractors = distractors

        for t in targetNodes { t.node.removeFromParent() }
        targetNodes.removeAll()

        var options = Array(distractors.prefix(distractorCount))
        if !options.contains(correct) { options.append(correct) }
        options.shuffle()

        let goalW = size.width * 0.72
        let goalH = size.height * 0.17
        let goalX = size.width / 2
        let goalY = size.height * 0.76

        let cols = options.count <= 4 ? 2 : 3
        let rows = (options.count + cols - 1) / cols
        let cellW = (goalW - 24) / CGFloat(cols)
        let cellH = (goalH - 16) / CGFloat(rows)

        for (idx, char) in options.enumerated() {
            let col = idx % cols
            let row = idx / cols
            let x = goalX - goalW/2 + 12 + cellW * CGFloat(col) + cellW / 2
            let y = goalY + 8 + cellH * CGFloat(row) + cellH / 2

            let isCorrect = char == correct
            let target = SKNode()
            target.position = CGPoint(x: x, y: y)
            target.zPosition = 7

            // Target bubble
            let bubbleColor = isCorrect
                ? UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1)
                : UIColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 1)
            let bubbleGlow = isCorrect ? UIColor.green : nil
            let bubbleTex = GameTexture.letterBubble(size: min(cellW, cellH) - 8, color: bubbleColor, glowColor: bubbleGlow)
            let bubble = SKSpriteNode(texture: bubbleTex)
            bubble.size = CGSize(width: min(cellW, cellH), height: min(cellW, cellH))
            target.addChild(bubble)

            // Letter
            let label = SKLabelNode(text: char)
            label.fontName = "AvenirNext-Heavy"
            label.fontSize = 28
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            target.addChild(label)

            addChild(target)
            targetNodes.append((node: target, character: char, isCorrect: isCorrect))
        }

        resetBall()
        canKick = true
    }

    private func resetBall() {
        guard ball != nil, goalkeeper != nil else { return }
        ball.removeAllActions()
        ball.position = CGPoint(x: size.width / 2, y: size.height * 0.20)
        ball.setScale(1.0); ball.alpha = 1.0; ball.zRotation = 0

        goalkeeper.removeAction(forKey: "sway")
        goalkeeper.position = CGPoint(x: size.width / 2, y: size.height * 0.77)
        goalkeeper.zRotation = 0
        startGoalkeeperSway()
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard canKick, let touch = touches.first else { return }
        let loc = touch.location(in: self)
        for target in targetNodes {
            if hypot(loc.x - target.node.position.x, loc.y - target.node.position.y) < 45 {
                kickBall(to: target); return
            }
        }
    }

    // MARK: - Kick

    private func kickBall(to target: (node: SKNode, character: String, isCorrect: Bool)) {
        canKick = false
        goalkeeper.removeAction(forKey: "sway")

        let targetPos = target.node.position
        let isCorrect = target.isCorrect

        // Goalkeeper dive
        let gkDiveX: CGFloat
        if isCorrect {
            gkDiveX = targetPos.x > size.width / 2
                ? size.width / 2 - size.width * 0.25
                : size.width / 2 + size.width * 0.25
        } else {
            gkDiveX = targetPos.x
        }
        let diveRotation: CGFloat = gkDiveX < size.width / 2 ? 0.7 : -0.7
        goalkeeper.run(SKAction.group([
            SKAction.moveTo(x: gkDiveX, duration: isCorrect ? 0.35 : 0.28),
            SKAction.rotate(toAngle: diveRotation, duration: 0.3)
        ]))

        // Ball arc flight
        let midY = (ball.position.y + targetPos.y) / 2 + 40
        let path = CGMutablePath()
        path.move(to: ball.position)
        path.addQuadCurve(to: targetPos, control: CGPoint(x: targetPos.x * 0.7 + ball.position.x * 0.3, y: midY))

        let fly = SKAction.follow(path, asOffset: false, orientToPath: false, duration: 0.4)
        fly.timingMode = .easeOut
        let spin = SKAction.rotate(byAngle: .pi * 4, duration: 0.4)
        let shrink = SKAction.scale(to: 0.55, duration: 0.4)

        ball.run(SKAction.sequence([
            SKAction.group([fly, spin, shrink]),
            SKAction.run { [weak self] in
                if isCorrect { self?.handleGoal(at: targetPos) }
                else { self?.handleSave(at: targetPos) }
            }
        ]))

        // Ball trail particles
        spawnBallTrail()
    }

    private func spawnBallTrail() {
        let trail = SKAction.repeat(SKAction.sequence([
            SKAction.run { [weak self] in
                guard let self else { return }
                let p = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...5))
                p.fillColor = .white.withAlphaComponent(0.3)
                p.strokeColor = .clear
                p.position = self.ball.position
                p.zPosition = 14
                self.addChild(p)
                p.run(SKAction.sequence([
                    SKAction.group([SKAction.fadeOut(withDuration: 0.3), SKAction.scale(to: 0.1, duration: 0.3)]),
                    SKAction.removeFromParent()
                ]))
            },
            SKAction.wait(forDuration: 0.03)
        ]), count: 12)
        run(trail)
    }

    private func handleGoal(at pos: CGPoint) {
        // Net ripple
        if let net = goalNode.childNode(withName: "net") {
            net.run(SKAction.sequence([
                SKAction.scale(to: 1.06, duration: 0.08),
                SKAction.scale(to: 0.97, duration: 0.08),
                SKAction.scale(to: 1.0, duration: 0.1)
            ]))
        }

        // Explosion of particles
        spawnGoalParticles(at: pos)
        flashScreen(color: .green)
        shakeCamera(intensity: 5)

        onKickResult?(currentCorrect, true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.goalkeeper.run(SKAction.rotate(toAngle: 0, duration: 0.3))
        }
    }

    private func handleSave(at pos: CGPoint) {
        // Ball bounces back
        ball.run(SKAction.sequence([
            SKAction.group([
                SKAction.move(to: CGPoint(x: size.width / 2, y: size.height * 0.4), duration: 0.3),
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.rotate(byAngle: -.pi * 2, duration: 0.3)
            ])
        ]))

        flashScreen(color: .red)
        shakeCamera(intensity: 8)

        // Impact sparks
        for _ in 0..<6 {
            let p = SKShapeNode(circleOfRadius: 3)
            p.fillColor = [.orange, .yellow, .white][Int.random(in: 0...2)]
            p.strokeColor = .clear; p.position = pos; p.zPosition = 20
            addChild(p)
            let a = CGFloat.random(in: 0...(.pi * 2))
            let d = CGFloat.random(in: 20...50)
            p.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: cos(a)*d, y: sin(a)*d, duration: 0.25),
                    SKAction.fadeOut(withDuration: 0.25)
                ]), SKAction.removeFromParent()
            ]))
        }

        onKickResult?("", false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            self.goalkeeper.run(SKAction.rotate(toAngle: 0, duration: 0.3))
            self.setChallenge(correct: self.currentCorrect, distractors: self.currentDistractors)
        }
    }

    // MARK: - Effects

    private func spawnGoalParticles(at pos: CGPoint) {
        let emojis = ["⚽", "🎉", "⭐", "🔥", "✨", "💫", "🏆", "👏"]
        for i in 0..<16 {
            let angle = CGFloat.random(in: 0...(.pi * 2))
            let dist = CGFloat.random(in: 50...150)
            let duration = Double.random(in: 0.4...0.8)

            if i < emojis.count {
                let label = SKLabelNode(text: emojis[i])
                label.fontSize = CGFloat.random(in: 22...38)
                label.position = pos; label.zPosition = 25
                addChild(label)
                label.run(SKAction.sequence([
                    SKAction.group([
                        SKAction.moveBy(x: cos(angle)*dist, y: sin(angle)*dist, duration: duration),
                        SKAction.sequence([SKAction.wait(forDuration: duration * 0.5), SKAction.fadeOut(withDuration: duration * 0.5)]),
                        SKAction.scale(to: 0.3, duration: duration)
                    ]),
                    SKAction.removeFromParent()
                ]))
            } else {
                let p = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...8))
                p.fillColor = [.green, .yellow, .white, .cyan][Int.random(in: 0...3)]
                p.strokeColor = .clear; p.position = pos; p.zPosition = 22
                addChild(p)
                p.run(SKAction.sequence([
                    SKAction.group([
                        SKAction.moveBy(x: cos(angle)*dist, y: sin(angle)*dist, duration: 0.5),
                        SKAction.fadeOut(withDuration: 0.5)
                    ]), SKAction.removeFromParent()
                ]))
            }
        }
    }

    func shakeCamera(intensity: CGFloat = 6) {
        cameraNode.run(SKAction.sequence([
            SKAction.moveBy(x: intensity, y: intensity * 0.5, duration: 0.025),
            SKAction.moveBy(x: -intensity * 2, y: -intensity, duration: 0.025),
            SKAction.moveBy(x: intensity * 1.5, y: intensity * 0.5, duration: 0.025),
            SKAction.moveBy(x: -intensity, y: 0, duration: 0.025),
            SKAction.moveTo(x: size.width / 2, duration: 0.025),
            SKAction.moveTo(y: size.height / 2, duration: 0.025),
        ]))
    }

    private func flashScreen(color: UIColor) {
        let flash = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        flash.fillColor = color.withAlphaComponent(0.2)
        flash.strokeColor = .clear; flash.zPosition = 50; flash.alpha = 0
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.04),
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent()
        ]))
    }
}
