import SwiftUI

/// Wraps the AI-generated avatar image with lively animations:
/// gentle floating, a waving hand on appear, and sparkle particles.
struct AnimatedAvatarView: View {
    let image: UIImage
    var size: CGFloat = 200

    // MARK: - Animation State

    @State private var isFloating = false
    @State private var waveAngle: Double = 0
    @State private var showWave = false
    @State private var waveOpacity: Double = 1
    @State private var sparklePhases: [Bool] = [false, false, false]

    var body: some View {
        ZStack {
            // Sparkle particles around the avatar
            sparkles

            // Main avatar image with float + breathing
            Circle()
                .fill(.clear)
                .frame(width: size, height: size)
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 3))
            .shadow(color: .black.opacity(0.2), radius: 10)
            .offset(y: isFloating ? -4 : 4)
            .scaleEffect(isFloating ? 1.02 : 1.0)

            // Waving hand emoji
            if showWave {
                Text("👋")
                    .font(.system(size: size * 0.22))
                    .rotationEffect(.degrees(waveAngle), anchor: .bottomTrailing)
                    .offset(x: size * 0.35, y: size * 0.25)
                    .opacity(waveOpacity)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: size + 60, height: size + 30) // Extra horizontal space for sparkles + hand, tight bottom for name
        .onAppear {
            startFloating()
            startWaving()
            startSparkles()
        }
    }

    // MARK: - Sparkles

    private var sparkles: some View {
        let positions: [(x: CGFloat, y: CGFloat)] = [
            (-size * 0.42, -size * 0.2),
            (size * 0.38, -size * 0.35),
            (size * 0.1, size * 0.42),
        ]

        return ForEach(0..<3, id: \.self) { i in
            Text("✨")
                .font(.system(size: 16))
                .opacity(sparklePhases[i] ? 1.0 : 0.0)
                .scaleEffect(sparklePhases[i] ? 1.0 : 0.3)
                .offset(x: positions[i].x, y: positions[i].y)
        }
    }

    // MARK: - Animation Triggers

    private func startFloating() {
        withAnimation(
            .easeInOut(duration: 2.5)
            .repeatForever(autoreverses: true)
        ) {
            isFloating = true
        }
    }

    private func startWaving() {
        // Show the hand
        withAnimation(.spring(duration: 0.4)) {
            showWave = true
        }

        // Wave back and forth (3 cycles)
        let waveDuration = 0.3
        let totalWaves = 6 // 3 full back-and-forth cycles

        for i in 0..<totalWaves {
            let delay = 0.4 + Double(i) * waveDuration
            let angle: Double = (i % 2 == 0) ? 25 : -25

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: waveDuration)) {
                    waveAngle = angle
                }
            }
        }

        // Return to center
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(totalWaves) * waveDuration) {
            withAnimation(.easeInOut(duration: 0.2)) {
                waveAngle = 0
            }
        }

        // Fade out after waving
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeOut(duration: 0.8)) {
                waveOpacity = 0
            }
        }

        // Remove from view
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            showWave = false
        }
    }

    private func startSparkles() {
        // Stagger sparkle animations with different delays
        for i in 0..<3 {
            let initialDelay = Double(i) * 1.2
            startSparkleLoop(index: i, delay: initialDelay)
        }
    }

    private func startSparkleLoop(index: Int, delay: TimeInterval) {
        // Fade in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeIn(duration: 0.6)) {
                sparklePhases[index] = true
            }
        }

        // Fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 1.2) {
            withAnimation(.easeOut(duration: 0.6)) {
                sparklePhases[index] = false
            }
        }

        // Repeat the cycle
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 3.0) {
            startSparkleLoop(index: index, delay: 0)
        }
    }
}
