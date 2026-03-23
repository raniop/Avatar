import Foundation
import SwiftUI

// MARK: - Game Types

enum MiniGameType: String, Codable, Equatable {
    case footballKick = "football"
    case basketballShoot = "basketball"
    case carRace = "car"
    case simonPattern = "simon"

    // Handle unknown/legacy game types from backend (e.g. "catch", "match", "sort", "sequence")
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = MiniGameType(rawValue: rawValue) ?? .footballKick
    }
}

// MARK: - Game Config (from backend, minimal)

struct MiniGameConfig: Codable, Equatable {
    let type: MiniGameType
    let round: Int  // 1, 2, or 3
}

// MARK: - Game Difficulty (computed on client from age + round)

struct GameDifficulty {
    let timeLimit: Int             // Seconds per round (45-60)
    let starThreshold: Int         // Score needed for star
    let itemCount: Int             // Number of challenges per round
    let speed: Double              // Game-specific speed factor (1.0 = normal)
    let wordLength: Int            // Max word length for spelling games
    let distractorCount: Int       // Number of wrong options shown
    let sequenceLength: Int        // Simon: starting pattern length
    let maxSequenceLength: Int     // Simon: max pattern length
}

// MARK: - Game Result

struct GameResult: Equatable {
    let round: Int
    let score: Int
    let total: Int
    let earnedStar: Bool
}

// MARK: - Football Target

struct FootballTarget: Identifiable, Equatable {
    let id: UUID
    let character: String
    let isCorrect: Bool
    var position: CGPoint
    var hit: Bool = false

    static func == (lhs: FootballTarget, rhs: FootballTarget) -> Bool {
        lhs.id == rhs.id && lhs.hit == rhs.hit
    }
}

// MARK: - Letter Ball (Basketball)

struct LetterBall: Identifiable, Equatable {
    let id: UUID
    let character: String
    let isCorrect: Bool
    var thrown: Bool = false
    var scored: Bool = false

    static func == (lhs: LetterBall, rhs: LetterBall) -> Bool {
        lhs.id == rhs.id && lhs.thrown == rhs.thrown && lhs.scored == rhs.scored
    }
}

// MARK: - Road Item (Car Race)

struct RoadItem: Identifiable, Equatable {
    let id: UUID
    let character: String
    let isCorrect: Bool
    var laneIndex: Int       // 0, 1, or 2
    var yOffset: CGFloat     // scrolls toward player
    var collected: Bool = false

    static func == (lhs: RoadItem, rhs: RoadItem) -> Bool {
        lhs.id == rhs.id && lhs.collected == rhs.collected
    }
}

// MARK: - Simon Button

struct SimonButton: Identifiable, Equatable {
    let id: Int
    let color: Color
    let emoji: String
    var isLit: Bool = false
}
