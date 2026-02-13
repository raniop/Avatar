import Foundation

final class APIClient: Sendable {
    static let shared = APIClient()

    // TODO: Replace with your actual backend URL
    private let baseURL = "http://localhost:3000/api/v1"
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var authToken: String?

    private init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func setAuthToken(_ token: String) {
        // Note: In production, use an actor or lock for thread safety
        nonisolated(unsafe) let client = self
        client.authToken = token
    }

    // MARK: - Auth

    func firebaseAuth(idToken: String, displayName: String) async throws -> User {
        let response: FirebaseAuthResponse = try await post("/auth/firebase", body: [
            "idToken": idToken,
            "displayName": displayName
        ])
        return response.user
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        try await post("/auth/login", body: ["email": email, "password": password])
    }

    func register(email: String, password: String, displayName: String) async throws -> AuthResponse {
        try await post("/auth/register", body: [
            "email": email,
            "password": password,
            "displayName": displayName
        ])
    }

    func getCurrentUser() async throws -> User {
        try await get("/users/me")
    }

    // MARK: - Children

    func getChildren() async throws -> [Child] {
        try await get("/children")
    }

    func createChild(_ child: CreateChildRequest) async throws -> Child {
        try await post("/children", body: child)
    }

    func updateChild(id: String, _ update: UpdateChildRequest) async throws -> Child {
        try await patch("/children/\(id)", body: update)
    }

    // MARK: - Avatar

    func createAvatar(childId: String, config: CreateAvatarRequest) async throws -> AvatarConfig {
        try await post("/children/\(childId)/avatar", body: config)
    }

    func getAvatar(childId: String) async throws -> AvatarConfig {
        try await get("/children/\(childId)/avatar")
    }

    // MARK: - Missions

    func getMissions() async throws -> [Mission] {
        try await get("/missions")
    }

    func getDailyMission(childId: String) async throws -> Mission {
        try await get("/children/\(childId)/missions/daily")
    }

    // MARK: - Conversations

    func createConversation(childId: String, missionId: String, locale: AppLocale) async throws -> Conversation {
        try await post("/conversations", body: [
            "childId": childId,
            "missionId": missionId,
            "locale": locale.rawValue
        ])
    }

    func endConversation(id: String) async throws -> Conversation {
        try await patch("/conversations/\(id)/end", body: EmptyBody())
    }

    func getConversations(childId: String) async throws -> [Conversation] {
        try await get("/children/\(childId)/conversations")
    }

    func getConversationSummary(conversationId: String) async throws -> ConversationSummary {
        try await get("/conversations/\(conversationId)/summary")
    }

    func getConversationTranscript(conversationId: String) async throws -> [Message] {
        try await get("/conversations/\(conversationId)/transcript")
    }

    // MARK: - Parent Questions

    func getQuestions(childId: String) async throws -> [ParentQuestion] {
        try await get("/children/\(childId)/questions")
    }

    func createQuestion(childId: String, question: CreateQuestionRequest) async throws -> ParentQuestion {
        try await post("/children/\(childId)/questions", body: question)
    }

    func deleteQuestion(id: String) async throws {
        try await delete("/questions/\(id)")
    }

    // MARK: - Parent Intervention

    func sendIntervention(conversationId: String, text: String) async throws {
        let _: EmptyResponse = try await post("/conversations/\(conversationId)/intervene", body: ["text": text])
    }

    // MARK: - HTTP Helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let request = try buildRequest(path: path, method: "GET")
        return try await execute(request)
    }

    private func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var request = try buildRequest(path: path, method: "POST")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }

    private func patch<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var request = try buildRequest(path: path, method: "PATCH")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }

    private func delete(_ path: String) async throws {
        let request = try buildRequest(path: path, method: "DELETE")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed
        }
    }

    private func buildRequest(path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.requestFailed
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.serverError(httpResponse.statusCode)
        }

        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - Request/Response Types

struct CreateChildRequest: Encodable {
    let name: String
    let age: Int
    let gender: String?
    let interests: [String]
    let developmentGoals: [String]
    let locale: String
}

struct UpdateChildRequest: Encodable {
    var name: String?
    var age: Int?
    var interests: [String]?
    var developmentGoals: [String]?
}

struct CreateAvatarRequest: Encodable {
    let name: String
    let skinTone: String
    let hairStyle: String
    let hairColor: String
    let eyeColor: String
    let outfit: String
    let accessories: [String]
    let voiceId: String
}

struct CreateQuestionRequest: Encodable {
    let questionText: String
    let topic: String?
    let priority: Int
    let isRecurring: Bool
}

struct EmptyBody: Encodable {}
struct EmptyResponse: Decodable {}

struct FirebaseAuthResponse: Decodable {
    let user: User
    let accessToken: String
}
