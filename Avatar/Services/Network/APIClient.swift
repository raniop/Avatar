import Foundation

final class APIClient: Sendable {
    static let shared = APIClient()

    // Backend hosted on Railway
    private let baseURL = "https://poetic-serenity-production-7de7.up.railway.app/api"
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    nonisolated(unsafe) private var authToken: String?

    private init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            // Try ISO8601 with fractional seconds first, then without
            let formatters: [ISO8601DateFormatter] = {
                let f1 = ISO8601DateFormatter()
                f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let f2 = ISO8601DateFormatter()
                f2.formatOptions = [.withInternetDateTime]
                return [f1, f2]
            }()
            for formatter in formatters {
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        // Backend returns camelCase JSON — do NOT use .convertFromSnakeCase

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // Backend expects camelCase — do NOT use .convertToSnakeCase
    }

    func setAuthToken(_ token: String) {
        nonisolated(unsafe) let client = self
        client.authToken = token
    }

    func clearAuthToken() {
        nonisolated(unsafe) let client = self
        client.authToken = nil
    }

    // MARK: - Auth

    func firebaseAuth(idToken: String, displayName: String) async throws -> FirebaseAuthResponse {
        try await post("/auth/firebase", body: [
            "idToken": idToken,
            "displayName": displayName
        ])
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

    func getCurrentUser() async throws -> UserWrapper {
        try await get("/auth/me")
    }

    // MARK: - Children

    func getChildren() async throws -> [Child] {
        let wrapper: ChildrenWrapper = try await get("/children")
        return wrapper.children
    }

    func createChild(_ child: CreateChildRequest) async throws -> Child {
        let wrapper: ChildWrapper = try await post("/children", body: child)
        return wrapper.child
    }

    func updateChild(id: String, _ update: UpdateChildRequest) async throws -> Child {
        let wrapper: ChildWrapper = try await put("/children/\(id)", body: update)
        return wrapper.child
    }

    func deleteChild(id: String) async throws {
        try await delete("/children/\(id)")
    }

    // MARK: - Avatar

    func createAvatar(config: CreateAvatarRequest) async throws -> AvatarConfig {
        let wrapper: AvatarWrapper = try await post("/avatars", body: config)
        return wrapper.avatar
    }

    func getAvatar(childId: String) async throws -> AvatarConfig {
        let wrapper: AvatarWrapper = try await get("/avatars/child/\(childId)")
        return wrapper.avatar
    }

    func setAvatarName(childId: String, name: String, voiceId: String? = nil) async throws {
        struct NameBody: Encodable { let name: String; let voiceId: String? }
        let _: AvatarWrapper = try await patch("/avatars/child/\(childId)/name", body: NameBody(name: name, voiceId: voiceId))
    }

    // MARK: - Missions

    func getMissions(age: Int? = nil, locale: String = "en", interests: [String]? = nil) async throws -> [Mission] {
        var path = "/missions?locale=\(locale)"
        if let age { path += "&age=\(age)" }
        if let interests, !interests.isEmpty {
            let joined = interests.joined(separator: ",")
            if let encoded = joined.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                path += "&interests=\(encoded)"
            }
        }
        let wrapper: MissionsWrapper = try await get(path)
        return wrapper.missions
    }

    func getDailyMission(childId: String, locale: String = "en") async throws -> Mission? {
        let wrapper: DailyMissionWrapper = try await get("/missions/daily/\(childId)?locale=\(locale)")
        return wrapper.mission
    }

    // MARK: - Conversations

    func createConversation(childId: String, missionId: String?, locale: AppLocale) async throws -> CreateConversationResponse {
        var body: [String: String] = [
            "childId": childId,
            "locale": locale.rawValue
        ]
        if let missionId { body["missionId"] = missionId }
        return try await post("/conversations", body: body)
    }

    func endConversation(id: String) async throws -> EndConversationResponse {
        try await post("/conversations/\(id)/end", body: EmptyBody())
    }

    func getConversations(childId: String, limit: Int = 20) async throws -> ConversationsWrapper {
        try await get("/conversations/child/\(childId)?limit=\(limit)")
    }

    func getConversationSummary(conversationId: String) async throws -> SummaryWrapper {
        try await get("/conversations/\(conversationId)/summary")
    }

    func getConversationTranscript(conversationId: String) async throws -> TranscriptWrapper {
        try await get("/conversations/\(conversationId)/transcript")
    }

    // MARK: - Parent Questions

    func getQuestions(childId: String) async throws -> [ParentQuestion] {
        let wrapper: QuestionsWrapper = try await get("/questions/child/\(childId)")
        return wrapper.questions
    }

    func createQuestion(childId: String, question: CreateQuestionRequest) async throws -> ParentQuestion {
        // Backend expects childId in the body, not in the URL
        let body = CreateQuestionRequestWithChild(
            childId: childId,
            questionText: question.questionText,
            topic: question.topic,
            priority: question.priority,
            isRecurring: question.isRecurring
        )
        let wrapper: QuestionWrapper = try await post("/questions", body: body)
        return wrapper.question
    }

    func deleteQuestion(id: String) async throws {
        try await delete("/questions/\(id)")
    }

    // MARK: - Parent Intervention

    func sendIntervention(conversationId: String, text: String) async throws {
        let _: InterventionResponse = try await post("/conversations/\(conversationId)/intervene", body: ["textContent": text])
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

    private func put<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var request = try buildRequest(path: path, method: "PUT")
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
            // Log response body for debugging
            if let body = String(data: data, encoding: .utf8) {
                print("API Error \(httpResponse.statusCode): \(body)")
            }
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.serverError(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            if let body = String(data: data, encoding: .utf8) {
                print("Decoding error for \(T.self): \(error)")
                print("Response body: \(body)")
            }
            throw APIError.decodingError
        }
    }
}

// MARK: - Request Types

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
    let childId: String
    let name: String
    let skinTone: String
    let hairStyle: String
    let hairColor: String
    let eyeColor: String
    let outfit: String
    let accessories: [String]
    let voiceId: String?
    let personalityTraits: [String]
}

struct CreateQuestionRequest: Encodable {
    let questionText: String
    let topic: String?
    let priority: Int
    let isRecurring: Bool
}

struct CreateQuestionRequestWithChild: Encodable {
    let childId: String
    let questionText: String
    let topic: String?
    let priority: Int
    let isRecurring: Bool
}

struct EmptyBody: Encodable {}
struct EmptyResponse: Decodable {}

// MARK: - Response Wrapper Types

struct FirebaseAuthResponse: Decodable {
    let user: User
    let accessToken: String
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let user: User
}

struct UserWrapper: Decodable {
    let user: User
}

struct ChildrenWrapper: Decodable {
    let children: [Child]
}

struct ChildWrapper: Decodable {
    let child: Child
}

struct AvatarWrapper: Decodable {
    let avatar: AvatarConfig
}

struct MissionsWrapper: Decodable {
    let missions: [Mission]
}

struct DailyMissionWrapper: Decodable {
    let mission: Mission?
}

struct CreateConversationResponse: Decodable {
    let conversation: Conversation
    let openingMessage: OpeningMessage

    struct OpeningMessage: Decodable {
        let id: String
        let role: String
        let textContent: String
        let emotion: String?
        let audioUrl: String?
        let audioData: String?  // base64-encoded MP3 audio
        let timestamp: Date
    }
}

struct EndConversationResponse: Decodable {
    let conversation: EndedConversation

    struct EndedConversation: Decodable {
        let id: String
        let status: String
        let endedAt: Date?
        let durationSeconds: Int?
    }
}

struct ConversationsWrapper: Decodable {
    let conversations: [ConversationListItem]
    let pagination: Pagination

    struct Pagination: Decodable {
        let total: Int
        let limit: Int
        let offset: Int
    }
}

struct ConversationListItem: Decodable, Identifiable {
    let id: String
    let missionId: String?
    let status: String
    let locale: String
    let startedAt: Date
    let endedAt: Date?
    let durationSeconds: Int?
    let mission: MissionInfo?
    let summary: SummaryInfo?

    struct MissionInfo: Decodable {
        let theme: String
        let titleEn: String
        let titleHe: String
    }

    struct SummaryInfo: Decodable {
        let briefSummary: String
        let moodAssessment: String?
        let engagementLevel: String?
    }
}

struct TranscriptWrapper: Decodable {
    let conversation: TranscriptConversation
    let messages: [Message]

    struct TranscriptConversation: Decodable {
        let id: String
        let status: String
        let locale: String
        let startedAt: Date
        let endedAt: Date?
        let durationSeconds: Int?
    }
}

struct SummaryWrapper: Decodable {
    let summary: ConversationSummary
}

struct QuestionsWrapper: Decodable {
    let questions: [ParentQuestion]
}

struct QuestionWrapper: Decodable {
    let question: ParentQuestion
}

struct InterventionResponse: Decodable {
    let message: InterventionMessage

    struct InterventionMessage: Decodable {
        let id: String
        let role: String
        let textContent: String
        let isParentIntervention: Bool
        let timestamp: Date
    }
}
