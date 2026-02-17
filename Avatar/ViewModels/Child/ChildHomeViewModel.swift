import Foundation
import Observation
import UIKit

extension Notification.Name {
    static let friendSetupCompleted = Notification.Name("friendSetupCompleted")
}

@Observable
final class ChildHomeViewModel {
    // Child's own AI-generated avatar (from AvatarStorage)
    var avatarName: String?
    var avatarImage: UIImage?

    // Friend character (preset chosen in AvatarSetupView, stored in UserDefaults)
    var friendPresetId: Int?
    var friendName: String?

    var availableMissions: [Mission] = []
    var isLoading = false
    var errorMessage: String?

    // Adventure progress
    var totalStars: Int = 0

    // Navigation state for starting a mission
    var selectedMission: Mission?
    var child: Child?
    var showConversation = false

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

        // Load child's own AI-generated avatar from per-child local cache (instant)
        if let savedAvatar = await storage.loadAvatar(childId: child.id) {
            avatarName = savedAvatar.name
            avatarImage = savedAvatar.image
        }

        // Load friend preset from UserDefaults
        friendPresetId = UserDefaults.standard.object(forKey: "friend_preset_\(child.id)") as? Int
        friendName = UserDefaults.standard.string(forKey: "friend_name_\(child.id)")

        // Migration: children who used the OLD AvatarSetupView flow
        // have avatar_setup_done_ set but no friend_preset_.
        // The stored avatar name IS the friend's name — detect and migrate.
        if friendPresetId == nil,
           UserDefaults.standard.bool(forKey: "avatar_setup_done_\(child.id)"),
           let name = avatarName,
           let presetId = Self.presetIdForName(name) {
            friendPresetId = presetId
            friendName = name
            UserDefaults.standard.set(presetId, forKey: "friend_preset_\(child.id)")
            UserDefaults.standard.set(name, forKey: "friend_name_\(child.id)")
            print("🔄 Migrated old friend selection: \(name) → preset \(presetId)")
        }

        // Sync from backend: if friend was set up on another device,
        // the avatar name is already on the backend — derive preset and cache locally.
        if friendPresetId == nil,
           let backendName = child.avatar?.name,
           let presetId = Self.presetIdForName(backendName) {
            friendPresetId = presetId
            friendName = backendName
            UserDefaults.standard.set(presetId, forKey: "friend_preset_\(child.id)")
            UserDefaults.standard.set(backendName, forKey: "friend_name_\(child.id)")
            print("🔄 Synced friend from backend: \(backendName) → preset \(presetId)")
        }

        // Load missions and adventure progress from backend
        await loadMissions()
        await loadAdventureProgress()

        isLoading = false
    }

    func startMission(_ mission: Mission) {
        selectedMission = mission
        showConversation = true
    }

    /// Reload adventure progress (e.g., after returning from an adventure)
    func refreshProgress() async {
        await loadAdventureProgress()
    }

    /// Reload friend data from UserDefaults (e.g., after friend setup completes).
    func reloadFriendData() {
        guard let child else { return }
        friendPresetId = UserDefaults.standard.object(forKey: "friend_preset_\(child.id)") as? Int
        friendName = UserDefaults.standard.string(forKey: "friend_name_\(child.id)")
        print("🔄 Reloaded friend data: preset=\(friendPresetId ?? -1), name=\(friendName ?? "nil")")
    }

    /// Map known preset character names to their IDs
    static func presetIdForName(_ name: String) -> Int? {
        let map: [String: Int] = [
            "אורי": 1, "Ori": 1,
            "נועם": 2, "Noah": 2,
            "טל": 3, "Tal": 3,
            "ליאם": 4, "Liam": 4,
            "נועה": 5, "Noa": 5,
            "מאיה": 6, "Maya": 6,
            "ליה": 7, "Lily": 7,
            "שירה": 8, "Shira": 8,
        ]
        return map[name]
    }

    private func loadMissions() async {
        do {
            // Read persisted locale to fetch localized mission titles
            let localeRaw = UserDefaults.standard.string(forKey: "app_locale") ?? "en"
            let interests = child?.interests.isEmpty == false ? child?.interests : nil
            print("📋 Loading missions: age=\(child?.age ?? -1), locale=\(localeRaw), interests=\(interests ?? [])")
            availableMissions = try await apiClient.getMissions(
                age: child?.age,
                locale: localeRaw,
                interests: interests
            )
            print("📋 Loaded \(availableMissions.count) missions")
        } catch {
            print("❌ Failed to load missions: \(error)")
        }
    }

    private func loadAdventureProgress() async {
        guard let child else { return }
        do {
            let response = try await apiClient.getAdventureProgress(childId: child.id)
            totalStars = response.totalStars
            print("⭐ Adventure progress: \(totalStars) total stars")
        } catch {
            print("❌ Failed to load adventure progress: \(error)")
        }
    }
}
