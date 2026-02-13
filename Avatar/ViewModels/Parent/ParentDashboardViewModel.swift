import Foundation
import Observation

@Observable
final class ParentDashboardViewModel {
    var children: [Child] = []
    var recentConversations: [Conversation] = []
    var showAddChild = false
    var isLoading = false

    private let apiClient = APIClient.shared

    func loadData() async {
        isLoading = true
        do {
            children = try await apiClient.getChildren()
            // Load recent conversations for first child
            if let firstChild = children.first {
                recentConversations = try await apiClient.getConversations(childId: firstChild.id)
            }
        } catch {
            // Will be empty on first launch with no backend
        }
        isLoading = false
    }

    func navigateToQuestions(for child: Child) {
        // TODO: Navigate to questions list
    }

    func navigateToHistory(for child: Child) {
        // TODO: Navigate to conversation history
    }

    func navigateToInsights(for child: Child) {
        // TODO: Navigate to insights dashboard
    }
}
