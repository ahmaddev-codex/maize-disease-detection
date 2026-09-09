# MaizeGuard — Features

All features of the MaizeGuard platform across mobile, backend, model, and UAV.

**Status:** `[x]` complete & verified · `[~]` code written, device-test pending · `[]` not started

---

## Mobile App (Flutter)

### Core Classifier
- [x] F01 — On-device EfficientNetB3 INT8 leaf disease classification (NCLB / Rust / GLS / Healthy)
- [x] F02 — Live camera capture with green corner-frame overlay guide
- [x] F03 — Brightness feedback (too dark / too bright) via luma histogram sampling
- [x] F04 — Gallery image picker as alternative scan input
- [x] F05 — GPU delegate → CPU fallback → FP16 fallback model loading chain
- [x] F06 — Inference latency displayed in milliseconds on result screen
- [x] F07 — 4-class confidence bar chart on result screen

### Seed Label OCR
- [x] F08 — On-device OCR via Google ML Kit (no internet required)
- [x] F09 — Fuzzy crop variety matching against 13 Nigerian varieties
- [x] F10 — Regex batch number extraction (BN-YYYY-NNN / LOT# / BATCH NO: patterns)
- [x] F11 — Multi-pattern planting date extraction → ISO 8601
- [x] F12 — Attach OCR fields to next scan (links seed label metadata to leaf scan)
- [x] F59 — OCR crop variety passed to AI advisor (was previously hardcoded null)

### Farm Map
- [x] F13 — OpenStreetMap tile map (no API key; works offline with cached tiles)
- [x] F14 — Disease pin markers with colour-coded icons per class
- [x] F15 — GPS tagging of each scan using device location
- [x] F57 — Tap a map pin to view disease detail card (disease, confidence, GPS, variety, date)

### Dashboard & Analytics
- [x] F16 — Farm Health Score (arc indicator, 0–100%)
- [x] F17 — Disease breakdown progress bars (last 30 days)
- [x] F18 — 7-day scan activity bar chart (fl_chart, gradient bars)
- [x] F56 — Farm health trend indicator — compares healthy% in last 7 days vs prior 7 days; shows Improving / Stable / Worsening

### History
- [x] F19 — Scan history cards with hero image thumbnail, disease dot, class label, confidence badge, date
- [x] F20 — Filter chips by disease class (NCLB / Rust / GLS / Healthy / All)
- [x] F21 — Long-press card to open action sheet: Add/Edit Notes + Delete
- [x] F58 — Per-scan notes — saved to SQLite, rendered inline in card with purple tint

### AI Advisor
- [x] F22 — On-device rule-based recommendation engine (urgency label, season, treatment steps)
- [x] F23 — Nigerian farming season detection (main Apr–Jul / off Aug–Nov / dry Dec–Mar)
- [x] F24 — Gemini 2.0 Flash AI agronomic advice (production backend; requires API key)
- [x] F25 — Gemini API key stored in FlutterSecureStorage (never leaves device)
- [x] F60 — Ollama local AI backend for development (auto-selected in debug builds via `kDebugMode`; no API key needed)

### Settings & UX
- [x] F26 — Dark / light theme toggle (persisted to SharedPreferences)
- [x] F27 — Gemini API key save / clear in settings (visible when Gemini backend is active)
- [x] F28 — Clear all scan data with confirmation dialog and spinner guard (no blank screen)
- [x] F29 — Model status chip on home screen (loading / GPU / CPU / FP16)
- [x] F54 — Floating glassmorphic pill bottom navigation bar with animated duotone icons

### Design System (`lib/widgets/ds.dart`)
- [x] F55 — Shared design tokens: `AppSpacing`, `AppRadius`, `AppDuration`
- [x] F55a — `GlassCard` — `ClipRRect + BackdropFilter + Container` with unified shadow
- [x] F55b — `DuotoneIcon` — `Stack` of glow icon + `ShaderMask` gradient icon
- [x] F55c — `StatChip`, `SectionLabel`, `BulletCard`, `DiseaseDot`, `EmptyState`

### Data Persistence
- [x] F30 — SQLite database via sqflite (`scan_records` table)
- [x] F31 — All REQUIREMENTS.md columns stored: image_path, class_id, class_name, confidence, all_scores, latency_ms, latitude, longitude, crop_variety, batch_number, planting_date, scanned_at, notes

---

## Machine Learning Model

- [x] F32 — EfficientNetB3 backbone pretrained on ImageNet
- [x] F33 — 4-class head: NCLB, Common Rust, Grey Leaf Spot, Healthy
- [x] F34 — PlantVillage dataset: 4,188 images, stratified 80/10/10 split
- [x] F35 — INT8 quantisation (~13 MB model, <50 ms on mid-range Android)
- [x] F36 — FP16 quantisation (fallback for devices without INT8 support)
- [x] F37 — Confusion matrix export after training
- [x] F38 — Phase gate validation: ≥90% accuracy, F1 ≥ 0.88, latency ≤ 200 ms

---

## UAV / Drone Integration

- [~] F39 — Real MAVLink drone connection (serial / UDP / TCP) via pymavlink
- [~] F40 — Mission waypoint upload to drone (QGC .waypoints format)
- [~] F41 — GPS telemetry streaming (lat, lon, alt, heading, battery)
- [~] F42 — Per-waypoint patch inference using TFLite model
- [~] F43 — Disease heatmap generation using KDE on GPS coordinates
- [~] F44 — Flask + Socket.IO live web dashboard (Leaflet.js)
- [~] F45 — Per-class marker clusters on live map
- [~] F46 — Real-time drone position marker with heading indicator
- [~] F47 — REST API: POST /telemetry, POST /patch, GET /api/patches

---

## Training Pipeline

- [x] F48 — run_all.sh: end-to-end pipeline (data prep → train → evaluate → export)
- [x] F49 — Phase gate banners printing all REQUIREMENTS.md targets
- [x] F50 — Data augmentation: flip, rotate, brightness, contrast, zoom
- [x] F51 — Class imbalance handling: weighted loss or oversampling
- [x] F52 — EarlyStopping + ReduceLROnPlateau callbacks
- [x] F53 — TFLite export (INT8 + FP16) after training

---

## UX Refinement & Practical Deployment

### Confidence & Diagnosis Quality
- [~] F63 — Confidence gate: if top-class score < 60%, a warning banner appears above the verdict card with retake tips (lighting, framing, distance); full result still shown below
- [] F64 — Multi-leaf scan mode: scan 3 leaves in one session, aggregate predictions (modal class + averaged confidence), show a summary card before committing the record
- [~] F65 — Scan feedback loop: "Was this diagnosis correct?" (Yes / No / Unsure) appears after AI advice loads; answer stored in DB `feedback` column (v2 migration); confirmed with a thank-you message

### Unified Recommendation Flow
- [~] F66 — ResultScreen is the unified screen: verdict card + on-device recommendation sections + inline AI advice in one scrollable view; `recommendation_screen.dart` and `ai_advice_sheet.dart` deleted; `/recommendation` now aliases `/result`
- [~] F67 — Single AI advice card with "AI-enhanced" source badge; on-device sections shown first with no duplicate treatment/prevention lists; AI card loads in-place below them
- [~] F68 — Redesigned ResultScreen: verdict card above the fold (disease name, urgency label, confidence + latency); "About this disease" and "Class scores" are collapsible cards at the bottom

### OCR Improvements
- [~] F69 — OCR inline correction: "Review & Correct" section shows editable TextFields pre-filled with OCR output; corrected values (not raw OCR) are attached to the next scan

### Accessibility
- [~] F70 — Text-to-speech: English → device TTS (`flutter_tts ^4.0.2`); Yoruba / Igbo / Hausa → YarnGPT API (`yarn_tts_service.dart`) with language-appropriate voices (Idera / Chinenye / Zainab); speaker icon on verdict card shows spinner while API loads, stop icon while playing; priority: translated sections → AI advice → English verdict fallback

### Language & Translation
- [~] F71 — "Display language" setting: English / Yoruba / Igbo / Hausa — persisted to SharedPreferences, selectable from Settings
- [~] F72 — AI advice generated in the selected display language — language instruction added to the Gemini/Groq/Ollama prompt so the full response arrives in the farmer's language
- [~] F73 — Recommendation screen translation: when a non-English display language is selected, a "Translate advice" button calls AI to rewrite the on-device recommendation text in the chosen language; translated text appears below the English content for that session

---

## AI Reliability

### Gemini → Groq Fallback
- [x] F74 — Groq as automatic fallback: in release builds, if Gemini fails for any reason (no key, rate-limit, network error, non-200 response), AiAdvisor automatically retries the same prompt against Groq (`llama-3.3-70b-versatile`) before surfacing an error to the user — zero extra user interaction required
- [x] F75 — GROQ_API_KEY in AppEnv: compile-time constant injected via `--dart-define-from-file=.env.json`; baked into the release build so farmers do not need to manage a second API key
