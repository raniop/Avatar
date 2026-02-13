import SwiftUI

struct ConversationView: View {
    @Bindable var viewModel: ConversationViewModel
    @Environment(\.dismiss) private var dismiss

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
                    onClose: {
                        Task { await viewModel.endMission() }
                    }
                )

                Spacer()

                // Avatar
                AvatarDisplayView(
                    config: viewModel.child.avatarConfig,
                    animator: viewModel.animator,
                    size: 260
                )

                // Speech bubbles
                if !viewModel.currentTranscription.isEmpty {
                    SpeechBubbleView(
                        text: viewModel.currentTranscription,
                        isChild: true,
                        isTyping: true
                    )
                    .padding(.horizontal)
                    .transition(.scale.combined(with: .opacity))
                }

                if let lastAvatarMessage = viewModel.messages.last(where: { $0.role == .avatar }) {
                    SpeechBubbleView(
                        text: lastAvatarMessage.textContent,
                        isChild: false,
                        isTyping: false
                    )
                    .padding(.horizontal)
                    .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                // Talk button
                TalkButtonView(
                    isListening: viewModel.isListening,
                    isProcessing: viewModel.isProcessing,
                    isPlayingResponse: viewModel.isPlayingResponse,
                    amplitude: viewModel.audioEngine.recordingAmplitude,
                    onPress: { viewModel.onTalkButtonPressed() },
                    onRelease: { viewModel.onTalkButtonReleased() }
                )
                .padding(.bottom, AppTheme.Spacing.xl)
            }

            // Phase overlays
            if viewModel.phase == .loading {
                LoadingOverlay(text: "Getting ready...")
            }

            if viewModel.phase == .complete {
                MissionCompleteOverlay {
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
                        Text("Parent is watching")
                            .font(.caption)
                    }
                    .padding(6)
                    .background(.black.opacity(0.3))
                    .clipShape(Capsule())
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.startMission()
        }
    }

}

// MARK: - Sub-components

struct ConversationTopBar: View {
    let timeRemaining: TimeInterval
    let phase: ConversationViewModel.Phase
    let onClose: () -> Void

    var body: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
            }

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

            // Phase indicator
            Text(phaseText)
                .font(AppTheme.Fonts.caption)
                .foregroundStyle(.white.opacity(0.6))
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
        case .intro: "Starting..."
        case .active: "Adventure"
        case .wrapUp: "Wrapping up"
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

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        Button {
            // Handled by gesture
        } label: {
            ZStack {
                // Pulse ring when listening
                if isListening {
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 3)
                        .frame(width: 100 + CGFloat(amplitude) * 40, height: 100 + CGFloat(amplitude) * 40)
                        .animation(.easeOut(duration: 0.1), value: amplitude)
                }

                // Main button
                Circle()
                    .fill(buttonColor)
                    .frame(width: 80, height: 80)
                    .shadow(color: buttonColor.opacity(0.4), radius: 8, y: 4)

                // Icon
                Group {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                    } else if isPlayingResponse {
                        Image(systemName: "waveform")
                            .font(.title)
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: isListening ? "mic.fill" : "mic")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isListening && !isProcessing && !isPlayingResponse {
                        onPress()
                    }
                }
                .onEnded { _ in
                    if isListening {
                        onRelease()
                    }
                }
        )
        .disabled(isProcessing || isPlayingResponse)
    }

    private var buttonColor: Color {
        if isListening { return AppTheme.Colors.danger }
        if isProcessing { return .gray }
        if isPlayingResponse { return AppTheme.Colors.secondary }
        return AppTheme.Colors.primary
    }
}

struct MissionBackgroundView: View {
    let theme: MissionTheme

    var body: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var backgroundColors: [Color] {
        switch theme {
        case .superhero: [Color(hex: "E74C3C"), Color(hex: "3498DB")]
        case .spaceExplorer: [Color(hex: "2C3E50"), Color(hex: "3498DB")]
        case .chef: [Color(hex: "F39C12"), Color(hex: "E74C3C")]
        case .soccerPlayer: [Color(hex: "27AE60"), Color(hex: "2ECC71")]
        case .detective: [Color(hex: "2C3E50"), Color(hex: "8E44AD")]
        case .artist: [Color(hex: "E91E63"), Color(hex: "9C27B0")]
        case .doctor: [Color(hex: "00BCD4"), Color(hex: "2196F3")]
        case .firefighter: [Color(hex: "FF5722"), Color(hex: "FF9800")]
        case .scientist: [Color(hex: "00BCD4"), Color(hex: "4CAF50")]
        case .musician: [Color(hex: "9C27B0"), Color(hex: "673AB7")]
        case .pirate: [Color(hex: "795548"), Color(hex: "3F51B5")]
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

                Text("Mission Complete!")
                    .font(AppTheme.Fonts.title)
                    .foregroundStyle(.white)

                Text("Great job today!")
                    .font(AppTheme.Fonts.childBody)
                    .foregroundStyle(.white.opacity(0.8))

                Button(action: onDismiss) {
                    Text("Done")
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
