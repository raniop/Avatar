import Foundation

enum ConversationStatus: String, Codable {
    case active
    case paused
    case completed
    case abandoned
}

enum MessageRole: String, Codable {
    case child
    case avatar
    case system
    case parentIntervention
}
