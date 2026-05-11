import SwiftUI
import SceneKit
import UIKit
import simd

/// Endless-runner game built with SceneKit. The child's avatar appears as the
/// runner's face (billboarded sprite mounted on a 3D body).
///
/// Controls:
/// - swipe left / right → change lane
/// - swipe up           → jump
/// - swipe down         → slide
struct TempleRunGameView: View {
    let avatarImage: UIImage?
    let difficulty: GameDifficulty
    let locale: AppLocale

    @Binding var score: Int
    @Binding var totalItems: Int
    @Binding var timeRemaining: Int
    let onTimeUp: () -> Void

    var body: some View {
        TempleRunSceneView(
            avatarImage: avatarImage,
            difficulty: difficulty,
            locale: locale,
            score: $score,
            totalItems: $totalItems,
            timeRemaining: $timeRemaining,
            onGameOver: onTimeUp
        )
        .ignoresSafeArea()
    }
}

// MARK: - SwiftUI bridge

private struct TempleRunSceneView: UIViewRepresentable {
    let avatarImage: UIImage?
    let difficulty: GameDifficulty
    let locale: AppLocale

    @Binding var score: Int
    @Binding var totalItems: Int
    @Binding var timeRemaining: Int
    let onGameOver: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            avatarImage: avatarImage,
            difficulty: difficulty,
            scoreBinding: $score,
            totalBinding: $totalItems,
            timeBinding: $timeRemaining,
            onGameOver: onGameOver
        )
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor(red: 0.96, green: 0.74, blue: 0.45, alpha: 1.0)
        view.antialiasingMode = .multisampling2X
        view.preferredFramesPerSecond = 60
        view.isPlaying = true
        view.rendersContinuously = true
        view.allowsCameraControl = false
        view.scene = context.coordinator.buildScene()
        view.delegate = context.coordinator

        for direction in [UISwipeGestureRecognizer.Direction.left,
                          .right, .up, .down] {
            let g = UISwipeGestureRecognizer(target: context.coordinator,
                                             action: #selector(Coordinator.handleSwipe(_:)))
            g.direction = direction
            g.numberOfTouchesRequired = 1
            view.addGestureRecognizer(g)
        }

        DispatchQueue.main.async {
            totalItems = difficulty.starThreshold
            timeRemaining = difficulty.timeLimit
        }

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}

// MARK: - Coordinator (game logic)

private final class Coordinator: NSObject, SCNSceneRendererDelegate {

    // Bindings
    private let scoreBinding: Binding<Int>
    private let totalBinding: Binding<Int>
    private let timeBinding: Binding<Int>
    private let onGameOver: () -> Void

    // Config
    private let avatarImage: UIImage?
    private let difficulty: GameDifficulty

    // Scene nodes
    private weak var scene: SCNScene?
    private var playerNode: SCNNode!         // root of the runner (we move this for jump/lane)
    private var characterContainer: SCNNode? // the loaded Mixamo character (skin + bones)
    private var cameraNode: SCNNode!
    private var trackSegments: [SCNNode] = []
    private var sideSegments: [SCNNode] = []
    private var obstacles: [Obstacle] = []
    private var coins: [SCNNode] = []
    private var coinsCollected: Int = 0

    // Mixamo animation library — keyed by skeleton bone name
    private var jumpAnimations: [(node: String, animation: SCNAnimation)] = []
    private var slideAnimations: [(node: String, animation: SCNAnimation)] = []
    private var deathAnimations: [(node: String, animation: SCNAnimation)] = []

    // State
    // Lane spacing is tuned for the camera's horizontal FOV in portrait orientation:
    // a phone screen is ~0.46 wide:tall, so even with a 65° vertical FOV the horizontal
    // half-FOV is only ~16°. Lanes wider than ±1.5 push the side runner off-screen.
    private let lanes: [Float] = [-1.3, 0, 1.3]
    private var currentLane = 1
    private var isJumping = false
    private var isSliding = false
    private var isAlive = true
    private var totalDistance: Float = 0
    private var timeAlive: TimeInterval = 0
    private var lastUpdate: TimeInterval = 0
    private var sessionStart: TimeInterval = 0
    private var nextSpawnAt: TimeInterval = 0
    private var nextCoinAt: TimeInterval = 0

    // Constants — character sized so it's clearly visible
    private let segmentLength: Float = 14
    private let segmentCount = 8
    private let trackWidth: Float = 5.0
    private let despawnZ: Float = 4
    private let spawnZ: Float = -90

    // Player vertical layout (y = 0 is ground)
    private let bodyHeight: Float = 1.6     // capsule height
    private let headRadius: Float = 0.45
    private let jumpHeight: Float = 2.6
    private let jumpDuration: TimeInterval = 0.65
    private let slideDuration: TimeInterval = 0.7
    private let laneChangeDuration: TimeInterval = 0.18

    init(
        avatarImage: UIImage?,
        difficulty: GameDifficulty,
        scoreBinding: Binding<Int>,
        totalBinding: Binding<Int>,
        timeBinding: Binding<Int>,
        onGameOver: @escaping () -> Void
    ) {
        self.avatarImage = avatarImage
        self.difficulty = difficulty
        self.scoreBinding = scoreBinding
        self.totalBinding = totalBinding
        self.timeBinding = timeBinding
        self.onGameOver = onGameOver
    }

    // MARK: - Scene construction

    func buildScene() -> SCNScene {
        let scene = SCNScene()
        self.scene = scene

        // Sky / fog — warm sunset
        let sky = UIColor(red: 0.96, green: 0.74, blue: 0.45, alpha: 1.0)
        scene.background.contents = sky
        scene.fogColor = sky
        scene.fogStartDistance = 35
        scene.fogEndDistance = 90
        scene.fogDensityExponent = 1.6

        // Lighting
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(white: 0.75, alpha: 1.0)
        scene.rootNode.addChildNode(ambient)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.color = UIColor(red: 1.0, green: 0.95, blue: 0.82, alpha: 1.0)
        sun.light?.intensity = 1100
        sun.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 5, 0)
        scene.rootNode.addChildNode(sun)

        // Build track and side scenery
        let stoneTexture = makeStoneTexture()
        for i in 0..<segmentCount {
            let seg = makeTrackSegment(texture: stoneTexture)
            seg.position = SCNVector3(0, 0, -Float(i) * segmentLength + despawnZ)
            scene.rootNode.addChildNode(seg)
            trackSegments.append(seg)
        }
        for i in 0..<segmentCount {
            let side = makeSideScenery()
            side.position = SCNVector3(0, 0, -Float(i) * segmentLength + despawnZ)
            scene.rootNode.addChildNode(side)
            sideSegments.append(side)
        }

        // Player
        playerNode = makePlayer()
        playerNode.position = SCNVector3(lanes[currentLane], 0, 0)
        scene.rootNode.addChildNode(playerNode)

        // Camera — fixed orientation. Looks straight down the corridor (-Z) with
        // a slight downward tilt. The player slides between lanes *inside* the
        // camera's view; the camera itself never rotates with them.
        let cam = SCNCamera()
        cam.fieldOfView = 65
        cam.zNear = 0.1
        cam.zFar = 150
        let camNode = SCNNode()
        camNode.camera = cam
        camNode.position = SCNVector3(0, 3.4, 5.4)
        camNode.eulerAngles = SCNVector3(-0.28, 0, 0)
        scene.rootNode.addChildNode(camNode)
        cameraNode = camNode

        return scene
    }

    private func makePlayer() -> SCNNode {
        let root = SCNNode()

        if let character = loadMixamoCharacter() {
            characterContainer = character
            root.addChildNode(character)
            preloadAuxiliaryAnimations()
        } else {
            // Fallback if asset loading fails: simple capsule + sphere
            let body = SCNCapsule(capRadius: 0.42, height: CGFloat(bodyHeight))
            let bodyMat = SCNMaterial()
            bodyMat.diffuse.contents = UIColor(red: 0.27, green: 0.55, blue: 0.92, alpha: 1.0)
            bodyMat.lightingModel = .lambert
            body.firstMaterial = bodyMat
            let bodyN = SCNNode(geometry: body)
            bodyN.position = SCNVector3(0, bodyHeight / 2, 0)
            root.addChildNode(bodyN)

            let head = SCNSphere(radius: CGFloat(headRadius))
            let headMat = SCNMaterial()
            headMat.diffuse.contents = UIColor(red: 1.0, green: 0.84, blue: 0.66, alpha: 1.0)
            head.firstMaterial = headMat
            let headN = SCNNode(geometry: head)
            headN.position = SCNVector3(0, bodyHeight + headRadius * 0.9, 0)
            root.addChildNode(headN)
        }

        // Soft drop shadow on the ground
        let shadow = SCNPlane(width: 1.4, height: 0.7)
        let shadowMat = SCNMaterial()
        shadowMat.diffuse.contents = UIColor(white: 0, alpha: 0.32)
        shadowMat.lightingModel = .constant
        shadow.firstMaterial = shadowMat
        let shadowN = SCNNode(geometry: shadow)
        shadowN.eulerAngles.x = -.pi / 2
        shadowN.position = SCNVector3(0, 0.02, 0)
        root.addChildNode(shadowN)

        return root
    }

    /// Loads Running.dae which contains the character mesh, skin, and a looping run animation.
    private func loadMixamoCharacter() -> SCNNode? {
        guard let scene = SCNScene(named: "art.scnassets/Running.dae") else {
            print("TempleRun: Could not load art.scnassets/Running.dae")
            return nil
        }

        let container = SCNNode()
        // Mixamo characters export at cm scale (~170 units = 170cm). Scale to ~1.8m world units.
        container.scale = SCNVector3(0.011, 0.011, 0.011)
        // Mixamo bind pose faces +Z; rotate so we see the character's back from the chase camera.
        container.eulerAngles.y = .pi

        for child in scene.rootNode.childNodes {
            container.addChildNode(child)
        }
        lockHipHorizontalDrift(in: container)
        return container
    }

    /// Mixamo "with motion" running clips translate the Hips bone forward each cycle,
    /// causing a visible "snap back" when the loop restarts. We pin the hip's local
    /// X/Z translation each frame using a transform constraint, leaving Y (vertical
    /// bob, jump squat) untouched.
    private func lockHipHorizontalDrift(in container: SCNNode) {
        guard let hip = container.childNode(withName: "mixamorig_Hips", recursively: true) else {
            return
        }
        let initialX = hip.position.x
        let initialZ = hip.position.z
        let constraint = SCNTransformConstraint(inWorldSpace: false) { _, transform in
            var t = transform
            t.m41 = initialX
            t.m43 = initialZ
            return t
        }
        hip.constraints = [constraint]
    }

    private func preloadAuxiliaryAnimations() {
        jumpAnimations  = extractAnimations(fromAsset: "JumpingUp")
        slideAnimations = extractAnimations(fromAsset: "RunningSlide")
        deathAnimations = extractAnimations(fromAsset: "FallingBackDeath")
    }

    private func extractAnimations(fromAsset name: String) -> [(node: String, animation: SCNAnimation)] {
        guard let scene = SCNScene(named: "art.scnassets/\(name).dae") else {
            print("TempleRun: Could not load art.scnassets/\(name).dae")
            return []
        }
        var result: [(String, SCNAnimation)] = []
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let nodeName = node.name else { return }
            for key in node.animationKeys {
                if let player = node.animationPlayer(forKey: key) {
                    result.append((nodeName, player.animation))
                }
            }
        }
        return result
    }

    /// Plays a one-shot Mixamo animation on top of the running base, with cross-fade.
    private func playOneShot(
        _ anims: [(node: String, animation: SCNAnimation)],
        key: String
    ) {
        guard let container = characterContainer, !anims.isEmpty else { return }
        for (nodeName, animation) in anims {
            guard let target = container.childNode(withName: nodeName, recursively: true),
                  let copy = animation.copy() as? SCNAnimation else { continue }
            copy.repeatCount = 1
            copy.isRemovedOnCompletion = true
            copy.blendInDuration = 0.12
            copy.blendOutDuration = 0.18
            target.addAnimation(copy, forKey: key)
        }
    }

    private func makeTrackSegment(texture: UIImage) -> SCNNode {
        let path = SCNBox(width: CGFloat(trackWidth), height: 0.4,
                          length: CGFloat(segmentLength), chamferRadius: 0)
        let mat = SCNMaterial()
        mat.diffuse.contents = texture
        mat.diffuse.wrapS = .repeat
        mat.diffuse.wrapT = .repeat
        mat.diffuse.contentsTransform = SCNMatrix4MakeScale(2, 4, 1)
        mat.lightingModel = .lambert
        path.firstMaterial = mat

        let node = SCNNode(geometry: path)
        node.position.y = -0.2

        // Lane separators — positioned between the three lanes (lanes are at -1.3, 0, 1.3)
        for x: Float in [-0.65, 0.65] {
            let line = SCNBox(width: 0.04, height: 0.42,
                              length: CGFloat(segmentLength), chamferRadius: 0)
            let lm = SCNMaterial()
            lm.diffuse.contents = UIColor(white: 0.18, alpha: 0.45)
            lm.lightingModel = .constant
            line.firstMaterial = lm
            let ln = SCNNode(geometry: line)
            ln.position = SCNVector3(x, 0, 0)
            node.addChildNode(ln)
        }

        return node
    }

    private func makeSideScenery() -> SCNNode {
        let group = SCNNode()
        let wallGeom = SCNBox(width: 4, height: 5,
                              length: CGFloat(segmentLength), chamferRadius: 0.3)
        let wallMat = SCNMaterial()
        wallMat.diffuse.contents = UIColor(red: 0.20, green: 0.45, blue: 0.22, alpha: 1.0)
        wallMat.lightingModel = .lambert

        let leftWall = SCNNode(geometry: wallGeom)
        leftWall.geometry?.firstMaterial = wallMat
        leftWall.position = SCNVector3(-trackWidth / 2 - 2.2, 2.2, 0)
        group.addChildNode(leftWall)

        let rightWall = SCNNode(geometry: wallGeom.copy() as? SCNGeometry ?? wallGeom)
        rightWall.geometry?.firstMaterial = wallMat
        rightWall.position = SCNVector3(trackWidth / 2 + 2.2, 2.2, 0)
        group.addChildNode(rightWall)

        // A single tall tree on each side per segment — consistent, not random
        for side: Float in [-1, 1] {
            let trunk = SCNCylinder(radius: 0.22, height: 4.0)
            let trunkMat = SCNMaterial()
            trunkMat.diffuse.contents = UIColor(red: 0.34, green: 0.22, blue: 0.12, alpha: 1.0)
            trunkMat.lightingModel = .lambert
            trunk.firstMaterial = trunkMat
            let trunkN = SCNNode(geometry: trunk)
            trunkN.position = SCNVector3(side * (trackWidth / 2 + 0.7), 2.0, 0)
            group.addChildNode(trunkN)

            let leaves = SCNSphere(radius: 1.1)
            let leafMat = SCNMaterial()
            leafMat.diffuse.contents = UIColor(red: 0.24, green: 0.58, blue: 0.28, alpha: 1.0)
            leafMat.lightingModel = .lambert
            leaves.firstMaterial = leafMat
            let leafN = SCNNode(geometry: leaves)
            leafN.position = SCNVector3(trunkN.position.x, 4.2, 0)
            group.addChildNode(leafN)
        }

        return group
    }

    private func makeStoneTexture() -> UIImage {
        let size = CGSize(width: 256, height: 256)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(red: 0.78, green: 0.65, blue: 0.48, alpha: 1.0).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            for _ in 0..<300 {
                let x = CGFloat.random(in: 0..<size.width)
                let y = CGFloat.random(in: 0..<size.height)
                let r = CGFloat.random(in: 0.5...2.2)
                let v = CGFloat.random(in: 0.35...0.85)
                UIColor(white: v, alpha: 0.18).setFill()
                ctx.fill(CGRect(x: x, y: y, width: r, height: r))
            }

            // Stone edge — single horizontal line at top of texture (suggests bricks)
            UIColor(white: 0.18, alpha: 0.4).setStroke()
            let cg = ctx.cgContext
            cg.setLineWidth(1.2)
            cg.move(to: CGPoint(x: 0, y: 8))
            cg.addLine(to: CGPoint(x: size.width, y: 8))
            cg.move(to: CGPoint(x: 0, y: size.height - 8))
            cg.addLine(to: CGPoint(x: size.width, y: size.height - 8))
            cg.strokePath()
        }
    }

    // MARK: - Spawning

    /// Total height of the player when standing (used to decide what
    /// obstacles can pass overhead when sliding).
    private var standingHeight: Float { bodyHeight + headRadius * 1.8 }

    private func spawnObstaclePattern(at z: Float) {
        guard let scene else { return }
        let roll = Int.random(in: 0..<10)

        if roll < 3 {
            // SLIDE banner — bottom at y=1.55 (taller than slid player at ~0.9)
            // Player normal-height head reaches ~standingHeight ≈ 2.4 — collides; sliding clears.
            let banner = SCNBox(width: CGFloat(trackWidth + 0.4), height: 0.5,
                                length: 0.6, chamferRadius: 0.05)
            let mat = SCNMaterial()
            mat.diffuse.contents = UIColor(red: 0.78, green: 0.20, blue: 0.20, alpha: 1.0)
            mat.lightingModel = .lambert
            banner.firstMaterial = mat
            let node = SCNNode(geometry: banner)
            node.position = SCNVector3(0, 1.85, z)

            // Two posts holding it up
            for x in [-trackWidth / 2 - 0.05, trackWidth / 2 + 0.05] {
                let post = SCNBox(width: 0.18, height: 1.85,
                                  length: 0.18, chamferRadius: 0)
                let postMat = SCNMaterial()
                postMat.diffuse.contents = UIColor(red: 0.40, green: 0.28, blue: 0.16, alpha: 1.0)
                post.firstMaterial = postMat
                let postN = SCNNode(geometry: post)
                postN.position = SCNVector3(x, -0.93, 0)
                node.addChildNode(postN)
            }

            scene.rootNode.addChildNode(node)
            obstacles.append(Obstacle(node: node, kind: .banner))

        } else if roll < 6 {
            // JUMP rock — single lane only (so lane-changing also works)
            let lane = Int.random(in: 0...2)
            let rock = SCNBox(width: 1.3, height: 0.8,
                              length: 1.0, chamferRadius: 0.2)
            let mat = SCNMaterial()
            mat.diffuse.contents = UIColor(red: 0.48, green: 0.42, blue: 0.36, alpha: 1.0)
            mat.lightingModel = .lambert
            rock.firstMaterial = mat
            let node = SCNNode(geometry: rock)
            node.position = SCNVector3(lanes[lane], 0.4, z)
            scene.rootNode.addChildNode(node)
            obstacles.append(Obstacle(node: node, kind: .rock))

        } else {
            // LANE CHANGE pillar — tall, blocks an entire lane
            let lane = Int.random(in: 0...2)
            let pillar = SCNBox(width: 1.2, height: 3.2,
                                length: 0.8, chamferRadius: 0.08)
            let mat = SCNMaterial()
            mat.diffuse.contents = UIColor(red: 0.55, green: 0.42, blue: 0.30, alpha: 1.0)
            mat.lightingModel = .lambert
            pillar.firstMaterial = mat
            let node = SCNNode(geometry: pillar)
            node.position = SCNVector3(lanes[lane], 1.6, z)

            let cap = SCNBox(width: 1.55, height: 0.3,
                             length: 1.05, chamferRadius: 0.05)
            let capMat = SCNMaterial()
            capMat.diffuse.contents = UIColor(red: 0.42, green: 0.32, blue: 0.22, alpha: 1.0)
            cap.firstMaterial = capMat
            let capNode = SCNNode(geometry: cap)
            capNode.position = SCNVector3(0, 1.75, 0)
            node.addChildNode(capNode)

            scene.rootNode.addChildNode(node)
            obstacles.append(Obstacle(node: node, kind: .pillar))
        }
    }

    private func spawnCoinRow(at z: Float) {
        guard let scene else { return }
        let lane = Int.random(in: 0...2)
        for i in 0..<5 {
            let sphere = SCNSphere(radius: 0.32)
            let mat = SCNMaterial()
            mat.diffuse.contents = UIColor(red: 1.0, green: 0.85, blue: 0.20, alpha: 1.0)
            mat.emission.contents = UIColor(red: 0.55, green: 0.45, blue: 0.0, alpha: 1.0)
            mat.lightingModel = .lambert
            sphere.firstMaterial = mat
            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3(lanes[lane], 1.0, z - Float(i) * 1.7)
            let spin = SCNAction.repeatForever(
                SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 1.4)
            )
            node.runAction(spin)
            scene.rootNode.addChildNode(node)
            coins.append(node)
        }
    }

    // MARK: - Render loop

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard isAlive, scene != nil else { return }

        if sessionStart == 0 {
            sessionStart = time
            lastUpdate = time
            // First obstacle no earlier than 4 seconds — give the player time to orient
            nextSpawnAt = time + 4.0
            nextCoinAt = time + 3.0
        }
        let dt = Float(min(0.05, time - lastUpdate))
        lastUpdate = time
        timeAlive = time - sessionStart

        let speed = Float(difficulty.baseSpeed + difficulty.speedRamp * timeAlive)
        let advance = speed * dt
        totalDistance += advance

        for seg in trackSegments {
            seg.position.z += advance
            if seg.position.z > despawnZ + segmentLength {
                seg.position.z -= Float(segmentCount) * segmentLength
            }
        }
        for seg in sideSegments {
            seg.position.z += advance
            if seg.position.z > despawnZ + segmentLength {
                seg.position.z -= Float(segmentCount) * segmentLength
            }
        }
        for obs in obstacles {
            obs.node.position.z += advance
        }
        for coin in coins {
            coin.position.z += advance
        }

        // Cull off-screen items
        obstacles.removeAll { obs in
            if obs.node.position.z > despawnZ + 4 {
                obs.node.removeFromParentNode()
                return true
            }
            return false
        }
        coins.removeAll { coin in
            if coin.position.z > despawnZ + 4 {
                coin.removeFromParentNode()
                return true
            }
            return false
        }

        // Spawning cadence — tightens slightly as the run gets longer
        let spawnGap = max(0.7, difficulty.spawnInterval - timeAlive * 0.012)
        if time >= nextSpawnAt {
            spawnObstaclePattern(at: spawnZ)
            nextSpawnAt = time + spawnGap
        }
        if time >= nextCoinAt {
            spawnCoinRow(at: spawnZ - 6)
            nextCoinAt = time + spawnGap * 1.5
        }

        // Collisions — use the player's *visual* AABB
        let p = playerNode.presentation.position
        let phLow = p.y                                         // feet
        let phHigh = p.y + (isSliding ? 1.0 : standingHeight)   // head top
        let pMin = simd_float3(p.x - 0.45, phLow, p.z - 0.45)
        let pMax = simd_float3(p.x + 0.45, phHigh, p.z + 0.45)

        for obs in obstacles {
            let op = obs.node.presentation.position
            let half: simd_float3
            switch obs.kind {
            case .banner: half = simd_float3(trackWidth / 2 + 0.2, 0.25, 0.3)
            case .rock:   half = simd_float3(0.65, 0.4, 0.5)
            case .pillar: half = simd_float3(0.6, 1.6, 0.4)
            }
            let oMin = simd_float3(op.x - half.x, op.y - half.y, op.z - half.z)
            let oMax = simd_float3(op.x + half.x, op.y + half.y, op.z + half.z)
            if aabbOverlap(aMin: pMin, aMax: pMax, bMin: oMin, bMax: oMax) {
                gameOver()
                return
            }
        }

        // Coin pickup
        coins.removeAll { coin in
            let cp = coin.presentation.position
            let dx = cp.x - p.x
            let dy = cp.y - (p.y + 1.0)
            let dz = cp.z - p.z
            if (dx * dx + dy * dy + dz * dz) < 0.85 {
                coin.removeFromParentNode()
                self.coinsCollected += 1
                return true
            }
            return false
        }

        // HUD updates — distance + 3·coins for a mild reward
        let dist = Int(totalDistance)
        let scoreValue = dist + coinsCollected * 3
        let timeLeft = max(0, difficulty.timeLimit - Int(timeAlive))
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isAlive else { return }
            self.scoreBinding.wrappedValue = scoreValue
            self.timeBinding.wrappedValue = timeLeft
        }

        if timeLeft <= 0 {
            gameOver()
        }
    }

    private func aabbOverlap(aMin: simd_float3, aMax: simd_float3,
                             bMin: simd_float3, bMax: simd_float3) -> Bool {
        return (aMin.x <= bMax.x && aMax.x >= bMin.x) &&
               (aMin.y <= bMax.y && aMax.y >= bMin.y) &&
               (aMin.z <= bMax.z && aMax.z >= bMin.z)
    }

    private func gameOver() {
        guard isAlive else { return }
        isAlive = false

        // Play the Mixamo death animation in place — no extra translation.
        playOneShot(deathAnimations, key: "death")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            self?.onGameOver()
        }
    }

    // MARK: - Input

    @objc func handleSwipe(_ g: UISwipeGestureRecognizer) {
        guard isAlive else { return }
        switch g.direction {
        case .left:  changeLane(by: -1)
        case .right: changeLane(by: +1)
        case .up:    jump()
        case .down:  slide()
        default: break
        }
    }

    private func changeLane(by delta: Int) {
        let next = max(0, min(2, currentLane + delta))
        guard next != currentLane else { return }
        currentLane = next
        let target = lanes[currentLane]
        let move = SCNAction.move(to: SCNVector3(target,
                                                 playerNode.position.y,
                                                 playerNode.position.z),
                                  duration: laneChangeDuration)
        move.timingMode = .easeOut
        playerNode.runAction(move)
    }

    private func jump() {
        guard !isJumping, !isSliding else { return }
        isJumping = true

        // Mixamo jump animation (one-shot pose layered over the running base)
        playOneShot(jumpAnimations, key: "jump")

        // Physically lift the node so collision boxes clear low obstacles
        let up = SCNAction.moveBy(x: 0, y: CGFloat(jumpHeight), z: 0,
                                  duration: jumpDuration / 2)
        up.timingMode = .easeOut
        let down = SCNAction.moveBy(x: 0, y: CGFloat(-jumpHeight), z: 0,
                                    duration: jumpDuration / 2)
        down.timingMode = .easeIn
        playerNode.runAction(SCNAction.sequence([up, down])) { [weak self] in
            self?.isJumping = false
        }
    }

    private func slide() {
        guard !isSliding, !isJumping else { return }
        isSliding = true

        // Mixamo slide animation
        playOneShot(slideAnimations, key: "slide")

        // Hold the slide flag for the duration so collision uses the shorter AABB
        DispatchQueue.main.asyncAfter(deadline: .now() + slideDuration) { [weak self] in
            self?.isSliding = false
        }
    }

    // MARK: - Types

    private enum ObstacleKind { case rock, banner, pillar }
    private struct Obstacle {
        let node: SCNNode
        let kind: ObstacleKind
    }
}
