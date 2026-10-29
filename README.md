
# OVERSHARE 🛡️
> *"Before You Share It, Know What It Reveals."*

**OVERSHARE** is an on-device privacy scanner and automated redaction app for Android. Built with Flutter, it empowers users to safely share screenshots and documents by detecting private identifiers, scoring exposure risk according to sharing context, burning irreversible pixel redactions directly into image files, and completely purging EXIF metadata.

---

## 🔒 Privacy Audit Results & Data Handling

OVERSHARE is engineered around verified, zero-compromise privacy principles:

| Privacy Boundary | What Leaves the Device? | What is Stored Locally? | What is Logged? |
|:---|:---|:---|:---|
| **Core On-Device Engine** (Default) | **ABSOLUTELY NOTHING**. Detection, decision rules, risk scoring, and pixel redactions execute 100% locally on the device CPU/GPU. | Only **masked previews** (e.g. `•••• 4444`, `s****@domain.com`), aggregate categories, timestamps, purpose, and before/after exposure scores in a local SQLite database. | Zero external analytics, tracking IDs, or telemetry. |
| **Optional AI Advisor** (Off by Default) | **Only abstract metadata**: Finding category names (e.g. `"Payment Card Number"`), confidence scores (`0.95`), sharing purpose, and audience. **NEVER** transmits images, pixels, raw text, or file paths. | Optional advisory summary in local SQLite `ai_advice` table. | Request validation and rate limit metrics on the self-hosted proxy. |
| **Image Retention** (Strictly Opt-in) | **Never leaves device**. | If explicitly enabled by the user, retained in app-private storage with an immediate delete control. Deleting a scan record permanently unlinks and physically shreds the file. | Audit confirmation of file deletion. |

---

## 📱 Platform Support Matrix

| Platform | Verification Status | Features Supported | Limitations & Fallback Behavior |
|:---|:---|:---|:---|
| **Android** | **Primary Verified Target** (API 21+) | 100% Full Feature Support: ML Kit OCR, ML Kit Face Detection, SQLite Relational History, Raw Pixel Redaction, Gallery/MediaStore Export (`gal`), EXIF Purging. | None. Target deployment platform. |
| **iOS** | Compatible Architecture | ML Kit OCR, Face Detection, SQLite, Pixel Redaction. | Requires iOS camera/photo library usage descriptions in `Info.plist`. |
| **Web** | Limited Mode (Best-Effort) | Manual canvas drag-to-redact, decision rules, risk scoring, in-memory pixel redaction, AI Advisor via proxy. | **Limited Mode**: Google ML Kit OCR and Face Detection are mobile-only native binaries. SQLite history is disabled on web with a clear notification banner: *"Web Mode — History Disabled: Processing is on-device and in-memory only."* |
| **Desktop / Unit Tests** | Automated CI / Headless | SQLite FFI (`sqflite_common_ffi`), Pure Dart pattern detector, decision rules, risk scorer, pixel redaction buffer. | ML Kit platform channels mockable for CI tests. |

---

## 🏛️ Architecture & Folder Structure

OVERSHARE adheres to a modular, feature-first clean architecture:

```text
lib/
├── core/
│   ├── app_state.dart             # Global Riverpod state (selected image, purpose, audience)
│   ├── purpose.dart               # SharingPurpose & Audience enum definitions
│   └── theme.dart                 # Material 3 theme definitions (Dark mode identity)
└── features/
    ├── import/                    # Ingestion & Home Screen
    │   ├── home_screen.dart       # Welcome screen, privacy banner, gallery picker, history link
    │   └── preview_screen.dart    # Image verification before analysis
    ├── scanner/                   # Detection Engine
    │   ├── models/                # BoundingBox, Finding, OcrLine, SensitiveType
    │   ├── luhn_checker.dart      # Mod-10 Luhn checksum algorithm for payment cards
    │   ├── face_detector_service.dart # ML Kit on-device face detector
    │   ├── ocr_service.dart       # Abstract OCR interface (ML Kit & test mocks)
    │   ├── pattern_detector.dart  # Pure Dart regex pattern matching & substring interpolation
    │   └── scanner_providers.dart # Riverpod async scanning pipeline
    ├── decision/                  # Decision Engine & Risk Scoring
    │   ├── purpose.dart           # Purpose & Audience definitions
    │   ├── rules_table.dart       # Matrix mapping (SensitiveType × Purpose × Audience) -> Action
    │   ├── recommendation.dart    # Generates KEEP / HIDE / OPTIONAL / BLUR FACE recommendations
    │   ├── risk_scorer.dart       # Explainable 0-100 Privacy Exposure Score & itemized breakdown
    │   ├── purpose_screen.dart    # Interactive purpose & audience selector
    │   └── decision_providers.dart# Reactive decision state providers
    ├── advisor/                   # Optional AI Advisor (Off by Default)
    │   ├── models/ai_advice.dart  # AiFindingAdvice, AiAdvisorResponse
    │   ├── advisor_service.dart   # Privacy-sanitized proxy client & assertion validator
    │   ├── advisor_providers.dart # Riverpod async advisor notifier (off by default)
    │   └── ai_consent_dialog.dart # Explicit user consent and privacy invariant modal
    ├── review/                    # Interactive Review & Before/After
    │   ├── models/                # ReviewState, FindingReviewItem, RedactionRegion
    │   ├── coordinate_converter.dart # Precise aspect-ratio letterbox coordinate converter
    │   ├── redaction_overlay_painter.dart # CustomPainter overlay for highlighted regions
    │   ├── review_notifier.dart   # Interactive toggle state & manual box manager
    │   ├── review_screen.dart     # Interactive canvas with drag-to-redact, AI Advisor, score breakdown
    │   ├── results_screen.dart    # Risk score card, breakdown list, and purpose switcher
    │   └── before_after_screen.dart# Slider, side-by-side, flip comparison & residual exposure report
    ├── redaction/                 # Redaction & Export Engine
    │   ├── redaction_service.dart # Raw pixel buffer mutation (solid black / heavy mosaic)
    │   ├── metadata_service.dart  # EXIF reader & metadata eradication verifier
    │   ├── export_service.dart    # Safe non-destructive disk export & sharing
    │   ├── redaction_providers.dart# Export state machine & residual score recalculation
    │   └── safe_copy_screen.dart  # Style choice, EXIF summary, and export flow
    └── history/                   # Relational Masked History Database
        ├── models/                # ScanRecord, FindingRecord, RedactionRecord, AiAdviceRecord
        ├── history_repository.dart# Repository interface (Sqflite, Web, InMemory)
        ├── history_database.dart  # SQLite schema v2, migrations, foreign key cascades & indexes
        ├── history_providers.dart # Riverpod history notifier
        └── history_screen.dart    # Audit log screen (details sheet, delete one, clear all)
```

---

## 🗄️ Database Schema (Version 2)

The local SQLite database (`overshare_history.db`) uses schema version 2 with foreign key constraints, cascading deletes, and performance indexes:

```sql
PRAGMA foreign_keys = ON;

-- 1. Scans Table
CREATE TABLE scans (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  createdAt TEXT NOT NULL,
  purpose TEXT NOT NULL,
  audience TEXT NOT NULL,
  originalScore INTEGER NOT NULL,
  sanitizedScore INTEGER NOT NULL,
  status TEXT NOT NULL,
  verificationStatus TEXT NOT NULL,
  retainedImagePath TEXT
);

-- 2. Findings Table (Stores masked previews only; never raw text)
CREATE TABLE findings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  scanId INTEGER NOT NULL,
  type TEXT NOT NULL,
  maskedPreview TEXT NOT NULL,
  x REAL NOT NULL,
  y REAL NOT NULL,
  w REAL NOT NULL,
  h REAL NOT NULL,
  confidence REAL NOT NULL,
  recommendation TEXT NOT NULL,
  reason TEXT NOT NULL,
  userAction TEXT NOT NULL,
  source TEXT NOT NULL,
  FOREIGN KEY (scanId) REFERENCES scans(id) ON DELETE CASCADE
);

-- 3. Redactions Table
CREATE TABLE redactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  scanId INTEGER NOT NULL,
  findingId INTEGER,
  style TEXT NOT NULL,
  applied INTEGER NOT NULL,
  verified INTEGER NOT NULL,
  FOREIGN KEY (scanId) REFERENCES scans(id) ON DELETE CASCADE
);

-- 4. Optional AI Advice Table
CREATE TABLE ai_advice (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  scanId INTEGER NOT NULL,
  findingId INTEGER,
  summary TEXT NOT NULL,
  model TEXT NOT NULL,
  createdAt TEXT NOT NULL,
  FOREIGN KEY (scanId) REFERENCES scans(id) ON DELETE CASCADE
);

-- Indexes for optimal cascading and queries
CREATE INDEX idx_findings_scan_id ON findings(scanId);
CREATE INDEX idx_redactions_scan_id ON redactions(scanId);
CREATE INDEX idx_ai_advice_scan_id ON ai_advice(scanId);
```

### v1 -> v2 Migration
When upgrading from legacy schema v1 (`scan_history`), the database automatically executes `migrateV1ToV2`:
- Creates the version 2 tables and indexes.
- Migrates flat `scan_history` records into `scans` with `legacy_migrated` status without data loss.

---

## 🤖 AI Configuration: `gemini-2.5-flash-lite`

### Model Selection Rationale
Before integrating an LLM, official documentation was consulted regarding capabilities, cost, latency, and data privacy:
- **Model**: Google `gemini-2.5-flash-lite`.
- **Capabilities**: Native JSON Structured Outputs (`responseMimeType: "application/json"` with schema validation). Strictly guarantees schema conformity with no hallucinated fields.
- **Cost**: \$0.10 / 1M input tokens, \$0.40 / 1M output tokens (Free tier in Google AI Studio). Typical advisory query uses < 200 input tokens (< \$0.00006 per call).
- **Latency**: Sub-second response time (~400–600ms) for an interactive UI.
- **Enterprise Privacy**: Prompts and completions under paid/enterprise terms are **never** used to train models.

### Backend Proxy (`server/`)
To protect API keys from extraction via reverse engineering:
- The mobile app contains **no API keys**.
- A lightweight Node.js proxy (`server/`) receives requests, enforces rate limits (`express-rate-limit`: 60 req/15 min), and performs strict payload validation:
  - Requests containing `image`, `bytes`, `rawText`, or unexpected fields are rejected immediately with `400 Bad Request`.
  - The proxy queries Gemini and returns sanitized JSON.
  - If no `GEMINI_API_KEY` is provided, the proxy falls back to an offline deterministic mock for local development and testing.

---

## 🛠️ Setup & Running

### Prerequisites
- Flutter SDK (v3.13+ or v3.47+ stable)
- Android SDK (API 21+)
- Node.js (v18+) *optional, for local AI proxy*

### 1. Flutter Dependencies
```bash
flutter pub get
```

### 2. Static Code Analysis
```bash
flutter analyze
```

### 3. Automated Test Suite (96 Tests)
```bash
flutter test
```
The test suite covers:
- Pattern detection precision & false positive avoidance (Cards, UPI, Aadhaar, PAN, Emails, Phones, Accounts)
- Luhn mod-10 card checksum validator
- Decision engine matrix coverage across all purposes and audiences
- Consistency invariants (asserting no finding is `KEEP` while reason states it exposes private data)
- Explainable risk scorer and point caps (0–100 bounds)
- Relational SQLite CRUD, foreign keys `ON DELETE CASCADE`, and `v1 -> v2` schema migrations
- Image retention physical file deletion
- Web mode unsupported fallback banners
- AI Advisor privacy payload sanitizer, rejection of forbidden keys, and resilience against server errors/timeouts
- Review screen interactive canvas, score breakdown sheet, and live audience switching
- Post-export residual exposure report on before/after comparison screen

### 4. Build Debug Android APK
```bash
flutter build apk --debug
```

### 5. Build Web Target
```bash
flutter build web
```

### 6. (Optional) Run Local AI Proxy Server
```bash
cd server
npm install
cp .env.example .env
# Add GEMINI_API_KEY in .env if live Gemini advisory is desired
npm start
```

---

## 🧪 Manual Verification Steps

1. **Launch App**: Open OVERSHARE on Android device or emulator.
2. **Select Image**: Tap **Select Screenshot** from the home screen and choose a receipt, document, or chat screenshot.
3. **Choose Purpose & Audience**: Select a purpose (e.g. `Payment proof`) and audience (`Private Recipient`). Notice how purpose-specific subtitles describe what is kept vs hidden.
4. **Interactive Review**:
   - Verify detected boxes: Payment card is marked `HIDE` (red), transaction ID is marked `KEEP` (green).
   - Tap any box on the canvas or in the list to toggle between `HIDE` and `KEEP`. Notice the **Exposure Score** updates in real-time.
   - Tap the score pill: The **Privacy Exposure Breakdown** bottom sheet opens showing itemized points and explanations.
   - Tap the **Audience Pill** in the top bar to toggle between `Private` and `Public`: Notice recommendations adapt live.
   - Drag anywhere on the canvas to draw a **Manual Redaction Box**. Tap the undo icon in the AppBar to remove it.
5. **Optional AI Advisor**:
   - Toggle **AI Privacy Advisor**: The consent dialog appears explaining what is sent (categories only) vs what is never sent (no images, no raw text).
   - Tap **Agree & Enable**: The `AI ADVISOR (ADVISORY ONLY)` card renders contextual explanations and clarifying questions.
6. **Export Safe Copy**:
   - Tap **Create safe copy**. Choose between **Heavy Pixelation** and **Solid Fill**.
   - Tap **Generate & Export Safe Copy**: The app burns pixels directly into the buffer, strips all EXIF metadata, and saves to a brand-new file.
7. **Before & After Comparison**:
   - Explore the **Draggable Slider**, **Side by Side**, and **Tap to Flip** comparison views.
   - Inspect the **Post-Export Residual Exposure Report**: Verifies `Zero residual exposure (0/100)`, raw pixel buffer mutation, and EXIF metadata purging.
8. **Masked History**:
   - Navigate to **Scan History**.
   - Tap a scan card: The **Masked History Audit** sheet displays the scan's masked audit trail (`•••• 4444`).
   - Tap the delete icon to remove a single scan, or tap the sweep icon to clear all history.

---

## ⚠️ Known Limitations

1. **OCR Environment**: Google ML Kit OCR performs best on high-contrast digital text and screenshots. Severely blurred photos, heavy distortion, or low-resolution scans may result in missed characters.
2. **Web Target Limitations**: Google ML Kit OCR and Face Detection rely on native Android/iOS libraries and are unavailable on Web. In Web mode, OVERSHARE provides manual canvas drag-to-redact and disables SQLite history with an in-memory session.
3. **Supported Formats**: Static raster images (`.png`, `.jpg`, `.jpeg`, `.webp`). Animated GIFs, video recordings, and multi-page PDF documents are currently out of scope.
=======
# OVERSHARE

