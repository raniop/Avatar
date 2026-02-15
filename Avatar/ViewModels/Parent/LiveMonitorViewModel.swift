import Foundation
import Observation

@Observable
final class LiveMonitorViewModel {
    var messages: [Message] = []
    var interventionText = ""
    var isConnected = false

    private let conversation: Conversation
    private let parentUserId: String
    private let webSocket = WebSocketClient()
    private let apiClient = APIClient.shared

    init(conversation: Conversation, parentUserId: String) {
        self.conversation = conversation
        self.parentUserId = parentUserId
        setupWebSocket()
    }

    func startWatching() {
        let token = KeychainManager.shared.getAccessToken()
        webSocket.connect(token: token)

        // Wait for connection then start monitoring
        Task { @MainActor in
            try? await waitForConnection(timeout: 5.0)
            webSocket.startMonitoring(
                parentUserId: parentUserId,
                conversationId: conversation.id
            )
            isConnected = true
        }
    }

    func stopWatching() {
        webSocket.stopMonitoring(conversationId: conversation.id)
        webSocket.disconnect()
        isConnected = false
    }

    func sendIntervention() {
        guard !interventionText.isEmpty else { return }
        let text = interventionText
        interventionText = ""

        webSocket.sendParentIntervention(
            parentUserId: parentUserId,
            conversationId: conversation.id,
            textContent: text
        )

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

    // MARK: - Setup

    private func setupWebSocket() {
        // Monitor started — server sends existing message history
        webSocket.onMonitorStarted = { [weak self] data in
            guard let self else { return }
            // Parse existing messages from the monitor data
            if let existingMessages = data["messages"] as? [[String: Any]] {
                for msgData in existingMessages {
                    if let msg = self.parseMessage(from: msgData) {
                        self.messages.append(msg)
                    }
                }
            }
        }

        // New message update from the conversation
        webSocket.onMessageUpdate = { [weak self] data in
            guard let self else { return }
            if let msg = self.parseMessage(from: data) {
                self.messages.append(msg)
            }
        }

        // Intervention confirmation
        webSocket.onInterventionSent = { [weak self] _ in
            _ = self // Intervention already added locally
        }

        // Parent ended conversation
        webSocket.onParentConversationEnded = { [weak self] _ in
            self?.isConnected = false
        }

        // Error
        webSocket.onParentError = { [weak self] error in
            print("Parent monitor error: \(error)")
            _ = self
        }
    }

    // MARK: - Helpers

    private func parseMessage(from data: [String: Any]) -> Message? {
        guard let textContent = data["textContent"] as? String,
              let roleStr = data["role"] as? String else { return nil }

        let role: MessageRole
        switch roleStr.uppercased() {
        case "CHILD": role = .child
        case "AVATAR": role = .avatar
        case "PARENT_INTERVENTION": role = .parentIntervention
        default: role = .avatar
        }

        let emotionStr = data["emotion"] as? String
        let emotion = emotionStr.flatMap { Emotion(rawValue: $0) }

        return Message(
            id: data["id"] as? String ?? UUID().uuidString,
            conversationId: conversation.id,
            role: role,
            textContent: textContent,
            emotion: emotion,
            isParentIntervention: role == .parentIntervention,
            timestamp: Date()
        )
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
}
