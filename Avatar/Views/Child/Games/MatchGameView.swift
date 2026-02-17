import SwiftUI

/// Memory card matching game.  A grid of face-down emoji cards; the child
/// flips two at a time and tries to find all matching pairs before time runs out.
struct MatchGameView: View {
    let theme: String
    let difficulty: GameDifficulty

    @Binding var score: Int
    @Binding var totalItems: Int
    @Binding var timeRemaining: Int
    let onTimeUp: () -> Void
    let onAllMatched: () -> Void

    // MARK: - Internal State

    @State private var cards: [MatchCard] = []
    @State private var firstFlipped: UUID?
    @State private var isChecking = false
    @State private var clockTimer: Timer?

    private var pairCount: Int {
        (difficulty.gridRows * difficulty.gridCols) / 2
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: difficulty.gridCols)
    }

    // MARK: - Body

    var body: some View {
        VStack {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(cards) { card in
                    MatchCardView(card: card) {
                        flipCard(card)
                    }
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { startGame() }
        .onDisappear { clockTimer?.invalidate() }
    }

    // MARK: - Setup

    private func startGame() {
        score = 0
        let emojis = GameThemeConfig.matchItems(for: theme, pairCount: pairCount)
        totalItems = emojis.count  // number of pairs
        timeRemaining = difficulty.timeLimit

        // Build card pairs and shuffle
        var deck: [MatchCard] = []
        for (index, emoji) in emojis.enumerated() {
            deck.append(MatchCard(id: UUID(), emoji: emoji, pairIndex: index))
            deck.append(MatchCard(id: UUID(), emoji: emoji, pairIndex: index))
        }
        cards = deck.shuffled()

        // Clock
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 1 {
                timeRemaining -= 1
            } else {
                timeRemaining = 0
                clockTimer?.invalidate()
                onTimeUp()
            }
        }
    }

    // MARK: - Game Logic

    private func flipCard(_ card: MatchCard) {
        guard !isChecking else { return }
        guard let idx = cards.firstIndex(where: { $0.id == card.id }) else { return }
        guard !cards[idx].faceUp, !cards[idx].matched else { return }

        withAnimation(.easeInOut(duration: 0.25)) {
            cards[idx].faceUp = true
        }

        if let firstId = firstFlipped {
            // Second card flipped — check for match
            isChecking = true
            let secondId = card.id

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                guard let firstIdx = cards.firstIndex(where: { $0.id == firstId }),
                      let secondIdx = cards.firstIndex(where: { $0.id == secondId }) else {
                    isChecking = false
                    firstFlipped = nil
                    return
                }

                if cards[firstIdx].pairIndex == cards[secondIdx].pairIndex {
                    // Match!
                    withAnimation(.spring(response: 0.3)) {
                        cards[firstIdx].matched = true
                        cards[secondIdx].matched = true
                    }
                    score += 1

                    // Check if all matched
                    if cards.allSatisfy({ $0.matched }) {
                        clockTimer?.invalidate()
                        onAllMatched()
                    }
                } else {
                    // No match — flip both back
                    withAnimation(.easeInOut(duration: 0.25)) {
                        cards[firstIdx].faceUp = false
                        cards[secondIdx].faceUp = false
                    }
                }

                firstFlipped = nil
                isChecking = false
            }
        } else {
            firstFlipped = card.id
        }
    }
}

// MARK: - Single Card View

private struct MatchCardView: View {
    let card: MatchCard
    let onTap: () -> Void

    var body: some View {
        ZStack {
            if card.matched {
                // Matched — dimmed emoji
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green.opacity(0.2))
                    .overlay(
                        Text(card.emoji)
                            .font(.system(size: 32))
                            .opacity(0.4)
                    )
            } else if card.faceUp {
                // Face up — show emoji
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.15))
                    .overlay(
                        Text(card.emoji)
                            .font(.system(size: 32))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.4), lineWidth: 2)
                    )
            } else {
                // Face down — question mark
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.1))
                    .overlay(
                        Text("❓")
                            .font(.system(size: 28))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onTapGesture { onTap() }
    }
}
