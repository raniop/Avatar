import Foundation

enum ConversationStatus: String, Codable {
    case active = "ACTIVE"
    case paused = "PAUSED"
    case completed = "COMPLETED"
    case abandoned = "ABANDONED"
}

enum MessageRole: String, Codable {
    case child = "CHILD"
    case avatar = "AVATAR"
    case system = "SYSTEM"
    case parentIntervention = "PARENT_INTERVENTION"
}
