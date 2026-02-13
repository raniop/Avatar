import Foundation

struct User: Codable, Identifiable, Equatable {
    let id: String
    var email: String
    var displayName: String
    var locale: AppLocale
    let createdAt: Date
    var updatedAt: Date?
}
