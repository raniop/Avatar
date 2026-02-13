import SwiftUI

struct AvatarDisplayView: View {
    let config: AvatarConfig?
    @Bindable var animator: AvatarAnimator
    var size: CGFloat = 280

    var body: some View {
        ZStack {
            if let config {
                // Shadow
                Ellipse()
                    .fill(.black.opacity(0.1))
                    .frame(width: size * 0.6, height: size * 0.08)
                    .offset(y: size * 0.45)

                // Body group
                VStack(spacing: 0) {
                    // Head + Face
                    ZStack {
                        // Head shape
                        Circle()
                            .fill(config.skinToneColor)
                            .frame(width: size * 0.55, height: size * 0.55)

                        // Eyes
                        HStack(spacing: size * 0.12) {
                            EyeView(state: animator.currentEyeState, color: config.eyeColorValue, size: size * 0.08)
                            EyeView(state: animator.currentEyeState, color: config.eyeColorValue, size: size * 0.08)
                        }
                        .offset(y: -size * 0.02)

                        // Eyebrows
                        HStack(spacing: size * 0.1) {
                            EyebrowView(state: animator.currentEyebrowState, size: size * 0.06)
                            EyebrowView(state: animator.currentEyebrowState, size: size * 0.06)
                                .scaleEffect(x: -1)
                        }
                        .offset(y: -size * 0.08)

                        // Mouth
                        MouthView(shape: animator.currentMouthShape, size: size * 0.12)
                            .offset(y: size * 0.08)

                        // Hair
                        HairView(style: config.hairStyle, color: config.hairColorValue, size: size * 0.55)
                    }

                    // Body
                    RoundedRectangle(cornerRadius: size * 0.1)
                        .fill(AppTheme.Colors.primary.opacity(0.8))
                        .frame(width: size * 0.45, height: size * 0.35)
                        .offset(y: -size * 0.03)
                }
                .scaleEffect(animator.scale)
                .offset(y: animator.bodyBounce)
                .rotationEffect(.degrees(animator.bodyRotation))
            } else {
                // Placeholder when no config
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: size * 0.6, height: size * 0.6)
                    .overlay(
                        Image(systemName: "face.smiling")
                            .font(.system(size: size * 0.25))
                            .foregroundStyle(.white.opacity(0.5))
                    )
            }

            // Emotion particles
            if let particleType = animator.emotionParticleType {
                EmotionParticlesOverlay(type: particleType, size: size)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            animator.startIdleAnimation()
        }
        .onDisappear {
            animator.stopAnimations()
        }
    }
}

// MARK: - Sub-components

struct EyeView: View {
    let state: EyeState
    let color: Color
    let size: CGFloat

    var body: some View {
        Group {
            switch state {
            case .neutral:
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .overlay(
                        Circle().fill(.white).frame(width: size * 0.35, height: size * 0.35)
                            .offset(x: size * 0.1, y: -size * 0.1)
                    )
            case .happy:
                // Curved happy eye (arc)
                Capsule()
                    .fill(color)
                    .frame(width: size, height: size * 0.3)
            case .wide:
                Circle()
                    .fill(color)
                    .frame(width: size * 1.2, height: size * 1.2)
                    .overlay(
                        Circle().fill(.white).frame(width: size * 0.4, height: size * 0.4)
                            .offset(x: size * 0.1, y: -size * 0.1)
                    )
            case .closed:
                Capsule()
                    .fill(color)
                    .frame(width: size, height: size * 0.15)
            case .lookingUp:
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .offset(y: -size * 0.15)
            case .soft:
                Ellipse()
                    .fill(color)
                    .frame(width: size, height: size * 0.7)
            case .wink:
                Capsule()
                    .fill(color)
                    .frame(width: size * 0.8, height: size * 0.15)
            }
        }
    }
}

struct EyebrowView: View {
    let state: EyebrowState
    let size: CGFloat

    var body: some View {
        Capsule()
            .fill(.brown.opacity(0.7))
            .frame(width: size * 1.5, height: size * 0.25)
            .rotationEffect(.degrees(eyebrowAngle))
    }

    private var eyebrowAngle: Double {
        switch state {
        case .neutral: 0
        case .raised: -10
        case .concerned: 10
        case .angry: 15
        case .excited: -15
        }
    }
}

struct MouthView: View {
    let shape: MouthShape
    let size: CGFloat

    var body: some View {
        Group {
            switch shape {
            case .closed:
                Capsule()
                    .fill(.pink.opacity(0.6))
                    .frame(width: size, height: size * 0.15)
            case .slightlyOpen:
                Ellipse()
                    .fill(.pink.opacity(0.6))
                    .frame(width: size * 0.6, height: size * 0.3)
            case .open:
                Ellipse()
                    .fill(.pink.opacity(0.6))
                    .frame(width: size * 0.7, height: size * 0.5)
            case .wide:
                Ellipse()
                    .fill(.pink.opacity(0.6))
                    .frame(width: size, height: size * 0.6)
            case .round:
                Circle()
                    .fill(.pink.opacity(0.6))
                    .frame(width: size * 0.5, height: size * 0.5)
            case .smile:
                Capsule()
                    .fill(.pink.opacity(0.6))
                    .frame(width: size, height: size * 0.25)
                    .offset(y: size * 0.05)
            case .laughing:
                Ellipse()
                    .fill(.pink.opacity(0.6))
                    .frame(width: size, height: size * 0.7)
            }
        }
    }
}

struct HairView: View {
    let style: HairStyle
    let color: Color
    let size: CGFloat

    var body: some View {
        Group {
            switch style {
            case .short:
                Capsule()
                    .fill(color)
                    .frame(width: size * 1.05, height: size * 0.4)
                    .offset(y: -size * 0.3)
            case .medium:
                Capsule()
                    .fill(color)
                    .frame(width: size * 1.1, height: size * 0.5)
                    .offset(y: -size * 0.25)
            case .long:
                VStack(spacing: 0) {
                    Capsule()
                        .fill(color)
                        .frame(width: size * 1.1, height: size * 0.5)
                    Rectangle()
                        .fill(color)
                        .frame(width: size * 0.9, height: size * 0.4)
                }
                .offset(y: -size * 0.25)
            case .curly:
                ZStack {
                    ForEach(0..<8, id: \.self) { i in
                        Circle()
                            .fill(color)
                            .frame(width: size * 0.2, height: size * 0.2)
                            .offset(
                                x: cos(Double(i) * .pi / 4) * size * 0.4,
                                y: sin(Double(i) * .pi / 4) * size * 0.35 - size * 0.15
                            )
                    }
                }
            case .braids:
                HStack(spacing: size * 0.3) {
                    Capsule().fill(color).frame(width: size * 0.12, height: size * 0.5)
                    Capsule().fill(color).frame(width: size * 0.12, height: size * 0.5)
                }
                .offset(y: size * 0.1)
            case .ponytail:
                VStack(spacing: 0) {
                    Capsule().fill(color).frame(width: size * 1.05, height: size * 0.35)
                    Capsule().fill(color).frame(width: size * 0.15, height: size * 0.35)
                        .offset(x: size * 0.25)
                }
                .offset(y: -size * 0.25)
            case .buzz:
                Capsule()
                    .fill(color.opacity(0.5))
                    .frame(width: size * 1.02, height: size * 0.3)
                    .offset(y: -size * 0.28)
            case .afro:
                Circle()
                    .fill(color)
                    .frame(width: size * 1.3, height: size * 1.1)
                    .offset(y: -size * 0.15)
            }
        }
    }
}

struct EmotionParticlesOverlay: View {
    let type: EmotionParticleType
    let size: CGFloat

    @State private var particles: [ParticleData] = []

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Text(particle.emoji)
                    .font(.system(size: particle.fontSize))
                    .offset(x: particle.x, y: particle.y)
                    .opacity(particle.opacity)
            }
        }
        .onAppear { spawnParticles() }
    }

    private func spawnParticles() {
        let emoji: String
        switch type {
        case .sparkles: emoji = "✨"
        case .stars: emoji = "⭐"
        case .hearts: emoji = "❤️"
        }

        for i in 0..<6 {
            let delay = Double(i) * 0.1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let particle = ParticleData(
                    emoji: emoji,
                    x: CGFloat.random(in: -size * 0.4...size * 0.4),
                    y: CGFloat.random(in: -size * 0.3...size * 0.1),
                    fontSize: CGFloat.random(in: 14...24),
                    opacity: 1.0
                )
                particles.append(particle)

                withAnimation(.easeOut(duration: 1.0)) {
                    if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                        particles[index].y -= 40
                        particles[index].opacity = 0
                    }
                }
            }
        }
    }
}

struct ParticleData: Identifiable {
    let id = UUID()
    let emoji: String
    var x: CGFloat
    var y: CGFloat
    let fontSize: CGFloat
    var opacity: Double
}
