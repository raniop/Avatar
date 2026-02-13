import Foundation
import Observation

@Observable
final class WebSocketClient {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    var connectionState: ConnectionState = .disconnected

    var onTranscription: ((String, Bool) -> Void)?  // (text, isFinal)
    var onAvatarResponseText: ((String, String) -> Void)?  // (text, emotion)
    var onAvatarResponseAudio: ((String, Double) -> Void)?  // (audioUrl, duration)
    var onParentIntervention: ((String) -> Void)?  // (text)
    var onConversationEnded: ((Data) -> Void)?  // (summary data)
    var onError: ((String) -> Void)?

    private var webSocket: URLSessionWebSocketTask?
    private let baseURL: String
    private var authToken: String?

    init(baseURL: String = "ws://localhost:3000") {
        self.baseURL = baseURL
    }

    func setAuthToken(_ token: String) {
        self.authToken = token
    }

    func connect() {
        guard connectionState != .connected && connectionState != .connecting else { return }
        connectionState = .connecting

        var urlString = "\(baseURL)/ws"
        if let token = authToken {
            urlString += "?token=\(token)"
        }

        guard let url = URL(string: urlString) else {
            connectionState = .error("Invalid URL")
            return
        }

        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        connectionState = .connected
        receiveMessages()
    }

    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        connectionState = .disconnected
    }

    // MARK: - Send Events

    func joinSession(conversationId: String, role: String) {
        send(event: "session:join", data: [
            "conversationId": conversationId,
            "role": role
        ])
    }

    func leaveSession(conversationId: String) {
        send(event: "session:leave", data: [
            "conversationId": conversationId
        ])
    }

    func sendAudioChunk(conversationId: String, audioData: Data, isFinal: Bool) {
        let base64Audio = audioData.base64EncodedString()
        send(event: "voice:audio_chunk", data: [
            "conversationId": conversationId,
            "audio": base64Audio,
            "isFinal": isFinal ? "true" : "false"
        ])
    }

    func sendParentIntervention(conversationId: String, text: String) {
        send(event: "parent:intervene", data: [
            "conversationId": conversationId,
            "text": text
        ])
    }

    func startWatching(conversationId: String) {
        send(event: "parent:watch_start", data: [
            "conversationId": conversationId
        ])
    }

    func stopWatching(conversationId: String) {
        send(event: "parent:watch_stop", data: [
            "conversationId": conversationId
        ])
    }

    // MARK: - Private

    private func send(event: String, data: [String: String]) {
        let payload: [String: Any] = [
            "event": event,
            "data": data
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        webSocket?.send(.string(jsonString)) { [weak self] error in
            if let error {
                self?.onError?(error.localizedDescription)
            }
        }
    }

    private func receiveMessages() {
        webSocket?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue listening
                self.receiveMessages()

            case .failure(let error):
                self.connectionState = .error(error.localizedDescription)
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? String,
              let eventData = json["data"] as? [String: Any] else { return }

        Task { @MainActor in
            switch event {
            case "voice:transcription":
                let transcription = eventData["text"] as? String ?? ""
                let isFinal = eventData["isFinal"] as? Bool ?? false
                self.onTranscription?(transcription, isFinal)

            case "avatar:response_text":
                let responseText = eventData["text"] as? String ?? ""
                let emotion = eventData["emotion"] as? String ?? "neutral"
                self.onAvatarResponseText?(responseText, emotion)

            case "avatar:response_audio":
                let audioUrl = eventData["audioUrl"] as? String ?? ""
                let duration = eventData["duration"] as? Double ?? 0
                self.onAvatarResponseAudio?(audioUrl, duration)

            case "parent:intervention_delivered":
                break

            case "parent:live_transcript":
                break

            case "conversation:ended":
                if let summaryData = try? JSONSerialization.data(withJSONObject: eventData) {
                    self.onConversationEnded?(summaryData)
                }

            case "error":
                let message = eventData["message"] as? String ?? "Unknown error"
                self.onError?(message)

            default:
                break
            }
        }
    }
}
