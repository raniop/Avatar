import Foundation
import Observation

@Observable
final class QuestionsViewModel {
    var questions: [ParentQuestion] = []
    var showAddQuestion = false
    var isLoading = false

    private let childId: String
    private let apiClient = APIClient.shared

    init(childId: String) {
        self.childId = childId
    }

    func loadQuestions() async {
        isLoading = true
        do {
            questions = try await apiClient.getQuestions(childId: childId)
        } catch {
            // Handle error
        }
        isLoading = false
    }

    func addQuestion(text: String, topic: String?, priority: Int, isRecurring: Bool) async {
        do {
            let request = CreateQuestionRequest(
                questionText: text,
                topic: topic,
                priority: priority,
                isRecurring: isRecurring
            )
            let question = try await apiClient.createQuestion(childId: childId, question: request)
            questions.append(question)
        } catch {
            // Handle error
        }
    }

    func deleteQuestion(_ question: ParentQuestion) async {
        do {
            try await apiClient.deleteQuestion(id: question.id)
            questions.removeAll { $0.id == question.id }
        } catch {
            // Handle error
        }
    }
}
