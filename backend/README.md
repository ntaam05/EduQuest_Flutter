# EduQuest REST API + Question parser + SignalR room game

Backend .NET 8, EF Core + SQLite. `RUN_API.bat` starts at `http://localhost:5080`; Swagger is at `http://localhost:5080/swagger`.

## Run

```powershell
dotnet restore
dotnet run
```

Requires .NET 8 SDK. First startup creates `eduquest.db`, adds compatibility fields to older room databases, and seeds sample quizzes. Back up the database before upgrades.

Demo account: `student@eduquest.local` / `Student@123`. Flutter creates one locally persisted install account per installation.

## REST API

| Method | Endpoint | Purpose |
|---|---|---|
| POST | `/api/auth/register` | Register; returns JWT |
| POST | `/api/auth/login` | Login; returns JWT |
| GET | `/api/quizzes?search=&subject=` | List quizzes with questions |
| GET | `/api/quizzes/{id}` | Quiz/options; hides correct answer before submission |
| POST | `/api/quizzes` | Create quiz and questions |
| DELETE | `/api/quizzes/{id}` | Delete eligible quiz owned by current user |
| POST | `/api/quizzes/{id}/attempts` | Begin single-player attempt |
| POST | `/api/quizzes/attempts/{attemptId}/submit` | Server-side scoring and history |
| GET | `/api/quizzes/attempts/mine` | Current user's attempt history |
| GET/PUT | `/api/profile` | Read/update profile and settings |
| GET | `/api/profile/stats` | Statistics from saved attempts |
| GET | `/api/rooms` | Active room list |
| POST | `/api/rooms` | Create room, make host a member |
| GET | `/api/rooms/code/{code}` | Find room by join code |
| GET | `/api/rooms/{id}` | Room details |
| GET | `/api/rooms/{id}/game-state` | Member-only authoritative snapshot/fallback |
| POST | `/api/rooms/join` | Join a waiting room or resume if already a member |
| POST | `/api/rooms/{id}/answers` | Submit an answer through REST fallback |
| POST | `/api/rooms/{id}/start` | Host starts server-owned round timer |
| POST | `/api/rooms/{id}/leave` | Leave waiting/finished room |
| POST | `/api/uploads/quiz-file` | Store and parse PDF/DOCX/XLSX/TXT |
| GET | `/api/uploads/mine` | Files previously uploaded by current user |

Requests for protected endpoints need `Authorization: Bearer <token>`. JSON keys use `snake_case`.

## Real-time room rules

SignalR hub: `/hubs/rooms`. Client-to-server methods: `JoinRoom`, `SubmitAnswer`, `LeaveRoom`. Server events: `RoomUpdated`, `QuestionStarted`, `RoundProgress`, `QuestionResult`, `GameFinished`.

The host selects a quiz, then starts the game. Each question remains open for 20–30 seconds (default 25). The server starts/stops timers, enforces a single answer per user/question, calculates points and stores each answer. During the answer window only the question/options and aggregate answer count are emitted; correctness, points, and updated ranking are withheld until the timer closes. The result event includes the correct answer, per-round points and cumulative leaderboard. Results remain visible for 5 seconds before the next question begins. Scores and answers persist in `RoomAnswers`/`RoomMembers`, and a worker continues transitions even if no client remains connected.

Points are awarded only for correct answers: 1,000 points near the start of the window, decaying linearly to at least 100 by the end. Incorrect or absent answers award 0.

## Document parser

- TXT: UTF-8 text extraction.
- DOCX: extracts paragraphs from `word/document.xml`.
- PDF: extracts text using PdfPig; image-only/scanned PDFs need OCR before upload.
- XLSX: reads the first worksheet; expects columns such as `Câu hỏi`, `A`, `B`, `C`, `D`, `Đáp án`, `Giải thích`.
- Structured text questions need one `Câu 1:`/`Question 1:` line, individual `A.`, `B.` etc option lines and a clear `Đáp án: B`/`Correct answer: B` line. See `../samples/mau_cau_hoi.txt`.
- If formatted questions do not exist, a conservative definition extractor can create question options from term-definition lines. Every such quiz includes a warning for human review. If the key cannot be identified confidently, the file remains a draft instead of inventing answers.

## Production hardening

Defaults are for local development/academic projects. Before public deployment, rotate `Jwt:Key`, use HTTPS, restrict CORS, add rate limiting and upload scanning, back up SQLite, and run build/API tests. The current environment has no .NET or Flutter SDK, so this source bundle has not been end-to-end compiled here.
