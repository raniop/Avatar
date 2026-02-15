import Foundation
import SwiftUI

enum AppLocale: String, Codable, CaseIterable {
    case english = "en"
    case hebrew = "he"

    var displayName: String {
        switch self {
        case .english: "English"
        case .hebrew: "עברית"
        }
    }

    var layoutDirection: LayoutDirection {
        switch self {
        case .english: .leftToRight
        case .hebrew: .rightToLeft
        }
    }

    // MARK: - Auth / Login

    var appTagline: String { self == .hebrew ? "החבר הכי טוב של הילד שלך" : "Your child's AI best friend" }
    var continueWithApple: String { self == .hebrew ? "המשך עם Apple" : "Continue with Apple" }
    var continueWithGoogle: String { self == .hebrew ? "המשך עם Google" : "Continue with Google" }
    var or: String { self == .hebrew ? "או" : "or" }
    var email: String { self == .hebrew ? "אימייל" : "Email" }
    var password: String { self == .hebrew ? "סיסמה" : "Password" }
    var logIn: String { self == .hebrew ? "התחבר" : "Log In" }
    var dontHaveAccount: String { self == .hebrew ? "אין לך חשבון? **הרשמה**" : "Don't have an account? **Sign Up**" }
    var alreadyHaveAccount: String { self == .hebrew ? "כבר יש לך חשבון? **התחברות**" : "Already have an account? **Log In**" }
    var createAccount: String { self == .hebrew ? "צור חשבון" : "Create Account" }
    var yourName: String { self == .hebrew ? "השם שלך" : "Your Name" }
    var passwordMinChars: String { self == .hebrew ? "סיסמה (6+ תווים)" : "Password (6+ characters)" }
    var confirmPassword: String { self == .hebrew ? "אימות סיסמה" : "Confirm Password" }
    var passwordsDontMatch: String { self == .hebrew ? "הסיסמאות לא תואמות" : "Passwords don't match" }

    // MARK: - Role Selection

    var welcome: String { self == .hebrew ? "ברוכים הבאים!" : "Welcome!" }
    var whoIsUsing: String { self == .hebrew ? "מי משתמש באפליקציה?" : "Who's using the app?" }
    var kidRole: String { self == .hebrew ? "ילד" : "Kid" }
    var kidSubtitle: String { self == .hebrew ? "משחק ושיחה" : "Play & Talk" }
    var parentRole: String { self == .hebrew ? "הורה" : "Parent" }
    var parentSubtitle: String { self == .hebrew ? "ניהול ומעקב" : "Manage & Monitor" }
    var parentVerification: String { self == .hebrew ? "אימות הורה" : "Parent Verification" }
    var wrongAnswer: String { self == .hebrew ? "תשובה שגויה. נסה שוב!" : "Wrong answer. Try again!" }
    var whatIs: String { self == .hebrew ? "כמה זה" : "What is" }
    var keepKidsSafe: String { self == .hebrew ? "כדי לשמור על הילדים, פתרו:" : "To keep kids safe, please solve:" }
    var answer: String { self == .hebrew ? "תשובה" : "Answer" }

    // MARK: - Tabs

    var home: String { self == .hebrew ? "בית" : "Home" }
    var dashboard: String { self == .hebrew ? "לוח בקרה" : "Dashboard" }

    // MARK: - Child Picker

    var choosePlayer: String { self == .hebrew ? "מי משחק?" : "Who's Playing?" }
    var noChildrenYet: String { self == .hebrew ? "אין ילדים עדיין" : "No children yet" }
    var askParentToSetup: String { self == .hebrew ? "בקש מההורה להוסיף אותך" : "Ask a parent to set you up" }
    var goBack: String { self == .hebrew ? "חזרה" : "Go Back" }
    var switchChild: String { self == .hebrew ? "החלף שחקן" : "Switch Player" }

    // MARK: - Child Home

    func greeting(_ name: String) -> String {
        self == .hebrew ? "היי! אני \(name)!" : "Hi there! I'm \(name)!"
    }
    func childGreeting(_ childName: String) -> String {
        self == .hebrew ? "היי \(childName)!" : "Hey \(childName)!"
    }
    var readyForAdventure: String { self == .hebrew ? "מוכנים להרפתקה?" : "Ready for an adventure?" }
    var changeAvatar: String { self == .hebrew ? "שנה אווטאר" : "Change Avatar" }
    var createAvatar: String { self == .hebrew ? "צור את האווטאר שלך!" : "Create Your Avatar!" }
    var letsGo: String { self == .hebrew ? "יאללה!" : "Let's Go!" }
    var chooseYourMission: String { self == .hebrew ? "בחר משימה" : "Choose Your Mission" }
    var noMissions: String { self == .hebrew ? "אין משימות זמינות כרגע" : "No missions available right now" }
    var gettingReady: String { self == .hebrew ? "מתכוננים..." : "Getting ready..." }

    // MARK: - Mission Card

    var minuteSuffix: String { self == .hebrew ? "דק׳" : "min" }

    // MARK: - Conversation

    var startingDots: String { self == .hebrew ? "מתחילים..." : "Starting..." }
    var adventure: String { self == .hebrew ? "הרפתקה" : "Adventure" }
    var wrappingUp: String { self == .hebrew ? "מסיימים" : "Wrapping up" }
    var missionComplete: String { self == .hebrew ? "המשימה הושלמה!" : "Mission Complete!" }
    var greatJob: String { self == .hebrew ? "עבודה מעולה היום!" : "Great job today!" }
    var done: String { self == .hebrew ? "סיום" : "Done" }
    var parentWatching: String { self == .hebrew ? "הורה צופה" : "Parent is watching" }

    // MARK: - Avatar / Child Creation

    var uploadPhotoToCreate: String { self == .hebrew ? "העלה תמונה\nליצירת אווטאר" : "Upload a photo\nto create avatar" }
    var tapToUploadPhoto: String { self == .hebrew ? "לחץ להעלאת תמונה" : "Tap to upload photo" }
    var creatingAvatar: String { self == .hebrew ? "יוצר אווטאר..." : "Creating avatar..." }
    var changePhoto: String { self == .hebrew ? "שנה תמונה" : "Change Photo" }
    var uploadPhoto: String { self == .hebrew ? "העלה תמונה" : "Upload Photo" }
    var childNameLabel: String { self == .hebrew ? "שם הילד/ה" : "Child's Name" }
    var enterChildName: String { self == .hebrew ? "הכנס שם לילד/ה" : "Enter child's name" }
    var saving: String { self == .hebrew ? "שומר..." : "Saving..." }
    var createChild: String { self == .hebrew ? "צור ילד/ה!" : "Create Child!" }
    var createChildTitle: String { self == .hebrew ? "צור ילד/ה" : "Create Child" }
    var letsStartTitle: String { self == .hebrew ? "בואו נתחיל!" : "Let's Get Started!" }
    var letsStartSubtitle: String { self == .hebrew ? "צרו את הפרופיל של הילד/ה כדי להתחיל\nעם החבר החדש שלהם" : "Create your child's profile to get started\nwith their new AI friend" }
    var createFirstChild: String { self == .hebrew ? "צור את הילד/ה הראשון/ה" : "Create Your First Child" }
    var enterAsParentFirst: String { self == .hebrew ? "היכנס כהורה קודם כדי להוסיף ילדים" : "Enter as parent first to add children" }
    var createChildHint: String { self == .hebrew ? "צור ילד 😊" : "Create a child 😊" }

    // MARK: - Child Profile Setup

    var basicInfo: String { self == .hebrew ? "פרטים בסיסיים" : "Basic Info" }
    var childsName: String { self == .hebrew ? "שם הילד/ה" : "Child's Name" }
    var age: String { self == .hebrew ? "גיל" : "Age" }
    var gender: String { self == .hebrew ? "מגדר" : "Gender" }
    var boy: String { self == .hebrew ? "בן" : "Boy" }
    var girl: String { self == .hebrew ? "בת" : "Girl" }
    var other: String { self == .hebrew ? "אחר" : "Other" }
    var interests: String { self == .hebrew ? "תחומי עניין" : "Interests" }
    var developmentGoals: String { self == .hebrew ? "יעדי התפתחות" : "Development Goals" }
    var whatToWorkOn: String { self == .hebrew ? "על מה תרצו לעבוד?" : "What would you like to work on?" }
    var language: String { self == .hebrew ? "שפה" : "Language" }
    var primaryLanguage: String { self == .hebrew ? "שפה ראשית" : "Primary Language" }
    var addChild: String { self == .hebrew ? "הוסף ילד/ה" : "Add Child" }
    var save: String { self == .hebrew ? "שמור" : "Save" }

    // MARK: - Settings

    var settings: String { self == .hebrew ? "הגדרות" : "Settings" }
    var account: String { self == .hebrew ? "חשבון" : "Account" }
    var name: String { self == .hebrew ? "שם" : "Name" }
    var appLanguage: String { self == .hebrew ? "שפת האפליקציה" : "App Language" }
    var switchRole: String { self == .hebrew ? "החלף תפקיד" : "Switch Role" }
    var logOut: String { self == .hebrew ? "התנתק" : "Log Out" }

    // MARK: - Common

    var cancel: String { self == .hebrew ? "ביטול" : "Cancel" }
    var enter: String { self == .hebrew ? "אישור" : "Enter" }
    var loading: String { self == .hebrew ? "טוען..." : "Loading..." }
    var delete: String { self == .hebrew ? "מחק" : "Delete" }
    func deleteChildConfirm(_ name: String) -> String {
        self == .hebrew ? "למחוק את \(name)? לא ניתן לשחזר." : "Delete \(name)? This cannot be undone."
    }
    var next: String { self == .hebrew ? "הבא" : "Next" }
    var conversation: String { self == .hebrew ? "שיחה" : "Conversation" }

    // MARK: - Parent Dashboard

    func welcomeUser(_ name: String) -> String {
        self == .hebrew ? "שלום, \(name)" : "Welcome, \(name)"
    }
    var addChildProfile: String { self == .hebrew ? "הוסיפו את פרופיל הילד/ה" : "Add your child's profile" }
    var addChildDescription: String { self == .hebrew ? "הגדירו את פרופיל הילד/ה כדי להתחיל עם חבר האווטאר" : "Set up your child's profile to get started with their AI avatar friend" }
    var recentConversations: String { self == .hebrew ? "שיחות אחרונות" : "Recent Conversations" }
    func childAge(_ ageValue: Int) -> String {
        self == .hebrew ? "גיל \(ageValue)" : "Age \(ageValue)"
    }
    var questions: String { self == .hebrew ? "שאלות" : "Questions" }
    var history: String { self == .hebrew ? "היסטוריה" : "History" }
    var insights: String { self == .hebrew ? "תובנות" : "Insights" }

    // MARK: - Conversation History

    var loadingConversations: String { self == .hebrew ? "טוען שיחות..." : "Loading conversations..." }
    var noConversationsYet: String { self == .hebrew ? "אין שיחות עדיין" : "No conversations yet" }
    func noConversationsDesc(_ childName: String) -> String {
        self == .hebrew ? "\(childName) עדיין לא שוחח/ה עם האווטאר." : "\(childName) hasn't had any conversations with their avatar yet."
    }
    func childHistory(_ childName: String) -> String {
        self == .hebrew ? "ההיסטוריה של \(childName)" : "\(childName)'s History"
    }

    // MARK: - Conversation Detail

    var summaryLabel: String { self == .hebrew ? "סיכום" : "Summary" }
    var transcript: String { self == .hebrew ? "תמליל" : "Transcript" }
    var conversationDetails: String { self == .hebrew ? "פרטי שיחה" : "Conversation Details" }
    var mood: String { self == .hebrew ? "מצב רוח" : "Mood" }
    var keyTopics: String { self == .hebrew ? "נושאים מרכזיים" : "Key Topics" }
    var yourQuestions: String { self == .hebrew ? "השאלות שלך" : "Your Questions" }
    var engagement: String { self == .hebrew ? "מעורבות" : "Engagement" }
    func engagementLevel(_ level: String) -> String {
        self == .hebrew ? "רמה: \(level)" : "Level: \(level)"
    }
    var attention: String { self == .hebrew ? "שים לב" : "Attention" }
    var detailedAnalysis: String { self == .hebrew ? "ניתוח מפורט" : "Detailed Analysis" }
    var noSummaryYet: String { self == .hebrew ? "אין סיכום עדיין." : "No summary available yet." }
    var viewLabel: String { self == .hebrew ? "תצוגה" : "View" }

    // MARK: - Insights

    var analyzing: String { self == .hebrew ? "מנתח..." : "Analyzing..." }
    var noInsightsYet: String { self == .hebrew ? "אין תובנות עדיין" : "No insights yet" }
    func insightsAppearAfter(_ childName: String) -> String {
        self == .hebrew ? "תובנות יופיעו אחרי ש\(childName) ישוחח/תשוחח כמה פעמים." : "Insights will appear after \(childName) has a few conversations."
    }
    func childInsights(_ childName: String) -> String {
        self == .hebrew ? "התובנות של \(childName)" : "\(childName)'s Insights"
    }
    var total: String { self == .hebrew ? "סה״כ" : "Total" }
    var conversationsPlural: String { self == .hebrew ? "שיחות" : "conversations" }
    var completed: String { self == .hebrew ? "הושלמו" : "Completed" }
    var finished: String { self == .hebrew ? "הסתיימו" : "finished" }
    var moodOverview: String { self == .hebrew ? "סקירת מצב רוח" : "Mood Overview" }
    var missionTopics: String { self == .hebrew ? "נושאי משימות" : "Mission Topics" }

    // MARK: - Live Monitor

    var connecting: String { self == .hebrew ? "מתחבר..." : "Connecting..." }
    var liveMonitor: String { self == .hebrew ? "צפייה בזמן אמת" : "Live Monitor" }
    var live: String { self == .hebrew ? "שידור חי" : "LIVE" }
    var sendGuidance: String { self == .hebrew ? "שלח הנחיה לאווטאר..." : "Send guidance to avatar..." }
    var childRole: String { self == .hebrew ? "ילד/ה" : "Child" }
    var avatarRole: String { self == .hebrew ? "אווטאר" : "Avatar" }
    var youIntervention: String { self == .hebrew ? "את/ה (התערבות)" : "You (intervention)" }

    // MARK: - Questions

    var activeQuestions: String { self == .hebrew ? "שאלות פעילות" : "Active Questions" }
    var questionsFooter: String { self == .hebrew ? "השאלות האלה ישולבו בצורה טבעית בשיחה הבאה של הילד/ה עם האווטאר." : "These questions will be naturally woven into your child's next conversation with their avatar." }
    func questionsFor(_ childName: String) -> String {
        self == .hebrew ? "שאלות עבור \(childName)" : "Questions for \(childName)"
    }
    var recurring: String { self == .hebrew ? "חוזרת" : "Recurring" }
    func priorityLabel(_ value: Int) -> String {
        self == .hebrew ? "עדיפות: \(value)" : "Priority: \(value)"
    }
    var addQuestion: String { self == .hebrew ? "הוסף שאלה" : "Add Question" }
    var question: String { self == .hebrew ? "שאלה" : "Question" }
    var whatToAsk: String { self == .hebrew ? "מה תרצה לשאול?" : "What would you like to ask?" }
    var details: String { self == .hebrew ? "פרטים" : "Details" }
    var topicOptional: String { self == .hebrew ? "נושא (אופציונלי)" : "Topic (optional)" }
    var add: String { self == .hebrew ? "הוסף" : "Add" }
    var exampleQuestions: String { self == .hebrew ? "שאלות לדוגמה:" : "Example questions:" }
    var exampleQ1: String { self == .hebrew ? "איך היה היום שלך בבית הספר?" : "How was your day at school?" }
    var exampleQ2: String { self == .hebrew ? "מישהו הפריע לך היום?" : "Did anyone bother you today?" }
    var exampleQ3: String { self == .hebrew ? "מה שימח אותך היום?" : "What made you happy today?" }
}
