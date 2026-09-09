# MaizeGuard — Feature Phases

Features from `features.md` split into logical, sequential phases. Each phase builds on the previous and has a clear gate condition before moving forward.

**Status:** `[x]` complete · `[~]` code written, not yet verified on device · `[]` not started

---

## [x] Phase 1 — Model Training & Validation
**Goal:** Produce a validated, exportable TFLite model that meets REQUIREMENTS.md targets.

| Status | Feature | Description |
|--------|---------|-------------|
| [x] | F32 | EfficientNetB3 backbone |
| [x] | F33 | 4-class classification head |
| [x] | F34 | PlantVillage dataset (4,188 images, stratified split) |
| [x] | F50 | Data augmentation |
| [x] | F51 | Class imbalance handling |
| [x] | F52 | EarlyStopping + ReduceLROnPlateau |
| [x] | F37 | Confusion matrix export |
| [x] | F35 | INT8 TFLite export |
| [x] | F36 | FP16 TFLite export |
| [x] | F48 | run_all.sh pipeline |
| [x] | F49 | Phase gate banners |

**Gate:** Accuracy ≥ 90%, F1 ≥ 0.88, INT8 latency ≤ 200 ms on target device.

---

## [~] Phase 2 — Mobile Core (Camera + Classification)
**Goal:** Working Flutter app that can scan a leaf and show a result — offline, on-device.

| Status | Feature | Description |
|--------|---------|-------------|
| [~] | F01 | On-device INT8 classification |
| [~] | F05 | GPU → CPU → FP16 model loading |
| [~] | F02 | Live camera capture with frame guide |
| [~] | F03 | Brightness feedback |
| [~] | F04 | Gallery image picker |
| [~] | F06 | Latency display |
| [~] | F07 | 4-class confidence bars |
| [~] | F29 | Model status chip on home screen |
| [~] | F30 | SQLite persistence |
| [~] | F31 | Full scan record schema |
| [~] | F26 | Dark / light theme |

**Gate:** App classifies a leaf image in < 500 ms end-to-end, saves record to DB.

---

## [~] Phase 3 — Seed Label OCR
**Goal:** Extract seed bag metadata and link it to the leaf scan.

| Status | Feature | Description |
|--------|---------|-------------|
| [~] | F08 | On-device OCR (ML Kit) |
| [~] | F09 | Fuzzy variety matching (13 Nigerian varieties) |
| [~] | F10 | Batch number extraction |
| [~] | F11 | Planting date extraction → ISO 8601 |
| [~] | F12 | Attach OCR fields to next scan |

**Gate:** OCR correctly extracts at least variety OR batch number on a sample seed bag photo.

---

## [~] Phase 4 — Farm Map & GPS
**Goal:** Pin each scan's location on an offline-capable farm map.

| Status | Feature | Description |
|--------|---------|-------------|
| [~] | F15 | GPS tagging of scans |
| [~] | F13 | OpenStreetMap tile map |
| [~] | F14 | Colour-coded disease pin markers |

**Gate:** At least 3 GPS-tagged scans visible as markers on the map.

---

## [~] Phase 5 — Analytics Dashboard & History
**Goal:** Give the farmer a clear picture of farm health over time.

| Status | Feature | Description |
|--------|---------|-------------|
| [~] | F16 | Farm Health Score arc |
| [~] | F17 | Disease breakdown bars (30 days) |
| [~] | F18 | 7-day activity bar chart |
| [~] | F19 | Scan history list with thumbnails |
| [~] | F20 | Filter by disease class |
| [~] | F21 | Delete scan record |

**Gate:** Dashboard loads and renders with real DB data; chart visible with ≥ 1 scan.

---

## [~] Phase 6 — Recommendations & AI Advisor
**Goal:** Give actionable advice, both offline (rule engine) and online (Gemini).

| Status | Feature | Description |
|--------|---------|-------------|
| [~] | F22 | On-device rule-based recommendation engine |
| [~] | F23 | Nigerian season detection |
| [~] | F24 | Gemini 2.0 Flash AI advice |
| [~] | F25 | Gemini API key in FlutterSecureStorage |
| [~] | F27 | Gemini API key management in settings |

**Gate:** Rule engine produces recommendations for all 4 classes; Gemini returns a non-empty response when a valid key is entered.

---

## [] Phase 7 — Polish & Settings
**Goal:** App is complete, stable, and configurable.

| Status | Feature | Description |
|--------|---------|-------------|
| [~] | F28 | Clear all scan data |
| [~] | F26 | Theme toggle persisted |
| [] | F38 | Phase gate validation (model meets targets on device) |

**Gate:** App passes flutter test, no compile errors, runs cleanly on Android and iOS simulator.

---

## [~] Phase 8 — UAV / Drone Integration
**Goal:** Connect a real drone, upload a mission, and map disease from aerial imagery.

| Status | Feature | Description |
|--------|---------|-------------|
| [~] | F39 | Real MAVLink connection (serial / UDP / TCP) |
| [~] | F40 | Waypoint mission upload |
| [~] | F41 | GPS telemetry streaming |
| [~] | F42 | Per-waypoint TFLite patch inference |
| [~] | F43 | Disease heatmap (KDE) |
| [~] | F44 | Flask + Socket.IO live web dashboard |
| [~] | F45 | Per-class marker clusters |
| [~] | F46 | Drone position marker |
| [~] | F47 | REST API endpoints |

**Gate:** Drone telemetry appears on live map; at least one patch classified and pinned.

---

## [~] Phase 9 — UX Refinement & Practical Deployment
**Goal:** Fix the duplicate recommendation confusion, unify the result→advice flow, add confidence gating, and add feedback collection — making the app genuinely usable for low-resource field deployment.

| Status | Feature | Description |
|--------|---------|-------------|
| [~] | F63 | Confidence gate — low-confidence banner + retake tips |
| []  | F64 | Multi-leaf scan mode — 3-leaf aggregation |
| [~] | F65 | Scan feedback — "Was this correct?" stored to DB (v2 migration) |
| [~] | F66 | Unified result + advice screen — recommendation_screen deleted |
| [~] | F67 | Single AI advice card with "AI-enhanced" source badge |
| [~] | F68 | Redesigned ResultScreen — verdict above fold, scores collapsible |
| [~] | F69 | OCR inline correction — editable Review & Correct form |
| [~] | F70 | Text-to-speech via flutter_tts — speaker button on verdict card |

**Gate:** Result screen shows diagnosis + advice in one view with no duplicate content; low-confidence scans show retake tips; feedback prompt appears after AI advice loads.

---

## [~] Phase 10 — Language & Translation
**Goal:** Farmers who are more comfortable in Yoruba, Igbo, or Hausa can read both the diagnosis result and the AI advice in their language with one setting change.

| Status | Feature | Description |
|--------|---------|-------------|
| [~] | F71 | Display language setting — English / Yoruba / Igbo / Hausa in Settings |
| [~] | F72 | AI advice generated in selected language — language instruction in prompt |
| [~] | F73 | Recommendation screen translate button — rewrites on-device advice in selected language via AI |

**Gate:** Switching to Hausa and tapping "Get AI Advice" returns the full advice in Hausa; tapping "Translate advice to Hausa" rewrites the on-device recommendation text in Hausa.

---

## [x] Phase 11 — AI Reliability (Gemini → Groq Fallback)
**Goal:** Prevent complete AI advice failure when Gemini is unavailable (no key, rate-limit, network error) by automatically retrying with Groq — transparent to the farmer.

| Status | Feature | Description |
|--------|---------|-------------|
| [x] | F74 | Gemini → Groq automatic fallback in `AiAdvisor` |
| [x] | F75 | `GROQ_API_KEY` compile-time constant via `AppEnv` |

**Gate:** With GEMINI_API_KEY intentionally blank and a valid GROQ_API_KEY in .env.json, "Get AI Advice" returns a valid response using the Groq backend.
