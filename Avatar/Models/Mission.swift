import Foundation

struct Mission: Codable, Identifiable, Hashable {
    let id: String
    let theme: MissionTheme
    var titleEn: String
    var titleHe: String
    var descriptionEn: String
    var descriptionHe: String
    let ageRangeMin: Int
    let ageRangeMax: Int
    let durationMinutes: Int
    let sceneryAssetKey: String
    let avatarCostumeKey: String

    func title(for locale: AppLocale) -> String {
        locale == .hebrew ? titleHe : titleEn
    }

    func description(for locale: AppLocale) -> String {
        locale == .hebrew ? descriptionHe : descriptionEn
    }
}
