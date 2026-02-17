import Foundation
import Observation
import SwiftUI
import UIKit

@Observable
final class AdventureViewModel {
    enum Phase: Equatable {
        case loading
        case active
        case complete
        case dismissed
        case error(String)
    }

    // MARK: - State

    var phase: Phase = .loading

    /// The latest story text from the avatar (displayed in the story card)
    var storyText = ""
    /// The avatar's current emotion
    var avatarEmotion: Emotion = .happy

    // MARK: - Adventure State

    var adventureState: AdventureState?
    var scenesCompleted: [Bool] = [false, false, false]
    var starsEarned: Int = 0
    var showCelebration = false
    var earnedCollectible: AdventureCollectible?

    /// Set when a scene just completed — triggers star fly-in animation
    var justEarnedStar = false

    /// Whether the mini-game overlay is currently showing
    var showMiniGame = false

    // MARK: - Audio/Interaction State

    var isListening: Bool { audioEngine.state == .listening }
    var isProcessing: Bool { audioEngine.state == .processing }
    var isPlayingResponse: Bool { audioEngine.state == .playingResponse }
    var isAvatarThinking = false
    var currentTranscription = ""
    var parentInterventionMessage: String?

    // MARK: - Typewriter State

    var typewriterMessageId: String?
    var typewriterVisibleWords: Int = 0
    var typewriterWaitingForAudio = false
    private var typewriterTimer: Timer?
    private var typewriterTotalWords: Int = 0

    // MARK: - Dependencies

    let audioEngine = AudioEngine()
    let animator = AvatarAnimator()
    var avatarImage: UIImage?
    var friendImage: UIImage?
    private let webSocket = WebSocketClient()
    private let apiClient = APIClient.shared
    private let avatarStorage = AvatarStorage.shared

    // MARK: - Session Data

    let child: Child
    let mission: Mission
    private var conversationId: String?
    private var audioBuffer = Data()
    private var sessionStartTime: CFAbsoluteTime = 0
    private var pendingOpeningAudioMessageId: String?
    private let backendBaseURL = "https://poetic-serenity-production-7de7.up.railway.app"

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

    func startAdventure() async {
        if let saved = await avatarStorage.loadAvatar(childId: child.id) {
            avatarImage = saved.image
        }
        loadFriendImage()

        phase = .loading
        let startTime = CFAbsoluteTimeGetCurrent()
        sessionStartTime = startTime

        let token = KeychainManager.shared.getAccessToken()
        webSocket.connect(token: token)

        do {
            let response = try await apiClient.createConversation(
                childId: child.id,
                missionId: mission.id,
                locale: appLocale
            )
            print("AdventureVM: [TIMING] API response: +\(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - startTime) * 1000))ms")

            let convId = response.conversation.id
            let opening = response.openingMessage
            conversationId = convId

            // Set initial adventure state from opening response
            if let adventure = opening.adventure {
                adventureState = adventure
            }

            // Set the opening story text
            storyText = opening.textContent

            // Play opening audio
            let openingAudioData: Data? = opening.audioData.flatMap { Data(base64Encoded: $0) }

            if let openingAudioData, !openingAudioData.isEmpty {
                beginTypewriterWait(messageId: opening.id, text: opening.textContent)
                phase = .active
                let emotion = opening.emotion.flatMap { Emotion(rawValue: $0) } ?? .happy
                audioEngine.playResponse(data: openingAudioData, emotion: emotion)
            } else if let audioUrl = opening.audioUrl, !audioUrl.isEmpty {
                let fullUrl = audioUrl.hasPrefix("http") ? audioUrl : "\(backendBaseURL)\(audioUrl)"
                if let url = URL(string: fullUrl) {
                    beginTypewriterWait(messageId: opening.id, text: opening.textContent)
                    phase = .active
                    let emotion = opening.emotion.flatMap { Emotion(rawValue: $0) } ?? .happy
                    audioEngine.playResponseFromURL(url, emotion: emotion)
                }
            } else {
                pendingOpeningAudioMessageId = opening.id
                beginTypewriterWait(messageId: opening.id, text: opening.textContent)

                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(20))
                    guard let self, self.phase == .loading else { return }
                    self.stopTypewriter()
                    self.phase = .active
                }
            }

            // Connect WebSocket and join room
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
                    print("AdventureVM: WebSocket connection failed: \(error)")
                }
            }

        } catch {
            print("AdventureVM: Error starting adventure: \(error)")
            phase = .error(error.localizedDescription)
        }
    }

    // MARK: - Child Interactions

    /// Called when child taps a choice button
    func selectChoice(_ choice: AdventureChoice) {
        guard phase == .active, audioEngine.state == .idle else { return }
        audioEngine.state = .processing
        isAvatarThinking = true
        webSocket.sendTextMessage(textContent: "[Choice] \(choice.label)")
    }

    func onTalkButtonPressed() {
        guard phase == .active, audioEngine.state == .idle else { return }
        audioBuffer = Data()
        audioEngine.startListening()
    }

    func onTalkButtonReleased() {
        guard audioEngine.state == .listening else { return }
        audioEngine.stopListening()
    }

    func sendTextMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, phase == .active, audioEngine.state == .idle else { return }
        audioEngine.state = .processing
        isAvatarThinking = true
        webSocket.sendTextMessage(textContent: trimmed)
    }

    func endAdventure() async {
        stopTypewriter()
        audioEngine.reset()
        webSocket.leaveConversation()
        phase = .dismissed
        webSocket.disconnect()
    }

    // MARK: - Mini-Game

    /// Called by MiniGameContainerView when a round completes
    func reportGameResult(_ result: GameResult) {
        withAnimation(.easeInOut(duration: 0.3)) {
            showMiniGame = false
        }

        // Send result to backend via WebSocket
        let message = "[GameResult] round=\(result.round) score=\(result.score) total=\(result.total) stars=\(result.earnedStar ? 1 : 0)"
        audioEngine.state = .processing
        isAvatarThinking = true
        webSocket.sendTextMessage(textContent: message)
    }

    // MARK: - Setup

    private func setupCallbacks() {
        webSocket.onReconnected = { [weak self] in
            guard let self, let convId = self.conversationId else { return }
            self.webSocket.joinConversation(
                conversationId: convId,
                childId: self.child.id,
                parentUserId: self.child.parentId,
                locale: self.appLocale.rawValue
            )
        }

        audioEngine.onAudioChunkReady = { [weak self] chunk in
            self?.audioBuffer.append(chunk)
        }

        audioEngine.onRecordingFinished = { [weak self] in
            guard let self else { return }
            let minimumPCMBytes = 16000
            guard self.audioBuffer.count >= minimumPCMBytes else {
                self.audioBuffer = Data()
                self.audioEngine.state = .idle
                return
            }
            let wavData = AudioRecorder.buildWAVData(from: self.audioBuffer)
            self.audioBuffer = Data()
            self.isAvatarThinking = true
            self.webSocket.sendVoiceData(audioData: wavData)

            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(45))
                guard let self, self.audioEngine.state == .processing else { return }
                self.audioEngine.state = .idle
                self.isAvatarThinking = false
            }
        }

        audioEngine.player.onAmplitudeUpdate = { [weak self] amplitude in
            self?.animator.updateLipSync(amplitude: amplitude)
        }

        audioEngine.onAudioDurationReady = { [weak self] duration in
            guard let self, self.typewriterMessageId != nil else { return }
            self.startTypewriterSynced(duration: duration)
        }

        audioEngine.onPlaybackComplete = { [weak self] in
            guard let self else { return }
            self.stopTypewriter()

            // After audio finishes for a celebrate interaction, auto-advance
            if self.adventureState?.interactionType == .celebrate {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(1.5))
                    guard let self else { return }
                    if self.adventureState?.isAdventureComplete == true {
                        self.showCelebration = true
                    }
                }
            }

            // After audio finishes for a miniGame interaction, show the game
            if self.adventureState?.interactionType == .miniGame && self.adventureState?.miniGame != nil {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(0.5))
                    guard let self else { return }
                    withAnimation(.spring(response: 0.4)) {
                        self.showMiniGame = true
                    }
                }
            }
        }

        // MARK: Socket.IO Event Callbacks

        webSocket.onConversationJoined = { [weak self] conversationId in
            print("AdventureVM: Joined conversation: \(conversationId)")
            _ = self
        }

        webSocket.onConversationProcessing = { [weak self] status in
            if status == "thinking" {
                self?.isAvatarThinking = true
            }
        }

        webSocket.onConversationResponse = { [weak self] data in
            guard let self else { return }
            self.isAvatarThinking = false
            self.currentTranscription = ""

            // Parse avatar message
            guard let avatarMsg = data["avatarMessage"] as? [String: Any],
                  let avatarText = avatarMsg["textContent"] as? String else {
                self.audioEngine.state = .idle
                return
            }

            let avatarId = avatarMsg["id"] as? String ?? UUID().uuidString
            let emotionStr = avatarMsg["emotion"] as? String ?? "neutral"
            let emotion = Emotion(rawValue: emotionStr) ?? .neutral

            self.avatarEmotion = emotion
            self.animator.transitionToEmotion(emotion)

            // Update story text
            self.storyText = avatarText

            // Parse adventure state from response
            if let adventureDict = avatarMsg["adventure"] as? [String: Any] {
                self.parseAdventureState(from: adventureDict)
            }

            // Get audio
            let audioUrl = avatarMsg["audioUrl"] as? String
            var inlineAudioData: Data?
            if let b64 = avatarMsg["audioData"] as? String {
                inlineAudioData = Data(base64Encoded: b64)
            } else if let bufferDict = avatarMsg["audioData"] as? [String: Any],
                      let byteArray = bufferDict["data"] as? [Int] {
                inlineAudioData = Data(byteArray.map { UInt8($0 & 0xFF) })
            }

            let hasAudio = (inlineAudioData != nil && !inlineAudioData!.isEmpty) || (audioUrl != nil && !audioUrl!.isEmpty)
            if hasAudio {
                self.beginTypewriterWait(messageId: avatarId, text: avatarText)
                self.playAvatarAudio(audioUrl: audioUrl, audioData: inlineAudioData, emotion: emotion)
            } else {
                self.audioEngine.state = .idle
            }
        }

        webSocket.onConversationAudio = { [weak self] data in
            guard let self else { return }
            let isOpeningAudio = self.pendingOpeningAudioMessageId != nil
            guard self.audioEngine.state == .idle || isOpeningAudio else { return }
            self.pendingOpeningAudioMessageId = nil

            var audioData: Data?
            if let b64 = data["audioData"] as? String {
                audioData = Data(base64Encoded: b64)
            }
            let audioUrl = data["audioUrl"] as? String

            if isOpeningAudio && self.phase == .loading {
                self.phase = .active
            }

            self.playAvatarAudio(audioUrl: audioUrl, audioData: audioData, emotion: self.avatarEmotion)
        }

        webSocket.onParentIntervention = { [weak self] _, textContent in
            self?.parentInterventionMessage = textContent
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self?.parentInterventionMessage = nil
            }
        }

        webSocket.onConversationEndedByParent = { [weak self] in
            Task { await self?.endAdventure() }
        }

        webSocket.onConversationError = { [weak self] _ in
            self?.audioEngine.state = .idle
            self?.isAvatarThinking = false
        }
    }

    // MARK: - Adventure State Parsing

    private func parseAdventureState(from dict: [String: Any]) {
        let sceneIndex = dict["sceneIndex"] as? Int ?? 0
        let sceneName = dict["sceneName"] as? String ?? ""
        let sceneEmojis = dict["sceneEmojis"] as? [String] ?? []
        let interactionTypeStr = dict["interactionType"] as? String ?? "voice"
        let interactionType = AdventureState.InteractionType(rawValue: interactionTypeStr) ?? .voice
        let stars = dict["starsEarned"] as? Int ?? 0
        let isSceneComplete = dict["isSceneComplete"] as? Bool ?? false
        let isAdventureComplete = dict["isAdventureComplete"] as? Bool ?? false

        var choices: [AdventureChoice]?
        if let choicesArray = dict["choices"] as? [[String: Any]] {
            choices = choicesArray.map { c in
                AdventureChoice(
                    id: c["id"] as? String ?? UUID().uuidString,
                    emoji: c["emoji"] as? String ?? "",
                    label: c["label"] as? String ?? ""
                )
            }
        }

        var collectible: AdventureCollectible?
        if let collectibleDict = dict["collectible"] as? [String: Any] {
            collectible = AdventureCollectible(
                emoji: collectibleDict["emoji"] as? String ?? "",
                name: collectibleDict["name"] as? String ?? ""
            )
        }

        // Parse miniGame config
        var miniGame: MiniGameConfig?
        if let mgDict = dict["miniGame"] as? [String: Any],
           let typeStr = mgDict["type"] as? String,
           let mgType = MiniGameType(rawValue: typeStr),
           let mgRound = mgDict["round"] as? Int {
            miniGame = MiniGameConfig(type: mgType, round: mgRound)
        }

        let newState = AdventureState(
            sceneIndex: sceneIndex,
            sceneName: sceneName,
            sceneEmojis: sceneEmojis,
            interactionType: interactionType,
            choices: choices,
            miniGame: miniGame,
            starsEarned: stars,
            isSceneComplete: isSceneComplete,
            isAdventureComplete: isAdventureComplete,
            collectible: collectible
        )

        // Detect new star earned
        if stars > self.starsEarned {
            self.justEarnedStar = true
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1.5))
                self?.justEarnedStar = false
            }
        }

        // Update scene completion
        if isSceneComplete && sceneIndex < 3 {
            scenesCompleted[sceneIndex] = true
        }

        self.starsEarned = stars
        self.adventureState = newState

        if let collectible {
            self.earnedCollectible = collectible
        }

        if isAdventureComplete {
            // Show celebration after audio finishes (handled in onPlaybackComplete)
            // If no audio, show immediately
            if audioEngine.state == .idle {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(1.5))
                    self?.showCelebration = true
                }
            }
        }

        // Auto-show mini-game when interaction type is miniGame
        if interactionType == .miniGame && miniGame != nil {
            // Show game overlay after a brief delay (let avatar text show first)
            // If audio is playing, wait for it to finish (handled in onPlaybackComplete)
            if audioEngine.state == .idle {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(0.5))
                    guard let self else { return }
                    withAnimation(.spring(response: 0.4)) {
                        self.showMiniGame = true
                    }
                }
            }
        }
    }

    // MARK: - Audio Playback

    private func playAvatarAudio(audioUrl: String?, audioData: Data?, emotion: Emotion) {
        if let audioData, !audioData.isEmpty {
            audioEngine.playResponse(data: audioData, emotion: emotion)
        } else if let audioUrl, !audioUrl.isEmpty {
            let fullUrl = audioUrl.hasPrefix("http") ? audioUrl : "\(backendBaseURL)\(audioUrl)"
            if let url = URL(string: fullUrl) {
                audioEngine.playResponseFromURL(url, emotion: emotion)
            } else {
                audioEngine.state = .idle
            }
        } else {
            audioEngine.state = .idle
        }
    }

    // MARK: - Helpers

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

    // MARK: - Typewriter

    private func beginTypewriterWait(messageId: String, text: String) {
        stopTypewriter()
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        typewriterTotalWords = words.count
        typewriterVisibleWords = 0
        typewriterMessageId = messageId
        typewriterWaitingForAudio = true

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard let self, self.typewriterMessageId == messageId else { return }
            self.stopTypewriter()
        }
    }

    private func startTypewriterSynced(duration: TimeInterval) {
        guard typewriterMessageId != nil else { return }
        typewriterWaitingForAudio = false
        typewriterVisibleWords = max(typewriterVisibleWords, 1)

        let wordsLeft = typewriterTotalWords - typewriterVisibleWords
        guard wordsLeft > 0 else {
            stopTypewriter()
            return
        }

        let effectiveDuration = duration * 0.90
        let interval = max(0.05, effectiveDuration / Double(wordsLeft))

        typewriterTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            self.typewriterVisibleWords += 1
            if self.typewriterVisibleWords >= self.typewriterTotalWords {
                timer.invalidate()
                self.typewriterTimer = nil
            }
        }
    }

    private func stopTypewriter() {
        typewriterTimer?.invalidate()
        typewriterTimer = nil
        typewriterMessageId = nil
        typewriterVisibleWords = 0
        typewriterTotalWords = 0
        typewriterWaitingForAudio = false
    }

    /// Returns visible portion of story text during typewriter animation
    var visibleStoryText: String {
        guard typewriterMessageId != nil else { return storyText }
        if typewriterWaitingForAudio { return "" }
        let words = storyText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let count = min(typewriterVisibleWords, words.count)
        if count >= words.count { return storyText }
        if count == 0 { return " " }
        return words.prefix(count).joined(separator: " ")
    }

    var isTypewriterActive: Bool {
        typewriterMessageId != nil && !typewriterWaitingForAudio
    }
}
