import Foundation

// MARK: - Educational Content Type

enum EducationalContentType: String, Codable, Equatable {
    case hebrewLetters = "hebrew_letters"
    case hebrewWords = "hebrew_words"
    case englishLetters = "english_letters"
    case englishWords = "english_words"
    case math = "math"
}

// MARK: - Challenge

struct EducationalChallenge {
    let prompt: String           // What to display (the target letter/word/equation)
    let promptEmoji: String?     // Optional picture hint (for advanced word-building)
    let correctAnswers: [String] // Correct characters in order (e.g. ["כ","ד","ו","ר"] for "כדור")
    let distractors: [String]    // Wrong options to mix in
}

// MARK: - Content Generator

struct EducationalContent {

    // MARK: - Default content type for age + locale

    static func defaultContentType(locale: AppLocale, age: Int) -> EducationalContentType {
        switch (locale, age) {
        case (.hebrew, ...4): return .hebrewLetters
        case (.hebrew, 5...6): return .hebrewWords
        case (.hebrew, 7...): return .hebrewWords
        case (.english, ...4): return .englishLetters
        case (.english, 5...): return .englishWords
        default: return .hebrewLetters
        }
    }

    // MARK: - Generate challenges

    static func generate(
        locale: AppLocale,
        age: Int,
        contentType: EducationalContentType,
        count: Int
    ) -> [EducationalChallenge] {
        switch contentType {
        case .hebrewLetters:
            return generateHebrewLetters(count: count)
        case .hebrewWords:
            return generateHebrewWords(age: age, count: count)
        case .englishLetters:
            return generateEnglishLetters(count: count)
        case .englishWords:
            return generateEnglishWords(age: age, count: count)
        case .math:
            return generateMath(age: age, count: count)
        }
    }

    // MARK: - Hebrew Letters

    private static let hebrewAlphabet = ["א","ב","ג","ד","ה","ו","ז","ח","ט","י","כ","ל","מ","נ","ס","ע","פ","צ","ק","ר","ש","ת"]

    private static func generateHebrewLetters(count: Int) -> [EducationalChallenge] {
        let shuffled = hebrewAlphabet.shuffled()
        return shuffled.prefix(count).map { letter in
            let others = hebrewAlphabet.filter { $0 != letter }.shuffled().prefix(3)
            return EducationalChallenge(
                prompt: letter,
                promptEmoji: nil,
                correctAnswers: [letter],
                distractors: Array(others)
            )
        }
    }

    // MARK: - Hebrew Words

    private static let hebrewWordsBank: [(word: String, emoji: String)] = [
        // 2-letter words (easiest)
        ("דג", "🐟"), ("גן", "🌳"), ("אם", "👩"), ("אב", "👨"),
        // 3-letter words
        ("בית", "🏠"), ("ילד", "👦"), ("שמש", "☀️"), ("ספר", "📖"),
        ("כלב", "🐕"), ("חתול", "🐱"), ("פרח", "🌸"), ("עץ", "🌲"),
        ("ים", "🌊"), ("גשם", "🌧️"), ("כוס", "🥤"), ("דלת", "🚪"),
        // 4-letter words (harder)
        ("כדור", "⚽"), ("ארנב", "🐰"), ("תפוח", "🍎"), ("שולחן", "🪑"),
        ("מטוס", "✈️"), ("רכבת", "🚂"), ("פרפר", "🦋"), ("שמלה", "👗"),
    ]

    private static func generateHebrewWords(age: Int, count: Int) -> [EducationalChallenge] {
        let maxLen: Int
        switch age {
        case ...4: maxLen = 2
        case 5...6: maxLen = 3
        default: maxLen = 5
        }

        let eligible = hebrewWordsBank.filter { $0.word.count <= maxLen }.shuffled()
        let showImage = age >= 7 // Advanced: show image, hide word

        return eligible.prefix(count).map { entry in
            let letters = entry.word.map { String($0) }
            let allLetters = Set(hebrewAlphabet)
            let wordLetters = Set(letters)
            let distractorPool = allLetters.subtracting(wordLetters).shuffled()
            let distractorCount = min(3, distractorPool.count)

            return EducationalChallenge(
                prompt: showImage ? "" : entry.word,
                promptEmoji: entry.emoji,
                correctAnswers: letters,
                distractors: Array(distractorPool.prefix(distractorCount))
            )
        }
    }

    // MARK: - English Letters

    private static let englishAlphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { String($0) }

    private static func generateEnglishLetters(count: Int) -> [EducationalChallenge] {
        let shuffled = englishAlphabet.shuffled()
        return shuffled.prefix(count).map { letter in
            let others = englishAlphabet.filter { $0 != letter }.shuffled().prefix(3)
            return EducationalChallenge(
                prompt: letter,
                promptEmoji: nil,
                correctAnswers: [letter],
                distractors: Array(others)
            )
        }
    }

    // MARK: - English Words

    private static let englishWordsBank: [(word: String, emoji: String)] = [
        // CVC words (easiest)
        ("CAT", "🐱"), ("DOG", "🐕"), ("SUN", "☀️"), ("BUS", "🚌"),
        ("CUP", "🥤"), ("HAT", "🎩"), ("BED", "🛏️"), ("PIG", "🐷"),
        // 4-letter words
        ("FISH", "🐟"), ("BALL", "⚽"), ("TREE", "🌲"), ("STAR", "⭐"),
        ("CAKE", "🎂"), ("BIRD", "🐦"), ("BOAT", "⛵"), ("FROG", "🐸"),
        // 5-letter words
        ("HOUSE", "🏠"), ("APPLE", "🍎"), ("HEART", "❤️"), ("FLOWER", "🌸"),
        ("PLANE", "✈️"), ("TRAIN", "🚂"), ("MOUSE", "🐭"), ("CLOUD", "☁️"),
    ]

    private static func generateEnglishWords(age: Int, count: Int) -> [EducationalChallenge] {
        let maxLen: Int
        switch age {
        case ...4: maxLen = 3
        case 5...6: maxLen = 4
        default: maxLen = 6
        }

        let eligible = englishWordsBank.filter { $0.word.count <= maxLen }.shuffled()
        let showImage = age >= 7

        return eligible.prefix(count).map { entry in
            let letters = entry.word.map { String($0) }
            let allLetters = Set(englishAlphabet)
            let wordLetters = Set(letters)
            let distractorPool = allLetters.subtracting(wordLetters).shuffled()
            let distractorCount = min(3, distractorPool.count)

            return EducationalChallenge(
                prompt: showImage ? "" : entry.word,
                promptEmoji: entry.emoji,
                correctAnswers: letters,
                distractors: Array(distractorPool.prefix(distractorCount))
            )
        }
    }

    // MARK: - Math

    private static func generateMath(age: Int, count: Int) -> [EducationalChallenge] {
        (0..<count).map { _ in
            let (equation, answer, wrong) = generateEquation(age: age)
            return EducationalChallenge(
                prompt: equation,
                promptEmoji: nil,
                correctAnswers: [answer],
                distractors: wrong
            )
        }
    }

    private static func generateEquation(age: Int) -> (equation: String, answer: String, wrong: [String]) {
        let a: Int, b: Int, op: String, result: Int

        switch age {
        case ...5:
            // Simple addition 1-5
            a = Int.random(in: 1...5)
            b = Int.random(in: 1...5)
            op = "+"
            result = a + b
        case 6...7:
            // Addition/subtraction up to 10
            if Bool.random() {
                a = Int.random(in: 1...10)
                b = Int.random(in: 1...min(a, 10))
                op = "-"
                result = a - b
            } else {
                a = Int.random(in: 1...10)
                b = Int.random(in: 1...10)
                op = "+"
                result = a + b
            }
        default:
            // Multiplication up to 10×10
            if Bool.random() {
                a = Int.random(in: 2...10)
                b = Int.random(in: 2...10)
                op = "×"
                result = a * b
            } else {
                a = Int.random(in: 1...20)
                b = Int.random(in: 1...20)
                op = "+"
                result = a + b
            }
        }

        let answer = "\(result)"
        var wrongSet = Set<String>()
        while wrongSet.count < 3 {
            let offset = Int.random(in: 1...5) * (Bool.random() ? 1 : -1)
            let wrong = result + offset
            if wrong > 0 && wrong != result {
                wrongSet.insert("\(wrong)")
            }
        }

        return ("\(a) \(op) \(b) = ?", answer, Array(wrongSet))
    }
}
