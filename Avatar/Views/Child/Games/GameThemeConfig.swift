import SwiftUI

/// Maps mission themes to educational sport game types and difficulty parameters.
/// All game configuration is deterministic and runs on the client.
struct GameThemeConfig {

    // MARK: - Theme → Game Type

    static func gameType(for theme: String) -> MiniGameType {
        switch theme {
        // Football ⚽ — active/physical themes
        case "sports_champion", "superhero_training", "dinosaur_world":
            return .footballKick
        // Basketball 🏀 — indoor/arena themes
        case "space_adventure", "music_studio", "singing_star", "dance_party":
            return .basketballShoot
        // Car Race 🏎️ — adventure/travel themes
        case "pirate_treasure_hunt", "cooking_adventure", "rainbow_land":
            return .carRace
        // Simon 🎵 — nature/calm themes
        case "magical_forest", "fairy_tale_kingdom", "underwater_explorer", "animal_rescue", "animal_hospital":
            return .simonPattern
        default:
            return .footballKick
        }
    }

    // MARK: - Simon Button Colors per Theme

    static func simonColors(for theme: String) -> [(color: Color, emoji: String)] {
        switch theme {
        case "magical_forest":
            return [
                (Color(hex: "9B59B6"), "🪄"),
                (Color(hex: "2ECC71"), "🍀"),
                (Color(hex: "E74C3C"), "🍄"),
                (Color(hex: "3498DB"), "🦋"),
            ]
        case "fairy_tale_kingdom":
            return [
                (Color(hex: "9B59B6"), "👑"),
                (Color(hex: "F1C40F"), "✨"),
                (Color(hex: "E91E63"), "🧚"),
                (Color(hex: "3498DB"), "🦄"),
            ]
        case "dance_party":
            return [
                (Color(hex: "E91E63"), "💃"),
                (Color(hex: "3F51B5"), "🕺"),
                (Color(hex: "FF9800"), "🪩"),
                (Color(hex: "4CAF50"), "🎶"),
            ]
        default:
            return [
                (Color(hex: "E74C3C"), "🔴"),
                (Color(hex: "2ECC71"), "🟢"),
                (Color(hex: "3498DB"), "🔵"),
                (Color(hex: "F1C40F"), "🟡"),
            ]
        }
    }

    // MARK: - Field/Court Colors per Theme

    static func fieldColor(for theme: String) -> Color {
        switch theme {
        case "sports_champion": return Color(hex: "2E7D32") // green grass
        case "superhero_training": return Color(hex: "1A237E") // dark blue
        case "dinosaur_world": return Color(hex: "33691E") // jungle green
        case "animal_rescue": return Color(hex: "00695C") // teal forest
        default: return Color(hex: "2E7D32")
        }
    }

    static func courtColor(for theme: String) -> Color {
        switch theme {
        case "space_adventure": return Color(hex: "1A1A2E") // dark space
        case "rainbow_land": return Color(hex: "F06292") // pink
        case "music_studio": return Color(hex: "4A148C") // deep purple
        case "singing_star": return Color(hex: "311B92") // deep indigo
        default: return Color(hex: "E65100") // basketball orange court
        }
    }

    static func roadColor(for theme: String) -> Color {
        switch theme {
        case "pirate_treasure_hunt": return Color(hex: "5D4037") // brown dirt
        case "underwater_explorer": return Color(hex: "0277BD") // ocean blue
        case "cooking_adventure": return Color(hex: "BF360C") // kitchen tile
        case "animal_hospital": return Color(hex: "37474F") // hospital gray
        default: return Color(hex: "424242") // asphalt
        }
    }

    // MARK: - Difficulty

    static func difficulty(for age: Int, round: Int) -> GameDifficulty {
        let base: GameDifficulty
        switch age {
        case 0...4:
            base = GameDifficulty(
                timeLimit: 50,
                starThreshold: 3,
                itemCount: 5,
                speed: 0.7,
                wordLength: 2,
                distractorCount: 2,
                sequenceLength: 2,
                maxSequenceLength: 4
            )
        case 5...6:
            base = GameDifficulty(
                timeLimit: 45,
                starThreshold: 4,
                itemCount: 6,
                speed: 0.85,
                wordLength: 3,
                distractorCount: 3,
                sequenceLength: 2,
                maxSequenceLength: 5
            )
        case 7...8:
            base = GameDifficulty(
                timeLimit: 40,
                starThreshold: 5,
                itemCount: 7,
                speed: 1.0,
                wordLength: 4,
                distractorCount: 3,
                sequenceLength: 3,
                maxSequenceLength: 6
            )
        case 9...10:
            base = GameDifficulty(
                timeLimit: 35,
                starThreshold: 6,
                itemCount: 8,
                speed: 1.15,
                wordLength: 5,
                distractorCount: 4,
                sequenceLength: 3,
                maxSequenceLength: 7
            )
        default: // 11+
            base = GameDifficulty(
                timeLimit: 30,
                starThreshold: 7,
                itemCount: 10,
                speed: 1.3,
                wordLength: 6,
                distractorCount: 4,
                sequenceLength: 4,
                maxSequenceLength: 8
            )
        }

        // Scale with round (round 2 harder, round 3 hardest)
        return GameDifficulty(
            timeLimit: base.timeLimit,
            starThreshold: base.starThreshold + (round - 1),
            itemCount: base.itemCount + (round - 1),
            speed: base.speed + Double(round - 1) * 0.1,
            wordLength: base.wordLength,
            distractorCount: base.distractorCount,
            sequenceLength: base.sequenceLength + (round - 1),
            maxSequenceLength: base.maxSequenceLength
        )
    }
}
