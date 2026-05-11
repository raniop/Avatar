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
    func readyForAdventure(gender: String? = nil) -> String {
        if self == .hebrew {
            switch gender?.lowercased() {
            case "girl": return "מוכנה להרפתקה?"
            default: return "מוכן להרפתקה?"
            }
        }
        return "Ready for an adventure?"
    }
    var changeAvatar: String { self == .hebrew ? "שנה אווטאר" : "Change Avatar" }
    var changeFriend: String { self == .hebrew ? "החלף חבר" : "Change Friend" }
    var createAvatar: String { self == .hebrew ? "צור את האווטאר שלך!" : "Create Your Avatar!" }
    var letsGo: String { self == .hebrew ? "יאללה!" : "Let's Go!" }
    func chooseYourMission(gender: String? = nil) -> String {
        if self == .hebrew {
            switch gender?.lowercased() {
            case "girl": return "בחרי משימה"
            default: return "בחר משימה"
            }
        }
        return "Choose Your Mission"
    }
    var noMissions: String { self == .hebrew ? "אין משימות זמינות כרגע" : "No missions available right now" }
    var gettingReady: String { self == .hebrew ? "מתכוננים..." : "Getting ready..." }
    var preparingAdventure: String { self == .hebrew ? "מכינים את ההרפתקה..." : "Preparing the adventure..." }
    var almostThere: String { self == .hebrew ? "עוד רגע יוצאים!" : "Almost there!" }

    // MARK: - Avatar Setup (child first-time)
    func heyChildName(_ name: String) -> String {
        self == .hebrew ? "היי \(name)," : "Hey \(name),"
    }
    func chooseYourFriend(gender: String? = nil) -> String {
        if self == .hebrew {
            switch gender?.lowercased() {
            case "girl": return "בחרי את החברה שלך!"
            default: return "בחר את החבר שלך!"
            }
        }
        return "Choose your friend!"
    }
    func meetYourFriend(gender: String? = nil) -> String {
        if self == .hebrew {
            switch gender?.lowercased() {
            case "girl": return "הנה החברה החדשה שלך!"
            default: return "הנה החבר החדש שלך!"
            }
        }
        return "Meet your new friend!"
    }
    func avatarIntro(avatarName: String, childName: String, gender: String? = nil) -> String {
        if self == .hebrew {
            switch gender?.lowercased() {
            case "girl": return "היי \(childName)! אני \(avatarName)!\nבואי נצא להרפתקאות ביחד!"
            default: return "היי \(childName)! אני \(avatarName)!\nבוא נצא להרפתקאות ביחד!"
            }
        }
        return "Hey \(childName)! I'm \(avatarName)!\nLet's go on adventures together!"
    }
    func newFriendReady(gender: String? = nil) -> String {
        if self == .hebrew {
            return "אני תמיד אהיה פה בשבילך ✨"
        }
        return "I'll always be here for you ✨"
    }

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

    // MARK: - Adventure Game

    var adventureComplete: String { self == .hebrew ? "ההרפתקה הושלמה!" : "Adventure Complete!" }
    var starsCollected: String { self == .hebrew ? "כוכבים" : "stars" }
    func starsEarnedLabel(_ count: Int) -> String {
        self == .hebrew ? "\(count) כוכבים" : "\(count) stars earned"
    }
    var typeHere: String { self == .hebrew ? "כתוב כאן..." : "Type here..." }

    // MARK: - Mini-Games

    var gameWatch: String { self == .hebrew ? "👀 צפה!" : "👀 Watch!" }
    var gameYourTurn: String { self == .hebrew ? "👆 תורך!" : "👆 Your turn!" }
    var gameNextRound: String { self == .hebrew ? "סיבוב הבא" : "Next Round" }
    var gameContinue: String { self == .hebrew ? "המשך" : "Continue" }
    func gameRoundLabel(_ current: Int, _ total: Int) -> String {
        self == .hebrew ? "סיבוב \(current)/\(total)" : "Round \(current)/\(total)"
    }
    func gameTimerLabel(_ seconds: Int) -> String { "\(seconds)s" }
    func gameScoreLabel(_ score: Int, _ threshold: Int) -> String { "\(score)/\(threshold)" }

    // MARK: - Sport Games

    var gameGoal: String { self == .hebrew ? "גול!" : "Goal!" }
    var gameSwish: String { self == .hebrew ? "קליעה!" : "Swish!" }
    var gameFindTheLetter: String { self == .hebrew ? "מצאו את האות" : "Find the letter" }
    var gameSpellTheWord: String { self == .hebrew ? "אייתו את המילה" : "Spell the word" }
    var gameCollectLetters: String { self == .hebrew ? "אספו אותיות" : "Collect letters" }
    var gameSolve: String { self == .hebrew ? "פתרו" : "Solve" }

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

    // Multi-step child creation flow
    var uploadChildPhoto: String { self == .hebrew ? "העלו תמונה של הילד/ה" : "Upload your child's photo" }
    var uploadChildPhotoSubtitle: String { self == .hebrew ? "נהפוך אותה לאווטאר מיוחד!" : "We'll turn it into a special avatar!" }
    var whatsTheirName: String { self == .hebrew ? "מה השם?" : "What's their name?" }
    var whatsTheirNameSubtitle: String { self == .hebrew ? "הכניסו את שם הילד/ה" : "Enter your child's name" }
    var whatDoTheyLove: String { self == .hebrew ? "מה הילד/ה אוהב/ת?" : "What do they love?" }
    var whatDoTheyLoveSubtitle: String { self == .hebrew ? "בחרו תחומי עניין ופרטים נוספים" : "Choose interests and more details" }
    var almostReady: String { self == .hebrew ? "כמעט מוכן..." : "Almost ready..." }
    var letsGoButton: String { self == .hebrew ? "בוא נתחיל!" : "Let's go!" }
    var meetAvatar: String { self == .hebrew ? "הכירו את האווטאר!" : "Meet the avatar!" }

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

    // MARK: - Parent Guidance

    var guidance: String { self == .hebrew ? "הנחיה" : "Guidance" }
    var guidanceTab: String { self == .hebrew ? "הנחיות" : "Guidance" }
    var activeGuidance: String { self == .hebrew ? "הנחיות פעילות" : "Active Guidance" }
    var guidanceFooter: String { self == .hebrew ? "ההנחיות ישפיעו על התנהגות האווטאר. הילד/ה לא יראה/תראה אותן." : "These instructions will influence the avatar's behavior. Your child won't see them." }
    func guidanceFor(_ childName: String) -> String {
        self == .hebrew ? "הנחיות עבור \(childName)" : "Guidance for \(childName)"
    }
    var addGuidance: String { self == .hebrew ? "הוסף הנחיה" : "Add Guidance" }
    var guidanceHint: String { self == .hebrew ? "מה תרצה שהאווטאר יעשה?" : "What should the avatar do?" }
    var guidanceExplanation: String { self == .hebrew ? "דוגמאות להנחיות:" : "Example instructions:" }
    var exampleG1: String { self == .hebrew ? "עודד את הילד/ה לספר על החברים שלו/ה" : "Encourage the child to talk about their friends" }
    var exampleG2: String { self == .hebrew ? "דבר איתו/ה על רגשות בצורה עדינה" : "Talk about emotions gently" }
    var exampleG3: String { self == .hebrew ? "שאל אותו/ה על בית הספר בצורה כיפית" : "Ask about school in a fun way" }
    var guideAvatar: String { self == .hebrew ? "הנחה אווטאר" : "Guide Avatar" }
    var messageToChild: String { self == .hebrew ? "הודעה לילד/ה" : "Message to Child" }
    var guidanceSent: String { self == .hebrew ? "הנחיה נשלחה" : "Guidance sent" }

    // MARK: - Onboarding

    var onboardingWelcomeTitle: String {
        self == .hebrew ? "ברוכים הבאים לאווטאר!" : "Welcome to Avatar!"
    }
    var onboardingWelcomeSubtitle: String {
        self == .hebrew
            ? "החבר הכי טוב של הילד שלך.\nאווטאר AI שמדבר, מקשיב ומלווה."
            : "Your child's AI best friend.\nAn avatar that talks, listens, and guides."
    }

    var onboardingSafeConversationsTitle: String {
        self == .hebrew ? "שיחות בטוחות" : "Safe Conversations"
    }
    var onboardingSafeConversationsSubtitle: String {
        self == .hebrew
            ? "הילד מדבר עם האווטאר בקול.\nהשיחות בטוחות, חמות ומותאמות אישית."
            : "Your child talks to their avatar by voice.\nConversations are safe, warm, and personalized."
    }

    var onboardingAdventuresTitle: String {
        self == .hebrew ? "הרפתקאות ומשימות" : "Adventures & Missions"
    }
    var onboardingAdventuresSubtitle: String {
        self == .hebrew
            ? "משימות מהנות שמעודדות סקרנות,\nיצירתיות וביטוי עצמי."
            : "Fun missions that encourage curiosity,\ncreativity, and self-expression."
    }

    var onboardingParentDashboardTitle: String {
        self == .hebrew ? "לוח בקרה להורים" : "Parent Dashboard"
    }
    var onboardingParentDashboardSubtitle: String {
        self == .hebrew
            ? "עקבו אחרי השיחות, קבלו תובנות\nוכוונו את האווטאר בזמן אמת."
            : "Follow conversations, get insights,\nand guide the avatar in real time."
    }

    var onboardingGetStarted: String {
        self == .hebrew ? "בואו נתחיל!" : "Get Started!"
    }
    var onboardingSkip: String {
        self == .hebrew ? "דלג" : "Skip"
    }
}
