import SwiftUI

struct AvatarConfig: Codable, Identifiable, Hashable {
    let id: String
    let childId: String
    var name: String
    var skinTone: String
    var hairStyle: HairStyle
    var hairColor: String
    var eyeColor: String
    var outfit: OutfitType
    var accessories: [AccessoryType]
    var voiceId: String

    var skinToneColor: Color { Color(hex: skinTone) }
    var hairColorValue: Color { Color(hex: hairColor) }
    var eyeColorValue: Color { Color(hex: eyeColor) }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AvatarConfig, rhs: AvatarConfig) -> Bool {
        lhs.id == rhs.id
    }

    static func preview(
        skinTone: String,
        hairStyle: HairStyle,
        hairColor: String,
        eyeColor: String
    ) -> AvatarConfig {
        AvatarConfig(
            id: "preview",
            childId: "preview",
            name: "Preview",
            skinTone: skinTone,
            hairStyle: hairStyle,
            hairColor: hairColor,
            eyeColor: eyeColor,
            outfit: .tshirt,
            accessories: [],
            voiceId: "nova"
        )
    }
}

enum HairStyle: String, Codable, CaseIterable, Identifiable {
    case short, medium, long, curly, braids, ponytail, buzz, afro
    var id: String { rawValue }
}

enum OutfitType: String, Codable, CaseIterable, Identifiable {
    case tshirt, dress, overalls, superhero, sportswear
    var id: String { rawValue }
}

enum AccessoryType: String, Codable, CaseIterable, Identifiable {
    case glasses, hat, bow, cape, headband
    var id: String { rawValue }
}
