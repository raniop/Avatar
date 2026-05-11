# Avatar

חבר AI לילדים — אפליקציית iOS דוברת עברית עם אווטאר אינטראקטיבי שמוביל ילדים דרך הרפתקאות נושאיות, שיחות קוליות ומיני-משחקים.

האפליקציה משלבת מודלי שפה (Claude), זיהוי דיבור (Whisper) והקראה בקול (OpenAI TTS) כדי לייצר חוויית שיחה טבעית בזמן אמת, עם דשבורד הורים למעקב והכוונה.

## ארכיטקטורה

המערכת מורכבת משני חלקים:

- **`Avatar/`** — אפליקציית iOS ב-Swift / SwiftUI (יעד iOS עיקרי)
- **`avatar-backend/`** — שרת Node.js (Fastify + Prisma + PostgreSQL) שמשרת את האפליקציה

תקשורת בין הלקוח לשרת מתבצעת ב-REST + WebSocket (Socket.IO) להזרמת הודעות בזמן אמת.

## תכונות עיקריות

### שיחות והרפתקאות
- הרפתקאות מבוססות-נרטיב עם התקדמות בסצנות (בחירה, שיחה קולית, חגיגה, מיני-משחק)
- 15+ נושאי הרפתקה: חלל, מתחת לים, יער, דינוזאורים, גיבורי-על, בישול, פיראטים, אגדות, הצלת חיות, מוזיקה, ריקוד, ספורט, ועוד
- איסוף כוכבים ופריטי-אספנות (אימוג'י) לאורך הסצנות
- שיחות קוליות חיות עם האווטאר (STT → Claude → TTS)

### מיני-משחקים (SpriteKit)
ארבעה משחקים עם שלוש רמות קושי כל אחד, מותאמים לגיל הילד:
1. **Football Kick** — בעיטה אל מטרות עם האות/תשובה הנכונה
2. **Basketball Shoot** — קליעה לסל עם תשובות נכונות
3. **Car Race** — איסוף פריטים נכונים תוך כדי נסיעה
4. **Simon Pattern** — חזרה על רצפי צבעים/אימוג'י (משחק זיכרון)

### צד ההורה
- דשבורד עם סטטוס שיחות, סיכומים והודעות
- שאלות מותאמות שההורה יכול לבקש שהאווטאר ישאל
- אפשרות התערבות חיה בשיחה
- התראות Push למצבים שדורשים תשומת לב

## מבנה הפרויקט

### iOS (`Avatar/`)
```
Avatar/
├── AvatarApp.swift          # נקודת כניסה
├── AvatarEngine/            # מנוע המיני-משחקים (SpriteKit)
├── Core/                    # תשתית בסיסית
├── Models/                  # User, Child, Mission, Conversation, AdventureState...
├── ViewModels/
├── Views/
│   ├── Auth/                # התחברות Firebase + Google
│   ├── Child/               # מסך הילד: בית, הרפתקאות, שיחה, משחקים
│   ├── Onboarding/          # יצירת פרופיל ואווטאר
│   └── Parent/              # דשבורד הורה
└── Services/
    ├── Auth/                # Firebase Auth + סנכרון JWT עם הבקנד
    ├── Audio/               # הקלטה, השמעה, VAD
    ├── Network/             # REST + WebSocket
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

**iOS:** Swift, SwiftUI, SpriteKit, Firebase Auth, AVFoundation

**Backend:** Node.js 20+, Fastify, Prisma, PostgreSQL, Socket.IO, Firebase Admin

**AI:** Anthropic Claude (שיחה), OpenAI Whisper (STT), OpenAI TTS HD (הקראה)

## הקמת סביבת פיתוח

### דרישות מקדימות
- Xcode 15+ (ל-iOS)
- Node.js 20+ ו-npm
- PostgreSQL רץ מקומית (או DATABASE_URL לשרת מרוחק)
- מפתחות API ל-Anthropic ו-OpenAI
- פרויקט Firebase עם Google Sign-In מופעל

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

האפליקציה תומכת בעברית (RTL) ובאנגלית. תוכן ההרפתקאות, הוראות המשחקים והקראת ה-TTS מותאמים לעברית כברירת מחדל.
