import Foundation

struct AdventureState: Codable, Equatable {
    let sceneIndex: Int
    let sceneName: String
    let sceneEmojis: [String]
    let interactionType: InteractionType
    let choices: [AdventureChoice]?
    let miniGame: MiniGameConfig?
    let starsEarned: Int
    let isSceneComplete: Bool
    let isAdventureComplete: Bool
    let collectible: AdventureCollectible?

    enum InteractionType: String, Codable {
        case choice
        case voice
        case celebrate
        case miniGame
    }
}

struct AdventureChoice: Codable, Identifiable, Equatable {
    let id: String
    let emoji: String
    let label: String
}

struct AdventureCollectible: Codable, Equatable {
    let emoji: String
    let name: String
}

struct AdventureProgressItem: Codable {
    let missionId: String
    let depth: Int
    let starsEarned: Int
    let collectibles: [AdventureCollectible]?
    let completedAt: Date?
}

struct AdventureProgressResponse: Codable {
    let progress: [AdventureProgressItem]
    let totalStars: Int
    let collectibles: [AdventureCollectible]
}
