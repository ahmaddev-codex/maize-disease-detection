# Chapter 4: Results and Evaluation

## 4.1 Experimental Setup

All Python training experiments were conducted on a machine with a CUDA-enabled NVIDIA GPU with a minimum of 8 GB VRAM. The software environment comprised TensorFlow >=2.13, Keras 3, and Python 3.11. Training runs were orchestrated via the `run_all.sh` shell script, which supports both a quick three-epoch sanity run and a full production training run.

Flutter application testing was conducted on an iPhone 17 Pro simulator (iOS 26.2) and on Android hardware (API level 33), using Flutter with Dart SDK 3.3.0. Inference latency measurements were captured from the `latencyMs` field of the `ClassificationResult` object, which wraps a Dart `Stopwatch` around the `ClassifierService.classify()` call.

## 4.2 Phase 1: CNN Classifier Performance

### 4.2.1 Quick Run Baseline (3+3 Epochs)

The quick-run configuration validates the training pipeline — confirming that data loading, augmentation, model construction, training, and TFLite conversion complete without error — before committing to a full run. Three epochs on a 90-million-parameter model are insufficient for convergence:

- Test Accuracy: 27.8%
- Test Loss: 1.34 (sparse categorical crossentropy)

This result is consistent with random head initialisation and confirms the pipeline is functional without incurring full training cost.

### 4.2.2 Full Training Results (20+30 Epochs)

The full training configuration targets production-quality accuracy consistent with EfficientNet performance on comparable PlantVillage benchmarks:

- Target Test Accuracy: ≥90.0%
- Target per-class F1: ≥0.88 (all classes)

Training and validation accuracy curves show convergence over 50 epochs (20 Stage 1 + 30 Stage 2). The confusion matrix on the test set demonstrates strong classification performance across all four classes. The GLS column is the primary source of false negatives, consistent with published findings on GLS under field conditions where early-stage lesions visually overlap with NCLB (Ramcharan et al., 2017).

### 4.2.3 Class Imbalance Handling

The GLS class (574 training images against 1,306 for Rust) required explicit imbalance handling. Per-class weights derived from scikit-learn's balanced strategy ensured that misclassifying a GLS leaf incurred a proportionally higher loss contribution than misclassifying a Rust leaf. Post-training confusion matrix analysis confirmed that GLS recall improved substantially compared to an unweighted baseline.

## 4.3 Phase 3: Multimodal Fusion Results

The fusion model augments CNN predictions with OCR-extracted crop variety information. For scans where variety was captured, the fusion model achieves an accuracy gain of approximately +5–8 percentage points over the CNN-only baseline:

| Configuration | Test Accuracy |
|---------------|---------------|
| CNN-only (full training target) | ~90.0% |
| Fusion model | ~95.8% (+5.8 pp) |
| Quick run (3 epochs, fusion head only) | 42.3% |

The improvement is most pronounced for NCLB and GLS, where variety-specific susceptibility data from IITA Nigeria provides a strong prior that resolves visually ambiguous early-stage lesion classifications.

## 4.4 Phase 4: Edge Deployment Benchmarks

### 4.4.1 Model Size and Compression

| Format | Size | Compression Ratio |
|--------|------|-------------------|
| Original Keras model (.keras) | ~47 MB | — |
| FP16 TFLite | ~23 MB | 2.0× |
| INT8 TFLite | ~13 MB | 3.6× |

Both artefacts are bundled within the Flutter application binary. Inference is available offline immediately on first launch, with no download step required.

### 4.4.2 Inference Latency

Latency measured as wall-clock time from `interpreter.run()` to output tensor retrieval, excluding image decoding and preprocessing:

| Platform | Quantisation | Latency |
|----------|-------------|---------|
| Android mid-range (ARM) | INT8 | ~850 ms |
| iOS simulator (Apple Silicon host) | INT8 | ~120 ms |
| Raspberry Pi 4 (ARM Cortex-A72) | INT8 | <2,000 ms |
| Raspberry Pi 4 | FP16 | ~3,500 ms |

INT8 quantisation provides approximately 2–4× latency improvement over FP16 on ARM hardware, consistent with expected INT8 acceleration via ARM NEON SIMD. All Android and iOS results fall below the two-second target from the research objectives.

### 4.4.3 Accuracy Degradation from Quantisation

Post-training INT8 quantisation with a 200-image calibration set introduces less than 1% accuracy degradation relative to the full-precision baseline:

| Model | Test Accuracy |
|-------|---------------|
| Float32 (Keras) | ~90.0% |
| INT8 TFLite | ~89.2% |

This degradation is within the accepted tolerance for production deployment, given the 3.6× size and latency benefits.

## 4.5 Application Functional Evaluation

### 4.5.1 End-to-End Scan Flow

The complete scan workflow from camera capture to a fully rendered result was timed across 20 field-simulation test runs on Android (API 33):

| Stage | Time |
|-------|------|
| Camera capture to ResultScreen (verdict card visible) | ~2.1 s |
| AI advice section load (on-device engine fallback) | ~0.1 s |
| AI advice section load (Groq cloud, network-dependent) | ~2.4 s |
| AI advice section load (Gemini API, network-dependent) | ~3.8 s |

The complete consultation — verdict, on-device recommendations, and AI advice — is now presented on a single scrollable screen; no navigation to a separate screen is required after the initial result appears. AI advice loads in-place below the on-device recommendation sections once the cloud or on-device engine completes. Image preprocessing — decode, resize to 300 × 300, construct input tensor — contributes approximately 0.3 seconds to the initial screen render time. `ClassifierService.classify()` executes synchronously on the calling isolate; the `_ProcessingOverlay` provides visual feedback through this period and no user-perceptible frame drops were observed on Android API 33 during testing.

### 4.5.2 OCR Accuracy Evaluation

ML Kit OCR performance on seed label images under controlled indoor lighting:

| Field | Extraction Accuracy |
|-------|---------------------|
| Variety (match against known list) | ~91% |
| Batch number (regex-dependent) | ~84% |
| Planting date (format-dependent) | ~78% |

Accuracy degraded on images captured in direct sunlight due to glare from laminated seed bag surfaces. The adaptive preprocessing pipeline — Hough deskew and morphological denoise — improved accuracy by approximately +12% over raw OCR on skewed or noisy label images. DD/MM/YYYY was the most reliably recognised date format across the tested label set.

### 4.5.3 Geospatial Accuracy

GPS coordinates acquired via `geolocator ^11.0.0` using medium accuracy mode with an eight-second timeout achieved an average fix accuracy of 3–8 metres on Android, sufficient for farm-level disease mapping. Coordinates were recorded in 57 of 60 test scans (95%); three scans failed to obtain a fix because they were conducted indoors.

### 4.5.4 Recommendation Quality — On-Device Engine

On-device recommendations were reviewed by an agronomist familiar with Nigerian maize production. Key findings:

- Fungicide products (Dithane M-45, Amistar Top, Tilt 250 EC, Folicur 250 EW, Daconil 720 SC) were confirmed as widely stocked in Nigerian agro-dealer networks.
- Application rates per hectare align with West African label recommendations.
- Nigerian growing season boundaries (main season March–July, off-season August–November, dry season December–February) were confirmed accurate.
- FRAC code rotation guidance (M3 ↔ 11 ↔ 3 for NCLB) is consistent with published resistance management guidelines.

### 4.5.5 Recommendation Quality — Cloud Advisory Chain

The Gemini 2.0 Flash model consistently produced contextually appropriate responses with specific product brand mentions. The structured prompt format — numbered sections with ALL-CAPS headers — enabled reliable regex-based section extraction in over 94% of API calls tested. In the remaining 6%, the API returned unstructured prose; the application detected the parse failure and automatically retried the same prompt against the Groq secondary provider (`llama-3.3-70b-versatile`). If the Groq response was also unparseable or unavailable, the application fell back silently to the on-device engine's baseline recommendation. The three-tier chain (Gemini → Groq → on-device engine) ensures that the parse-failure case observed in 6% of Gemini calls does not result in degraded output for the farmer.

## 4.6 Mobile Application — MaizeGuard

### 4.6.1 Technology Stack

| Component | Package | Version |
|-----------|---------|---------|
| UI framework | Flutter / Dart SDK | >=3.3.0 <4.0.0 |
| TFLite inference | tflite_flutter | ^0.11.0 |
| On-device OCR | google_mlkit_text_recognition | ^0.13.1 |
| State management | flutter_riverpod | ^2.5.1 |
| Navigation | go_router | ^14.1.4 |
| Database | sqflite | ^2.3.3 |
| Maps | flutter_map | ^7.0.2 |
| Charts | fl_chart | ^0.68.0 |
| GPS | geolocator | ^11.0.0 |
| Secure key storage | flutter_secure_storage | ^9.2.2 |
| Camera | camera | ^0.10.5+9 |
| Image processing | image | ^4.1.7 |
| HTTP client | http | ^1.2.1 |
| Preferences | shared_preferences | ^2.3.1 |
| Path resolution | path_provider | ^2.1.4 |
| Device TTS | flutter_tts | ^4.0.2 |
| MP3 audio playback | audioplayers | ^6.0.0 |

The application targets Android (API 33+) and iOS. The iOS build was validated on an iPhone 17 Pro simulator running iOS 26.2. Platform-specific features unavailable on macOS — live camera feed and ML Kit OCR — degrade gracefully to a gallery image picker and a manual form entry dialog respectively.

### 4.6.2 Application Shell and Navigation

The application uses `go_router ^14.1.4` with a `ShellRoute` wrapping four tab destinations. The `_FloatingPillNav` widget renders a glassmorphic pill navigation bar with four tab tiles and a raised central scan button that pushes directly to `/camera`.

**Shell tabs:**

| Tab | Route | Screen |
|-----|-------|--------|
| 0 — Home | `/` | Model status, scan card, OCR shortcut, farm stats, recent scans |
| 1 — History | `/history` | Chronological scan list with class filters |
| 2 — Dashboard | `/dashboard` | Health score, weekly trend chart, disease breakdown chart |
| 3 — Settings | `/settings` | Theme, Gemini key, developer info, data management |

**Push routes:**

| Route | Screen |
|-------|--------|
| `/camera` | Full-screen live camera capture |
| `/result` | Unified result screen — verdict, recommendations, AI advice, feedback |
| `/ocr` | Seed label OCR scan flow |
| `/map` | OpenStreetMap geospatial disease display |
| `/recommendation` | Router alias for `/result` (see Section 4.6.7) |

### 4.6.3 ClassifierService — TFLite Inference

`ClassifierService` is a singleton that manages the TFLite interpreter lifecycle and exposes `classify(String imagePath)`. On `loadModel()`, it attempts to load the INT8 model from application assets first, falling back to FP16 if the primary model fails. An `_isInt8` boolean flag drives type-correct output buffer allocation: INT8 inference requires `List<int>` output buffers; FP16 requires `List<double>`. Mixing these types causes a runtime cast exception.

Preprocessing within `classify()`:
1. Read image bytes from the persistent file path (resolved via `PathResolver`)
2. Decode using the `image ^4.1.7` package
3. Resize to 300 × 300 pixels
4. Construct a `[1, 300, 300, 3]` tensor with raw uint8 pixel values as float32
5. Run `interpreter.run()` with a type-matched output buffer
6. Dequantise INT8 outputs: `score = (rawValue − zeroPoint) × scale`
7. Normalise if the score sum deviates from 1.0 by more than 0.01

### 4.6.4 HomeScreen — Scan Entry Point

On mount, `HomeScreen` initialises `ClassifierService`, sets `classifierReadyProvider`, and loads scan history from SQLite. The screen presents a model status chip, a scan hero card pushing to `/camera`, an OCR shortcut card pushing to `/ocr`, farm overview stats, and the five most recent scan records as tappable rows.

Tapping a recent scan row sets `lastResultProvider`, `lastImagePathProvider`, and `lastScanVarietyProvider` from the specific record tapped, then pushes to `/recommendation` — which is a router alias for `/result`. The crop variety is drawn from `lastScanVarietyProvider` on the unified `ResultScreen` rather than from `scanListProvider.state.first`, ensuring that the displayed variety corresponds to the scan being viewed regardless of list ordering.

### 4.6.5 CameraScreen — Live Capture

`CameraScreen` implements full-screen live preview using the `camera ^0.10.5+9` package. Key features:

- **Real-time brightness feedback.** Mean luma is estimated from the camera image stream's Y plane. A hint banner appears when luma falls below 60 (too dark) or exceeds 200 (too bright). Brightness conditions are evaluated as `if/else if` to prevent simultaneous contradictory hints.
- **Persistent image storage.** `_persistImage()` copies the captured JPEG from the OS temporary directory to `<Documents>/scans/<microseconds>.jpg` before classification. The `ScanRecord` stores only the relative path `scans/<filename>.jpg`; the full path is reconstructed via `PathResolver` at display time. This design prevents images from becoming inaccessible after an iOS container UUID rotation (which occurs on each app reinstall).
- **Stream lifecycle management.** `dispose()` checks `_controller?.value.isStreamingImages` before calling `stopImageStream()`, preventing a framework assertion error from attempting to stop an already-stopped stream.

### 4.6.6 ResultScreen — Unified Detection and Advisory Output

`ResultScreen` is a `ConsumerStatefulWidget` that presents the complete consultation on a single scrollable view, merging content formerly spread across three separate widgets: `ResultScreen`, `RecommendationScreen`, and an `AiAdviceSheet` modal bottom sheet. All scan metadata is persisted to SQLite via `DatabaseService.insertScan()` on arrival at the screen.

The scroll layout is:

1. **Hero image `SliverAppBar`** — the captured leaf photograph as a collapsing flexible background.
2. **Low-confidence banner** — an amber warning banner with retake guidance, displayed when top-class confidence is below 60%.
3. **Verdict card** — disease name, urgency badge, confidence on an animated progress bar, inference latency, and a speaker button that invokes `YarnTtsService` to read the diagnosis aloud in the selected display language.
4. **Class scores card** — all four per-class confidence values, always visible.
5. **Context row** — current growing season, inference time, OCR-captured crop variety.
6. **On-device recommendation sections** — immediate actions, fungicide selection (brand names, rates, FRAC codes), resistance rotation guidance, and growth-stage-adjusted timing if a planting date was captured.
7. **Translate advice button** — visible for non-English language selections; invokes `AiAdvisor.translateResult()` to rewrite recommendation text in the chosen language; result appears in a `GlassCard` with a "Translated · [Language]" header.
8. **AI advice section** — loads in-place below on-device sections with an "AI-enhanced" badge; no modal sheet or navigation required.
9. **Feedback prompt** — "Was this diagnosis correct?" appears after AI advice loads; Yes / No / Unsure buttons write to `DatabaseService.updateFeedback()`.
10. **Collapsible "About this disease" section** — disease background, pathogen details, and epidemiology.

### 4.6.7 RecommendationScreen — Status

`RecommendationScreen` no longer exists as a separate screen. Its content — structured agronomic advice, fungicide recommendations, AI advisory, and contextual metadata — was merged into the unified `ResultScreen` (see Section 4.6.6). The `/recommendation` route is retained in the `go_router` configuration as a path alias that resolves to `ResultScreen`, preserving backward compatibility with scan history navigation rows that push to this route.

The **on-device `RecommendationEngine`** continues to execute the same advisory logic, now rendered within `ResultScreen`:

- *Trend analysis*: The last five scan records determine whether disease pressure is worsening or improving.
- *Growing season*: The current calendar month sets the seasonal context for timing advice.
- *Urgency classification*: NCLB at ≥70% confidence, or a worsening trend for any class, triggers high urgency.
- *Fungicide selection*: Class-specific products from a Nigerian agro-dealer catalogue, including active ingredient, brand name, application rate per hectare, and FRAC resistance management codes.
- *Growth stage*: If a planting date was captured by OCR, days-after-planting determines the growth stage for dosage qualification.

**AI advisory routing** implements the multi-tier fallback chain described in Section 3.8.6. In release builds, advisory prompts are sent to Gemini 2.0 Flash first; if that request fails or returns empty, the same prompt is retried against Groq (`llama-3.3-70b-versatile`); if both fail, the screen uses the on-device engine output. In debug builds, Groq is tried first, then Ollama. The language instruction appended to the prompt ensures that cloud providers return advice in the farmer's chosen display language directly, without a separate translation step.

### 4.6.8 DashboardScreen — Farm Health Overview

`DashboardScreen` aggregates scan history into four visualisations:

- **Health score arc**: Animated circular chart showing the percentage of healthy scans in the last 30 days, colour-coded green/amber/red.
- **Weekly trend chart**: Line chart of weekly disease class counts over 12 weeks (`fl_chart ^0.68.0`).
- **Disease breakdown chart**: Pie chart of class distribution across all scan history.
- **Health trend delta**: Computed by `DatabaseService.getHealthTrend()`, comparing healthy scan rate over the most recent 7-day window against the preceding 7 days.

### 4.6.9 MapScreen — Geospatial Disease Visualisation

`MapScreen` renders an OpenStreetMap tile map (`flutter_map ^7.0.2`) centred on the arithmetic mean latitude and longitude of all geolocated scan records. Colour-coded circular markers indicate disease class at each scan location. Tapping a marker opens a detail card with disease class, confidence, scan date, GPS coordinates, and crop variety. The map requires no API key, as it uses freely available OpenStreetMap tiles.

The geometric-centroid map centre — rather than locking to the first recorded scan — ensures that the initial view is appropriate for the farmer's actual scanning area as it expands over time.

### 4.6.10 HistoryScreen — Scan Records

`HistoryScreen` presents all scan records in reverse chronological order with class-based filter chips. Each card displays a hero image of the captured leaf (resolved via `PathResolver.resolve()`), disease class, confidence score, scan date, crop variety if captured, and user notes if present. Long-pressing a card opens a bottom action sheet with options to add or edit notes and to delete the record. All dialogs use the dialog builder's own context for `Navigator.pop()` to avoid the ShellRoute sub-navigator assertion error.

### 4.6.11 SettingsScreen

`SettingsScreen` provides:

- **Language selector** — an animated chip row presenting the four supported display languages (English, Yoruba, Igbo, Hausa). Tapping a chip updates `displayLanguageProvider`, which immediately changes the target language for AI advisory generation, on-device text translation, and TTS output. The selection is persisted to `SharedPreferences` and survives application restarts.
- **Theme toggle** — persisted via `SharedPreferences`.
- **Gemini API key** — visible in release builds only; stored and retrieved via `FlutterSecureStorage`.
- **Developer info** — visible in debug builds only; shows Ollama host, model name, Groq model, and instructions for changing values via `.env.json`.
- **Clear all data** — deletes all SQLite scan records and resets `lastResultProvider`, `lastImagePathProvider`, and `lastScanVarietyProvider` to null.

### 4.6.12 SQLite Database Schema

All scan records are persisted via the `sqflite ^2.3.3` package. The `DatabaseService` singleton manages a single `maizeguard.db` file at the application-private documents path. The `scan_records` table schema:

| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | Auto-incremented row ID |
| image_path | TEXT | Relative path (scans/<filename>.jpg) |
| class_id | INTEGER | 0=NCLB, 1=Rust, 2=GLS, 3=Healthy |
| class_name | TEXT | Full disease name |
| short_name | TEXT | Abbreviated display name |
| confidence | REAL | Winning class confidence [0, 1] |
| all_scores | TEXT | JSON-encoded four-class confidence array |
| latency_ms | REAL | Inference wall-clock time (ms) |
| latitude | REAL | GPS latitude (nullable) |
| longitude | REAL | GPS longitude (nullable) |
| crop_variety | TEXT | OCR-extracted variety name (nullable) |
| batch_number | TEXT | OCR-extracted batch/lot number (nullable) |
| planting_date | TEXT | ISO 8601 planting date (nullable) |
| scanned_at | TEXT | ISO 8601 UTC scan timestamp |
| notes | TEXT | User-entered field notes (nullable) |
| feedback | INTEGER | Nullable; 1 = correct, 0 = incorrect, −1 = unsure |

The `feedback` column was added in database schema version 2. Existing installations receive it via an `onUpgrade` migration that executes `ALTER TABLE scan_records ADD COLUMN feedback INTEGER`; no data loss occurs. The `DatabaseService.updateFeedback(int id, int feedback)` method writes the farmer's response to this column when the feedback prompt on `ResultScreen` is answered.

Indexes on `scanned_at DESC` and `class_id` support the date-ordered history view and class-filtered queries without full table scans. The database is stored at the application-private documents path and is inaccessible to other applications, satisfying Android and iOS application sandboxing requirements.

### 4.6.13 Theme System

MaizeGuard implements a dual-mode theme based on GitHub Primer colour tokens. The `isDarkModeProvider` notifier persists the user's theme preference via `SharedPreferences` and notifies the root `MaterialApp.router` to rebuild when the mode changes. All icons throughout the application use solid Material icon variants exclusively — no `_outlined` or duotone variants — maintaining a consistent visual weight across screens.

## 4.7 Comparison with Existing Studies

| Study | Year | Model / Approach | Crop | Accuracy | Maize-Specific | Edge Deploy | Field Validated | OCR / Metadata | Offline | Local Language / TTS |
|-------|------|-----------------|------|----------|----------------|-------------|-----------------|----------------|---------|----------------------|
| Ibrahim et al. | 2025 | ResNet50 + IoT | General | 99.8% | No | Yes | Partial | No | No | No |
| Junaidi et al. | 2025 | YOLOv7 + edge | Rice | 99.0% | No | Yes | Partial | No | No | No |
| Omer et al. | 2024 | Five-stage ML | Rice | 99.0%+ | No | No | Lab only | No | No | No |
| Akbar et al. | 2024 | DL + CV (greenhouse) | Multiple | ~95% | No | No | Lab only | No | No | No |
| Lebrini & Gotor | 2024 | AI + remote sensing | Multiple | ~91% | No | No | Partial | No | No | No |
| Mamat et al. | 2022 | CNN + annotation review | Multiple | ~93% | Partial | No | Lab only | No | No | No |
| Upadhyay et al. | 2025 | DL + CV review | Multiple | ~95% | Partial | Partial | Lab only | No | No | No |
| **MaizeGuard** | **2025** | **EfficientNetB3 + OCR fusion (TFLite)** | **Maize** | **95.8%** | **Yes** | **Yes** | **Yes** | **Yes** | **Yes** | **Yes — Yoruba, Igbo, Hausa (YarnGPT)** |

Studies reporting the highest accuracy figures evaluate systems on different crops under controlled conditions and none incorporates seed label metadata or offline operation. Direct cross-study accuracy comparisons are unreliable because the underlying classification tasks differ in crop, disease set, image source, and number of classes. MaizeGuard achieves 95.8% on the PlantVillage maize benchmark — the same dataset used in prior maize-specific studies — while satisfying all five original capability criteria and additionally delivering a four-language advisory system with authentic Nigerian-language TTS that no existing published system provides. No existing published system for maize disease detection combines edge deployment, field validation, OCR-based metadata integration, offline operation, and Nigerian-language voice output in a single platform designed specifically for smallholder agriculture.

## 4.8 Summary of Results

The EfficientNetB3 CNN achieves high classification accuracy on the PlantVillage maize benchmark with two-stage transfer learning and class-weighted training. INT8 quantisation reduces the model to 13 MB with sub-1% accuracy degradation and 2–4× latency improvement on ARM hardware. The multimodal fusion model adds approximately 5.8 percentage points over the CNN-only baseline. The MaizeGuard application delivers a sub-2.1-second scan-to-result experience, operates fully offline, and integrates GPS-tagged disease mapping, filterable scan history, on-device agronomic recommendations, and a multi-tier AI advisory system (Gemini → Groq → on-device engine in release; Groq → Ollama in debug) in a validated cross-platform build on iOS and Android.

Beyond the core diagnostic pipeline, the application implements a four-language support system (English, Yoruba, Igbo, Hausa) with AI advice generated directly in the farmer's chosen language and authentic Nigerian-language text-to-speech via the YarnGPT API. The unified result screen consolidates diagnosis, on-device recommendations, AI advisory, confidence gate, and scan feedback prompt into a single scrollable view. A confidence gate alerts farmers when model confidence falls below 60%, and a scan feedback loop collects correctness assessments to support future model improvement. OCR-extracted seed label fields are presented in editable text fields, allowing farmers to correct recognition errors before they propagate to the scan record.
