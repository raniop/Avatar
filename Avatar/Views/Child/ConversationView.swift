import SwiftUI

struct ConversationView: View {
    @Bindable var viewModel: ConversationViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var appRouter

    private var L: AppLocale { appRouter.currentLocale }

    var body: some View {
        ZStack {
            MissionBackgroundView(theme: viewModel.mission.theme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ConversationTopBar(
                    locale: L,
                    missionEmoji: viewModel.mission.emoji,
                    missionTitle: viewModel.mission.title,
                    onEnd: {
                        Task { await viewModel.endMission() }
                    }
                )

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageRowView(
                                    message: message,
                                    viewModel: viewModel,
                                    locale: L
                                )
                                .id(message.id)
                            }

                            if !viewModel.currentTranscription.isEmpty {
                                ChatBubbleView(
                                    text: viewModel.currentTranscription,
                                    isChild: true,
                                    locale: L
                                )
                                .opacity(0.6)
                                .id("transcription")
                            }

                            if viewModel.isAvatarThinking {
                                HStack {
                                    TypingIndicator()
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .id("processing")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 32)
                        .padding(.bottom, 8)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: viewModel.typewriterVisibleWords) { _, _ in
                        if let id = viewModel.typewriterMessageId {
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo(id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.isAvatarThinking) { _, thinking in
                        if thinking {
                            withAnimation {
                                proxy.scrollTo("processing", anchor: .bottom)
                            }
                        }
                    }
                }

                ChatInputBar(
                    viewModel: viewModel,
                    locale: L
                )
                .padding(.bottom, AppTheme.Spacing.sm)
            }

            if viewModel.phase == .loading {
                KidLoadingOverlay(
                    locale: L,
                    missionTitle: viewModel.mission.title,
                    emoji: viewModel.mission.emoji,
                    avatarImage: viewModel.avatarImage,
                    theme: viewModel.mission.theme
                )
            }

            if viewModel.parentInterventionMessage != nil {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "eye.fill")
                            .font(.caption)
                        Text(L.parentWatching)
                            .font(.caption)
                    }
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(.black.opacity(0.3))
                    .clipShape(Capsule())
                    .padding(.bottom, 100)
                }
            }
        }
        .environment(\.layoutDirection, L.layoutDirection)
        .navigationBarHidden(true)
        .task {
            await viewModel.startMission()
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            if newPhase == .dismissed {
                dismiss()
            }
        }
    }

}

// MARK: - Message Row (handles typewriter + waiting states)

struct MessageRowView: View {
    let message: Message
    let viewModel: ConversationViewModel
    let locale: AppLocale

    var body: some View {
        if viewModel.isWaitingForAudio(messageId: message.id) {
            // Typing dots while waiting for audio to arrive
            HStack {
                if let img = viewModel.friendImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                }
                TypingIndicator()
                Spacer()
            }
        } else {
            let visibleText = viewModel.visibleText(for: message)
            ChatBubbleView(
                text: message.textContent,
                visibleText: visibleText,
                isChild: message.role == .child,
                locale: locale,
                avatarImage: message.role == .avatar ? viewModel.friendImage : nil
            )
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubbleView: View {
    let text: String
    /// Partial text during typewriter (nil = show full text)
    var visibleText: String? = nil
    let isChild: Bool
    let locale: AppLocale
    var avatarImage: UIImage? = nil

    private var bubbleColor: Color {
        isChild ? AppTheme.Colors.primary : .white
    }

    /// Tail points toward the sender: trailing for child, leading for avatar.
    /// In RTL layout the environment flips leading/trailing automatically.
    private var tailEdge: BubbleTailShape.TailEdge {
        isChild ? .trailing : .leading
    }

    private let tailWidth: CGFloat = 8

    private var textColor: Color {
        isChild ? .white : AppTheme.Colors.textPrimary
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isChild { Spacer(minLength: 60) }

            // Avatar thumbnail for non-child messages
            if !isChild, let img = avatarImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
            }

            // Use full text for layout sizing; overlay visible portion during typewriter
            Text(text)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(visibleText != nil ? .clear : textColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .padding(tailEdge == .trailing ? .trailing : .leading, tailWidth)
                .overlay(alignment: .topLeading) {
                    if let partial = visibleText {
                        Text(partial)
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundStyle(textColor)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .padding(tailEdge == .trailing ? .trailing : .leading, tailWidth)
                    }
                }
                .background(
                    BubbleTailShape(tailEdge: tailEdge)
                        .fill(bubbleColor)
                        .shadow(color: .black.opacity(0.05), radius: 3, y: 2)
                )

            if !isChild { Spacer(minLength: 60) }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

// MARK: - Bubble Shape with Tail

struct BubbleTailShape: Shape {
    enum TailEdge {
        case leading, trailing
    }

    let tailEdge: TailEdge
    let cornerRadius: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        // Telegram/WhatsApp-style bubble: rounded rectangle with a visible tail
        // at the bottom corner on the sender's side. The tail is drawn INSIDE
        // the rect (ChatBubbleView adds padding on the tail side).
        let r = cornerRadius
        var path = Path()

        switch tailEdge {
        case .trailing:
            // The tail is on the right side. The bubble body ends at (maxX - 8),
            // and the tail fills the remaining 8pt on the right.
            let bodyRight = rect.maxX - 8

            // Top-left corner
            path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
            // Top edge
            path.addLine(to: CGPoint(x: bodyRight - r, y: rect.minY))
            // Top-right corner (of the body)
            path.addQuadCurve(
                to: CGPoint(x: bodyRight, y: rect.minY + r),
                control: CGPoint(x: bodyRight, y: rect.minY)
            )
            // Right edge of body down to where tail starts
            path.addLine(to: CGPoint(x: bodyRight, y: rect.maxY - 14))
            // Tail: curves out to the right and down to a point, then back
            path.addCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY),
                control1: CGPoint(x: bodyRight, y: rect.maxY - 4),
                control2: CGPoint(x: rect.maxX, y: rect.maxY - 4)
            )
            // Tail tip curves back left along bottom
            path.addCurve(
                to: CGPoint(x: bodyRight - 6, y: rect.maxY - 2),
                control1: CGPoint(x: rect.maxX - 1, y: rect.maxY + 1),
                control2: CGPoint(x: bodyRight, y: rect.maxY)
            )
            // Bottom edge
            path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY - 2))
            // Bottom-left corner
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - 2 - r),
                control: CGPoint(x: rect.minX, y: rect.maxY - 2)
            )
            // Left edge
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
            // Top-left corner
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + r, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )

        case .leading:
            // The tail is on the left side. The bubble body starts at (minX + 8).
            let bodyLeft = rect.minX + 8

            // Top-left corner (of the body)
            path.move(to: CGPoint(x: bodyLeft + r, y: rect.minY))
            // Top edge
            path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
            // Top-right corner
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + r),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            // Right edge
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 2 - r))
            // Bottom-right corner
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - r, y: rect.maxY - 2),
                control: CGPoint(x: rect.maxX, y: rect.maxY - 2)
            )
            // Bottom edge to tail
            path.addLine(to: CGPoint(x: bodyLeft + 6, y: rect.maxY - 2))
            // Tail: curves left and down to a point
            path.addCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY),
                control1: CGPoint(x: bodyLeft, y: rect.maxY),
                control2: CGPoint(x: rect.minX + 1, y: rect.maxY + 1)
            )
            // Tail tip curves back up along left edge
            path.addCurve(
                to: CGPoint(x: bodyLeft, y: rect.maxY - 14),
                control1: CGPoint(x: rect.minX, y: rect.maxY - 4),
                control2: CGPoint(x: bodyLeft, y: rect.maxY - 4)
            )
            // Left edge of body
            path.addLine(to: CGPoint(x: bodyLeft, y: rect.minY + r))
            // Top-left corner
            path.addQuadCurve(
                to: CGPoint(x: bodyLeft + r, y: rect.minY),
                control: CGPoint(x: bodyLeft, y: rect.minY)
            )
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Typing Indicator (three dots animation)

struct TypingIndicator: View {
    @State private var dot1 = false
    @State private var dot2 = false
    @State private var dot3 = false

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(.white.opacity(dot1 ? 0.9 : 0.3)).frame(width: 8, height: 8)
            Circle().fill(.white.opacity(dot2 ? 0.9 : 0.3)).frame(width: 8, height: 8)
            Circle().fill(.white.opacity(dot3 ? 0.9 : 0.3)).frame(width: 8, height: 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever()) { dot1 = true }
            withAnimation(.easeInOut(duration: 0.5).repeatForever().delay(0.15)) { dot2 = true }
            withAnimation(.easeInOut(duration: 0.5).repeatForever().delay(0.3)) { dot3 = true }
        }
    }
}

// MARK: - Sub-components

struct ConversationTopBar: View {
    let locale: AppLocale
    var missionEmoji: String = ""
    var missionTitle: String = ""
    let onEnd: () -> Void

    var body: some View {
        HStack {
            // End conversation button
            Button(action: onEnd) {
                Text(locale == .hebrew ? "סיום" : "End")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
            }

            Spacer()

            // Mission title
            HStack(spacing: 5) {
                Text(missionEmoji)
                    .font(.system(size: 18))
                Text(missionTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer()

            // Invisible spacer to balance the end button
            Color.clear
                .frame(width: 70, height: 1)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.sm)
    }
}

struct SpeechBubbleView: View {
    let text: String
    let isChild: Bool
    let isTyping: Bool

    var body: some View {
        HStack {
            if isChild { Spacer() }

            Text(text)
                .font(AppTheme.Fonts.childBody)
                .foregroundStyle(isChild ? .white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isChild ? AppTheme.Colors.primary : .white)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg))
                .opacity(isTyping ? 0.8 : 1.0)

            if !isChild { Spacer() }
        }
    }
}

struct TalkButtonView: View {
    let isListening: Bool
    let isProcessing: Bool
    let isPlayingResponse: Bool
    let amplitude: Float
    let onPress: () -> Void
    let onRelease: () -> Void

    @State private var isPressing = false

    private var canRecord: Bool {
        !isProcessing && !isPlayingResponse
    }

    var body: some View {
        ZStack {
            // Pulse ring when listening
            if isListening {
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 3)
                    .frame(width: 90 + CGFloat(amplitude) * 30, height: 90 + CGFloat(amplitude) * 30)
                    .animation(.easeOut(duration: 0.1), value: amplitude)
            }

            // Main button
            Circle()
                .fill(buttonColor)
                .frame(width: 64, height: 64)
                .shadow(color: buttonColor.opacity(0.4), radius: 6, y: 3)
                .scaleEffect(isPressing ? 0.92 : 1.0)
                .animation(.easeOut(duration: 0.1), value: isPressing)

            // Icon
            Group {
                if isProcessing {
                    ProgressView()
                        .tint(.white)
                } else if isPlayingResponse {
                    Image(systemName: "waveform")
                        .font(.title3)
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: isListening ? "mic.fill" : "mic")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
            }
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard canRecord, !isPressing else { return }
                    isPressing = true
                    onPress()
                }
                .onEnded { _ in
                    isPressing = false
                    if isListening {
                        onRelease()
                    }
                }
        )
        .allowsHitTesting(canRecord)
    }

    private var buttonColor: Color {
        if isListening { return AppTheme.Colors.danger }
        if isProcessing { return .gray }
        if isPlayingResponse { return AppTheme.Colors.secondary }
        return AppTheme.Colors.primary
    }
}

// MARK: - Chat Input Bar (text field + mic/send toggle)

struct ChatInputBar: View {
    @Bindable var viewModel: ConversationViewModel
    let locale: AppLocale
    @State private var textInput = ""
    @FocusState private var isTextFocused: Bool

    private var canInteract: Bool {
        !viewModel.isProcessing && !viewModel.isPlayingResponse
    }

    private var hasText: Bool {
        !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            // Text input field (multiline with TextEditor)
            HStack(alignment: .bottom) {
                TextField(locale == .hebrew ? "כתוב כאן..." : "Type here...", text: $textInput, axis: .vertical)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(.black)
                    .tint(AppTheme.Colors.primary)
                    .focused($isTextFocused)
                    .disabled(!canInteract)
                    .lineLimit(1...4)
                    .submitLabel(.return)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 22))

            // Send button (when text entered) OR Mic button (when empty)
            if hasText {
                // Send button
                Button(action: sendText) {
                    Circle()
                        .fill(AppTheme.Colors.primary)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "arrow.up")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        )
                }
                .disabled(!canInteract)
            } else {
                // Mic button
                MicButton(
                    isListening: viewModel.isListening,
                    isProcessing: viewModel.isProcessing,
                    isPlayingResponse: viewModel.isPlayingResponse,
                    amplitude: viewModel.audioEngine.recordingAmplitude,
                    onPress: { viewModel.onTalkButtonPressed() },
                    onRelease: { viewModel.onTalkButtonReleased() }
                )
            }
        }
        .padding(.horizontal, 16)
    }

    private func sendText() {
        let text = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        textInput = ""
        isTextFocused = false
        viewModel.sendTextMessage(text)
    }
}

// MARK: - Compact Mic Button (tap to start, auto-stops on silence)

struct MicButton: View {
    let isListening: Bool
    let isProcessing: Bool
    let isPlayingResponse: Bool
    let amplitude: Float
    let onPress: () -> Void
    let onRelease: () -> Void

    private var canTap: Bool {
        !isProcessing && !isPlayingResponse
    }

    var body: some View {
        ZStack {
            // Pulse ring when listening
            if isListening {
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 2)
                    .frame(width: 56 + CGFloat(amplitude) * 20, height: 56 + CGFloat(amplitude) * 20)
                    .animation(.easeOut(duration: 0.1), value: amplitude)
            }

            Circle()
                .fill(buttonColor)
                .frame(width: 48, height: 48)
                .shadow(color: buttonColor.opacity(0.4), radius: 4, y: 2)

            Group {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else if isPlayingResponse {
                    Image(systemName: "waveform")
                        .font(.body)
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: isListening ? "stop.fill" : "mic.fill")
                        .font(.body)
                        .foregroundStyle(.white)
                }
            }
        }
        .contentShape(Circle())
        .onTapGesture {
            guard canTap else { return }
            if isListening {
                onRelease()  // Tap again to stop manually
            } else {
                onPress()    // Tap to start (auto-stops on silence)
            }
        }
        .allowsHitTesting(canTap)
    }

    private var buttonColor: Color {
        if isListening { return AppTheme.Colors.danger }
        if isProcessing { return .gray }
        if isPlayingResponse { return AppTheme.Colors.secondary }
        return AppTheme.Colors.primary
    }
}

struct MissionBackgroundView: View {
    let theme: String

    var body: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var backgroundColors: [Color] {
        switch theme {
        case "superhero_training": [Color(hex: "E74C3C"), Color(hex: "3498DB")]
        case "space_adventure": [Color(hex: "2C3E50"), Color(hex: "3498DB")]
        case "cooking_adventure": [Color(hex: "F39C12"), Color(hex: "E74C3C")]
        case "underwater_explorer": [Color(hex: "006994"), Color(hex: "00CED1")]
        case "magical_forest": [Color(hex: "228B22"), Color(hex: "90EE90")]
        case "dinosaur_world": [Color(hex: "8B4513"), Color(hex: "DAA520")]
        case "pirate_treasure", "pirate_treasure_hunt": [Color(hex: "795548"), Color(hex: "3F51B5")]
        case "fairy_tale", "fairy_tale_kingdom": [Color(hex: "E91E63"), Color(hex: "9C27B0")]
        case "animal_rescue": [Color(hex: "4CAF50"), Color(hex: "8BC34A")]
        case "rainbow_land": [Color(hex: "FF6B6B"), Color(hex: "C56CF0")]
        case "music_studio": [Color(hex: "9B59B6"), Color(hex: "E91E63")]
        case "dance_party": [Color(hex: "E91E63"), Color(hex: "F39C12")]
        case "sports_champion": [Color(hex: "27AE60"), Color(hex: "2980B9")]
        case "singing_star": [Color(hex: "8E44AD"), Color(hex: "E74C3C")]
        case "animal_hospital": [Color(hex: "1ABC9C"), Color(hex: "3498DB")]
        default: [Color(hex: "74B9FF"), Color(hex: "A29BFE")]
        }
    }
}

// MARK: - Kid-Friendly Loading Animation

struct KidLoadingOverlay: View {
    let locale: AppLocale
    let missionTitle: String
    let emoji: String
    let avatarImage: UIImage?
    let theme: String

    @State private var avatarScale: CGFloat = 0.0
    @State private var avatarBounce: CGFloat = 0
    @State private var portalRotation: Double = 0
    @State private var portalScale: CGFloat = 0.3
    @State private var showContent = false
    @State private var emojiScale: CGFloat = 0.0
    @State private var textIndex = 0
    @State private var progress: CGFloat = 0
    @State private var showBubbles = false
    @State private var starBounce = false

    private var loadingTexts: [String] {
        [locale.gettingReady, locale.preparingAdventure, locale.almostThere]
    }

    private var themeColors: [Color] {
        switch theme {
        case "superhero_training": [Color(hex: "FF6B6B"), Color(hex: "4ECDC4"), Color(hex: "2C3E50")]
        case "space_adventure": [Color(hex: "0F0C29"), Color(hex: "302B63"), Color(hex: "24243E")]
        case "cooking_adventure": [Color(hex: "F2994A"), Color(hex: "F2C94C"), Color(hex: "EB5757")]
        case "underwater_explorer": [Color(hex: "005C97"), Color(hex: "00D2FF"), Color(hex: "0052D4")]
        case "magical_forest": [Color(hex: "134E5E"), Color(hex: "71B280"), Color(hex: "2E8B57")]
        case "dinosaur_world": [Color(hex: "8B6914"), Color(hex: "DAA520"), Color(hex: "CD853F")]
        case "pirate_treasure", "pirate_treasure_hunt": [Color(hex: "2C3E50"), Color(hex: "4CA1AF"), Color(hex: "3F51B5")]
        case "fairy_tale", "fairy_tale_kingdom": [Color(hex: "C471ED"), Color(hex: "F64F59"), Color(hex: "8E44AD")]
        case "animal_rescue": [Color(hex: "11998E"), Color(hex: "38EF7D"), Color(hex: "56AB2F")]
        case "sports_champion": [Color(hex: "1D976C"), Color(hex: "93F9B9"), Color(hex: "2193B0")]
        default: [Color(hex: "A770EF"), Color(hex: "CF8BF3"), Color(hex: "FDB99B")]
        }
    }

    /// Bright accent color derived from the theme
    private var accentColor: Color {
        switch theme {
        case "superhero_training": Color(hex: "FFE66D")
        case "space_adventure": Color(hex: "A8EDEA")
        case "cooking_adventure": Color(hex: "FFFFFF")
        case "underwater_explorer": Color(hex: "7FFFD4")
        case "magical_forest": Color(hex: "ADFF2F")
        case "dinosaur_world": Color(hex: "FFD700")
        case "pirate_treasure", "pirate_treasure_hunt": Color(hex: "FFD700")
        case "fairy_tale", "fairy_tale_kingdom": Color(hex: "FFB6C1")
        case "animal_rescue": Color(hex: "FFFACD")
        default: Color(hex: "FFFFFF")
        }
    }

    var body: some View {
        let screenW = UIScreen.main.bounds.width
        let screenH = UIScreen.main.bounds.height

        ZStack {
            // Rich multi-stop gradient background
            MeshGradientBackground(colors: themeColors)
                .ignoresSafeArea()

            // Floating colorful bubbles
            ForEach(0..<12, id: \.self) { i in
                FloatingBubble(index: i, isActive: showBubbles, accentColor: accentColor, screenW: screenW, screenH: screenH)
            }

            VStack(spacing: 0) {
                Spacer()

                // ── Magical Portal + Avatar ──
                ZStack {
                    // Outer rotating portal ring
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: [accentColor, .white.opacity(0.5), accentColor.opacity(0.3), .white, accentColor],
                                center: .center
                            ),
                            lineWidth: 5
                        )
                        .frame(width: 190, height: 190)
                        .rotationEffect(.degrees(portalRotation))
                        .scaleEffect(portalScale)

                    // Inner soft glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [accentColor.opacity(0.15), .clear],
                                center: .center,
                                startRadius: 50,
                                endRadius: 110
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(portalScale)

                    // Avatar image
                    if let img = avatarImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 160, height: 160)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: 4)
                            )
                            .shadow(color: accentColor.opacity(0.6), radius: 25)
                            .scaleEffect(avatarScale)
                            .offset(y: avatarBounce)
                    }
                }

                Spacer().frame(height: 36)

                // ── Mission Emoji (bounces in) ──
                Text(emoji)
                    .font(.system(size: 64))
                    .scaleEffect(emojiScale)
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

                Spacer().frame(height: 14)

                // ── Mission Title ──
                Text(missionTitle)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                    .multilineTextAlignment(.center)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 40)

                // ── Progress bar with star ──
                VStack(spacing: 14) {
                    // Animated status text
                    Text(loadingTexts[textIndex])
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.4), value: textIndex)

                    // Progress track with moving star
                    let barWidth = screenW - 100
                    ZStack(alignment: .leading) {
                        // Background track
                        Capsule()
                            .fill(.white.opacity(0.2))
                            .frame(width: barWidth, height: 14)

                        // Filled portion with gradient
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [accentColor, .white],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(14, progress * barWidth), height: 14)
                            .shadow(color: accentColor.opacity(0.5), radius: 6)

                        // Star at the tip of progress
                        Text("⭐")
                            .font(.system(size: 24))
                            .offset(
                                x: max(0, progress * barWidth - 12),
                                y: starBounce ? -6 : 0
                            )
                    }
                    .frame(width: barWidth)
                }
                .opacity(showContent ? 1 : 0)
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
        }
        .onAppear { startAnimations() }
    }

    private func startAnimations() {
        // Portal appears with spin
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            portalScale = 1.0
        }

        // Portal continuous rotation
        withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
            portalRotation = 360
        }

        // Avatar pop-in with bounce
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.2)) {
            avatarScale = 1.0
        }

        // Avatar gentle float
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.6)) {
            avatarBounce = -12
        }

        // Emoji bounce in
        withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.4)) {
            emojiScale = 1.0
        }

        // Content fade in
        withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
            showContent = true
        }

        // Bubbles start
        withAnimation(.easeIn(duration: 0.3).delay(0.3)) {
            showBubbles = true
        }

        // Progress bar fills over ~8s (typical load time)
        withAnimation(.easeInOut(duration: 8.0).delay(0.5)) {
            progress = 0.92
        }

        // Star bounces along the progress bar
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(0.6)) {
            starBounce = true
        }

        // Cycle through loading texts
        Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { timer in
            withAnimation {
                textIndex = min(textIndex + 1, loadingTexts.count - 1)
            }
            if textIndex >= loadingTexts.count - 1 {
                timer.invalidate()
            }
        }
    }
}

/// Mesh-like gradient background with 3 colors for depth
private struct MeshGradientBackground: View {
    let colors: [Color]

    @State private var animate = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colors,
                startPoint: animate ? .topLeading : .topTrailing,
                endPoint: animate ? .bottomTrailing : .bottomLeading
            )

            // Soft radial overlay for depth
            RadialGradient(
                colors: [colors.first?.opacity(0.3) ?? .clear, .clear],
                center: animate ? .topLeading : .bottomTrailing,
                startRadius: 100,
                endRadius: 500
            )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

/// Colorful floating bubbles scattered across the screen
private struct FloatingBubble: View {
    let index: Int
    let isActive: Bool
    let accentColor: Color
    let screenW: CGFloat
    let screenH: CGFloat

    @State private var opacity: Double = 0
    @State private var yOffset: CGFloat = 0
    @State private var scale: CGFloat = 0.3

    private var bubbleSize: CGFloat {
        [14, 22, 10, 18, 26, 12, 20, 16, 24, 8, 15, 20][index % 12]
    }

    private var bubbleColor: Color {
        let colors: [Color] = [
            .white.opacity(0.4),
            accentColor.opacity(0.5),
            .white.opacity(0.25),
            accentColor.opacity(0.35),
            .white.opacity(0.5),
            accentColor.opacity(0.4),
            .white.opacity(0.3),
            accentColor.opacity(0.45),
            .white.opacity(0.35),
            accentColor.opacity(0.3),
            .white.opacity(0.45),
            accentColor.opacity(0.5),
        ]
        return colors[index % 12]
    }

    private var xPos: CGFloat {
        let positions: [CGFloat] = [0.08, 0.92, 0.18, 0.82, 0.35, 0.65, 0.5, 0.25, 0.75, 0.42, 0.58, 0.15]
        return screenW * positions[index % 12]
    }

    private var yPos: CGFloat {
        let positions: [CGFloat] = [0.1, 0.15, 0.7, 0.75, 0.3, 0.45, 0.85, 0.22, 0.6, 0.38, 0.52, 0.9]
        return screenH * positions[index % 12]
    }

    var body: some View {
        Circle()
            .fill(bubbleColor)
            .frame(width: bubbleSize, height: bubbleSize)
            .blur(radius: bubbleSize > 18 ? 2 : 1)
            .opacity(opacity)
            .scaleEffect(scale)
            .offset(y: yOffset)
            .position(x: xPos, y: yPos)
            .onAppear {
                guard isActive else { return }
                animate()
            }
            .onChange(of: isActive) { _, active in
                if active { animate() }
            }
    }

    private func animate() {
        let delay = Double(index) * 0.12
        let duration = Double.random(in: 2.5...4.0)
        let drift = CGFloat.random(in: (-30)...(-15))

        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay)) {
            opacity = Double.random(in: 0.6...1.0)
            yOffset = drift
            scale = CGFloat.random(in: 0.8...1.2)
        }
    }
}

struct MissionCompleteOverlay: View {
    let locale: AppLocale
    let onDismiss: () -> Void

    @State private var showStars = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.lg) {
                if showStars {
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(AppTheme.Colors.accent)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                Text(locale.missionComplete)
                    .font(AppTheme.Fonts.title)
                    .foregroundStyle(.white)

                Text(locale.greatJob)
                    .font(AppTheme.Fonts.childBody)
                    .foregroundStyle(.white.opacity(0.8))

                Button(action: onDismiss) {
                    Text(locale.done)
                        .font(AppTheme.Fonts.childBody)
                        .foregroundStyle(AppTheme.Colors.primary)
                        .padding(.horizontal, AppTheme.Spacing.xl)
                        .padding(.vertical, AppTheme.Spacing.md)
                        .background(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5).delay(0.3)) {
                showStars = true
            }
        }
    }
}
