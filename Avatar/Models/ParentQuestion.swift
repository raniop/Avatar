import Foundation

struct ParentQuestion: Codable, Identifiable, Equatable {
    let id: String
    let childId: String
    var questionText: String
    var topic: String?
    var priority: Int
    var isActive: Bool
    var isRecurring: Bool
    let createdAt: Date
}
