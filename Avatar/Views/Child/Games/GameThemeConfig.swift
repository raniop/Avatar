import SwiftUI

/// Difficulty curve for the runner game. Scales with the child's age and the
/// adventure round number.
struct GameThemeConfig {
    static func gameType(for theme: String) -> MiniGameType { .templeRun }

    static func difficulty(for age: Int, round: Int) -> GameDifficulty {
        let base: GameDifficulty
        switch age {
        case 0...4:
            base = GameDifficulty(timeLimit: 60, starThreshold: 120, baseSpeed: 9, speedRamp: 0.10, spawnInterval: 2.0)
        case 5...6:
            base = GameDifficulty(timeLimit: 60, starThreshold: 160, baseSpeed: 11, speedRamp: 0.15, spawnInterval: 1.7)
        case 7...8:
            base = GameDifficulty(timeLimit: 60, starThreshold: 220, baseSpeed: 13, speedRamp: 0.20, spawnInterval: 1.4)
        case 9...10:
            base = GameDifficulty(timeLimit: 60, starThreshold: 280, baseSpeed: 15, speedRamp: 0.25, spawnInterval: 1.2)
        default:
            base = GameDifficulty(timeLimit: 60, starThreshold: 340, baseSpeed: 17, speedRamp: 0.30, spawnInterval: 1.0)
        }

        let roundBoost = Double(round - 1)
        return GameDifficulty(
            timeLimit: base.timeLimit,
            starThreshold: base.starThreshold + (round - 1) * 60,
            baseSpeed: base.baseSpeed + roundBoost * 1.5,
            speedRamp: base.speedRamp + roundBoost * 0.05,
            spawnInterval: max(0.6, base.spawnInterval - roundBoost * 0.15)
        )
    }
}
