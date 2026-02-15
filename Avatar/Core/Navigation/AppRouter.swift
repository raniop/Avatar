import SwiftUI
import Observation

enum UserRole: String {
    case child
    case parent
}

@Observable
final class AppRouter {
    var currentLocale: AppLocale {
        didSet {
            UserDefaults.standard.set(currentLocale.rawValue, forKey: "app_locale")
        }
    }
    var activeRole: UserRole? = nil
    var childNavigationPath = NavigationPath()
    var parentNavigationPath = NavigationPath()

    /// Pre-fetched children list so RoleSelectionView doesn't need its own loading screen
    var cachedChildren: [Child]?
    var hasCheckedChildren = false

    init() {
        if let saved = UserDefaults.standard.string(forKey: "app_locale"),
           let locale = AppLocale(rawValue: saved) {
            self.currentLocale = locale
        } else {
            // Auto-detect device language
            let preferredLanguage = Locale.preferredLanguages.first ?? "en"
            if preferredLanguage.hasPrefix("he") {
                self.currentLocale = .hebrew
            } else {
                self.currentLocale = .english
            }
            UserDefaults.standard.set(currentLocale.rawValue, forKey: "app_locale")
        }
    }

    var selectedChild: Child?
    var activeConversation: Conversation?

    func navigateToMission(_ mission: Mission) {
        childNavigationPath.append(ChildRoute.missionStart(mission))
    }

    func navigateToConversation(_ conversation: Conversation, mission: Mission) {
        activeConversation = conversation
        childNavigationPath.append(ChildRoute.conversation(conversation, mission))
    }

    func navigateToConversationDetail(_ conversation: Conversation) {
        parentNavigationPath.append(ParentRoute.conversationDetail(conversation))
    }

    func popChild() {
        guard !childNavigationPath.isEmpty else { return }
        childNavigationPath.removeLast()
    }

    func popParent() {
        guard !parentNavigationPath.isEmpty else { return }
        parentNavigationPath.removeLast()
    }

    /// Pre-fetch children right after authentication so we skip the
    /// loading spinner inside RoleSelectionView.
    /// Pass `force: true` to refresh after creating a new child.
    func prefetchChildren(force: Bool = false) async {
        guard !hasCheckedChildren || force else { return }
        do {
            cachedChildren = try await APIClient.shared.getChildren()
        } catch {
            cachedChildren = []
        }
        hasCheckedChildren = true
    }

    func switchRole() {
        childNavigationPath = NavigationPath()
        parentNavigationPath = NavigationPath()
        selectedChild = nil
        activeRole = nil
    }

    /// Reset cached data on logout.
    func resetOnLogout() {
        cachedChildren = nil
        hasCheckedChildren = false
        switchRole()
    }

    /// Return to child picker without going back to role selection
    func switchChild() {
        childNavigationPath = NavigationPath()
        selectedChild = nil
        // activeRole stays .child → RootView will show ChildPickerView
    }
}

enum ChildRoute: Hashable {
    case missionSelection
    case missionStart(Mission)
    case conversation(Conversation, Mission)
    case missionComplete(Conversation)
}

enum ParentRoute: Hashable {
    case childProfile(Child)
    case questions(Child)
    case conversationHistory(Child)
    case conversationDetail(Conversation)
    case liveMonitor(Conversation)
    case insights(Child)
}
