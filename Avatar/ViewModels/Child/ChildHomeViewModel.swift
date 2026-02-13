import Foundation
import Observation
import UIKit

@Observable
final class ChildHomeViewModel {
    var avatarName: String?
    var avatarImage: UIImage?
    var availableMissions: [Mission] = []
    var isLoading = false
    var errorMessage: String?

    private let storage = AvatarStorage.shared

    var hasAvatar: Bool {
        avatarName != nil && avatarImage != nil
    }

    func loadData() async {
        isLoading = true

        // Load avatar (local cache first, then Firebase)
        if let savedAvatar = await storage.loadAvatar() {
            avatarName = savedAvatar.name
            avatarImage = savedAvatar.image
        }

        // Load mock missions
        loadMockMissions()

        isLoading = false
    }

    func startMission(_ mission: Mission) {
        // TODO: Create conversation and navigate to conversation view
    }

    private func loadMockMissions() {
        availableMissions = MissionTheme.allCases.prefix(6).enumerated().map { index, theme in
            Mission(
                id: "mock-\(theme.rawValue)",
                theme: theme,
                titleEn: "\(theme.displayNameEn) Adventure",
                titleHe: "הרפתקת \(theme.displayNameHe)",
                descriptionEn: "Join your avatar on an amazing \(theme.displayNameEn.lowercased()) mission!",
                descriptionHe: "הצטרפו לאווטר שלכם למשימת \(theme.displayNameHe) מדהימה!",
                ageRangeMin: 3,
                ageRangeMax: 7,
                durationMinutes: 5,
                sceneryAssetKey: theme.rawValue,
                avatarCostumeKey: theme.rawValue
            )
        }
    }
}
