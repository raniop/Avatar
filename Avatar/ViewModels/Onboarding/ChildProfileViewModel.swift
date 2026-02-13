import Foundation
import Observation

@Observable
final class ChildProfileViewModel {
    var name = ""
    var age = 4
    var gender = "boy"
    var selectedInterests: [String] = []
    var selectedGoals: [String] = []
    var locale: AppLocale = .english
    var isSaving = false

    let availableInterests = [
        "Dinosaurs", "Space", "Animals", "Soccer", "Cars",
        "Drawing", "Music", "Dancing", "Building", "Cooking",
        "Superheroes", "Princesses", "Robots", "Nature", "Swimming"
    ]

    let availableGoals = [
        "Confidence", "Sharing", "Emotional Expression", "Making Friends",
        "Patience", "Dealing with Anger", "Independence", "Kindness",
        "Problem Solving", "Listening", "Being Brave", "Cooperation"
    ]

    private let apiClient = APIClient.shared

    func saveChild() async {
        isSaving = true
        do {
            let request = CreateChildRequest(
                name: name,
                age: age,
                gender: gender,
                interests: selectedInterests,
                developmentGoals: selectedGoals,
                locale: locale.rawValue
            )
            _ = try await apiClient.createChild(request)
        } catch {
            // Handle error
        }
        isSaving = false
    }
}
