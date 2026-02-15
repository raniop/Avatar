import Foundation

struct Mission: Codable, Identifiable, Hashable {
    let id: String
    let theme: String
    // Backend returns localized title/description based on ?locale= query param
    var title: String
    var description: String
    let ageRangeMin: Int
    let ageRangeMax: Int
    let durationMinutes: Int
    let sceneryAssetKey: String?
    let avatarCostumeKey: String?

    func title(for locale: AppLocale) -> String {
        title
    }

    func description(for locale: AppLocale) -> String {
        description
    }

    // Map theme string to emoji for display
    var emoji: String {
        switch theme {
        case "space_adventure": "🚀"
        case "underwater_explorer": "🌊"
        case "magical_forest": "🌲"
        case "dinosaur_world": "🦕"
        case "superhero_training": "🦸"
        case "cooking_adventure": "👨‍🍳"
        case "pirate_treasure_hunt": "🏴‍☠️"
        case "fairy_tale_kingdom": "🏰"
        case "animal_rescue": "🐾"
        case "rainbow_land": "🌈"
        default: "⭐"
        }
    }
}
