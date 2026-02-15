import Foundation
import Observation

/// Pairs a conversation with the child it belongs to
struct ChildConversation: Identifiable {
    let id: String
    let childId: String
    let childName: String
    let conversation: ConversationListItem

    init(childId: String, childName: String, conversation: ConversationListItem) {
        self.id = conversation.id
        self.childId = childId
        self.childName = childName
        self.conversation = conversation
    }
}

@Observable
final class ParentDashboardViewModel {
    var children: [Child] = []
    var recentConversations: [ChildConversation] = []
    var showAddChild = false
    var isLoading = false
    var isDeleting = false

    private let apiClient = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            children = try await apiClient.getChildren()
            // Load recent conversations for ALL children
            var allConversations: [ChildConversation] = []
            for child in children {
                let wrapper = try await apiClient.getConversations(childId: child.id, limit: 10)
                let mapped = wrapper.conversations.map {
                    ChildConversation(childId: child.id, childName: child.name, conversation: $0)
                }
                allConversations.append(contentsOf: mapped)
            }
            // Sort by most recent first
            recentConversations = allConversations.sorted { $0.conversation.startedAt > $1.conversation.startedAt }
        } catch {
            print("ParentDashboard loadData error: \(error.localizedDescription)")
        }
        isLoading = false
    }

    func deleteChild(_ child: Child) async {
        isDeleting = true
        do {
            try await apiClient.deleteChild(id: child.id)
            // Clean up local avatar cache
            await AvatarStorage.shared.deleteAvatar(childId: child.id)
            // Remove child from list
            children.removeAll { $0.id == child.id }
            // Remove that child's conversations
            recentConversations.removeAll { $0.childId == child.id }
        } catch {
            print("Delete child error: \(error.localizedDescription)")
        }
        isDeleting = false
    }
}
