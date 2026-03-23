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

                // HUD overlay
                VStack {
                    promptView
                        .padding(.top, 4)
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
                Text(locale == .hebrew ? "בעט לאות הנכונה!" : "Kick to the right letter!")
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

        let kickScene = PenaltyKickScene(size: size)
        kickScene.scaleMode = .resizeFill
        kickScene.gameSpeed = difficulty.speed
        kickScene.onKickResult = { character, isCorrect in
            handleKick(character: character, isCorrect: isCorrect)
        }
        if let ch = challenges.first {
            let correct = ch.correctAnswers[0]
            let distractors = Array(ch.distractors.prefix(difficulty.distractorCount))
            kickScene.pendingCorrect = correct
            kickScene.pendingDistractors = distractors
        }
        self.scene = kickScene
        startTimer()
    }

    private func handleKick(character: String, isCorrect: Bool) {
        if isCorrect {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            guard let challenge = currentChallenge else { return }
            if challenge.correctAnswers.count > 1 {
                letterIndex += 1
                if letterIndex >= challenge.correctAnswers.count {
                    score += 1; showFeedback("⚽ גול!")
                    advanceChallenge()
                } else {
                    showFeedback("👍"); updateSceneChallenge()
                }
            } else {
                score += 1; showFeedback("⚽ גול!")
                advanceChallenge()
            }
        } else {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            showFeedback("🧤")
        }
    }

    private func updateSceneChallenge() {
        guard let ch = currentChallenge, letterIndex < ch.correctAnswers.count else { return }
        scene?.setChallenge(correct: ch.correctAnswers[letterIndex], distractors: Array(ch.distractors.prefix(difficulty.distractorCount)))
    }

    private func advanceChallenge() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            currentIndex += 1; letterIndex = 0
            if currentIndex >= challenges.count { timerRunning = false; onTimeUp() }
            else { updateSceneChallenge() }
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

class PenaltyKickScene: SKScene {

    var gameSpeed: Double = 1.0
    var onKickResult: ((String, Bool) -> Void)?
    var pendingCorrect: String?
    var pendingDistractors: [String]?

    private var currentCorrect = ""
    private var currentDistractors: [String] = []

    // Nodes
    private var ball: SKNode!
    private var goalkeeper: SKNode!
    private var goalNode: SKNode!
    private var cameraNode: SKCameraNode!
    private var targetNodes: [(node: SKNode, character: String, isCorrect: Bool)] = []
    private var canKick = true
    private var ballResting = true

    // Crowd
    private var crowdNodes: [SKNode] = []

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.15, green: 0.45, blue: 0.15, alpha: 1)
        setupCamera()
        setupField()
        setupGoal()
        setupGoalkeeper()
        setupBall()
        setupCrowd()
        startGoalkeeperSway()

        // Apply pending challenge if set before didMove
        if let correct = pendingCorrect, let distractors = pendingDistractors {
            pendingCorrect = nil; pendingDistractors = nil
            setChallenge(correct: correct, distractors: distractors)
        }
    }

    // MARK: - Setup

    private func setupCamera() {
        cameraNode = SKCameraNode()
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(cameraNode)
        camera = cameraNode
    }

    private func setupField() {
        // Grass gradient (darker at top = distance)
        let grassColors: [(CGFloat, UIColor)] = [
            (0.0, UIColor(red: 0.1, green: 0.35, blue: 0.1, alpha: 1)),
            (0.5, UIColor(red: 0.15, green: 0.45, blue: 0.15, alpha: 1)),
            (1.0, UIColor(red: 0.2, green: 0.55, blue: 0.2, alpha: 1)),
        ]
        for i in 0..<20 {
            let y = size.height * CGFloat(i) / 20.0
            let h = size.height / 20.0 + 1
            let t = CGFloat(i) / 20.0
            let color = UIColor(
                red: 0.1 + t * 0.12,
                green: 0.3 + t * 0.25,
                blue: 0.1 + t * 0.12,
                alpha: 1
            )
            let stripe = SKShapeNode(rect: CGRect(x: 0, y: y, width: size.width, height: h))
            stripe.fillColor = color
            stripe.strokeColor = .clear
            stripe.zPosition = -20
            addChild(stripe)
        }

        // Grass texture lines
        for _ in 0..<40 {
            let x = CGFloat.random(in: 0...size.width)
            let y = CGFloat.random(in: 0...size.height * 0.6)
            let line = SKShapeNode(rect: CGRect(x: 0, y: 0, width: CGFloat.random(in: 15...40), height: 1.5))
            line.fillColor = UIColor(red: 0.25, green: 0.6, blue: 0.2, alpha: 0.15)
            line.strokeColor = .clear
            line.position = CGPoint(x: x, y: y)
            line.zPosition = -18
            line.zRotation = CGFloat.random(in: -0.2...0.2)
            addChild(line)
        }

        // Penalty box
        let boxW = size.width * 0.75
        let boxH = size.height * 0.35
        let boxY = size.height * 0.52
        let box = SKShapeNode(rect: CGRect(x: (size.width - boxW) / 2, y: boxY, width: boxW, height: boxH), cornerRadius: 0)
        box.fillColor = .clear
        box.strokeColor = .white.withAlphaComponent(0.2)
        box.lineWidth = 2
        box.zPosition = -15
        addChild(box)

        // Penalty spot
        let spot = SKShapeNode(circleOfRadius: 4)
        spot.fillColor = .white.withAlphaComponent(0.5)
        spot.strokeColor = .clear
        spot.position = CGPoint(x: size.width / 2, y: size.height * 0.3)
        spot.zPosition = -15
        addChild(spot)

        // Center arc
        let arcPath = CGMutablePath()
        arcPath.addArc(center: CGPoint(x: size.width / 2, y: boxY),
                       radius: 60, startAngle: .pi * 0.2, endAngle: .pi * 0.8, clockwise: false)
        let arc = SKShapeNode(path: arcPath)
        arc.strokeColor = .white.withAlphaComponent(0.15)
        arc.lineWidth = 2
        arc.zPosition = -15
        addChild(arc)
    }

    private func setupGoal() {
        goalNode = SKNode()
        goalNode.position = CGPoint(x: size.width / 2, y: size.height * 0.78)
        goalNode.zPosition = 5
        addChild(goalNode)

        let goalW: CGFloat = size.width * 0.7
        let goalH: CGFloat = size.height * 0.16
        let postWidth: CGFloat = 6

        // Net background
        let netBg = SKShapeNode(rect: CGRect(x: -goalW/2, y: 0, width: goalW, height: goalH), cornerRadius: 2)
        netBg.fillColor = UIColor(white: 0, alpha: 0.3)
        netBg.strokeColor = .clear
        netBg.zPosition = -2
        goalNode.addChild(netBg)

        // Net lines
        let netSpacing: CGFloat = 12
        for col in 0...Int(goalW / netSpacing) {
            let x = -goalW/2 + CGFloat(col) * netSpacing
            let line = SKShapeNode(rect: CGRect(x: x, y: 0, width: 1, height: goalH))
            line.fillColor = .white.withAlphaComponent(0.08)
            line.strokeColor = .clear
            line.zPosition = -1
            goalNode.addChild(line)
        }
        for row in 0...Int(goalH / netSpacing) {
            let y = CGFloat(row) * netSpacing
            let line = SKShapeNode(rect: CGRect(x: -goalW/2, y: y, width: goalW, height: 1))
            line.fillColor = .white.withAlphaComponent(0.08)
            line.strokeColor = .clear
            line.zPosition = -1
            goalNode.addChild(line)
        }

        // Posts
        let leftPost = SKShapeNode(rect: CGRect(x: -goalW/2 - postWidth/2, y: -5, width: postWidth, height: goalH + 10), cornerRadius: 2)
        leftPost.fillColor = .white
        leftPost.strokeColor = UIColor(white: 0.85, alpha: 1)
        leftPost.lineWidth = 1
        goalNode.addChild(leftPost)

        let rightPost = SKShapeNode(rect: CGRect(x: goalW/2 - postWidth/2, y: -5, width: postWidth, height: goalH + 10), cornerRadius: 2)
        rightPost.fillColor = .white
        rightPost.strokeColor = UIColor(white: 0.85, alpha: 1)
        rightPost.lineWidth = 1
        goalNode.addChild(rightPost)

        // Crossbar
        let crossbar = SKShapeNode(rect: CGRect(x: -goalW/2 - postWidth/2, y: goalH, width: goalW + postWidth, height: postWidth), cornerRadius: 2)
        crossbar.fillColor = .white
        crossbar.strokeColor = UIColor(white: 0.85, alpha: 1)
        crossbar.lineWidth = 1
        goalNode.addChild(crossbar)
    }

    private func setupGoalkeeper() {
        goalkeeper = SKNode()
        goalkeeper.position = CGPoint(x: size.width / 2, y: size.height * 0.78 + 10)
        goalkeeper.zPosition = 6

        // Body
        let body = SKShapeNode(rectOf: CGSize(width: 30, height: 40), cornerRadius: 6)
        body.fillColor = UIColor(red: 1.0, green: 0.7, blue: 0.1, alpha: 1)
        body.strokeColor = UIColor(red: 0.8, green: 0.5, blue: 0, alpha: 1)
        body.lineWidth = 2
        goalkeeper.addChild(body)

        // Head
        let head = SKShapeNode(circleOfRadius: 12)
        head.fillColor = UIColor(red: 0.95, green: 0.8, blue: 0.6, alpha: 1)
        head.strokeColor = .clear
        head.position = CGPoint(x: 0, y: 28)
        goalkeeper.addChild(head)

        // Gloves
        for dx: CGFloat in [-22, 22] {
            let glove = SKShapeNode(circleOfRadius: 8)
            glove.fillColor = UIColor(red: 0.2, green: 0.7, blue: 0.2, alpha: 1)
            glove.strokeColor = .clear
            glove.position = CGPoint(x: dx, y: 10)
            glove.name = "glove"
            goalkeeper.addChild(glove)
        }

        addChild(goalkeeper)
    }

    private func setupBall() {
        ball = SKNode()
        ball.position = CGPoint(x: size.width / 2, y: size.height * 0.22)
        ball.zPosition = 15

        // Ball body
        let ballShape = SKShapeNode(circleOfRadius: 22)
        ballShape.fillColor = .white
        ballShape.strokeColor = UIColor(white: 0.3, alpha: 1)
        ballShape.lineWidth = 2
        ball.addChild(ballShape)

        // Pentagon pattern
        for angle in stride(from: 0.0, to: Double.pi * 2, by: Double.pi * 2 / 5) {
            let pent = SKShapeNode(circleOfRadius: 6)
            pent.fillColor = UIColor(white: 0.15, alpha: 1)
            pent.strokeColor = .clear
            pent.position = CGPoint(x: cos(angle) * 11, y: sin(angle) * 11)
            ball.addChild(pent)
        }

        // Center pentagon
        let center = SKShapeNode(circleOfRadius: 7)
        center.fillColor = UIColor(white: 0.15, alpha: 1)
        center.strokeColor = .clear
        ball.addChild(center)

        // Shadow
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 40, height: 12))
        shadow.fillColor = UIColor(white: 0, alpha: 0.25)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -25)
        shadow.zPosition = -1
        ball.addChild(shadow)

        addChild(ball)
    }

    private func setupCrowd() {
        // Crowd behind goal (top of screen)
        let crowdY = size.height * 0.92
        for i in 0..<30 {
            let x = CGFloat(i) * (size.width / 30) + CGFloat.random(in: -5...5)
            let person = SKShapeNode(circleOfRadius: CGFloat.random(in: 4...7))
            let colors: [UIColor] = [.red, .blue, .yellow, .green, .white, .orange, .purple, .cyan]
            person.fillColor = colors.randomElement()!.withAlphaComponent(0.6)
            person.strokeColor = .clear
            person.position = CGPoint(x: x, y: crowdY + CGFloat.random(in: -8...8))
            person.zPosition = -12
            addChild(person)
            crowdNodes.append(person)
        }
    }

    // MARK: - Goalkeeper

    private func startGoalkeeperSway() {
        let sway = SKAction.repeatForever(SKAction.sequence([
            SKAction.wait(forDuration: Double.random(in: 0.8...1.5)),
            SKAction.run { [weak self] in
                guard let self, self.canKick else { return }
                let range = self.size.width * 0.15
                let newX = self.size.width / 2 + CGFloat.random(in: -range...range)
                self.goalkeeper.run(SKAction.moveTo(x: newX, duration: 0.6))
            }
        ]))
        goalkeeper.run(sway, withKey: "sway")
    }

    // MARK: - Challenge

    func setChallenge(correct: String, distractors: [String]) {
        currentCorrect = correct
        currentDistractors = distractors

        // Remove old targets
        for t in targetNodes { t.node.removeFromParent() }
        targetNodes.removeAll()

        // Create letter targets inside goal
        var options = distractors.shuffled()
        if !options.contains(correct) { options.append(correct) }
        else { options.append(correct) } // ensure correct is in
        // Deduplicate and limit
        var seen = Set<String>()
        var unique: [String] = []
        for o in options {
            if !seen.contains(o) { seen.insert(o); unique.append(o) }
            if unique.count >= distractors.count + 1 { break }
        }
        unique.shuffle()

        let goalW = size.width * 0.7
        let goalH = size.height * 0.16
        let goalX = size.width / 2
        let goalY = size.height * 0.78

        let cols = unique.count <= 4 ? 2 : 3
        let rows = (unique.count + cols - 1) / cols
        let cellW = (goalW - 20) / CGFloat(cols)
        let cellH = (goalH - 20) / CGFloat(rows)

        for (idx, char) in unique.enumerated() {
            let col = idx % cols
            let row = idx / cols
            let x = goalX - goalW/2 + 10 + cellW * CGFloat(col) + cellW / 2
            let y = goalY + 10 + cellH * CGFloat(row) + cellH / 2

            let isCorrect = char == correct
            let target = SKNode()
            target.position = CGPoint(x: x, y: y)
            target.zPosition = 7

            // Target background
            let bg = SKShapeNode(rectOf: CGSize(width: cellW - 8, height: cellH - 6), cornerRadius: 8)
            bg.fillColor = UIColor(white: 1, alpha: 0.15)
            bg.strokeColor = .white.withAlphaComponent(0.4)
            bg.lineWidth = 2
            target.addChild(bg)

            // Letter
            let label = SKLabelNode(text: char)
            label.fontName = "AvenirNext-Heavy"
            label.fontSize = 30
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            target.addChild(label)

            // Glow for correct (subtle)
            if isCorrect {
                let glow = SKShapeNode(rectOf: CGSize(width: cellW - 4, height: cellH - 2), cornerRadius: 10)
                glow.fillColor = .clear
                glow.strokeColor = UIColor.green.withAlphaComponent(0.0) // hidden, revealed on hover
                glow.glowWidth = 0
                glow.name = "correctGlow"
                target.addChild(glow)
            }

            addChild(target)
            targetNodes.append((node: target, character: char, isCorrect: isCorrect))
        }

        // Reset ball and goalkeeper
        resetBall()
        canKick = true
    }

    private func resetBall() {
        guard ball != nil, goalkeeper != nil else { return }
        ball.removeAllActions()
        ball.position = CGPoint(x: size.width / 2, y: size.height * 0.22)
        ball.setScale(1.0)
        ball.alpha = 1.0
        ballResting = true

        goalkeeper.removeAction(forKey: "sway")
        goalkeeper.position = CGPoint(x: size.width / 2, y: size.height * 0.78 + 10)
        startGoalkeeperSway()
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard canKick, let touch = touches.first else { return }
        let loc = touch.location(in: self)

        // Find which target was tapped
        for target in targetNodes {
            let dist = hypot(loc.x - target.node.position.x, loc.y - target.node.position.y)
            if dist < 45 {
                kickBall(to: target)
                return
            }
        }
    }

    // MARK: - Kick

    private func kickBall(to target: (node: SKNode, character: String, isCorrect: Bool)) {
        canKick = false
        ballResting = false
        goalkeeper.removeAction(forKey: "sway")

        let targetPos = target.node.position
        let isCorrect = target.isCorrect

        // Goalkeeper reaction
        if isCorrect {
            // Dive WRONG way
            let wrongX = targetPos.x > size.width / 2
                ? size.width / 2 - size.width * 0.25
                : size.width / 2 + size.width * 0.25
            let dive = SKAction.group([
                SKAction.moveTo(x: wrongX, duration: 0.3),
                SKAction.rotate(toAngle: wrongX < size.width/2 ? 0.8 : -0.8, duration: 0.3),
            ])
            goalkeeper.run(dive)
        } else {
            // Dive TOWARD ball and catch
            let dive = SKAction.group([
                SKAction.moveTo(x: targetPos.x, duration: 0.25),
                SKAction.rotate(toAngle: targetPos.x < size.width/2 ? 0.5 : -0.5, duration: 0.25),
            ])
            goalkeeper.run(dive)
        }

        // Ball flight — arc toward target
        let midY = (ball.position.y + targetPos.y) / 2 + 30
        let path = CGMutablePath()
        path.move(to: ball.position)
        path.addQuadCurve(to: targetPos, control: CGPoint(x: targetPos.x, y: midY))

        let fly = SKAction.follow(path, asOffset: false, orientToPath: false, duration: 0.4)
        fly.timingMode = .easeOut
        let shrink = SKAction.scale(to: 0.6, duration: 0.4) // perspective
        let spin = SKAction.rotate(byAngle: .pi * 3, duration: 0.4)

        ball.run(SKAction.group([fly, shrink, spin])) { [weak self] in
            guard let self else { return }
            if isCorrect {
                self.handleGoal(at: targetPos)
            } else {
                self.handleSave(at: targetPos)
            }
        }
    }

    private func handleGoal(at pos: CGPoint) {
        // Net ripple
        if let net = goalNode.children.first(where: { ($0 as? SKShapeNode)?.fillColor == UIColor(white: 0, alpha: 0.3) }) {
            net.run(SKAction.sequence([
                SKAction.scale(to: 1.08, duration: 0.1),
                SKAction.scale(to: 1.0, duration: 0.2)
            ]))
        }

        // Goal particles
        spawnGoalParticles(at: pos)

        // Crowd goes wild
        animateCrowd()

        // Flash
        flashScreen(color: .green)

        // Camera shake (small, celebratory)
        shakeCamera(intensity: 4)

        onKickResult?(currentCorrect, true)

        // Reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.goalkeeper.run(SKAction.rotate(toAngle: 0, duration: 0.3))
        }
    }

    private func handleSave(at pos: CGPoint) {
        // Ball bounces back
        let bounceBack = SKAction.move(to: CGPoint(x: size.width / 2, y: size.height * 0.4), duration: 0.3)
        bounceBack.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: 0.2)
        ball.run(SKAction.sequence([bounceBack, fade]))

        // Flash red
        flashScreen(color: .red)
        shakeCamera(intensity: 6)

        // Save particles (fewer)
        for _ in 0..<5 {
            let p = SKShapeNode(circleOfRadius: 4)
            p.fillColor = .orange
            p.strokeColor = .clear
            p.position = pos
            p.zPosition = 20
            addChild(p)
            let move = SKAction.moveBy(x: CGFloat.random(in: -40...40), y: CGFloat.random(in: -30...30), duration: 0.3)
            p.run(SKAction.sequence([SKAction.group([move, SKAction.fadeOut(withDuration: 0.3)]), SKAction.removeFromParent()]))
        }

        onKickResult?(targetNodes.first(where: { $0.node.position == pos })?.character ?? "", false)

        // Reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            self.goalkeeper.run(SKAction.rotate(toAngle: 0, duration: 0.3))
            self.setChallenge(correct: self.currentCorrect, distractors: self.currentDistractors)
        }
    }

    // MARK: - Effects

    private func spawnGoalParticles(at pos: CGPoint) {
        let emojis = ["⚽", "🎉", "⭐", "🔥", "✨", "💫", "🏆", "👏"]
        for i in 0..<15 {
            let isEmoji = i < emojis.count
            if isEmoji {
                let label = SKLabelNode(text: emojis[i])
                label.fontSize = CGFloat.random(in: 20...36)
                label.position = pos
                label.zPosition = 25
                addChild(label)
                let angle = CGFloat.random(in: 0...(.pi * 2))
                let dist = CGFloat.random(in: 60...160)
                label.run(SKAction.sequence([
                    SKAction.group([
                        SKAction.moveBy(x: cos(angle) * dist, y: sin(angle) * dist, duration: 0.7),
                        SKAction.fadeOut(withDuration: 0.7),
                        SKAction.scale(to: 0.3, duration: 0.7)
                    ]),
                    SKAction.removeFromParent()
                ]))
            } else {
                let p = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...7))
                p.fillColor = [.green, .yellow, .white, .cyan][Int.random(in: 0...3)]
                p.strokeColor = .clear; p.position = pos; p.zPosition = 22
                addChild(p)
                let angle = CGFloat.random(in: 0...(.pi * 2))
                let dist = CGFloat.random(in: 40...100)
                p.run(SKAction.sequence([
                    SKAction.group([
                        SKAction.moveBy(x: cos(angle) * dist, y: sin(angle) * dist, duration: 0.5),
                        SKAction.fadeOut(withDuration: 0.5)
                    ]),
                    SKAction.removeFromParent()
                ]))
            }
        }
    }

    private func animateCrowd() {
        for person in crowdNodes {
            person.run(SKAction.sequence([
                SKAction.moveBy(x: 0, y: CGFloat.random(in: 5...15), duration: 0.15),
                SKAction.moveBy(x: 0, y: CGFloat.random(in: -15 ... -5), duration: 0.15),
                SKAction.moveBy(x: 0, y: CGFloat.random(in: 3...8), duration: 0.1),
                SKAction.moveBy(x: 0, y: CGFloat.random(in: -8 ... -3), duration: 0.1),
            ]))
        }
    }

    func shakeCamera(intensity: CGFloat = 6) {
        let shake = SKAction.sequence([
            SKAction.moveBy(x: intensity, y: 0, duration: 0.03),
            SKAction.moveBy(x: -intensity * 2, y: intensity * 0.5, duration: 0.03),
            SKAction.moveBy(x: intensity * 1.5, y: -intensity * 0.5, duration: 0.03),
            SKAction.moveBy(x: -intensity, y: 0, duration: 0.03),
            SKAction.moveTo(x: size.width / 2, duration: 0.03),
            SKAction.moveTo(y: size.height / 2, duration: 0.03),
        ])
        cameraNode.run(shake)
    }

    private func flashScreen(color: UIColor) {
        let flash = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        flash.fillColor = color.withAlphaComponent(0.2)
        flash.strokeColor = .clear
        flash.zPosition = 50; flash.alpha = 0
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.05),
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.removeFromParent()
        ]))
    }
}
