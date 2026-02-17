import Foundation

/// Maps mission themes to game types, emoji items, difficulty parameters, and sort categories.
/// All game configuration is deterministic and runs on the client — the backend only says "play a game".
struct GameThemeConfig {

    // MARK: - Theme → Game Type

    static func gameType(for theme: String) -> MiniGameType {
        switch theme {
        case "sports_champion", "space_adventure", "underwater_explorer":
            return .catchGame
        case "magical_forest", "dinosaur_world", "pirate_treasure_hunt":
            return .matchGame
        case "cooking_adventure", "animal_rescue", "rainbow_land", "animal_hospital":
            return .sortGame
        case "fairy_tale_kingdom", "superhero_training", "music_studio", "dance_party", "singing_star":
            return .sequenceGame
        default:
            return .catchGame
        }
    }

    // MARK: - Catch Game Items

    static func catchItems(for theme: String) -> [String] {
        switch theme {
        case "sports_champion":
            return ["⚽", "🏀", "🎾", "🏐", "🏈", "⚾", "🥎", "🏓"]
        case "space_adventure":
            return ["⭐", "💎", "🪐", "☄️", "🌟", "💫", "🔮", "🌙"]
        case "underwater_explorer":
            return ["🐠", "🐟", "🐚", "💎", "🦀", "🐙", "🦈", "🐬"]
        case "cooking_adventure":
            return ["🍎", "🥕", "🧀", "🍕", "🍰", "🥚", "🍓", "🌽"]
        default:
            return ["⭐", "💎", "🎯", "🌟", "🔮", "💫", "✨", "🎪"]
        }
    }

    // MARK: - Match Game Items (pairs)

    static func matchItems(for theme: String, pairCount: Int) -> [String] {
        let pool: [String]
        switch theme {
        case "magical_forest":
            pool = ["🦋", "🍄", "🦊", "🌸", "🦉", "🐿️", "🌺", "🪻"]
        case "dinosaur_world":
            pool = ["🦕", "🦖", "🥚", "🌋", "🦴", "🌿", "🐾", "🪨"]
        case "pirate_treasure_hunt":
            pool = ["⚓", "🗡️", "💰", "🏴‍☠️", "🗺️", "💎", "🦜", "🧭"]
        case "fairy_tale_kingdom":
            pool = ["👑", "🧚", "🦄", "🌈", "🏰", "🐉", "🪄", "🌟"]
        default:
            pool = ["🌟", "💎", "🎯", "🔮", "🦋", "🌸", "🎪", "✨"]
        }
        return Array(pool.prefix(pairCount))
    }

    // MARK: - Sort Game Categories

    static func sortCategories(for theme: String) -> [SortZone] {
        switch theme {
        case "cooking_adventure":
            return [
                SortZone(id: 0, emoji: "🍎", label: "Fruits", color: "FF6B6B"),
                SortZone(id: 1, emoji: "🥕", label: "Veggies", color: "4ECDC4"),
                SortZone(id: 2, emoji: "🧀", label: "Dairy", color: "FFE66D"),
            ]
        case "animal_rescue":
            return [
                SortZone(id: 0, emoji: "🌊", label: "Water", color: "0984E3"),
                SortZone(id: 1, emoji: "🌍", label: "Land", color: "00B894"),
                SortZone(id: 2, emoji: "☁️", label: "Sky", color: "74B9FF"),
            ]
        case "rainbow_land":
            return [
                SortZone(id: 0, emoji: "🔴", label: "Warm", color: "E74C3C"),
                SortZone(id: 1, emoji: "🔵", label: "Cool", color: "3498DB"),
            ]
        case "animal_hospital":
            return [
                SortZone(id: 0, emoji: "💊", label: "Medicine", color: "E17055"),
                SortZone(id: 1, emoji: "🩹", label: "Bandage", color: "FDCB6E"),
                SortZone(id: 2, emoji: "💉", label: "Vaccine", color: "6C5CE7"),
            ]
        default:
            return [
                SortZone(id: 0, emoji: "✅", label: "Group A", color: "00B894"),
                SortZone(id: 1, emoji: "🔵", label: "Group B", color: "0984E3"),
            ]
        }
    }

    static func sortItems(for theme: String, count: Int) -> [SortItem] {
        switch theme {
        case "cooking_adventure":
            let all: [(String, String, Int)] = [
                ("🍎", "Apple", 0), ("🍌", "Banana", 0), ("🍇", "Grapes", 0), ("🍓", "Strawberry", 0),
                ("🥕", "Carrot", 1), ("🥦", "Broccoli", 1), ("🌽", "Corn", 1), ("🍅", "Tomato", 1),
                ("🧀", "Cheese", 2), ("🥛", "Milk", 2), ("🍦", "Ice Cream", 2), ("🧈", "Butter", 2),
            ]
            return Array(all.prefix(count)).map { SortItem(id: UUID(), emoji: $0.0, label: $0.1, correctZone: $0.2) }
        case "animal_rescue":
            let all: [(String, String, Int)] = [
                ("🐟", "Fish", 0), ("🐬", "Dolphin", 0), ("🐙", "Octopus", 0), ("🦈", "Shark", 0),
                ("🐶", "Dog", 1), ("🐱", "Cat", 1), ("🐘", "Elephant", 1), ("🦁", "Lion", 1),
                ("🦅", "Eagle", 2), ("🦋", "Butterfly", 2), ("🐝", "Bee", 2), ("🦜", "Parrot", 2),
            ]
            return Array(all.prefix(count)).map { SortItem(id: UUID(), emoji: $0.0, label: $0.1, correctZone: $0.2) }
        case "rainbow_land":
            let all: [(String, String, Int)] = [
                ("🔴", "Red", 0), ("🟠", "Orange", 0), ("🟡", "Yellow", 0), ("💗", "Pink", 0),
                ("🔵", "Blue", 1), ("🟢", "Green", 1), ("🟣", "Purple", 1), ("💙", "Teal", 1),
            ]
            return Array(all.prefix(count)).map { SortItem(id: UUID(), emoji: $0.0, label: $0.1, correctZone: $0.2) }
        case "animal_hospital":
            let all: [(String, String, Int)] = [
                ("💊", "Pill", 0), ("🧪", "Syrup", 0), ("💉", "Shot", 2), ("🩺", "Checkup", 2),
                ("🩹", "Bandage", 1), ("🩻", "X-Ray", 1), ("🩼", "Splint", 1), ("💊", "Vitamin", 0),
            ]
            return Array(all.prefix(count)).map { SortItem(id: UUID(), emoji: $0.0, label: $0.1, correctZone: $0.2) }
        default:
            let all: [(String, String, Int)] = [
                ("⭐", "Star", 0), ("🌙", "Moon", 0), ("☀️", "Sun", 1), ("🌍", "Earth", 1),
            ]
            return Array(all.prefix(count)).map { SortItem(id: UUID(), emoji: $0.0, label: $0.1, correctZone: $0.2) }
        }
    }

    // MARK: - Sequence Game Buttons

    static func sequenceButtons(for theme: String) -> [SequenceButton] {
        switch theme {
        case "fairy_tale_kingdom":
            return [
                SequenceButton(id: 0, emoji: "🪄", color: "9B59B6"),
                SequenceButton(id: 1, emoji: "✨", color: "F1C40F"),
                SequenceButton(id: 2, emoji: "💫", color: "E91E63"),
                SequenceButton(id: 3, emoji: "🌟", color: "3498DB"),
            ]
        case "superhero_training":
            return [
                SequenceButton(id: 0, emoji: "⚡", color: "F1C40F"),
                SequenceButton(id: 1, emoji: "💪", color: "E74C3C"),
                SequenceButton(id: 2, emoji: "🔥", color: "E67E22"),
                SequenceButton(id: 3, emoji: "🛡️", color: "3498DB"),
            ]
        case "music_studio", "singing_star":
            return [
                SequenceButton(id: 0, emoji: "🎵", color: "9B59B6"),
                SequenceButton(id: 1, emoji: "🎶", color: "E74C3C"),
                SequenceButton(id: 2, emoji: "🎸", color: "F39C12"),
                SequenceButton(id: 3, emoji: "🥁", color: "2ECC71"),
            ]
        case "dance_party":
            return [
                SequenceButton(id: 0, emoji: "💃", color: "E91E63"),
                SequenceButton(id: 1, emoji: "🕺", color: "3F51B5"),
                SequenceButton(id: 2, emoji: "🪩", color: "FF9800"),
                SequenceButton(id: 3, emoji: "🎶", color: "4CAF50"),
            ]
        default:
            return [
                SequenceButton(id: 0, emoji: "🔴", color: "E74C3C"),
                SequenceButton(id: 1, emoji: "🟢", color: "2ECC71"),
                SequenceButton(id: 2, emoji: "🔵", color: "3498DB"),
                SequenceButton(id: 3, emoji: "🟡", color: "F1C40F"),
            ]
        }
    }

    // MARK: - Difficulty

    static func difficulty(for age: Int, round: Int) -> GameDifficulty {
        // Base difficulty by age bracket
        let base: GameDifficulty
        switch age {
        case 0...4:
            base = GameDifficulty(
                spawnInterval: 2.0, fallDuration: 4.0, itemCount: 6,
                timeLimit: 45, starThreshold: 3,
                gridRows: 2, gridCols: 2, sequenceLength: 2, maxSequenceLength: 3, sortCategories: 2
            )
        case 5...6:
            base = GameDifficulty(
                spawnInterval: 1.5, fallDuration: 3.5, itemCount: 8,
                timeLimit: 40, starThreshold: 4,
                gridRows: 2, gridCols: 3, sequenceLength: 2, maxSequenceLength: 4, sortCategories: 2
            )
        case 7...8:
            base = GameDifficulty(
                spawnInterval: 1.0, fallDuration: 3.0, itemCount: 10,
                timeLimit: 35, starThreshold: 5,
                gridRows: 3, gridCols: 3, sequenceLength: 3, maxSequenceLength: 5, sortCategories: 3
            )
        case 9...10:
            base = GameDifficulty(
                spawnInterval: 0.8, fallDuration: 2.5, itemCount: 12,
                timeLimit: 30, starThreshold: 7,
                gridRows: 3, gridCols: 4, sequenceLength: 3, maxSequenceLength: 6, sortCategories: 3
            )
        default: // 11-12
            base = GameDifficulty(
                spawnInterval: 0.6, fallDuration: 2.0, itemCount: 15,
                timeLimit: 25, starThreshold: 8,
                gridRows: 4, gridCols: 4, sequenceLength: 4, maxSequenceLength: 7, sortCategories: 3
            )
        }

        // Scale difficulty with round (round 2 is harder, round 3 is hardest)
        let roundMultiplier = 1.0 + Double(round - 1) * 0.15
        return GameDifficulty(
            spawnInterval: max(0.4, base.spawnInterval / roundMultiplier),
            fallDuration: max(1.5, base.fallDuration / roundMultiplier),
            itemCount: base.itemCount + (round - 1) * 2,
            timeLimit: base.timeLimit,
            starThreshold: base.starThreshold + (round - 1),
            gridRows: base.gridRows,
            gridCols: base.gridCols,
            sequenceLength: base.sequenceLength + (round - 1),
            maxSequenceLength: base.maxSequenceLength,
            sortCategories: base.sortCategories
        )
    }
}
