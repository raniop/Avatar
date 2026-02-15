import Foundation
import Observation

/// WebSocket client that speaks the Socket.io v4 protocol (Engine.IO v4)
/// using native URLSessionWebSocketTask (no external dependencies).
///
/// Socket.io protocol packets:
/// Engine.IO: 0=open, 2=ping, 3=pong, 4=message, 5=upgrade, 6=noop
/// Socket.IO: 0=connect, 1=disconnect, 2=event, 3=ack, 4=connect_error
///
/// An event message looks like: "42[\"eventName\",{...data...}]"
/// A connect message looks like: "40" or "40/namespace,"
@Observable
final class WebSocketClient {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    var connectionState: ConnectionState = .disconnected

    // MARK: - Callbacks

    // Connection events
    var onReconnected: (() -> Void)?                                // Called after successful reconnect

    // Conversation events
    var onConversationJoined: ((String) -> Void)?                  // (conversationId)
    var onConversationProcessing: ((String) -> Void)?              // (status: "transcribing"|"thinking")
    var onConversationResponse: (([String: Any]) -> Void)?         // (full response data)
    var onConversationAudio: (([String: Any]) -> Void)?            // (audio data for a message)
    var onParentIntervention: ((String, String) -> Void)?          // (id, textContent)
    var onConversationEndedByParent: (() -> Void)?
    var onConversationError: ((String) -> Void)?

    // Parent monitoring events
    var onMonitorStarted: (([String: Any]) -> Void)?              // (monitor data with messages)
    var onMessageUpdate: (([String: Any]) -> Void)?               // (message update data)
    var onInterventionSent: (([String: Any]) -> Void)?            // (intervention confirmation)
    var onParentConversationEnded: (([String: Any]) -> Void)?     // (conversation ended)
    var onActiveSessions: (([[String: Any]]) -> Void)?            // (active sessions list)
    var onParentError: ((String) -> Void)?

    // MARK: - Private

    private var webSocket: URLSessionWebSocketTask?
    private let baseURL: String
    private var pingTimer: Timer?
    private var sid: String?
    private var authToken: String?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var isReconnecting = false  // Track reconnect state separately

    init(baseURL: String = "https://poetic-serenity-production-7de7.up.railway.app") {
        self.baseURL = baseURL
    }

    // MARK: - Connection

    func connect(token: String? = nil) {
        guard connectionState != .connected && connectionState != .connecting else { return }
        connectionState = .connecting
        self.authToken = token

        // Socket.io v4 uses Engine.IO v4 — start with polling handshake, then upgrade to WS
        // For simplicity, connect directly to websocket transport
        var urlString = baseURL
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")
        urlString += "/ws/?EIO=4&transport=websocket"

        if let token {
            urlString += "&token=\(token)"
        }

        guard let url = URL(string: urlString) else {
            connectionState = .error("Invalid URL")
            return
        }

        print("WebSocket: Connecting to \(urlString.prefix(80))...")
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300  // 5 min — AI responses can take a while
        config.timeoutIntervalForResource = 600
        let session = URLSession(configuration: config)
        webSocket = session.webSocketTask(with: url)
        // Increase maximumMessageSize for large audio payloads
        webSocket?.maximumMessageSize = 10 * 1024 * 1024  // 10 MB
        webSocket?.resume()

        // Start receiving messages
        receiveMessages()
    }

    func disconnect() {
        stopPingTimer()
        // Send Socket.IO disconnect: "41"
        sendRaw("41")
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        connectionState = .disconnected
        sid = nil
    }

    // MARK: - Conversation Events (Child)

    func joinConversation(conversationId: String, childId: String, parentUserId: String, locale: String = "en") {
        emitEvent("conversation:join", data: [
            "conversationId": conversationId,
            "childId": childId,
            "parentUserId": parentUserId,
            "locale": locale
        ])
    }

    func sendVoiceData(audioData: Data) {
        // For binary audio, send as base64 in a JSON event
        let base64Audio = audioData.base64EncodedString()
        emitEvent("conversation:voice", data: [
            "audioData": base64Audio
        ])
    }

    func sendTextMessage(textContent: String) {
        emitEvent("conversation:text", data: [
            "textContent": textContent
        ])
    }

    func leaveConversation() {
        emitEvent("conversation:leave", data: [:])
    }

    // MARK: - Parent Events

    func startMonitoring(parentUserId: String, conversationId: String) {
        emitEvent("parent:monitor", data: [
            "parentUserId": parentUserId,
            "conversationId": conversationId
        ])
    }

    func sendParentIntervention(parentUserId: String, conversationId: String, textContent: String) {
        emitEvent("parent:intervene", data: [
            "parentUserId": parentUserId,
            "conversationId": conversationId,
            "textContent": textContent
        ])
    }

    func stopMonitoring(conversationId: String) {
        emitEvent("parent:stop_monitor", data: [
            "conversationId": conversationId
        ])
    }

    func endConversationAsParent(parentUserId: String, conversationId: String) {
        emitEvent("parent:end_conversation", data: [
            "parentUserId": parentUserId,
            "conversationId": conversationId
        ])
    }

    func getActiveSessions(parentUserId: String) {
        emitEvent("parent:get_active_sessions", data: [
            "parentUserId": parentUserId
        ])
    }

    // MARK: - Socket.IO Protocol

    /// Emit a Socket.IO event: "42[\"eventName\",{data}]"
    private func emitEvent(_ event: String, data: [String: Any]) {
        guard connectionState == .connected else {
            print("WebSocket: Cannot emit \(event) — not connected (state: \(connectionState))")
            return
        }
        let payload: [Any] = [event, data]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("WebSocket: Failed to serialize event \(event)")
            return
        }
        // Prepend "42" for Socket.IO event type
        let dataSize = event == "conversation:voice" ? "(audio \(data["audioData"].map { "\(($0 as? String)?.count ?? 0) chars" } ?? "?"))" : ""
        print("WebSocket: Emitting \(event) \(dataSize)")
        sendRaw("42\(jsonString)")
    }

    private func sendRaw(_ text: String) {
        webSocket?.send(.string(text)) { [weak self] error in
            if let error {
                print("WebSocket send error: \(error.localizedDescription)")
                self?.onConversationError?(error.localizedDescription)
            }
        }
    }

    // MARK: - Receive & Parse

    private func receiveMessages() {
        webSocket?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                self.reconnectAttempts = 0  // Reset on successful receive
                switch message {
                case .string(let text):
                    self.handleRawMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleRawMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue listening
                self.receiveMessages()

            case .failure(let error):
                print("WebSocket: Receive error: \(error.localizedDescription)")
                Task { @MainActor in
                    self.connectionState = .error(error.localizedDescription)
                    self.attemptReconnect()
                }
            }
        }
    }

    private func attemptReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            print("WebSocket: Max reconnect attempts reached (\(maxReconnectAttempts))")
            isReconnecting = false
            return
        }
        reconnectAttempts += 1
        isReconnecting = true  // Flag stays true until onReconnected fires
        let delay = reconnectAttempts == 1 ? 0.3 : Double(reconnectAttempts) * 1.0  // 0.3s, 2s, 3s...
        print("WebSocket: Reconnecting in \(delay)s (attempt \(reconnectAttempts)/\(maxReconnectAttempts))")

        // Clean up old socket
        stopPingTimer()
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        sid = nil
        connectionState = .disconnected

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connect(token: self?.authToken)
        }
    }

    private func handleRawMessage(_ raw: String) {
        // Engine.IO message types:
        // 0 = open (contains session info)
        // 2 = ping
        // 3 = pong
        // 4 = Socket.IO message
        guard let firstChar = raw.first else { return }

        switch firstChar {
        case "0":
            // Engine.IO open packet — extract sid and setup ping
            handleOpen(raw)

        case "2":
            // Engine.IO ping — respond with pong
            sendRaw("3")

        case "3":
            // Engine.IO pong — ignore
            break

        case "4":
            // Socket.IO packet — parse the sub-type
            let socketIOPayload = String(raw.dropFirst())
            handleSocketIOPacket(socketIOPayload)

        default:
            print("WebSocket: Unknown EIO packet: \(raw.prefix(20))")
        }
    }

    private func handleOpen(_ raw: String) {
        // Parse: 0{"sid":"xxx","upgrades":[],"pingInterval":25000,"pingTimeout":20000}
        let jsonPart = String(raw.dropFirst())
        guard let data = jsonPart.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        sid = json["sid"] as? String
        let pingInterval = (json["pingInterval"] as? Int) ?? 25000

        // Send Socket.IO connect packet: "40"
        sendRaw("40")

        // Start ping timer
        startPingTimer(interval: TimeInterval(pingInterval) / 1000.0)
    }

    private func handleSocketIOPacket(_ packet: String) {
        guard let firstChar = packet.first else { return }

        switch firstChar {
        case "0":
            // Socket.IO connect acknowledgment
            Task { @MainActor in
                self.connectionState = .connected
                if self.isReconnecting {
                    print("WebSocket: Reconnected to Socket.IO — re-joining conversation")
                    self.isReconnecting = false
                    self.reconnectAttempts = 0
                    self.onReconnected?()
                }
            }
            print("WebSocket: Connected to Socket.IO")

        case "1":
            // Socket.IO disconnect
            Task { @MainActor in
                self.connectionState = .disconnected
            }

        case "2":
            // Socket.IO event: "2[\"eventName\",{data}]"
            let eventPayload = String(packet.dropFirst())
            handleEvent(eventPayload)

        case "4":
            // Socket.IO connect error
            let errorPayload = String(packet.dropFirst())
            print("WebSocket: Socket.IO connect error: \(errorPayload)")
            Task { @MainActor in
                self.connectionState = .error("Connection rejected")
            }

        default:
            break
        }
    }

    private func handleEvent(_ payload: String) {
        guard let data = payload.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let eventName = array.first as? String else {
            print("WebSocket: Failed to parse event: \(payload.prefix(100))")
            return
        }

        let eventData = array.count > 1 ? array[1] as? [String: Any] ?? [:] : [:]

        Task { @MainActor in
            self.routeEvent(eventName, data: eventData)
        }
    }

    private func routeEvent(_ event: String, data: [String: Any]) {
        switch event {
        // ── Conversation Events ──────────────
        case "conversation:joined":
            let conversationId = data["conversationId"] as? String ?? ""
            onConversationJoined?(conversationId)

        case "conversation:processing":
            let status = data["status"] as? String ?? ""
            onConversationProcessing?(status)

        case "conversation:response":
            onConversationResponse?(data)

        case "conversation:audio":
            onConversationAudio?(data)

        case "conversation:parent_intervention":
            let id = data["id"] as? String ?? ""
            let textContent = data["textContent"] as? String ?? ""
            onParentIntervention?(id, textContent)

        case "conversation:ended_by_parent":
            onConversationEndedByParent?()

        case "conversation:error":
            let message = data["message"] as? String ?? "Unknown error"
            onConversationError?(message)

        case "conversation:left":
            break

        // ── Parent Events ────────────────────
        case "parent:monitor_started":
            onMonitorStarted?(data)

        case "parent:message_update":
            onMessageUpdate?(data)

        case "parent:intervention_sent":
            onInterventionSent?(data)

        case "parent:conversation_ended":
            onParentConversationEnded?(data)

        case "parent:active_sessions":
            let sessions = data["sessions"] as? [[String: Any]] ?? []
            onActiveSessions?(sessions)

        case "parent:error":
            let message = data["message"] as? String ?? "Unknown error"
            onParentError?(message)

        case "parent:monitor_stopped":
            break

        default:
            print("WebSocket: Unhandled event: \(event)")
        }
    }

    // MARK: - Ping/Pong

    private func startPingTimer(interval: TimeInterval) {
        stopPingTimer()
        DispatchQueue.main.async { [weak self] in
            self?.pingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.sendRaw("2")  // Engine.IO ping
            }
        }
    }

    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
}
