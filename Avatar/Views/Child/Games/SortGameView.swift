import SwiftUI

/// Drag-to-sort game.  Items appear one at a time at the top and the child
/// drags each item into the correct target zone at the bottom.
struct SortGameView: View {
    let theme: String
    let difficulty: GameDifficulty

    @Binding var score: Int
    @Binding var totalItems: Int
    @Binding var timeRemaining: Int
    let onTimeUp: () -> Void
    let onAllSorted: () -> Void

    // MARK: - Internal State

    @State private var items: [SortItem] = []
    @State private var zones: [SortZone] = []
    @State private var currentIndex = 0
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var clockTimer: Timer?
    @State private var feedback: SortFeedback?
    @State private var zoneFrames: [Int: CGRect] = [:]

    private var currentItem: SortItem? {
        guard currentIndex < items.count else { return nil }
        return items[currentIndex]
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Current item to sort
                Spacer()

                if let item = currentItem {
                    VStack(spacing: 8) {
                        Text(item.emoji)
                            .font(.system(size: 64))
                        Text(item.label)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .offset(dragOffset)
                    .scaleEffect(isDragging ? 1.1 : 1.0)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                isDragging = false
                                handleDrop(at: CGPoint(
                                    x: geo.size.width / 2 + value.translation.width,
                                    y: geo.size.height * 0.4 + value.translation.height
                                ))
                            }
                    )
                    .animation(.spring(response: 0.3), value: dragOffset)
                } else {
                    // All done placeholder
                    Text("✅")
                        .font(.system(size: 64))
                }

                Spacer()

                // Feedback overlay
                if let fb = feedback {
                    Text(fb == .correct ? "✅" : "❌")
                        .font(.system(size: 48))
                        .transition(.scale.combined(with: .opacity))
                        .padding(.bottom, 8)
                }

                // Target zones
                HStack(spacing: 12) {
                    ForEach(zones) { zone in
                        SortZoneView(zone: zone, isHighlighted: isDragging)
                            .background(
                                GeometryReader { zoneGeo in
                                    Color.clear.onAppear {
                                        let frame = zoneGeo.frame(in: .named("sortArea"))
                                        zoneFrames[zone.id] = frame
                                    }
                                }
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .coordinateSpace(name: "sortArea")
        }
        .onAppear { startGame() }
        .onDisappear { clockTimer?.invalidate() }
    }

    // MARK: - Setup

    private func startGame() {
        score = 0
        currentIndex = 0
        zones = GameThemeConfig.sortCategories(for: theme)
        items = GameThemeConfig.sortItems(for: theme, count: difficulty.itemCount).shuffled()
        totalItems = items.count
        timeRemaining = difficulty.timeLimit

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

    // MARK: - Drop Logic

    private func handleDrop(at point: CGPoint) {
        guard let item = currentItem else { return }

        // Find which zone was hit
        var matchedZone: Int?
        for (zoneId, frame) in zoneFrames {
            if frame.contains(point) {
                matchedZone = zoneId
                break
            }
        }

        if let zoneId = matchedZone {
            if zoneId == item.correctZone {
                // Correct!
                score += 1
                withAnimation(.spring(response: 0.3)) {
                    feedback = .correct
                    dragOffset = .zero
                }
            } else {
                // Wrong!
                withAnimation(.spring(response: 0.3)) {
                    feedback = .wrong
                    dragOffset = .zero
                }
            }

            // Advance to next item after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.3)) {
                    feedback = nil
                    currentIndex += 1
                }
                if currentIndex >= items.count {
                    clockTimer?.invalidate()
                    onAllSorted()
                }
            }
        } else {
            // Dropped outside any zone — bounce back
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                dragOffset = .zero
            }
        }
    }
}

// MARK: - Feedback

private enum SortFeedback {
    case correct, wrong
}

// MARK: - Zone View

private struct SortZoneView: View {
    let zone: SortZone
    let isHighlighted: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(zone.emoji)
                .font(.system(size: 32))
            Text(zone.label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 110)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: zone.color).opacity(isHighlighted ? 0.5 : 0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    Color(hex: zone.color).opacity(isHighlighted ? 0.9 : 0.5),
                    style: StrokeStyle(lineWidth: isHighlighted ? 3 : 2, dash: isHighlighted ? [] : [8])
                )
        )
        .scaleEffect(isHighlighted ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHighlighted)
    }
}
