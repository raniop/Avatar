import Foundation

enum MissionTheme: String, Codable, CaseIterable, Identifiable {
    case superhero
    case mechanic
    case soccerPlayer
    case chef
    case spaceExplorer
    case artist
    case detective
    case doctor
    case firefighter
    case scientist
    case musician
    case animalRescuer
    case pirate
    case gardener
    case builder

    var id: String { rawValue }

    var displayNameEn: String {
        switch self {
        case .superhero: "Superhero"
        case .mechanic: "Mechanic"
        case .soccerPlayer: "Soccer Player"
        case .chef: "Chef"
        case .spaceExplorer: "Space Explorer"
        case .artist: "Artist"
        case .detective: "Detective"
        case .doctor: "Doctor"
        case .firefighter: "Firefighter"
        case .scientist: "Scientist"
        case .musician: "Musician"
        case .animalRescuer: "Animal Rescuer"
        case .pirate: "Pirate"
        case .gardener: "Gardener"
        case .builder: "Builder"
        }
    }

    var displayNameHe: String {
        switch self {
        case .superhero: "גיבור על"
        case .mechanic: "מוסכניק"
        case .soccerPlayer: "שחקן כדורגל"
        case .chef: "שף"
        case .spaceExplorer: "חוקר חלל"
        case .artist: "אמן"
        case .detective: "בלש"
        case .doctor: "רופא"
        case .firefighter: "כבאי"
        case .scientist: "מדען"
        case .musician: "מוזיקאי"
        case .animalRescuer: "מציל חיות"
        case .pirate: "פיראט"
        case .gardener: "גנן"
        case .builder: "בנאי"
        }
    }

    var emoji: String {
        switch self {
        case .superhero: "🦸"
        case .mechanic: "🔧"
        case .soccerPlayer: "⚽"
        case .chef: "👨‍🍳"
        case .spaceExplorer: "🚀"
        case .artist: "🎨"
        case .detective: "🔍"
        case .doctor: "👨‍⚕️"
        case .firefighter: "🚒"
        case .scientist: "🔬"
        case .musician: "🎵"
        case .animalRescuer: "🐾"
        case .pirate: "🏴‍☠️"
        case .gardener: "🌱"
        case .builder: "🏗️"
        }
    }
}
