import Foundation

struct Message: Codable, Identifiable, Equatable {
    let id: String
    let conversationId: String
    let role: MessageRole
    let textContent: String
    var audioUrl: String?
    var audioDuration: Double?
    var emotion: Emotion?
    let isParentIntervention: Bool
    let timestamp: Date
}
