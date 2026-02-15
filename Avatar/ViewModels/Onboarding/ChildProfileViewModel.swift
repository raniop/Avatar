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
        "Soccer", "Basketball", "Tennis", "Swimming", "Gymnastics",
        "Martial Arts", "Cycling", "Running", "Skateboarding",
        "Drawing", "Music", "Dancing", "Singing", "Photography",
        "Crafts", "Theater",
        "Space", "Science", "Robots", "Video Games", "Coding",
        "Math Puzzles",
        "Animals", "Dinosaurs", "Nature", "Gardening", "Ocean Life",
        "Superheroes", "Princesses", "Cars", "Lego", "Building",
        "Cooking", "Reading", "Fairy Tales", "Pirates",
        "Board Games", "Puzzles", "Magic Tricks"
    ]

    let availableGoals = [
        "Confidence", "Sharing", "Emotional Expression", "Making Friends",
        "Patience", "Dealing with Anger", "Independence", "Kindness",
        "Problem Solving", "Listening", "Being Brave", "Cooperation"
    ]

    func localizedInterest(_ key: String) -> String {
        guard locale == .hebrew else { return key }
        switch key {
        case "Soccer": return "כדורגל"
        case "Basketball": return "כדורסל"
        case "Tennis": return "טניס"
        case "Swimming": return "שחייה"
        case "Gymnastics": return "התעמלות"
        case "Martial Arts": return "אומנויות לחימה"
        case "Cycling": return "רכיבת אופניים"
        case "Running": return "ריצה"
        case "Skateboarding": return "סקייטבורד"
        case "Drawing": return "ציור"
        case "Music": return "מוזיקה"
        case "Dancing": return "ריקוד"
        case "Singing": return "שירה"
        case "Photography": return "צילום"
        case "Crafts": return "יצירה"
        case "Theater": return "תיאטרון"
        case "Space": return "חלל"
        case "Science": return "מדע"
        case "Robots": return "רובוטים"
        case "Video Games": return "משחקי מחשב"
        case "Coding": return "תכנות"
        case "Math Puzzles": return "חידות מתמטיקה"
        case "Animals": return "חיות"
        case "Dinosaurs": return "דינוזאורים"
        case "Nature": return "טבע"
        case "Gardening": return "גינון"
        case "Ocean Life": return "חיי הים"
        case "Superheroes": return "גיבורי על"
        case "Princesses": return "נסיכות"
        case "Cars": return "מכוניות"
        case "Lego": return "לגו"
        case "Building": return "בנייה"
        case "Cooking": return "בישול"
        case "Reading": return "קריאה"
        case "Fairy Tales": return "אגדות"
        case "Pirates": return "פיראטים"
        case "Board Games": return "משחקי קופסה"
        case "Puzzles": return "פאזלים"
        case "Magic Tricks": return "קסמים"
        default: return key
        }
    }

    func localizedGoal(_ key: String) -> String {
        guard locale == .hebrew else { return key }
        switch key {
        case "Sharing": return "שיתוף"
        case "Confidence": return "ביטחון עצמי"
        case "Making Friends": return "לבנות חברויות"
        case "Emotional Expression": return "ביטוי רגשי"
        case "Dealing with Anger": return "התמודדות עם כעס"
        case "Patience": return "סבלנות"
        case "Kindness": return "חסד ואדיבות"
        case "Independence": return "עצמאות"
        case "Problem Solving": return "פתרון בעיות"
        case "Listening": return "הקשבה"
        case "Being Brave": return "אומץ"
        case "Cooperation": return "שיתוף פעולה"
        default: return key
        }
    }

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
