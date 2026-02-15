import SwiftUI

struct ConversationView: View {
    @Bindable var viewModel: ConversationViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var appRouter

    private var L: AppLocale { appRouter.currentLocale }

    /// Whether the typewriter is currently animating an avatar response
    private var isTypewriterActive: Bool {
        viewModel.isTypewriting && !viewModel.typewriterText.isEmpty
    }

    /// The ID of the last avatar message (the one being typewritten)
    private var typewriterMessageId: String? {
        viewModel.messages.last(where: { $0.role == .avatar })?.id
    }

    var body: some View {
        ZStack {
            // Mission-themed background
            MissionBackgroundView(theme: viewModel.mission.theme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with timer
                ConversationTopBar(
                    timeRemaining: viewModel.missionTimeRemaining,
                    phase: viewModel.phase,
                    locale: L,
                    onClose: {
                        Task { await viewModel.endMission(userInitiated: true) }
                    }
                )

                // Small avatar at top
                if let img = viewModel.avatarImage {
                    AnimatedAvatarView(image: img, size: 100)
                        .padding(.top, 8)
                }

                // Chat messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                // Skip the last avatar message if the typewriter
                                // is currently animating it (to avoid duplicate)
                                if isTypewriterActive && message.role == .avatar && message.id == typewriterMessageId {
                                    EmptyView()
                                } else {
                                    ChatBubbleView(
                                        text: message.textContent,
                                        isChild: message.role == .child,
                                        locale: L
                                    )
                                    .id(message.id)
                                }
                            }

                            // Live typewriter text (current avatar response being typed)
                            if isTypewriterActive {
                                ChatBubbleView(
                                    text: viewModel.typewriterText,
                                    isChild: false,
                                    locale: L
                                )
                                .id("typewriter")
                            }

                            // "Transcribing..." indicator
                            if !viewModel.currentTranscription.isEmpty {
                                ChatBubbleView(
                                    text: viewModel.currentTranscription,
                                    isChild: true,
                                    locale: L
                                )
                                .opacity(0.6)
                                .id("transcription")
                            }

                            // Processing indicator
                            if viewModel.isProcessing {
                                HStack {
                                    TypingIndicator()
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .id("processing")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: viewModel.typewriterText) { _, _ in
                        withAnimation {
                            proxy.scrollTo("typewriter", anchor: .bottom)
                        }
                    }
                }

                // Chat input bar (text field + mic button)
                ChatInputBar(
                    viewModel: viewModel,
                    locale: L
                )
                .padding(.bottom, AppTheme.Spacing.sm)
            }

            // Phase overlays
            if viewModel.phase == .loading {
                LoadingOverlay(text: L.gettingReady)
            }

            if viewModel.phase == .complete {
                MissionCompleteOverlay(locale: L) {
                    dismiss()
                }
            }

            // Parent intervention indicator
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

// MARK: - Chat Bubble

struct ChatBubbleView: View {
    let text: String
    let isChild: Bool
    let locale: AppLocale

    var body: some View {
        HStack {
            if isChild { Spacer(minLength: 60) }

            Text(text)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(isChild ? .white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isChild ? AppTheme.Colors.primary : .white)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.05), radius: 3, y: 2)

            if !isChild { Spacer(minLength: 60) }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
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
    let timeRemaining: TimeInterval
    let phase: ConversationViewModel.Phase
    let locale: AppLocale
    let onClose: () -> Void

    var body: some View {
        HStack {
            // Phase indicator
            Text(phaseText)
                .font(AppTheme.Fonts.caption)
                .foregroundStyle(.white.opacity(0.6))

            Spacer()

            // Timer
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.caption)
                Text(timeString)
                    .font(.system(.body, design: .rounded).monospacedDigit())
            }
            .foregroundStyle(timeRemaining <= 30 ? AppTheme.Colors.danger : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.black.opacity(0.3))
            .clipShape(Capsule())

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.sm)
    }

    private var timeString: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var phaseText: String {
        switch phase {
        case .intro: locale.startingDots
        case .active: locale.adventure
        case .wrapUp: locale.wrappingUp
        default: ""
        }
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
                    .focused($isTextFocused)
                    .disabled(!canInteract)
                    .lineLimit(1...4)
                    .submitLabel(.return)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.white)
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

// MARK: - Compact Mic Button

struct MicButton: View {
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
                .scaleEffect(isPressing ? 0.9 : 1.0)
                .animation(.easeOut(duration: 0.1), value: isPressing)

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
                    Image(systemName: isListening ? "mic.fill" : "mic")
                        .font(.body)
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
                    if isListening { onRelease() }
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

struct LoadingOverlay: View {
    let text: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.md) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text(text)
                    .font(AppTheme.Fonts.childBody)
                    .foregroundStyle(.white)
            }
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
