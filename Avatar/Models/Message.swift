import Foundation

struct Message: Codable, Identifiable, Equatable {
    let id: String
    var conversationId: String?
    let role: MessageRole
    let textContent: String
    var audioUrl: String?
    var audioDuration: Double?
    var emotion: Emotion?
    var isParentIntervention: Bool?
    let timestamp: Date
}
