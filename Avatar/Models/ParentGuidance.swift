import Foundation

struct ParentGuidance: Codable, Identifiable {
    let id: String
    let childId: String
    let instruction: String
    let isActive: Bool
    let createdAt: Date
    var updatedAt: Date?
}
