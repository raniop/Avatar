import Foundation

struct ConversationSummary: Codable, Identifiable, Equatable {
    let id: String
    let conversationId: String
    var briefSummary: String
    var detailedSummary: String
    var moodAssessment: String?
    var keyTopics: [String]
    var emotionalFlags: EmotionalFlags?
    var questionAnswers: [QuestionAnswer]
    var engagementLevel: String?
    var talkativenessScore: Double?
}

struct EmotionalFlags: Codable, Equatable {
    let hasFlags: Bool
    var flags: [String]
    var recommendation: String?
}

struct QuestionAnswer: Codable, Equatable {
    let questionId: String
    let childResponse: String
    let analysis: String?
}
