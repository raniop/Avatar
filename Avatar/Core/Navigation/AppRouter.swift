import SwiftUI
import Observation

@Observable
final class AppRouter {
    var currentLocale: AppLocale = .english
    var childNavigationPath = NavigationPath()
    var parentNavigationPath = NavigationPath()

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
