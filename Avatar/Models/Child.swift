import Foundation

struct Child: Codable, Identifiable, Hashable {
    let id: String
    let parentId: String
    var name: String
    var age: Int
    var birthday: Date?
    var gender: String?
    var interests: [String]
    var developmentGoals: [String]
    var locale: AppLocale
    let createdAt: Date

    // Backend returns "avatar" field (not "avatarConfig")
    var avatar: AvatarConfig?
}
