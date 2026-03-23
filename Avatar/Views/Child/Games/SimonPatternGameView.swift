import SwiftUI

struct SimonPatternGameView: View {
    let theme: String
    let difficulty: GameDifficulty
    @Binding var score: Int
    @Binding var totalItems: Int
    let onGameOver: () -> Void

    @State private var buttons: [SimonButton] = []
    @State private var sequence: [Int] = []
    @State private var playerIndex = 0
    @State private var isShowingSequence = false
    @State private var currentLength: Int
    @State private var feedback: String? = nil

    init(theme: String, difficulty: GameDifficulty, score: Binding<Int>, totalItems: Binding<Int>, onGameOver: @escaping () -> Void) {
        self.theme = theme
        self.difficulty = difficulty
        self._score = score
        self._totalItems = totalItems
        self.onGameOver = onGameOver
        self._currentLength = State(initialValue: difficulty.sequenceLength)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Status
            if isShowingSequence {
                Text("👀")
                    .font(.system(size: 48))
                    .transition(.scale)
            } else {
                Text("👆")
                    .font(.system(size: 48))
                    .transition(.scale)
            }

            if let feedback {
                Text(feedback)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            }

            // 2x2 Button Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(buttons) { button in
                    Button {
                        handleTap(button.id)
                    } label: {
                        VStack(spacing: 8) {
                            Text(button.emoji)
                                .font(.system(size: 44))
                            Text(button.isLit ? "●" : "")
                                .font(.system(size: 12))
                                .foregroundStyle(.white)
                                .frame(height: 12)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(button.color.opacity(button.isLit ? 1.0 : 0.4))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.white.opacity(button.isLit ? 0.8 : 0.2), lineWidth: 3)
                        )
                        .scaleEffect(button.isLit ? 1.08 : 1.0)
                        .animation(.spring(response: 0.2), value: button.isLit)
                    }
                    .disabled(isShowingSequence)
                }
            }
            .padding(.horizontal, 32)

            // Progress
            HStack(spacing: 4) {
                ForEach(0..<currentLength, id: \.self) { i in
                    Circle()
                        .fill(i < playerIndex ? Color.green : Color.white.opacity(0.3))
                        .frame(width: 12, height: 12)
                }
            }
            .padding(.top, 8)

            Spacer()
        }
        .onAppear {
            setupGame()
        }
    }

    private func setupGame() {
        let colors = GameThemeConfig.simonColors(for: theme)
        buttons = colors.enumerated().map { i, c in
            SimonButton(id: i, color: c.color, emoji: c.emoji)
        }
        totalItems = difficulty.maxSequenceLength
        score = 0
        generateSequence()
        showSequence()
    }

    private func generateSequence() {
        while sequence.count < difficulty.maxSequenceLength {
            sequence.append(Int.random(in: 0..<buttons.count))
        }
    }

    private func showSequence() {
        isShowingSequence = true
        playerIndex = 0
        let toShow = Array(sequence.prefix(currentLength))

        for (index, buttonId) in toShow.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.6) {
                lightButton(buttonId)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Double(toShow.count) * 0.6 + 0.3) {
            isShowingSequence = false
        }
    }

    private func lightButton(_ id: Int) {
        guard let idx = buttons.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            buttons[idx].isLit = true
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeInOut(duration: 0.15)) {
                buttons[idx].isLit = false
            }
        }
    }

    private func handleTap(_ buttonId: Int) {
        guard !isShowingSequence else { return }

        lightButton(buttonId)

        let expected = sequence[playerIndex]
        if buttonId == expected {
            playerIndex += 1
            if playerIndex >= currentLength {
                // Completed this sequence
                score += 1
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation { feedback = "✅" }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation { feedback = nil }
                }

                if currentLength >= difficulty.maxSequenceLength {
                    // Won the game
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        onGameOver()
                    }
                } else {
                    currentLength += 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        showSequence()
                    }
                }
            }
        } else {
            // Wrong button - game over
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            withAnimation { feedback = "❌" }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                onGameOver()
            }
        }
    }
}
