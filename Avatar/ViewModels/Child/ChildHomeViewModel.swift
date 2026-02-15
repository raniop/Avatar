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

    // Navigation state for starting a mission
    var selectedMission: Mission?
    var child: Child?
    var showConversation = false
    var isStartingMission = false

    private let storage = AvatarStorage.shared
    private let apiClient = APIClient.shared

    var hasAvatar: Bool {
        avatarName != nil && avatarImage != nil
    }

    /// Set the selected child (from AppRouter) before calling loadData()
    func configure(with child: Child) {
        self.child = child
    }

    func loadData() async {
        guard let child else { return }
        isLoading = true

        // Load avatar from per-child local cache (instant)
        if let savedAvatar = await storage.loadAvatar(childId: child.id) {
            avatarName = savedAvatar.name
            avatarImage = savedAvatar.image
        }

        // Load missions from backend
        await loadMissions()

        isLoading = false
    }

    func startMission(_ mission: Mission) {
        guard let child = child, !isStartingMission else { return }

        isStartingMission = true
        selectedMission = mission

        // Don't create conversation here -- let ConversationViewModel handle it
        // This avoids the double-creation bug and speeds up navigation
        showConversation = true
        isStartingMission = false
    }

    private func loadMissions() async {
        do {
            // Read persisted locale to fetch localized mission titles
            let localeRaw = UserDefaults.standard.string(forKey: "app_locale") ?? "en"
            availableMissions = try await apiClient.getMissions(locale: localeRaw)
        } catch {
            print("Failed to load missions: \(error.localizedDescription)")
        }
    }
}
