import SwiftUI

/// Simon-Says sequence game.  The game shows a sequence of button presses,
/// then the child must repeat it.  Each successful round adds one more step.
struct SequenceGameView: View {
    let theme: String
    let difficulty: GameDifficulty

    @Binding var score: Int
    @Binding var totalItems: Int
    let onGameOver: () -> Void

    // MARK: - Internal State

    @State private var buttons: [SequenceButton] = []
    @State private var sequence: [Int] = []         // The sequence of button IDs
    @State private var playerIndex = 0               // Where the player is in the sequence
    @State private var phase: SequencePhase = .watching
    @State private var currentLength = 0
    @State private var highlightedButton: Int?
    @State private var feedbackColor: Color?         // Green / Red flash
    @State private var showPhaseLabel = true

    private enum SequencePhase {
        case watching
        case repeating
        case feedback
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Phase label
            if showPhaseLabel {
                Text(phase == .watching ? "👀 Watch!" : "👆 Your turn!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            }

            // Sequence length indicator
            HStack(spacing: 6) {
                ForEach(0..<currentLength, id: \.self) { i in
                    Circle()
                        .fill(i < playerIndex && phase == .repeating ? .green : .white.opacity(0.4))
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.bottom, 8)

            // Buttons
            HStack(spacing: 16) {
                ForEach(buttons) { button in
                    SequenceButtonView(
                        button: button,
                        isLit: highlightedButton == button.id,
                        feedbackColor: highlightedButton == button.id ? feedbackColor : nil
                    ) {
                        handleTap(button.id)
                    }
                    .disabled(phase != .repeating)
                }
            }
            .padding(.horizontal, 16)

            Spacer()
            Spacer()
        }
        .onAppear { startGame() }
    }

    // MARK: - Setup

    private func startGame() {
        buttons = GameThemeConfig.sequenceButtons(for: theme)
        currentLength = difficulty.sequenceLength
        score = 0
        totalItems = difficulty.maxSequenceLength
        sequence = []

        // Build initial sequence
        for _ in 0..<currentLength {
            sequence.append(buttons.randomElement()!.id)
        }

        playSequence()
    }

    // MARK: - Show Sequence

    private func playSequence() {
        phase = .watching
        showPhaseLabel = true
        playerIndex = 0
        highlightedButton = nil

        // Animate each step with delay
        for (index, buttonId) in sequence.enumerated() {
            let showDelay = Double(index) * 0.8 + 0.6 // 0.6s initial pause
            let hideDelay = showDelay + 0.5

            DispatchQueue.main.asyncAfter(deadline: .now() + showDelay) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    highlightedButton = buttonId
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    highlightedButton = nil
                }
            }
        }

        // Switch to repeating after sequence plays
        let totalDuration = Double(sequence.count) * 0.8 + 0.8
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
            withAnimation(.spring(response: 0.3)) {
                phase = .repeating
            }
        }
    }

    // MARK: - Player Input

    private func handleTap(_ buttonId: Int) {
        guard phase == .repeating, playerIndex < sequence.count else { return }

        if sequence[playerIndex] == buttonId {
            // Correct tap
            withAnimation(.easeInOut(duration: 0.1)) {
                feedbackColor = .green
                highlightedButton = buttonId
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    highlightedButton = nil
                    feedbackColor = nil
                }
            }

            playerIndex += 1

            if playerIndex >= sequence.count {
                // Completed the current sequence!
                score += 1

                if currentLength >= difficulty.maxSequenceLength {
                    // Game over — reached max
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onGameOver()
                    }
                } else {
                    // Add one more to sequence and replay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        currentLength += 1
                        sequence.append(buttons.randomElement()!.id)
                        playSequence()
                    }
                }
            }
        } else {
            // Wrong tap — game over
            withAnimation(.easeInOut(duration: 0.1)) {
                feedbackColor = .red
                highlightedButton = buttonId
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    highlightedButton = nil
                    feedbackColor = nil
                }
                onGameOver()
            }
        }
    }
}

// MARK: - Single Button View

private struct SequenceButtonView: View {
    let button: SequenceButton
    let isLit: Bool
    let feedbackColor: Color?
    let onTap: () -> Void

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    feedbackColor ??
                    Color(hex: button.color).opacity(isLit ? 1.0 : 0.4)
                )
                .shadow(color: isLit ? Color(hex: button.color).opacity(0.6) : .clear, radius: 12)

            Text(button.emoji)
                .font(.system(size: 36))
        }
        .frame(width: 72, height: 72)
        .scaleEffect(isLit ? 1.15 : 1.0)
        .animation(.spring(response: 0.2), value: isLit)
        .onTapGesture { onTap() }
    }
}
