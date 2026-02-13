import Foundation
import Observation

@Observable
final class ConversationViewModel {
    enum Phase: Equatable {
        case loading
        case intro
        case active
        case wrapUp
        case complete
        case error(String)
    }

    // MARK: - State

    var phase: Phase = .loading
    var messages: [Message] = []
    var currentTranscription = ""
    var avatarEmotion: Emotion = .happy
    var missionTimeRemaining: TimeInterval = 300  // 5 minutes
    var parentInterventionMessage: String?

    var isListening: Bool { audioEngine.state == .listening }
    var isProcessing: Bool { audioEngine.state == .processing }
    var isPlayingResponse: Bool { audioEngine.state == .playingResponse }

    // MARK: - Dependencies

    let audioEngine = AudioEngine()
    let animator = AvatarAnimator()
    private let webSocket = WebSocketClient()
    private let apiClient = APIClient.shared

    // MARK: - Session Data

    let child: Child
    let mission: Mission
    private var conversationId: String?
    private var missionTimer: Timer?
    private var audioBuffer = Data()

    init(child: Child, mission: Mission) {
        self.child = child
        self.mission = mission
        setupCallbacks()
    }

    // MARK: - Lifecycle

    func startMission() async {
        phase = .loading

        do {
            // 1. Create conversation on backend
            let conversation = try await apiClient.createConversation(
                childId: child.id,
                missionId: mission.id,
                locale: child.locale
            )
            conversationId = conversation.id

            // 2. Connect WebSocket
            if let token = KeychainManager.shared.getAccessToken() {
                webSocket.setAuthToken(token)
            }
            webSocket.connect()
            webSocket.joinSession(conversationId: conversation.id, role: "child")

            // 3. Start mission timer
            startMissionTimer()

            // 4. Transition to intro
            phase = .intro

            // Avatar sends first greeting (server-initiated)
            // Wait briefly then move to active phase
            try await Task.sleep(for: .seconds(2))
            phase = .active

        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func onTalkButtonPressed() {
        guard phase == .active,
              audioEngine.state == .idle else { return }
        audioBuffer = Data()
        audioEngine.startListening()
    }

    func onTalkButtonReleased() {
        guard audioEngine.state == .listening else { return }
        audioEngine.stopListening()
    }

    func endMission() async {
        missionTimer?.invalidate()
        missionTimer = nil

        if let conversationId {
            _ = try? await apiClient.endConversation(id: conversationId)
            webSocket.leaveSession(conversationId: conversationId)
        }
        webSocket.disconnect()
        audioEngine.reset()
        phase = .complete
    }

    // MARK: - Setup

    private func setupCallbacks() {
        // Audio chunks → WebSocket
        audioEngine.onAudioChunkReady = { [weak self] chunk in
            guard let self, let conversationId = self.conversationId else { return }
            self.audioBuffer.append(chunk)
            self.webSocket.sendAudioChunk(
                conversationId: conversationId,
                audioData: chunk,
                isFinal: false
            )
        }

        // Recording finished → send final marker
        audioEngine.onRecordingFinished = { [weak self] in
            guard let self, let conversationId = self.conversationId else { return }
            self.webSocket.sendAudioChunk(
                conversationId: conversationId,
                audioData: Data(),
                isFinal: true
            )
        }

        // Lip-sync during playback
        audioEngine.player.onAmplitudeUpdate = { [weak self] amplitude in
            self?.animator.updateLipSync(amplitude: amplitude)
        }

        // WebSocket events
        webSocket.onTranscription = { [weak self] text, isFinal in
            self?.currentTranscription = text
            if isFinal {
                self?.addChildMessage(text: text)
                self?.currentTranscription = ""
            }
        }

        webSocket.onAvatarResponseText = { [weak self] text, emotionStr in
            guard let self else { return }
            let emotion = Emotion(rawValue: emotionStr) ?? .neutral
            self.avatarEmotion = emotion
            self.animator.transitionToEmotion(emotion)
            self.addAvatarMessage(text: text, emotion: emotion)
        }

        webSocket.onAvatarResponseAudio = { [weak self] audioUrl, _ in
            guard let self, let url = URL(string: audioUrl) else { return }
            self.audioEngine.playResponseFromURL(url, emotion: self.avatarEmotion)
        }

        webSocket.onParentIntervention = { [weak self] text in
            self?.parentInterventionMessage = text
            // Clear after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self?.parentInterventionMessage = nil
            }
        }

        webSocket.onConversationEnded = { [weak self] _ in
            self?.phase = .complete
        }

        webSocket.onError = { [weak self] error in
            self?.phase = .error(error)
        }
    }

    // MARK: - Helpers

    private func addChildMessage(text: String) {
        let message = Message(
            id: UUID().uuidString,
            conversationId: conversationId ?? "",
            role: .child,
            textContent: text,
            isParentIntervention: false,
            timestamp: Date()
        )
        messages.append(message)
    }

    private func addAvatarMessage(text: String, emotion: Emotion) {
        let message = Message(
            id: UUID().uuidString,
            conversationId: conversationId ?? "",
            role: .avatar,
            textContent: text,
            emotion: emotion,
            isParentIntervention: false,
            timestamp: Date()
        )
        messages.append(message)
    }

    private func startMissionTimer() {
        missionTimeRemaining = TimeInterval(mission.durationMinutes * 60)

        missionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.missionTimeRemaining -= 1

            if self.missionTimeRemaining <= 30 && self.phase == .active {
                self.phase = .wrapUp
            }

            if self.missionTimeRemaining <= 0 {
                Task { await self.endMission() }
            }
        }
    }
}
