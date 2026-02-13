import Foundation

enum AppLocale: String, Codable, CaseIterable {
    case english = "en"
    case hebrew = "he"

    var displayName: String {
        switch self {
        case .english: "English"
        case .hebrew: "עברית"
        }
    }
}
