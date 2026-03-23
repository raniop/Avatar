import SwiftUI
import SpriteKit

// MARK: - SwiftUI Wrapper

struct BasketballShootGameView: View {
    let theme: String
    let difficulty: GameDifficulty
    let locale: AppLocale
    let age: Int
    @Binding var score: Int
    @Binding var totalItems: Int
    @Binding var timeRemaining: Int
    let onTimeUp: () -> Void

    @State private var scene: BasketballScene?
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

                VStack {
                    promptView.padding(.top, 4)
                    Spacer()
                }

                if let feedback {
                    Text(feedback)
                        .font(.system(size: 60, weight: .black, design: .rounded))
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

    @ViewBuilder
    private var promptView: some View {
        if let challenge = currentChallenge {
            VStack(spacing: 4) {
                if let emoji = challenge.promptEmoji {
                    Text(emoji).font(.system(size: 36))
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
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.black.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func setupGame(size: CGSize) {
        let contentType = EducationalContent.defaultContentType(locale: locale, age: age)
        challenges = EducationalContent.generate(locale: locale, age: age, contentType: contentType, count: difficulty.itemCount)
        totalItems = challenges.count
        score = 0; currentIndex = 0; letterIndex = 0; timerRunning = true

        let bbScene = BasketballScene(size: size)
        bbScene.scaleMode = .resizeFill
        bbScene.onShootResult = { character, isCorrect in
            handleShoot(character: character, isCorrect: isCorrect)
        }
        if let ch = challenges.first {
            let correct = ch.correctAnswers[0]
            bbScene.setChallenge(correct: correct, distractors: Array(ch.distractors.prefix(difficulty.distractorCount)))
        }
        self.scene = bbScene
        startTimer()
    }

    private func handleShoot(character: String, isCorrect: Bool) {
        if isCorrect {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            guard let challenge = currentChallenge else { return }
            if challenge.correctAnswers.count > 1 {
                letterIndex += 1
                if letterIndex >= challenge.correctAnswers.count {
                    score += 1; showFeedback("🏀 סל!")
                    advanceChallenge()
                } else { showFeedback("👍"); updateScene() }
            } else {
                score += 1; showFeedback("🏀 סל!")
                advanceChallenge()
            }
        } else {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            showFeedback("🧱")
        }
    }

    private func updateScene() {
        guard let ch = currentChallenge, letterIndex < ch.correctAnswers.count else { return }
        scene?.setChallenge(correct: ch.correctAnswers[letterIndex], distractors: Array(ch.distractors.prefix(difficulty.distractorCount)))
    }

    private func advanceChallenge() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            currentIndex += 1; letterIndex = 0
            if currentIndex >= challenges.count { timerRunning = false; onTimeUp() }
            else { updateScene() }
        }
    }

    private func showFeedback(_ text: String) {
        withAnimation(.spring(response: 0.3)) { feedback = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { withAnimation { feedback = nil } }
    }

    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            guard timerRunning else { timer.invalidate(); return }
            if timeRemaining > 0 { timeRemaining -= 1 }
            else { timer.invalidate(); timerRunning = false; onTimeUp() }
        }
    }
}

// MARK: - SpriteKit Scene

class BasketballScene: SKScene {

    var onShootResult: ((String, Bool) -> Void)?
    private var currentCorrect = ""
    private var currentDistractors: [String] = []

    // Nodes
    private var ball: SKNode!
    private var cameraNode: SKCameraNode!
    private var hoopTargets: [(node: SKNode, character: String, isCorrect: Bool, rimCenter: CGPoint)] = []
    private var canShoot = true
    private var ballRestPos: CGPoint = .zero

    override func didMove(to view: SKView) {
        setupCamera()
        setupCourt()
        setupBall()
    }

    private func setupCamera() {
        cameraNode = SKCameraNode()
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(cameraNode)
        camera = cameraNode
    }

    private func setupCourt() {
        // Court floor
        for i in 0..<15 {
            let y = CGFloat(i) * size.height / 15
            let h = size.height / 15 + 1
            let t = CGFloat(i) / 15.0
            let color = UIColor(red: 0.55 - t * 0.15, green: 0.35 - t * 0.1, blue: 0.2 - t * 0.05, alpha: 1)
            let strip = SKShapeNode(rect: CGRect(x: 0, y: y, width: size.width, height: h))
            strip.fillColor = color; strip.strokeColor = .clear; strip.zPosition = -20
            addChild(strip)
        }

        // Floor lines (wood grain)
        for x in stride(from: CGFloat(0), to: size.width, by: 28) {
            let line = SKShapeNode(rect: CGRect(x: x, y: 0, width: 1, height: size.height))
            line.fillColor = UIColor(white: 0, alpha: 0.06)
            line.strokeColor = .clear; line.zPosition = -18
            addChild(line)
        }

        // Court markings
        let centerCircle = SKShapeNode(circleOfRadius: 50)
        centerCircle.strokeColor = .white.withAlphaComponent(0.15)
        centerCircle.lineWidth = 2; centerCircle.fillColor = .clear
        centerCircle.position = CGPoint(x: size.width / 2, y: size.height * 0.45)
        centerCircle.zPosition = -15
        addChild(centerCircle)

        // Three-point arc hint
        let arcPath = CGMutablePath()
        arcPath.addArc(center: CGPoint(x: size.width / 2, y: size.height * 0.75),
                       radius: size.width * 0.38, startAngle: .pi * 1.15, endAngle: .pi * 1.85, clockwise: true)
        let arc = SKShapeNode(path: arcPath)
        arc.strokeColor = .white.withAlphaComponent(0.1)
        arc.lineWidth = 2; arc.zPosition = -15
        addChild(arc)
    }

    private func setupBall() {
        ballRestPos = CGPoint(x: size.width / 2, y: size.height * 0.15)
        ball = SKNode()
        ball.position = ballRestPos
        ball.zPosition = 15

        // Ball body
        let ballBody = SKShapeNode(circleOfRadius: 24)
        ballBody.fillColor = UIColor(red: 1.0, green: 0.55, blue: 0.1, alpha: 1)
        ballBody.strokeColor = UIColor(red: 0.6, green: 0.3, blue: 0, alpha: 1)
        ballBody.lineWidth = 2
        ball.addChild(ballBody)

        // Ball lines (cross)
        for angle: CGFloat in [0, .pi/2] {
            let path = CGMutablePath()
            path.addArc(center: .zero, radius: 23, startAngle: angle, endAngle: angle + .pi, clockwise: false)
            let line = SKShapeNode(path: path)
            line.strokeColor = UIColor(red: 0.4, green: 0.2, blue: 0, alpha: 0.4)
            line.lineWidth = 1.5; line.fillColor = .clear
            ball.addChild(line)
        }

        // Shadow
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 44, height: 14))
        shadow.fillColor = UIColor(white: 0, alpha: 0.2)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -28); shadow.zPosition = -1
        ball.addChild(shadow)

        // Bounce idle animation
        let bounce = SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x: 0, y: 6, duration: 0.4),
            SKAction.moveBy(x: 0, y: -6, duration: 0.4),
        ]))
        bounce.timingMode = .easeInEaseOut
        ball.run(bounce, withKey: "bounce")

        addChild(ball)
    }

    // MARK: - Challenge

    func setChallenge(correct: String, distractors: [String]) {
        currentCorrect = correct
        currentDistractors = distractors

        for t in hoopTargets { t.node.removeFromParent() }
        hoopTargets.removeAll()

        var options = distractors
        if !options.contains(correct) { options.append(correct) }
        options.shuffle()

        let cols = options.count <= 3 ? options.count : (options.count <= 4 ? 2 : 3)
        let rows = (options.count + cols - 1) / cols
        let hoopW: CGFloat = min(120, (size.width - 40) / CGFloat(cols))
        let startY = size.height * 0.72
        let spacingY: CGFloat = 100

        for (idx, char) in options.enumerated() {
            let col = idx % cols
            let row = idx / cols
            let x = size.width / 2 + (CGFloat(col) - CGFloat(cols - 1) / 2) * (hoopW + 10)
            let y = startY - CGFloat(row) * spacingY
            let isCorrect = char == correct

            let hoop = createHoop(character: char, isCorrect: isCorrect, width: hoopW)
            hoop.position = CGPoint(x: x, y: y)
            addChild(hoop)

            let rimY = y - 22
            hoopTargets.append((node: hoop, character: char, isCorrect: isCorrect, rimCenter: CGPoint(x: x, y: rimY)))
        }

        resetBall()
        canShoot = true
    }

    private func createHoop(character: String, isCorrect: Bool, width: CGFloat) -> SKNode {
        let hoop = SKNode()
        hoop.zPosition = 8

        // Backboard
        let bbW = width * 0.75
        let bbH: CGFloat = 50
        let backboard = SKShapeNode(rectOf: CGSize(width: bbW, height: bbH), cornerRadius: 3)
        backboard.fillColor = UIColor(white: 1, alpha: 0.2)
        backboard.strokeColor = .white.withAlphaComponent(0.5)
        backboard.lineWidth = 2
        backboard.position = CGPoint(x: 0, y: 20)
        hoop.addChild(backboard)

        // Letter on backboard
        let label = SKLabelNode(text: character)
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 28; label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 20)
        hoop.addChild(label)

        // Rim (ellipse)
        let rimPath = CGMutablePath()
        rimPath.addEllipse(in: CGRect(x: -bbW * 0.35, y: -28, width: bbW * 0.7, height: 14))
        let rim = SKShapeNode(path: rimPath)
        rim.strokeColor = UIColor(red: 1.0, green: 0.4, blue: 0, alpha: 1)
        rim.lineWidth = 4; rim.fillColor = .clear
        rim.name = "rim"
        hoop.addChild(rim)

        // Net strings
        let netW = bbW * 0.6
        for i in 0..<7 {
            let t = CGFloat(i) / 6.0
            let startX = -netW/2 + t * netW
            let endX = startX * 0.6
            let path = CGMutablePath()
            path.move(to: CGPoint(x: startX, y: -22))
            path.addQuadCurve(to: CGPoint(x: endX, y: -50), control: CGPoint(x: (startX + endX) / 2, y: -35))
            let string = SKShapeNode(path: path)
            string.strokeColor = .white.withAlphaComponent(0.2)
            string.lineWidth = 1
            hoop.addChild(string)
        }

        return hoop
    }

    private func resetBall() {
        ball.removeAction(forKey: "shoot")
        ball.position = ballRestPos
        ball.setScale(1.0); ball.alpha = 1.0
        ball.zRotation = 0
        // Restart bounce
        let bounce = SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x: 0, y: 6, duration: 0.4),
            SKAction.moveBy(x: 0, y: -6, duration: 0.4),
        ]))
        ball.run(bounce, withKey: "bounce")
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard canShoot, let touch = touches.first else { return }
        let loc = touch.location(in: self)

        for target in hoopTargets {
            if abs(loc.x - target.node.position.x) < 60 && abs(loc.y - target.node.position.y) < 60 {
                shootBall(at: target)
                return
            }
        }
    }

    // MARK: - Shoot

    private func shootBall(at target: (node: SKNode, character: String, isCorrect: Bool, rimCenter: CGPoint)) {
        canShoot = false
        ball.removeAction(forKey: "bounce")

        let targetPos = target.rimCenter
        let isCorrect = target.isCorrect

        // Arc path
        let controlY = max(targetPos.y + 100, ball.position.y + 150)
        let path = CGMutablePath()
        path.move(to: ball.position)
        path.addQuadCurve(to: targetPos, control: CGPoint(x: (ball.position.x + targetPos.x) / 2, y: controlY))

        let fly = SKAction.follow(path, asOffset: false, orientToPath: false, duration: 0.5)
        fly.timingMode = .easeOut
        let spin = SKAction.rotate(byAngle: .pi * 4, duration: 0.5)
        let shrink = SKAction.scale(to: 0.6, duration: 0.5)

        let shootAction = SKAction.sequence([
            SKAction.group([fly, spin, shrink]),
            SKAction.run { [weak self] in
                guard let self else { return }
                if isCorrect { self.handleSwish(at: target) }
                else { self.handleBounce(at: target) }
            }
        ])
        ball.run(shootAction, withKey: "shoot")
    }

    private func handleSwish(at target: (node: SKNode, character: String, isCorrect: Bool, rimCenter: CGPoint)) {
        // Ball drops through
        ball.run(SKAction.sequence([
            SKAction.moveBy(x: 0, y: -60, duration: 0.2),
            SKAction.fadeOut(withDuration: 0.1)
        ]))

        // Rim flash green
        if let rim = target.node.childNode(withName: "rim") as? SKShapeNode {
            rim.strokeColor = .green
            rim.glowWidth = 8
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                rim.strokeColor = UIColor(red: 1.0, green: 0.4, blue: 0, alpha: 1)
                rim.glowWidth = 0
            }
        }

        // Swish particles
        spawnSwishParticles(at: target.rimCenter)
        flashScreen(color: .green)

        onShootResult?(target.character, true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.resetBall()
        }
    }

    private func handleBounce(at target: (node: SKNode, character: String, isCorrect: Bool, rimCenter: CGPoint)) {
        // Ball bounces off rim
        let bounceDir: CGFloat = ball.position.x > target.rimCenter.x ? 1 : -1
        ball.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: bounceDir * 60, y: -120, duration: 0.4),
                SKAction.fadeOut(withDuration: 0.4),
                SKAction.rotate(byAngle: bounceDir * .pi * 2, duration: 0.4)
            ])
        ]))

        // Rim flash red
        if let rim = target.node.childNode(withName: "rim") as? SKShapeNode {
            rim.strokeColor = .red
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                rim.strokeColor = UIColor(red: 1.0, green: 0.4, blue: 0, alpha: 1)
            }
        }

        // Bounce sparks
        for _ in 0..<4 {
            let p = SKShapeNode(circleOfRadius: 3)
            p.fillColor = .orange; p.strokeColor = .clear
            p.position = target.rimCenter; p.zPosition = 20
            addChild(p)
            p.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: CGFloat.random(in: -30...30), y: CGFloat.random(in: -20...20), duration: 0.3),
                    SKAction.fadeOut(withDuration: 0.3)
                ]),
                SKAction.removeFromParent()
            ]))
        }

        flashScreen(color: .red)
        shakeCamera()

        onShootResult?(target.character, false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            self.setChallenge(correct: self.currentCorrect, distractors: self.currentDistractors)
        }
    }

    private func spawnSwishParticles(at pos: CGPoint) {
        for _ in 0..<12 {
            let p = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...7))
            p.fillColor = [.green, .yellow, .white, .cyan][Int.random(in: 0...3)]
            p.strokeColor = .clear; p.position = pos; p.zPosition = 22
            addChild(p)
            let angle = CGFloat.random(in: 0...(.pi * 2))
            let dist = CGFloat.random(in: 40...100)
            p.run(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: cos(angle) * dist, y: sin(angle) * dist, duration: 0.5),
                    SKAction.fadeOut(withDuration: 0.5),
                    SKAction.scale(to: 0.2, duration: 0.5)
                ]),
                SKAction.removeFromParent()
            ]))
        }

        // Swoosh text
        let swoosh = SKLabelNode(text: "💫")
        swoosh.fontSize = 40; swoosh.position = pos; swoosh.zPosition = 25
        addChild(swoosh)
        swoosh.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 60, duration: 0.5),
                SKAction.fadeOut(withDuration: 0.5),
                SKAction.scale(to: 2.0, duration: 0.5)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    func shakeCamera() {
        cameraNode.run(SKAction.sequence([
            SKAction.moveBy(x: 5, y: 0, duration: 0.03),
            SKAction.moveBy(x: -10, y: 3, duration: 0.03),
            SKAction.moveBy(x: 8, y: -3, duration: 0.03),
            SKAction.moveBy(x: -5, y: 0, duration: 0.03),
            SKAction.moveTo(x: size.width / 2, duration: 0.03),
            SKAction.moveTo(y: size.height / 2, duration: 0.03),
        ]))
    }

    private func flashScreen(color: UIColor) {
        let flash = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        flash.fillColor = color.withAlphaComponent(0.15)
        flash.strokeColor = .clear; flash.zPosition = 50; flash.alpha = 0
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.05),
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.removeFromParent()
        ]))
    }
}
