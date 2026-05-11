import Foundation
import SwiftUI

// MARK: - Game Types

enum MiniGameType: String, Codable, Equatable {
    case templeRun

    /// Any string we receive from the backend (legacy game ids included)
    /// resolves to the single supported runner game.
    init(from decoder: Decoder) throws {
        _ = try decoder.singleValueContainer().decode(String.self)
        self = .templeRun
    }
}

// MARK: - Game Config (from backend, minimal)

struct MiniGameConfig: Codable, Equatable {
    let type: MiniGameType
    let round: Int
}

// MARK: - Game Difficulty (computed on client from age + round)

struct GameDifficulty {
    let timeLimit: Int           // Max session length in seconds
    let starThreshold: Int       // Distance (m) needed to earn the star
    let baseSpeed: Double        // Starting forward speed (units/sec)
    let speedRamp: Double        // Speed gained per second of survival
    let spawnInterval: Double    // Seconds between obstacle spawns
}

// MARK: - Game Result

struct GameResult: Equatable {
    let round: Int
    let score: Int
    let total: Int
    let earnedStar: Bool
}
