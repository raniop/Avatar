import Foundation
import Observation

@Observable
final class LiveMonitorViewModel {
    var messages: [Message] = []
    var interventionText = ""
    var isConnected = false

    private let conversation: Conversation
    private let webSocket = WebSocketClient()
    private let apiClient = APIClient.shared

    init(conversation: Conversation) {
        self.conversation = conversation
        setupWebSocket()
    }

    func startWatching() {
        if let token = KeychainManager.shared.getAccessToken() {
            webSocket.setAuthToken(token)
        }
        webSocket.connect()
        webSocket.startWatching(conversationId: conversation.id)
        isConnected = true
    }

    func stopWatching() {
        webSocket.stopWatching(conversationId: conversation.id)
        webSocket.disconnect()
        isConnected = false
    }

    func sendIntervention() {
        guard !interventionText.isEmpty else { return }
        let text = interventionText
        interventionText = ""

        webSocket.sendParentIntervention(conversationId: conversation.id, text: text)

        // Add local message for immediate feedback
        let message = Message(
            id: UUID().uuidString,
            conversationId: conversation.id,
            role: .parentIntervention,
            textContent: text,
            isParentIntervention: true,
            timestamp: Date()
        )
        messages.append(message)
    }

    private func setupWebSocket() {
        webSocket.onTranscription = { [weak self] text, isFinal in
            guard let self, isFinal else { return }
            let message = Message(
                id: UUID().uuidString,
                conversationId: self.conversation.id,
                role: .child,
                textContent: text,
                isParentIntervention: false,
                timestamp: Date()
            )
            self.messages.append(message)
        }

        webSocket.onAvatarResponseText = { [weak self] text, emotionStr in
            guard let self else { return }
            let message = Message(
                id: UUID().uuidString,
                conversationId: self.conversation.id,
                role: .avatar,
                textContent: text,
                emotion: Emotion(rawValue: emotionStr),
                isParentIntervention: false,
                timestamp: Date()
            )
            self.messages.append(message)
        }
    }
}
