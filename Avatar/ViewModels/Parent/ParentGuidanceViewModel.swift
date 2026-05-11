import Foundation
import Observation

@Observable
final class ParentGuidanceViewModel {
    var guidanceItems: [ParentGuidance] = []
    var showAddGuidance = false
    var isLoading = false

    private let childId: String
    private let apiClient = APIClient.shared

    init(childId: String) {
        self.childId = childId
    }

    func loadGuidance() async {
        isLoading = true
        do {
            guidanceItems = try await apiClient.getGuidance(childId: childId)
        } catch {
            // Handle error
        }
        isLoading = false
    }

    func addGuidance(instruction: String) async {
        do {
            let item = try await apiClient.createGuidance(childId: childId, instruction: instruction)
            guidanceItems.append(item)
        } catch {
            // Handle error
        }
    }

    func deleteGuidance(_ item: ParentGuidance) async {
        do {
            try await apiClient.deleteGuidance(id: item.id)
            guidanceItems.removeAll { $0.id == item.id }
        } catch {
            // Handle error
        }
    }
}
