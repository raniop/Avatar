import Foundation

struct Conversation: Codable, Identifiable, Hashable {
    let id: String
    let childId: String
    let missionId: String?
    var status: ConversationStatus
    let locale: AppLocale
    let startedAt: Date
    var endedAt: Date?
    var durationSeconds: Int?
}
