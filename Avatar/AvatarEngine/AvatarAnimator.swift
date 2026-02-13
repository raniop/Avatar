import SwiftUI
import Observation

enum MouthShape: String, CaseIterable {
    case closed
    case slightlyOpen
    case open
    case wide
    case round
    case smile
    case laughing
}

enum EyeState: String, CaseIterable {
    case neutral
    case happy
    case wide
    case closed
    case lookingUp
    case soft
    case wink
}

enum EyebrowState: String, CaseIterable {
    case neutral
    case raised
    case concerned
    case angry
    case excited
}

@Observable
final class AvatarAnimator {
    var currentMouthShape: MouthShape = .closed
    var currentEyeState: EyeState = .neutral
    var currentEyebrowState: EyebrowState = .neutral
    var bodyBounce: CGFloat = 0
    var bodyRotation: Double = 0
    var scale: CGFloat = 1.0
    var currentEmotion: Emotion = .neutral
    var isBlinking = false
    var emotionParticleType: EmotionParticleType?

    private var idleTimer: Timer?
    private var blinkTimer: Timer?
    private var bouncePhase: Double = 0

    func startIdleAnimation() {
        // Gentle body sway
        idleTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.bouncePhase += 0.05
            self.bodyBounce = sin(self.bouncePhase) * 3
            self.bodyRotation = sin(self.bouncePhase * 0.7) * 0.5
        }

        // Periodic blink
        scheduleNextBlink()
    }

    func stopAnimations() {
        idleTimer?.invalidate()
        idleTimer = nil
        blinkTimer?.invalidate()
        blinkTimer = nil
    }

    func updateLipSync(amplitude: Float) {
        withAnimation(.linear(duration: 0.05)) {
            switch amplitude {
            case 0..<0.05:
                currentMouthShape = .closed
            case 0.05..<0.15:
                currentMouthShape = .slightlyOpen
            case 0.15..<0.35:
                currentMouthShape = .open
            case 0.35..<0.6:
                currentMouthShape = .wide
            default:
                currentMouthShape = .round
            }
        }
    }

    func transitionToEmotion(_ emotion: Emotion) {
        currentEmotion = emotion

        withAnimation(.spring(duration: 0.3)) {
            switch emotion {
            case .happy:
                currentEyeState = .happy
                currentMouthShape = .smile
                currentEyebrowState = .neutral
                emotionParticleType = .sparkles
            case .excited:
                currentEyeState = .wide
                currentMouthShape = .wide
                currentEyebrowState = .excited
                scale = 1.05
                emotionParticleType = .stars
            case .thinking:
                currentEyeState = .lookingUp
                currentMouthShape = .slightlyOpen
                currentEyebrowState = .raised
                emotionParticleType = nil
            case .curious:
                currentEyeState = .wide
                currentMouthShape = .round
                currentEyebrowState = .raised
                emotionParticleType = nil
            case .concerned:
                currentEyeState = .soft
                currentMouthShape = .slightlyOpen
                currentEyebrowState = .concerned
                emotionParticleType = nil
            case .laughing:
                currentEyeState = .closed
                currentMouthShape = .laughing
                currentEyebrowState = .excited
                emotionParticleType = .sparkles
            case .surprised:
                currentEyeState = .wide
                currentMouthShape = .round
                currentEyebrowState = .raised
                emotionParticleType = .stars
            case .proud:
                currentEyeState = .happy
                currentMouthShape = .smile
                currentEyebrowState = .neutral
                scale = 1.03
                emotionParticleType = .hearts
            case .encouraging:
                currentEyeState = .happy
                currentMouthShape = .smile
                currentEyebrowState = .neutral
                emotionParticleType = .sparkles
            case .sad:
                currentEyeState = .soft
                currentMouthShape = .closed
                currentEyebrowState = .concerned
                emotionParticleType = nil
            case .sleepy:
                currentEyeState = .closed
                currentMouthShape = .slightlyOpen
                currentEyebrowState = .neutral
                emotionParticleType = nil
            case .neutral:
                currentEyeState = .neutral
                currentMouthShape = .closed
                currentEyebrowState = .neutral
                emotionParticleType = nil
            }
        }

        // Reset scale after bounce
        if scale != 1.0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(duration: 0.2)) {
                    self.scale = 1.0
                }
            }
        }

        // Clear particles after a delay
        if emotionParticleType != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    self.emotionParticleType = nil
                }
            }
        }
    }

    private func scheduleNextBlink() {
        let delay = Double.random(in: 2...5)
        blinkTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.performBlink()
            self.scheduleNextBlink()
        }
    }

    private func performBlink() {
        let previousEyeState = currentEyeState
        withAnimation(.easeInOut(duration: 0.1)) {
            isBlinking = true
            currentEyeState = .closed
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.1)) {
                self.isBlinking = false
                self.currentEyeState = previousEyeState
            }
        }
    }
}

enum EmotionParticleType {
    case sparkles
    case stars
    case hearts
}
