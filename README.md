# Avatar

חבר AI לילדים — אפליקציית iOS דוברת עברית עם אווטאר אינטראקטיבי שמוביל ילדים דרך הרפתקאות נושאיות, שיחות קוליות ומיני-משחק תלת-ממדי.

האפליקציה משלבת מודלי שפה (Claude), זיהוי דיבור (Whisper) והקראה בקול (OpenAI TTS) כדי לייצר חוויית שיחה טבעית בזמן אמת, עם דשבורד הורים למעקב, הכוונה והתאמה אישית.

## ארכיטקטורה

המערכת מורכבת משני חלקים:

- **`Avatar/`** — אפליקציית iOS ב-Swift / SwiftUI (יעד iOS עיקרי)
- **`avatar-backend/`** — שרת Node.js (Fastify + Prisma + PostgreSQL) שמשרת את האפליקציה

תקשורת בין הלקוח לשרת מתבצעת ב-REST + WebSocket (Socket.IO) להזרמת הודעות בזמן אמת. התראות Push נשלחות דרך Firebase Cloud Messaging.

## תכונות עיקריות

### שיחות והרפתקאות
- הרפתקאות מבוססות-נרטיב עם התקדמות בסצנות (בחירה, שיחה קולית, חגיגה, מיני-משחק)
- 15+ נושאי הרפתקה: חלל, מתחת לים, יער, דינוזאורים, גיבורי-על, בישול, פיראטים, אגדות, הצלת חיות, מוזיקה, ריקוד, ספורט, ועוד
- איסוף כוכבים ופריטי-אספנות (אימוג'י) לאורך הסצנות
- שיחות קוליות חיות עם האווטאר (STT → Claude → TTS)

### מיני-משחק: Temple Run
משחק רץ אינסופי תלת-ממדי בנוי ב-**SceneKit** עם דמות Mixamo אנימטיבית שעליה רוכב הפנים של האווטאר.

- **3 מסלולים** — החלקה ימינה/שמאלה למעבר בין מסלולים
- **קפיצה** (swipe למעלה) מעל מכשולים נמוכים, **גלישה** (swipe למטה) מתחת ל-banners תלויים
- מטבעות לאיסוף לאורך המסלול (כל מטבע = 3 נקודות), ונקודות מרחק
- מכשולים רנדומליים: סלעים, banners, עמודים
- סיום משחק בהתנגשות או בסיום הזמן
- 3 רמות קושי שמתאימות את עצמן לפי גיל הילד והסבב הנוכחי (זמן, מהירות, צפיפות מכשולים)
- סגנון חזותי: שקיעה חמה, מסלול אבן, חומות ירוקות עם עצים

### תוכן חינוכי
מערכת `EducationalContent` מייצרת אתגרי שאלות מותאמי גיל ושפה: אותיות עברית, מילים בעברית עם רמזי אימוג'י, אותיות ומילים באנגלית, חישובי מתמטיקה. (מוכן ככלי משותף לשילוב במשחקים ובהרפתקאות.)

### צד ההורה
- דשבורד עם סטטוס שיחות, סיכומים והודעות
- שאלות מותאמות שההורה יכול לבקש שהאווטאר ישאל
- אפשרות התערבות חיה בשיחה
- **כרטיסי הנחיה** — ההורה יכול ליצור הוראות מותאמות אישית לילד (לדוגמה: "תקח שלוש נשימות אם אתה מתוסכל", "תאכל חטיף לפני המשחק")
- התראות Push (Firebase Cloud Messaging) למצבים שדורשים תשומת לב

## מבנה הפרויקט

### iOS (`Avatar/`)
```
Avatar/
├── AvatarApp.swift          # נקודת כניסה
├── AvatarEngine/            # אנימציית אווטאר
├── Core/                    # ניווט, ערכת נושא, תשתית
├── Models/                  # User, Child, Mission, Conversation,
│                            # MiniGameConfig, EducationalContent,
│                            # ParentGuidance, AdventureState...
├── Resources/
│   ├── Fonts/
│   ├── Sounds/
│   └── art.scnassets/       # נכסי SceneKit למשחק התלת-ממדי
├── ViewModels/
├── Views/
│   ├── Auth/                # התחברות Firebase + Google
│   ├── Child/               # מסך הילד: בית, הרפתקאות, שיחה
│   │   └── Games/
│   │       ├── TempleRunGameView.swift      # המשחק (SceneKit)
│   │       ├── MiniGameContainerView.swift  # HUD + countdown + score
│   │       └── GameThemeConfig.swift
│   ├── Onboarding/          # יצירת פרופיל ואווטאר
│   └── Parent/              # דשבורד, מוניטור חי, הנחיות הורה
└── Services/
    ├── Auth/                # Firebase Auth + סנכרון JWT עם הבקנד
    ├── Audio/               # הקלטה, השמעה, VAD
    ├── Network/             # REST + WebSocket + OpenAI
    ├── Notifications/       # PushNotificationManager (FCM)
    └── Storage/
```

### Backend (`avatar-backend/`)
```
avatar-backend/
├── src/
│   ├── index.ts
│   ├── routes/              # auth, children, avatars, missions,
│   │                        # conversations, questions, devices, guidance
│   └── services/            # ConversationEngine (Claude),
│                            # VoicePipeline (Whisper + TTS),
│                            # SummaryEngine, NotificationService
├── prisma/
│   └── schema.prisma        # User, Child, Avatar, MissionTemplate,
│                            # Conversation, Message, AdventureProgress...
└── package.json
```

## Stack טכנולוגי

**iOS:** Swift, SwiftUI, **SceneKit** (למשחק), AVFoundation, Firebase Auth & Messaging

**Backend:** Node.js 20+, Fastify, Prisma, PostgreSQL, Socket.IO, Firebase Admin

**AI:** Anthropic Claude (שיחה), OpenAI Whisper (STT), OpenAI TTS HD (הקראה)

**אנימציה:** דמויות Mixamo (running, jump, slide, death) על מסלול תלת-ממדי

## הקמת סביבת פיתוח

### דרישות מקדימות
- Xcode 15+ (ל-iOS)
- Node.js 20+ ו-npm
- PostgreSQL רץ מקומית (או DATABASE_URL לשרת מרוחק)
- מפתחות API ל-Anthropic ו-OpenAI
- פרויקט Firebase עם Google Sign-In ו-Cloud Messaging מופעלים

### Backend
```bash
cd avatar-backend
cp .env.example .env          # ערוך את הקובץ ומלא את המפתחות
npm install
npm run prisma:migrate        # יוצר את הסכימה ב-DB
npm run dev                   # מפעיל בפורט 3000 עם hot reload
```

משתני סביבה חשובים (ראה `.env.example`):
`DATABASE_URL`, `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `JWT_SECRET`, `JWT_REFRESH_SECRET`, `PORT`, `CORS_ORIGIN`, `UPLOAD_DIR`

### iOS
1. פתח את `Avatar.xcodeproj` ב-Xcode
2. ודא שקובץ `GoogleService-Info.plist` מעודכן עם פרויקט ה-Firebase שלך
3. עדכן את ה-base URL של הבקנד ב-`Avatar/Services/Network/`
4. Build & Run על סימולטור או מכשיר

## סקריפטים שימושיים (Backend)

| פקודה | תיאור |
|------|------|
| `npm run dev` | פיתוח עם tsx watch |
| `npm run build` | קומפילציה + Prisma generate |
| `npm start` | הרצת production מתוך `dist/` |
| `npm run prisma:studio` | GUI למסד הנתונים |
| `npm run typecheck` | בדיקת טיפוסים בלבד |
| `npm run lint` | ESLint |

## לוקליזציה

האפליקציה תומכת בעברית (RTL) ובאנגלית. תוכן ההרפתקאות, הוראות המשחק והקראת ה-TTS מותאמים לעברית כברירת מחדל.
