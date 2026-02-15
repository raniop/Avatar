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

    /// Typewriter state -- character-by-character reveal of avatar messages
    var typewriterText = ""
    var isTypewriting = false
    private var typewriterTask: Task<Void, Never>?

    var isListening: Bool { audioEngine.state == .listening }
    var isProcessing: Bool { audioEngine.state == .processing }
    var isPlayingResponse: Bool { audioEngine.state == .playingResponse }

    /// Show avatar typing indicator only when AI is actually generating a response
    var isAvatarThinking = false

    // MARK: - Dependencies

    let audioEngine = AudioEngine()
    let animator = AvatarAnimator()
    var avatarImage: UIImage?
    private let webSocket = WebSocketClient()
    private let apiClient = APIClient.shared
    private let avatarStorage = AvatarStorage.shared

    // MARK: - Session Data

    let child: Child
    let mission: Mission
    private var conversationId: String?
    private var audioBuffer = Data()

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

    init(child: Child, mission: Mission) {
        self.child = child
        self.mission = mission
        setupCallbacks()
    }

    // MARK: - Lifecycle

    func startMission() async {
        phase = .loading
        let startTime = CFAbsoluteTimeGetCurrent()

        // Start WebSocket connection early (in parallel with API call)
        let token = KeychainManager.shared.getAccessToken()
        webSocket.connect(token: token)

        // Load avatar image and create conversation in parallel
        async let conversationCreate = apiClient.createConversation(
            childId: child.id,
            missionId: mission.id,
            locale: appLocale
        )

        // Load avatar image (fast, from local cache)
        if let saved = await avatarStorage.loadAvatar(childId: child.id) {
            avatarImage = saved.image
        }
        print("ConversationVM: [TIMING] Avatar loaded: +\(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - startTime) * 1000))ms")

        do {
            let response = try await conversationCreate
            print("ConversationVM: [TIMING] API response: +\(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - startTime) * 1000))ms")

            let convId = response.conversation.id
            let openingText = response.openingMessage.textContent
            let openingAudioUrl = response.openingMessage.audioUrl
            // Decode inline base64 audio data if available
            let openingAudioData: Data? = response.openingMessage.audioData.flatMap { Data(base64Encoded: $0) }

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

            // Prepare typewriter BEFORE showing the message to prevent full-text flash.
            if !openingText.isEmpty {
                typewriterText = ""
                isTypewriting = true
            }
            messages.append(openingMsg)

            // Show the conversation immediately — don't wait for WebSocket!
            // The greeting text + typewriter can start while WebSocket connects in background.
            phase = .intro
            print("ConversationVM: [TIMING] Phase -> intro: +\(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - startTime) * 1000))ms")

            // Start typewriter immediately (without audio — audio arrives via WebSocket)
            if !openingText.isEmpty {
                startTypewriter(fullText: openingText, audioUrl: openingAudioUrl, audioData: openingAudioData, emotion: openingEmotion)
            }

            // Connect WebSocket in background while typewriter runs
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

            // Wait for typewriter/TTS to finish before moving to active
            let wordCount = openingText.split(separator: " ").count
            let waitDuration = max(2.0, Double(wordCount) / 2.5 + 0.5)
            try await Task.sleep(for: .seconds(waitDuration))
            phase = .active
            print("ConversationVM: [TIMING] Phase -> active: +\(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - startTime) * 1000))ms")

        } catch {
            print("ConversationVM: Error starting mission: \(error)")
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

    /// End the conversation and dismiss.
    func endMission(userInitiated: Bool = false) async {
        // Clean up audio & socket first (fast)
        audioEngine.reset()
        webSocket.leaveConversation()

        phase = .dismissed

        // End conversation on backend in background (don't block UI)
        if let conversationId {
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

                // Start typewriter + TTS (prefer inline audio data over URL download)
                self.startTypewriter(fullText: avatarText, audioUrl: audioUrl, audioData: inlineAudioData, emotion: emotion)
            } else {
                // No avatar message in response -- reset to idle so mic works again
                print("ConversationVM: No avatarMessage in response, resetting to idle")
                self.audioEngine.state = .idle
            }
        }

        // Audio data arrives separately (after text response) for faster perceived response
        webSocket.onConversationAudio = { [weak self] data in
            guard let self else { return }
            let messageId = data["messageId"] as? String
            print("ConversationVM: Received audio for message \(messageId ?? "?"), engineState=\(self.audioEngine.state)")

            // Don't play audio if user already started a new interaction
            guard self.audioEngine.state == .idle else {
                print("ConversationVM: Skipping audio — engine busy (\(self.audioEngine.state))")
                return
            }

            // Decode base64 audio
            var audioData: Data?
            if let b64 = data["audioData"] as? String {
                audioData = Data(base64Encoded: b64)
                print("ConversationVM: Decoded audio base64, size=\(audioData?.count ?? 0)")
            }

            if let audioData, !audioData.isEmpty {
                let emotion = self.avatarEmotion
                print("ConversationVM: Playing TTS audio (\(audioData.count) bytes)")
                self.audioEngine.playResponse(data: audioData, emotion: emotion)
            } else if let audioUrl = data["audioUrl"] as? String, !audioUrl.isEmpty {
                let fullUrl = audioUrl.hasPrefix("http") ? audioUrl : "\(self.backendBaseURL)\(audioUrl)"
                if let url = URL(string: fullUrl) {
                    let emotion = self.avatarEmotion
                    print("ConversationVM: Downloading TTS from: \(fullUrl)")
                    self.audioEngine.playResponseFromURL(url, emotion: emotion)
                }
            }
        }

        webSocket.onParentIntervention = { [weak self] id, textContent in
            self?.parentInterventionMessage = textContent
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self?.parentInterventionMessage = nil
            }
        }

        webSocket.onConversationEndedByParent = { [weak self] in
            Task { await self?.endMission(userInitiated: true) }
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

    // MARK: - Typewriter Animation

    private func startTypewriter(fullText: String, audioUrl: String?, audioData: Data? = nil, emotion: Emotion) {
        typewriterTask?.cancel()
        typewriterText = ""
        isTypewriting = true

        // Start TTS playback — prefer inline audio data over URL download
        if let audioData, !audioData.isEmpty {
            // Play directly from inline data (fastest, no network roundtrip)
            print("ConversationVM: Playing TTS from inline audio data (\(audioData.count) bytes)")
            audioEngine.playResponse(data: audioData, emotion: emotion)
        } else if let audioUrl, !audioUrl.isEmpty {
            // Fall back to downloading from URL
            let fullUrl = audioUrl.hasPrefix("http") ? audioUrl : "\(backendBaseURL)\(audioUrl)"
            if let url = URL(string: fullUrl) {
                print("ConversationVM: Starting TTS download from: \(fullUrl)")
                audioEngine.playResponseFromURL(url, emotion: emotion)
            } else {
                print("ConversationVM: Invalid TTS URL: \(fullUrl)")
                audioEngine.state = .idle
            }
        } else {
            print("ConversationVM: No audio URL and no inline data -- text-only mode")
            audioEngine.state = .idle
        }

        guard !fullText.isEmpty else {
            isTypewriting = false
            return
        }

        // Estimate TTS duration: ~2.5 words/sec for children's speech
        let wordCount = fullText.split(separator: " ").count
        let estimatedDuration = max(2.0, Double(wordCount) / 2.5)
        let charDelay = max(20, Int((estimatedDuration / Double(fullText.count)) * 1000))

        typewriterTask = Task { @MainActor in
            for char in fullText {
                if Task.isCancelled { break }
                typewriterText.append(char)
                try? await Task.sleep(for: .milliseconds(charDelay))
            }
            isTypewriting = false
        }
    }

    // MARK: - Helpers

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
                            self.startTypewriter(fullText: msg.textContent, audioUrl: audioUrl, emotion: emotion)
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
