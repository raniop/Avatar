import Foundation
import Observation
import UIKit

@Observable
final class ConversationViewModel {
    enum Phase: Equatable {
        case loading
        case intro
        case active
        case wrapUp
        case complete
        case dismissed
        case error(String)
    }

    // MARK: - State

    var phase: Phase = .loading
    var messages: [Message] = []
    var currentTranscription = ""
    var avatarEmotion: Emotion = .happy
    var parentInterventionMessage: String?

    /// Whether audio is pending for the opening message (arrives via WebSocket after API response)
    private var pendingOpeningAudioMessageId: String?

    var isListening: Bool { audioEngine.state == .listening }
    var isProcessing: Bool { audioEngine.state == .processing }
    var isPlayingResponse: Bool { audioEngine.state == .playingResponse }

    /// Show avatar typing indicator only when AI is actually generating a response
    var isAvatarThinking = false

    // MARK: - Typewriter State

    /// ID of the message currently being typewritten (nil = no active typewriter)
    var typewriterMessageId: String?
    /// Number of words currently visible for the typewriter message
    var typewriterVisibleWords: Int = 0
    /// Whether the typewriter message is waiting for audio (show typing dots)
    var typewriterWaitingForAudio = false
    /// Timer that reveals words one by one
    private var typewriterTimer: Timer?
    /// Total word count for the current typewriter message
    private var typewriterTotalWords: Int = 0

    // MARK: - Dependencies

    let audioEngine = AudioEngine()
    let animator = AvatarAnimator()
    var avatarImage: UIImage?
    /// The friend/avatar character's preset image (shown next to chat bubbles)
    var friendImage: UIImage?
    private let webSocket = WebSocketClient()
    private let apiClient = APIClient.shared
    private let avatarStorage = AvatarStorage.shared

    // MARK: - Session Data

    let child: Child
    let mission: Mission
    private var conversationId: String?
    private var audioBuffer = Data()
    /// Session start time for timing logs
    private var sessionStartTime: CFAbsoluteTime = 0

    /// If set, resume this existing conversation instead of creating a new one
    private let existingConversationId: String?

    /// Base URL for resolving relative audio URLs from the backend
    private let backendBaseURL = "https://poetic-serenity-production-7de7.up.railway.app"

    /// Current app locale (from UserDefaults, not from child model)
    private var appLocale: AppLocale {
        if let raw = UserDefaults.standard.string(forKey: "app_locale"),
           let locale = AppLocale(rawValue: raw) {
            return locale
        }
        return .english
    }

    init(child: Child, mission: Mission, existingConversationId: String? = nil) {
        self.child = child
        self.mission = mission
        self.existingConversationId = existingConversationId
        setupCallbacks()
    }

    // MARK: - Lifecycle

    func startMission() async {
        // Load images immediately so KidLoadingOverlay shows the avatar right away
        if let saved = await avatarStorage.loadAvatar(childId: child.id) {
            avatarImage = saved.image
        }
        loadFriendImage()

        // Route to resume flow if we have an existing conversation
        if let existingId = existingConversationId {
            await resumeConversation(id: existingId)
            return
        }

        // Check for an existing ACTIVE conversation for this mission
        // Only resume if the child actually participated (sent at least one message)
        do {
            if let active = try await apiClient.getActiveConversation(childId: child.id, missionId: mission.id) {
                let transcript = try await apiClient.getConversationTranscript(conversationId: active.id)
                let childSentMessage = transcript.messages.contains { $0.role == .child }
                if childSentMessage {
                    print("🔄 Resuming conversation \(active.id) — child has \(transcript.messages.filter { $0.role == .child }.count) messages")
                    await resumeConversation(id: active.id)
                    return
                } else {
                    print("🆕 Existing conversation \(active.id) has no child messages, starting fresh")
                }
            }
        } catch {
            print("⚠️ Failed to check for existing conversation: \(error)")
        }

        phase = .loading
        let startTime = CFAbsoluteTimeGetCurrent()
        sessionStartTime = startTime

        // Start WebSocket connection early (in parallel with API call)
        let token = KeychainManager.shared.getAccessToken()
        webSocket.connect(token: token)
        print("🕐 [TIMING] WebSocket connect started: +\(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - startTime) * 1000))ms")

        // Load avatar image and create conversation in parallel
        async let conversationCreate = apiClient.createConversation(
            childId: child.id,
            missionId: mission.id,
            locale: appLocale
        )

        print("🕐 [TIMING] API call started: +\(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - startTime) * 1000))ms")

        do {
            let response = try await conversationCreate
            print("🕐 [TIMING] API response received: +\(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - startTime) * 1000))ms")

            let convId = response.conversation.id
            let openingText = response.openingMessage.textContent
            let openingAudioUrl = response.openingMessage.audioUrl
            // Decode inline base64 audio data if available
            let openingAudioData: Data? = response.openingMessage.audioData.flatMap { Data(base64Encoded: $0) }
            print("ConversationVM: Opening audio: url=\(openingAudioUrl ?? "nil"), inlineDataSize=\(openingAudioData?.count ?? 0), hasAudioData=\(response.openingMessage.audioData != nil)")

            // Add the opening message from the avatar
            let opening = response.openingMessage
            let openingEmotion = opening.emotion.flatMap { Emotion(rawValue: $0) } ?? .happy
            let openingMsg = Message(
                id: opening.id,
                conversationId: response.conversation.id,
                role: .avatar,
                textContent: opening.textContent,
                audioUrl: openingAudioUrl,
                audioDuration: nil,
                emotion: openingEmotion,
                isParentIntervention: false,
                timestamp: opening.timestamp
            )

            conversationId = convId
            messages.append(openingMsg)

            // Play audio if available inline, otherwise stay on loading screen until audio arrives
            if let openingAudioData, !openingAudioData.isEmpty {
                // Audio available now — go to active immediately with synced typewriter
                beginTypewriterWait(messageId: opening.id, text: openingText)
                phase = .active
                audioEngine.playResponse(data: openingAudioData, emotion: openingEmotion)
                print("🕐 [TIMING] Phase -> active (inline audio): +\(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - startTime) * 1000))ms")
            } else if let openingAudioUrl, !openingAudioUrl.isEmpty {
                let fullUrl = openingAudioUrl.hasPrefix("http") ? openingAudioUrl : "\(backendBaseURL)\(openingAudioUrl)"
                if let url = URL(string: fullUrl) {
                    beginTypewriterWait(messageId: opening.id, text: openingText)
                    phase = .active
                    audioEngine.playResponseFromURL(url, emotion: openingEmotion)
                    print("🕐 [TIMING] Phase -> active (audio URL): +\(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - startTime) * 1000))ms")
                }
            } else {
                // Audio will arrive via WebSocket — STAY ON LOADING SCREEN
                pendingOpeningAudioMessageId = opening.id
                beginTypewriterWait(messageId: opening.id, text: openingText)
                print("🕐 [TIMING] Waiting for WebSocket audio (staying on loading screen): +\(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - startTime) * 1000))ms")

                // Safety: if audio doesn't arrive within 20s, go to active anyway
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(20))
                    guard let self, self.phase == .loading else { return }
                    print("🕐 [TIMING] Safety timeout — going to active without audio")
                    self.stopTypewriter()
                    self.phase = .active
                }
            }

            // Connect WebSocket in background
            Task { @MainActor in
                do {
                    try await self.waitForConnection(timeout: 8.0)
                    print("ConversationVM: [TIMING] WebSocket connected: +\(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - startTime) * 1000))ms")

                    self.webSocket.joinConversation(
                        conversationId: convId,
                        childId: self.child.id,
                        parentUserId: self.child.parentId,
                        locale: self.appLocale.rawValue
                    )
                    print("ConversationVM: [TIMING] Joined room: +\(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - startTime) * 1000))ms")
                } catch {
                    print("ConversationVM: WebSocket connection failed: \(error)")
                }
            }

        } catch {
            print("ConversationVM: Error starting mission: \(error)")
            phase = .error(error.localizedDescription)
        }
    }

    /// Resume an existing ACTIVE conversation — load transcript and reconnect WebSocket.
    private func resumeConversation(id convId: String) async {
        phase = .loading
        let startTime = CFAbsoluteTimeGetCurrent()

        // Start WebSocket connection early (in parallel)
        let token = KeychainManager.shared.getAccessToken()
        webSocket.connect(token: token)

        // Load transcript (avatar images already loaded in startMission)
        async let transcriptFetch = apiClient.getConversationTranscript(conversationId: convId)

        do {
            let transcript = try await transcriptFetch
            print("ConversationVM: [RESUME] Loaded \(transcript.messages.count) messages (+\(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - startTime) * 1000))ms)")

            conversationId = convId
            messages = transcript.messages

            // Go straight to active (no intro/typewriter for resumed conversations)
            phase = .active

            // Connect WebSocket and join room
            Task { @MainActor in
                do {
                    try await self.waitForConnection(timeout: 8.0)
                    print("ConversationVM: [RESUME] WebSocket connected: +\(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - startTime) * 1000))ms")

                    self.webSocket.joinConversation(
                        conversationId: convId,
                        childId: self.child.id,
                        parentUserId: self.child.parentId,
                        locale: self.appLocale.rawValue
                    )
                    print("ConversationVM: [RESUME] Joined room: +\(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - startTime) * 1000))ms")
                } catch {
                    print("ConversationVM: [RESUME] WebSocket connection failed: \(error)")
                }
            }

        } catch {
            print("ConversationVM: [RESUME] Error resuming conversation: \(error)")
            // Fall back to creating a new conversation
            await startNewConversation()
        }
    }

    /// Create a new conversation (used as fallback when resume fails).
    private func startNewConversation() async {
        phase = .loading
        let startTime = CFAbsoluteTimeGetCurrent()

        let token = KeychainManager.shared.getAccessToken()
        if webSocket.connectionState != .connected {
            webSocket.connect(token: token)
        }

        do {
            let response = try await apiClient.createConversation(
                childId: child.id,
                missionId: mission.id,
                locale: appLocale
            )

            let convId = response.conversation.id
            let openingText = response.openingMessage.textContent
            let openingAudioUrl = response.openingMessage.audioUrl
            let openingAudioData: Data? = response.openingMessage.audioData.flatMap { Data(base64Encoded: $0) }

            let opening = response.openingMessage
            let openingEmotion = opening.emotion.flatMap { Emotion(rawValue: $0) } ?? .happy
            let openingMsg = Message(
                id: opening.id,
                conversationId: response.conversation.id,
                role: .avatar,
                textContent: opening.textContent,
                audioUrl: openingAudioUrl,
                audioDuration: nil,
                emotion: openingEmotion,
                isParentIntervention: false,
                timestamp: opening.timestamp
            )

            conversationId = convId
            messages.append(openingMsg)

            if let openingAudioData, !openingAudioData.isEmpty {
                beginTypewriterWait(messageId: opening.id, text: opening.textContent)
                phase = .active
                audioEngine.playResponse(data: openingAudioData, emotion: openingEmotion)
            } else if let openingAudioUrl, !openingAudioUrl.isEmpty {
                let fullUrl = openingAudioUrl.hasPrefix("http") ? openingAudioUrl : "\(backendBaseURL)\(openingAudioUrl)"
                if let url = URL(string: fullUrl) {
                    beginTypewriterWait(messageId: opening.id, text: opening.textContent)
                    phase = .active
                    audioEngine.playResponseFromURL(url, emotion: openingEmotion)
                }
            } else {
                pendingOpeningAudioMessageId = opening.id
                beginTypewriterWait(messageId: opening.id, text: opening.textContent)
                // Stay on loading screen — audio will arrive via WebSocket
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(20))
                    guard let self, self.phase == .loading else { return }
                    self.stopTypewriter()
                    self.phase = .active
                }
            }

            Task { @MainActor in
                do {
                    try await self.waitForConnection(timeout: 8.0)
                    self.webSocket.joinConversation(
                        conversationId: convId,
                        childId: self.child.id,
                        parentUserId: self.child.parentId,
                        locale: self.appLocale.rawValue
                    )
                } catch {
                    print("ConversationVM: WebSocket connection failed: \(error)")
                }
            }

        } catch {
            print("ConversationVM: Error starting mission (fallback): \(error)")
            phase = .error(error.localizedDescription)
        }
    }

    func onTalkButtonPressed() {
        guard phase == .active else { return }
        // Allow recording only when idle
        guard audioEngine.state == .idle else {
            print("ConversationVM: Talk pressed but engine state = \(audioEngine.state)")
            return
        }
        audioBuffer = Data()
        audioEngine.startListening()
    }

    func onTalkButtonReleased() {
        guard audioEngine.state == .listening else { return }
        audioEngine.stopListening()
    }

    /// Leave the conversation and dismiss.
    /// By default, the conversation stays ACTIVE on the backend so the child can resume later.
    /// Pass `endConversation: true` when the parent explicitly ends it.
    func endMission(endConversation: Bool = false) async {
        // Clean up audio, typewriter & socket first (fast)
        stopTypewriter()
        audioEngine.reset()
        webSocket.leaveConversation()

        phase = .dismissed

        // Only mark COMPLETED on backend when explicitly requested (parent ended it)
        if endConversation, let conversationId {
            Task.detached { [apiClient] in
                _ = try? await apiClient.endConversation(id: conversationId)
            }
        }
        webSocket.disconnect()
    }

    // MARK: - Setup

    private func setupCallbacks() {
        // WebSocket reconnected — re-join conversation room and fetch missed messages
        webSocket.onReconnected = { [weak self] in
            guard let self, let convId = self.conversationId else { return }
            print("ConversationVM: Re-joining conversation after reconnect: \(convId)")
            self.webSocket.joinConversation(
                conversationId: convId,
                childId: self.child.id,
                parentUserId: self.child.parentId,
                locale: self.appLocale.rawValue
            )

            // Only fetch missed messages if we were waiting for a response
            let wasProcessing = self.audioEngine.state == .processing
            if wasProcessing {
                // Fetch any messages we missed during the disconnect
                Task { @MainActor [weak self] in
                    // Small delay to let the join complete
                    try? await Task.sleep(for: .milliseconds(500))
                    await self?.fetchMissedMessages()
                    // If polling didn't find anything either, reset to idle so mic works
                    if self?.audioEngine.state == .processing {
                        print("ConversationVM: Still processing after polling, resetting to idle")
                        self?.audioEngine.state = .idle
                    }
                }
            }
        }

        // Audio chunks -> accumulate in buffer (backend expects complete audio, not streaming)
        audioEngine.onAudioChunkReady = { [weak self] chunk in
            self?.audioBuffer.append(chunk)
        }

        // Recording finished -> wrap PCM in WAV header and send via Socket.IO
        audioEngine.onRecordingFinished = { [weak self] in
            guard let self else { return }

            // Minimum ~0.5 seconds of audio at 16kHz/16bit/mono = 16000 bytes
            let minimumPCMBytes = 16000
            guard self.audioBuffer.count >= minimumPCMBytes else {
                print("ConversationVM: Recording too short (\(self.audioBuffer.count) bytes < \(minimumPCMBytes) min), ignoring")
                self.audioBuffer = Data()
                self.audioEngine.state = .idle
                return
            }

            // Wrap raw 16-bit PCM in WAV header so Whisper can recognize it
            let wavData = AudioRecorder.buildWAVData(from: self.audioBuffer)
            let pcmBytes = self.audioBuffer.count
            self.audioBuffer = Data()
            print("ConversationVM: Sending \(wavData.count) bytes WAV audio (\(pcmBytes) PCM bytes, ~\(String(format: "%.1f", Double(pcmBytes) / 32000.0))s)")
            self.webSocket.sendVoiceData(audioData: wavData)

            // Start a safety timeout: if no response within 45 seconds, reset to idle
            // Voice pipeline (Whisper STT + Claude AI + TTS) can take 15-30s
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(45))
                guard let self else { return }
                if self.audioEngine.state == .processing {
                    print("ConversationVM: Processing timeout — resetting to idle")
                    self.audioEngine.state = .idle
                }
            }
        }

        // Lip-sync during playback
        audioEngine.player.onAmplitudeUpdate = { [weak self] amplitude in
            self?.animator.updateLipSync(amplitude: amplitude)
        }

        audioEngine.onAudioDurationReady = { [weak self] duration in
            guard let self else { return }
            let elapsed = String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - self.sessionStartTime) * 1000)
            print("🕐 [TIMING] Audio playback starting: +\(elapsed)ms, duration=\(String(format: "%.2f", duration))s, typewriterActive=\(self.typewriterMessageId != nil)")
            // Audio just started playing — begin synced typewriter reveal
            if self.typewriterMessageId != nil {
                self.startTypewriterSynced(duration: duration)
            }
        }

        // When audio playback completes, ensure all text is fully revealed
        audioEngine.onPlaybackComplete = { [weak self] in
            guard let self else { return }
            let elapsed = String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - self.sessionStartTime) * 1000)
            print("🕐 [TIMING] Audio playback complete: +\(elapsed)ms")
            self.stopTypewriter()
        }

        // MARK: Socket.IO Event Callbacks

        webSocket.onConversationJoined = { [weak self] conversationId in
            print("ConversationVM: Joined conversation: \(conversationId)")
            _ = self
        }

        webSocket.onConversationProcessing = { [weak self] status in
            print("ConversationVM: Processing status: \(status)")
            if status == "transcribing" {
                self?.currentTranscription = "..."
                self?.isAvatarThinking = false
            } else if status == "thinking" {
                self?.isAvatarThinking = true
            }
        }

        // Server sends back the full response (child message + avatar message)
        webSocket.onConversationResponse = { [weak self] data in
            guard let self else { return }
            print("ConversationVM: Received conversation response")
            self.isAvatarThinking = false

            // Parse child message (what the child said, transcribed)
            if let childMsg = data["childMessage"] as? [String: Any],
               let childText = childMsg["textContent"] as? String {
                let childId = childMsg["id"] as? String ?? UUID().uuidString

                // Check if we already added this message locally (from sendTextMessage)
                let alreadyExists = self.messages.contains { msg in
                    msg.role == .child && msg.textContent == childText && msg.id.hasPrefix("local_")
                }

                if alreadyExists {
                    // Update the local message with the server-assigned ID
                    if let idx = self.messages.lastIndex(where: { $0.role == .child && $0.textContent == childText && $0.id.hasPrefix("local_") }) {
                        self.messages[idx] = Message(
                            id: childId,
                            conversationId: self.conversationId ?? "",
                            role: .child,
                            textContent: childText,
                            isParentIntervention: false,
                            timestamp: Date()
                        )
                    }
                } else {
                    let message = Message(
                        id: childId,
                        conversationId: self.conversationId ?? "",
                        role: .child,
                        textContent: childText,
                        isParentIntervention: false,
                        timestamp: Date()
                    )
                    self.messages.append(message)
                }
                self.currentTranscription = ""
                print("ConversationVM: Child said: \(childText)")
            }

            // Parse avatar message (AI response)
            if let avatarMsg = data["avatarMessage"] as? [String: Any],
               let avatarText = avatarMsg["textContent"] as? String {
                let avatarId = avatarMsg["id"] as? String ?? UUID().uuidString
                let emotionStr = avatarMsg["emotion"] as? String ?? "neutral"
                let emotion = Emotion(rawValue: emotionStr) ?? .neutral

                self.avatarEmotion = emotion
                self.animator.transitionToEmotion(emotion)

                let message = Message(
                    id: avatarId,
                    conversationId: self.conversationId ?? "",
                    role: .avatar,
                    textContent: avatarText,
                    emotion: emotion,
                    isParentIntervention: false,
                    timestamp: Date()
                )
                self.messages.append(message)

                // Get audio URL and/or inline audio data from response
                let audioUrl = avatarMsg["audioUrl"] as? String
                let audioDataBase64 = avatarMsg["audioData"] as? String
                // audioData can also come as a dict with "type":"Buffer","data":[...] from socket.io
                var inlineAudioData: Data?
                if let b64 = audioDataBase64 {
                    inlineAudioData = Data(base64Encoded: b64)
                    print("ConversationVM: Got inline audioData base64, size=\(inlineAudioData?.count ?? 0)")
                } else if let bufferDict = avatarMsg["audioData"] as? [String: Any],
                          let byteArray = bufferDict["data"] as? [Int] {
                    inlineAudioData = Data(byteArray.map { UInt8($0 & 0xFF) })
                    print("ConversationVM: Got inline audioData buffer, size=\(inlineAudioData?.count ?? 0)")
                }
                print("ConversationVM: Avatar response - emotion=\(emotionStr), audioUrl=\(audioUrl ?? "nil"), hasInlineAudio=\(inlineAudioData != nil), text=\(avatarText.prefix(60))")

                // Start typewriter + play audio. If audio is available, typewriter will sync via onAudioDurationReady.
                // If no audio at all, just reveal text immediately.
                let hasAudio = (inlineAudioData != nil && !inlineAudioData!.isEmpty) || (audioUrl != nil && !audioUrl!.isEmpty)
                if hasAudio {
                    self.beginTypewriterWait(messageId: avatarId, text: avatarText)
                    self.playAvatarAudio(audioUrl: audioUrl, audioData: inlineAudioData, emotion: emotion)
                } else {
                    // No audio — just show text instantly
                    self.audioEngine.state = .idle
                }
            } else {
                // No avatar message in response -- reset to idle so mic works again
                print("ConversationVM: No avatarMessage in response, resetting to idle")
                self.audioEngine.state = .idle
            }
        }

        // Audio arrives separately (e.g., opening message audio via WebSocket)
        webSocket.onConversationAudio = { [weak self] data in
            guard let self else { return }
            let messageId = data["messageId"] as? String
            let elapsed = String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - self.sessionStartTime) * 1000)
            print("🕐 [TIMING] Audio arrived via WebSocket: +\(elapsed)ms, messageId=\(messageId ?? "?"), engineState=\(self.audioEngine.state)")

            // Only play if engine is idle (not already playing something else)
            let isOpeningAudio = self.pendingOpeningAudioMessageId != nil
            guard self.audioEngine.state == .idle || isOpeningAudio else {
                print("ConversationVM: Skipping audio — engine busy (\(self.audioEngine.state))")
                return
            }
            self.pendingOpeningAudioMessageId = nil

            var audioData: Data?
            if let b64 = data["audioData"] as? String {
                audioData = Data(base64Encoded: b64)
            }
            let audioUrl = data["audioUrl"] as? String

            // If still on loading screen (waiting for opening audio), transition to active now
            if isOpeningAudio && self.phase == .loading {
                self.phase = .active
                print("🕐 [TIMING] Phase -> active (audio arrived): +\(elapsed)ms")
            }

            // Audio will trigger synced typewriter reveal via onAudioDurationReady callback
            self.playAvatarAudio(audioUrl: audioUrl, audioData: audioData, emotion: self.avatarEmotion)
        }

        webSocket.onParentIntervention = { [weak self] id, textContent in
            self?.parentInterventionMessage = textContent
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self?.parentInterventionMessage = nil
            }
        }

        webSocket.onConversationEndedByParent = { [weak self] in
            Task { await self?.endMission(endConversation: true) }
        }

        webSocket.onConversationError = { [weak self] error in
            print("ConversationVM: Socket error: \(error)")
            // Reset audio engine to idle so user can try again
            self?.audioEngine.state = .idle
            self?.isAvatarThinking = false
            self?.currentTranscription = ""
            // Don't set phase to error for transient issues
        }
    }

    // MARK: - Audio Playback

    /// Play avatar TTS audio. Text is already shown in the message bubble — this just plays audio.
    private func playAvatarAudio(audioUrl: String?, audioData: Data?, emotion: Emotion) {
        if let audioData, !audioData.isEmpty {
            print("ConversationVM: Playing inline audio (\(audioData.count) bytes)")
            audioEngine.playResponse(data: audioData, emotion: emotion)
        } else if let audioUrl, !audioUrl.isEmpty {
            let fullUrl = audioUrl.hasPrefix("http") ? audioUrl : "\(backendBaseURL)\(audioUrl)"
            if let url = URL(string: fullUrl) {
                print("ConversationVM: Playing audio from URL: \(fullUrl)")
                audioEngine.playResponseFromURL(url, emotion: emotion)
            } else {
                audioEngine.state = .idle
            }
        } else {
            // No audio available
            audioEngine.state = .idle
        }
    }

    // MARK: - Helpers

    /// Load the friend character's preset image from the app bundle
    private func loadFriendImage() {
        if let presetId = UserDefaults.standard.object(forKey: "friend_preset_\(child.id)") as? Int {
            friendImage = UIImage(named: "avatar_preset_\(presetId)")
        }
    }

    private func waitForConnection(timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while webSocket.connectionState != .connected {
            if Date() > deadline {
                throw URLError(.timedOut)
            }
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    /// Fetch messages from backend that may have been missed during WebSocket disconnect.
    /// Polls up to 6 times (every 3 seconds for 18 seconds) because the backend might
    /// still be processing the voice when we first check.
    private func fetchMissedMessages() async {
        guard let convId = conversationId else { return }

        let maxPolls = 6
        let pollInterval: Duration = .seconds(3)
        let messageCountBefore = messages.count

        for attempt in 1...maxPolls {
            do {
                let transcript = try await apiClient.getConversationTranscript(conversationId: convId)
                let existingIds = Set(messages.map(\.id))
                // Also skip messages that match locally-added text (dedup with optimistic messages)
                let existingTexts = Set(messages.filter { $0.id.hasPrefix("local_") }.map(\.textContent))

                var newMessages: [Message] = []
                for msg in transcript.messages {
                    if !existingIds.contains(msg.id) && !existingTexts.contains(msg.textContent) {
                        newMessages.append(msg)
                    }
                }

                if !newMessages.isEmpty {
                    print("ConversationVM: Found \(newMessages.count) missed messages (poll \(attempt)/\(maxPolls))")
                    for msg in newMessages {
                        messages.append(msg)

                        if msg.role == .avatar {
                            let audioUrl = msg.audioUrl
                            let emotion = msg.emotion ?? .happy
                            self.avatarEmotion = emotion
                            self.animator.transitionToEmotion(emotion)
                            let hasAudio = audioUrl != nil && !audioUrl!.isEmpty
                            if hasAudio {
                                self.beginTypewriterWait(messageId: msg.id, text: msg.textContent)
                            }
                            self.playAvatarAudio(audioUrl: audioUrl, audioData: nil, emotion: emotion)
                        }
                    }
                    return // Got messages, stop polling
                }
            } catch {
                print("ConversationVM: Poll \(attempt) failed: \(error)")
            }

            // If a new message arrived via WebSocket while we were polling, stop
            if messages.count > messageCountBefore {
                print("ConversationVM: Messages arrived via WebSocket, stop polling (poll \(attempt))")
                return
            }

            if attempt < maxPolls {
                print("ConversationVM: No missed messages yet, polling again in 3s (poll \(attempt)/\(maxPolls))")
                try? await Task.sleep(for: pollInterval)
            }
        }
        print("ConversationVM: Polling exhausted, no missed messages found")
    }

    // MARK: - Typewriter

    /// Start typewriter for a message. Shows typing dots until audio arrives,
    /// then reveals words synced to the audio duration.
    private func beginTypewriterWait(messageId: String, text: String) {
        stopTypewriter()
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        typewriterTotalWords = words.count
        typewriterVisibleWords = 0
        typewriterMessageId = messageId
        typewriterWaitingForAudio = true
        print("⏳ Typewriter: Waiting for audio — messageId=\(messageId), words=\(words.count)")

        // Safety timeout: if audio never arrives, show full text after 15s
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard let self, self.typewriterMessageId == messageId else { return }
            print("⏳ Typewriter: Safety timeout — forcing full text for \(messageId)")
            self.stopTypewriter()
        }
    }

    /// Audio just started playing — begin revealing words synced to the duration.
    private func startTypewriterSynced(duration: TimeInterval) {
        guard typewriterMessageId != nil else { return }
        typewriterWaitingForAudio = false

        // Show first word immediately
        typewriterVisibleWords = max(typewriterVisibleWords, 1)

        let wordsLeft = typewriterTotalWords - typewriterVisibleWords
        guard wordsLeft > 0 else {
            stopTypewriter()
            return
        }

        // Distribute remaining words across 90% of audio duration
        let effectiveDuration = duration * 0.90
        let interval = max(0.05, effectiveDuration / Double(wordsLeft))
        print("⏳ Typewriter: Synced start — \(wordsLeft) words over \(String(format: "%.2f", effectiveDuration))s, interval=\(String(format: "%.0f", interval * 1000))ms")

        typewriterTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            self.typewriterVisibleWords += 1
            if self.typewriterVisibleWords >= self.typewriterTotalWords {
                timer.invalidate()
                self.typewriterTimer = nil
                print("⏳ Typewriter: All words revealed")
            }
        }
    }

    /// Immediately show all remaining text and clean up typewriter state.
    private func stopTypewriter() {
        typewriterTimer?.invalidate()
        typewriterTimer = nil
        typewriterMessageId = nil
        typewriterVisibleWords = 0
        typewriterTotalWords = 0
        typewriterWaitingForAudio = false
    }

    /// Returns the visible text for a message, respecting the typewriter state.
    /// Returns nil when the message should show its full text (not being typewritten).
    func visibleText(for message: Message) -> String? {
        guard message.id == typewriterMessageId else { return nil }
        if typewriterWaitingForAudio { return nil } // show typing dots
        let words = message.textContent.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let count = min(typewriterVisibleWords, words.count)
        if count >= words.count { return nil } // all words visible — show full text
        if count == 0 { return " " } // at least a space so bubble renders
        return words.prefix(count).joined(separator: " ")
    }

    /// Whether a message should show typing dots (waiting for audio).
    func isWaitingForAudio(messageId: String) -> Bool {
        messageId == typewriterMessageId && typewriterWaitingForAudio
    }

    /// Send a text message typed by the child via keyboard
    func sendTextMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard phase == .active else { return }
        guard audioEngine.state == .idle else { return }

        // Immediately show the child's message in chat (don't wait for server)
        let childMsg = Message(
            id: "local_\(UUID().uuidString)",
            conversationId: conversationId ?? "",
            role: .child,
            textContent: trimmed,
            isParentIntervention: false,
            timestamp: Date()
        )
        messages.append(childMsg)

        audioEngine.state = .processing
        webSocket.sendTextMessage(textContent: trimmed)
    }
}
