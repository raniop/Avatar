import Foundation

// MARK: - Game Types

enum MiniGameType: String, Codable, Equatable {
    case catchGame = "catch"
    case matchGame = "match"
    case sortGame = "sort"
    case sequenceGame = "sequence"
}

// MARK: - Game Config (from backend, minimal)

struct MiniGameConfig: Codable, Equatable {
    let type: MiniGameType
    let round: Int  // 1, 2, or 3
}

// MARK: - Game Difficulty (computed on client from age + round)

struct GameDifficulty {
    let spawnInterval: Double      // Catch: seconds between spawns
    let fallDuration: Double       // Catch: seconds for item to fall across screen
    let itemCount: Int             // Total items in the round
    let timeLimit: Int             // Seconds
    let starThreshold: Int         // Score needed for star
    let gridRows: Int              // Match: grid rows
    let gridCols: Int              // Match: grid cols
    let sequenceLength: Int        // Sequence: starting length
    let maxSequenceLength: Int     // Sequence: max length
    let sortCategories: Int        // Sort: number of target zones (2 or 3)
}

// MARK: - Game Result

struct GameResult: Equatable {
    let round: Int
    let score: Int
    let total: Int
    let earnedStar: Bool
}

// MARK: - Falling Item (Catch Game)

struct FallingItem: Identifiable, Equatable {
    let id: UUID
    let emoji: String
    var x: CGFloat
    var y: CGFloat
    var caught: Bool = false
    var missed: Bool = false
}

// MARK: - Match Card (Match Game)

struct MatchCard: Identifiable, Equatable {
    let id: UUID
    let emoji: String
    let pairIndex: Int
    var faceUp: Bool = false
    var matched: Bool = false
}

// MARK: - Sort Item (Sort Game)

struct SortItem: Identifiable, Equatable {
    let id: UUID
    let emoji: String
    let label: String
    let correctZone: Int  // Index of the correct target zone
}

struct SortZone: Identifiable, Equatable {
    let id: Int
    let emoji: String
    let label: String
    let color: String  // hex color
}

// MARK: - Sequence Button (Sequence Game)

struct SequenceButton: Identifiable, Equatable {
    let id: Int
    let emoji: String
    let color: String  // hex color
    var isLit: Bool = false
}
