import SwiftUI

/// Falling-objects tap game.  Emojis fall from the top of the screen and the
/// child taps them to "catch" them before they reach the bottom.
struct CatchGameView: View {
    let theme: String
    let difficulty: GameDifficulty

    @Binding var score: Int
    @Binding var totalItems: Int
    @Binding var timeRemaining: Int
    let onTimeUp: () -> Void

    // MARK: - Internal State

    @State private var items: [FallingItem] = []
    @State private var spawnTimer: Timer?
    @State private var clockTimer: Timer?
    @State private var spawnedCount = 0
    @State private var screenSize: CGSize = .zero
    @State private var catchEffects: [CatchEffect] = []

    private let itemSize: CGFloat = 50

    private var emojis: [String] {
        GameThemeConfig.catchItems(for: theme)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Falling items
                ForEach(items.filter({ !$0.caught && !$0.missed })) { item in
                    Text(item.emoji)
                        .font(.system(size: itemSize))
                        .position(x: item.x, y: item.y)
                        .onTapGesture { catchItem(item) }
                }

                // Catch effects (little burst animations)
                ForEach(catchEffects) { effect in
                    CatchBurstView(emoji: effect.emoji)
                        .position(x: effect.x, y: effect.y)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onAppear {
                screenSize = geo.size
                startGame()
            }
        }
        .onDisappear { stopTimers() }
    }

    // MARK: - Game Logic

    private func startGame() {
        score = 0
        totalItems = difficulty.itemCount
        timeRemaining = difficulty.timeLimit
        spawnedCount = 0
        items = []

        // Spawn timer
        spawnTimer = Timer.scheduledTimer(withTimeInterval: difficulty.spawnInterval, repeats: true) { _ in
            guard spawnedCount < difficulty.itemCount else {
                spawnTimer?.invalidate()
                // Once last item finishes falling the game is still running on the clock
                return
            }
            spawnItem()
        }

        // Clock timer (1 s ticks)
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 1 {
                timeRemaining -= 1
            } else {
                timeRemaining = 0
                stopTimers()
                onTimeUp()
            }
        }
    }

    private func spawnItem() {
        let emoji = emojis[spawnedCount % emojis.count]
        let padding: CGFloat = 30
        let xRange = padding...(max(screenSize.width - padding, padding + 1))
        let randomX = CGFloat.random(in: xRange)

        let item = FallingItem(
            id: UUID(),
            emoji: emoji,
            x: randomX,
            y: -itemSize
        )
        spawnedCount += 1
        items.append(item)

        // Animate fall
        let itemId = item.id
        withAnimation(.linear(duration: difficulty.fallDuration)) {
            if let idx = items.firstIndex(where: { $0.id == itemId }) {
                items[idx].y = screenSize.height + itemSize
            }
        }

        // Mark missed after fall completes
        DispatchQueue.main.asyncAfter(deadline: .now() + difficulty.fallDuration + 0.1) {
            if let idx = items.firstIndex(where: { $0.id == itemId && !$0.caught }) {
                items[idx].missed = true
            }
        }
    }

    private func catchItem(_ item: FallingItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id && !$0.caught && !$0.missed }) else { return }
        items[idx].caught = true
        score += 1

        // Spawn burst effect
        let effect = CatchEffect(id: UUID(), emoji: "✨", x: items[idx].x, y: items[idx].y)
        catchEffects.append(effect)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            catchEffects.removeAll { $0.id == effect.id }
        }
    }

    private func stopTimers() {
        spawnTimer?.invalidate()
        spawnTimer = nil
        clockTimer?.invalidate()
        clockTimer = nil
    }
}

// MARK: - Catch Effect Model

private struct CatchEffect: Identifiable {
    let id: UUID
    let emoji: String
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Burst Animation

private struct CatchBurstView: View {
    let emoji: String
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 1

    var body: some View {
        Text(emoji)
            .font(.system(size: 36))
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4)) {
                    scale = 1.8
                    opacity = 0
                }
            }
    }
}
