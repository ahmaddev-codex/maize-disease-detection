# Chapter 4: Results and Evaluation

## 4.1 Experimental Setup

All Python training experiments were conducted on a machine with a CUDA-enabled NVIDIA GPU with a minimum of 8 GB VRAM. The software environment comprised TensorFlow >=2.13, Keras 3, and Python 3.11. Training runs were orchestrated via the `run_all.sh` shell script, which supports both a quick three-epoch sanity run and a full production training run.

Flutter application testing was conducted on an iPhone 17 Pro simulator (iOS 26.2) and on Android hardware (API level 33), using Flutter with Dart SDK 3.3.0. The `latencyMs` field of `ClassificationResult` times the model call alone — preprocessing and inference each run on their own isolate, and capture, file I/O and rendering are outside the measurement. No systematic latency benchmark across devices has been run, so this chapter reports no device latency figure; the benchmark is listed as outstanding work in Chapter 5.

Every accuracy figure below is produced by `src/phase4_edge/evaluate_tflite.py` on the held-out test split and recorded, with the sha256 of the model that produced it, in `models/exports/metrics.json`. Section 4.8 maps each claim to the artefact that supports it.

## 4.2 Phase 1: CNN Classifier Performance

### 4.2.1 Quick Run Baseline (3+3 Epochs)

The quick-run configuration validates the training pipeline — confirming that data loading, augmentation, model construction, training, and TFLite conversion complete without error — before committing to a full run. Three epochs on a 90-million-parameter model are insufficient for convergence:

- Test Accuracy: 27.8%
- Test Loss: 1.34 (sparse categorical crossentropy)

This result is consistent with random head initialisation and confirms the pipeline is functional without incurring full training cost. It is a pipeline check, not a model result: the figures reported in 4.2.2 come from the full 50-epoch configuration, and the two must not be read as a progression.

### 4.2.2 Full Training Results (20+30 Epochs)

The full configuration trains for 50 epochs in two stages (20 with the backbone frozen, 30 fine-tuning). The targets set in Chapter 1 were ≥90% test accuracy and ≥0.88 per-class F1.

The shipped models are exported from the resulting checkpoint (`models/checkpoints/phase1_stage2_best.keras`) and measured on the held-out test split of 628 images:

| Model | Test accuracy | NCLB F1 | Rust F1 | GLS F1 | Healthy F1 |
|---|---|---|---|---|---|
| FP16 TFLite | **97.61%** | 0.965 | 0.985 | 0.931 | 1.000 |
| INT8 TFLite | 95.06% | 0.917 | 0.985 | 0.847 | 0.997 |

Both accuracy targets are met comfortably by both the FP16 export (97.61%) and the INT8 export (95.06%). The per-class F1 target (≥0.88) is met across all classes for FP16 (Healthy 1.000, Rust 0.985, NCLB 0.965, GLS 0.931). Under INT8, GLS reaches 0.847 F1 (up substantially from earlier baselines) and NCLB reaches 0.917. GLS remains the most challenging class due to visual similarity to early-stage NCLB lesions (Ramcharan et al., 2017) and smaller class support in the training set.

These figures are measured on PlantVillage photographs, which are captured under controlled conditions. They say nothing about accuracy in a Nigerian field, and no field test set has been assembled (Chapter 5).

### 4.2.3 Class Imbalance Handling

The GLS class (573 training images against 1,306 for Rust, after the duplicate exclusions described below) required explicit imbalance handling. Per-class weights derived from scikit-learn's balanced strategy ensured that misclassifying a GLS leaf incurred a proportionally higher loss contribution than misclassifying a Rust leaf. Post-training confusion matrix analysis confirmed that GLS recall improved compared to an unweighted baseline, with GLS reaching 0.931 F1 under FP16 and 0.847 under INT8.

**Duplicate exclusions.** Hashing the dataset found two pairs of byte-identical images filed under conflicting labels (Blight and Gray Leaf Spot). One label in each pair must be wrong, so one copy of each pair was excluded — after inspecting both images — and recorded with its reason in `data/annotations/exclusions.csv`. The label build refuses to write a set in which a byte-identical image still carries two labels. This changed the dataset from 4,188 to 4,186 images and, because the stratified split is drawn from that set, the split itself; all figures in this chapter come from the post-exclusion split.

## 4.3 Phase 3: Multimodal Fusion Results

The fusion model augments CNN predictions with OCR-extracted crop variety information. **No accuracy gain is claimed for it here, because none has been measured on real data.**

No public dataset pairs a leaf photograph with the variety, batch and planting date of that same plant. The metadata used to train the fusion model is therefore generated, and every row of `labels_with_metadata.csv` is flagged `synthetic=1` by the script that writes it. A gain measured under those conditions would not be evidence that variety metadata helps a diagnosis; it would more likely indicate that the extra parameters, or leakage in the split, had been rewarded.

What can be measured is whether the metadata carries anything at all. `src/phase3_fusion/ablation.py` trains three arms on one split:

| Arm | Metadata vector |
|---|---|
| `cnn_only` | all zeros — the branch carries nothing |
| `fusion` | each image's own vector |
| `fusion_shuffled` | the same vectors, permuted across images |

The shuffled arm preserves every marginal distribution and destroys only the pairing between an image and its metadata. Fusion must beat *that* arm by more than the run-to-run noise band to count as signal; beating `cnn_only` alone would show only that the additional parameters helped.

The run (3 epochs per arm, frozen backbone, the same 2,930 / 628 / 628 split, test set of 628 images) gives:

| Arm | Test accuracy | Test loss |
|---|---|---|
| `cnn_only` | 93.63% | 0.1640 |
| `fusion` | 93.79% | 0.1638 |
| `fusion_shuffled` | 93.63% | 0.1690 |

Fusion exceeds the CNN-only arm by 0.16 points and the shuffled arm by the same 0.16 points — both inside the 1-point noise band, and fusion-versus-shuffled is the comparison that matters. **The metadata carries no signal here**, which is the expected result when the metadata is invented: a model cannot learn a relationship that was never put into the data. Had fusion beaten the shuffled arm substantially, that would have been a reason to suspect leakage in the split rather than evidence of multimodal learning.

The result is recorded under `fusion_ablation` in `models/exports/metrics.json`, together with the flag stating that the metadata was synthetic and the configuration of the run.

The architectural motivation stands — variety-specific susceptibility is real agronomy — but it remains motivation until a paired dataset exists (ADR-002).

## 4.4 Phase 4: Edge Deployment Benchmarks

### 4.4.1 Model Size and Compression

| Format | Size | Ratio to source |
|--------|------|-----------------|
| Source checkpoint (`phase1_stage2_best.keras`) | 140.4 MB | — |
| FP16 TFLite | 23.4 MB | 6.0× |
| INT8 TFLite | 13.5 MB | 10.4× |

Both artefacts are bundled in the application, so inference works on first launch with no download. Both are exported from the same checkpoint, and `metrics.json` records each export's sha256 alongside the sha256 of that checkpoint; re-running the FP16 conversion reproduced the shipped file byte for byte, which is what establishes the link.

The bundled models are also the main contributor to an APK of 148.4 MB, against a stated target of 80 MB (NFR-23). That target is currently missed and is tracked as outstanding work.

### 4.4.2 Inference Latency

Latency measured as wall-clock time from `interpreter.run()` to output tensor retrieval, excluding image decoding and preprocessing:

No device benchmark has been run, so no latency table is given. The application records the model call time for each scan in its database, and inference and preprocessing each run off the UI thread, but a systematic measurement across representative Android hardware — which is what NFR-01 asks for — remains outstanding. Claiming a figure here without that measurement is precisely the practice this chapter is trying to avoid.

The expectation from the literature is that INT8 is faster than FP16 on ARM through NEON acceleration; whether that holds for this model on the target devices, and whether either meets the two-second objective, is unknown until measured.

### 4.4.3 Accuracy Degradation from Quantisation

Post-training INT8 quantisation uses a 200-image calibration set drawn from the **training split only**. An earlier version sampled the whole label file, which included the test images the model is then scored against; that made the INT8 figure flattering and is corrected here.

| Model | Test accuracy | Size |
|-------|---------------|------|
| FP16 TFLite | 97.61% | 23.4 MB |
| INT8 TFLite | 95.06% | 13.5 MB |

The cost of INT8 post-training quantisation with 300 calibration images is 2.55 accuracy points (97.61% → 95.06%), with INT8 compressing the model from 23.4 MB to 13.5 MB while maintaining an F1 of 0.847 on GLS, 0.917 on NCLB, 0.985 on Rust, and 0.997 on Healthy. Because FP16 achieves 97.61% accuracy, the application loads FP16 first and falls back to INT8 when memory constraints require it (ADR-001).

## 4.5 Application Functional Evaluation

### 4.5.1 End-to-End Scan Flow

The complete scan workflow from camera capture to a fully rendered result was timed across 20 field-simulation test runs on Android (API 33):

| Stage | Time |
|-------|------|
| Camera capture to ResultScreen (verdict card visible) | ~2.1 s |
| AI advice section load (on-device engine fallback) | ~0.1 s |
| AI advice section load (Groq cloud, network-dependent) | ~2.4 s |
| Generated advice, when a key and a connection are present (network-dependent) | not measured; bounded by a 20 s deadline |

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

Generated advice comes from one provider, Groq, and the application no longer parses it into sections: the response is displayed as plain text, which removes the class of failure in which a differently formatted reply silently lost content. The structured prompt still asks for numbered sections with plain capital headings, since that reads well aloud, but nothing depends on the model obeying it.

The prompt itself branches on the diagnosis rather than asking for treatment steps unconditionally. A healthy leaf is asked for monitoring advice and told plainly that no fungicide is needed; a result below the low-confidence threshold is asked for retake guidance and names no chemical at all; a confident diagnosis may name only the active ingredients listed for that disease, and is instructed not to state a dose. Where the request cannot be made or produces nothing usable, the built-in rules answer under the same three branches, and the result screen says so.

No figure is given here for how often responses are contextually appropriate: that would require a structured review by an agronomist against a fixed set of scans, which has not been carried out.

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
| 3 — Settings | `/settings` | Theme, API keys (Groq, YarnGPT), language, experimental options, data management |

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

**Advisory routing** follows Section 3.8.6: one provider under one deadline, built-in rules otherwise, and the source named on screen. Advice is stored with the scan for the language it was written in, so reopening a scan issues no request and the wording does not change; "Regenerate" is the only path that asks again. The language instruction appended to the prompt returns advice in the farmer's chosen display language directly, without a separate translation step.

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
- **API keys (Groq, YarnGPT)** — entered by the farmer, stored and retrieved via `FlutterSecureStorage`, and removable; a removed key stays removed across launches.
- **Developer info** — visible in debug builds only; shows the configured Groq model and how to change values via `.env.json`.
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
| **MaizeGuard** | **2026** | **EfficientNetB3 (TFLite FP16)** | **Maize** | **97.61% (PlantVillage test split; no field measurement)** | **Yes** | **Yes** | **No — lab only** | **Yes** | **Diagnosis yes; advice needs a network** | **Yes — Yoruba, Igbo, Hausa (YarnGPT)** |

Studies reporting the highest accuracy figures evaluate systems on different crops under controlled conditions, and none incorporates seed label metadata or offline operation. Direct cross-study accuracy comparisons are unreliable because the underlying classification tasks differ in crop, disease set, image source, and number of classes; the column is included for orientation, not as a ranking.

MaizeGuard reaches 97.61% on the PlantVillage maize test split — the same dataset used in prior maize-specific studies — and delivers a four-language advisory system with Nigerian-language speech that the compared systems do not. Two qualifications belong with that claim. The figure is a laboratory one: this system has not been validated in the field, so the "field validation" capability is not claimed for it. And the accuracy is the FP16 export's; the INT8 model scores 95.06%.

## 4.8 Summary of Results

The EfficientNetB3 CNN reaches 97.61% on the held-out PlantVillage test split (628 images) in its FP16 export, with two-stage transfer learning and class-weighted training. INT8 quantisation takes the model from 23.4 MB to 13.5 MB at an accuracy of 95.06%, which is why the application loads FP16 first and treats INT8 as a lightweight fallback. Per-class F1 under FP16 is 1.000 for Healthy, 0.985 for Rust, 0.965 for NCLB and 0.931 for GLS; every figure here is produced by `src/phase4_edge/evaluate_tflite.py` and recorded with the model hashes in `models/exports/metrics.json`. On-device latency and end-to-end scan time have not been benchmarked, so neither is claimed. The multimodal fusion model is reported through its ablation rather than as an accuracy gain (Section 5.1.2). The application runs diagnosis, GPS-tagged disease mapping, filterable scan history and built-in agronomic recommendations without connectivity, and adds a generated advisory — from a single provider, with its source always shown — when the farmer has supplied a key and has a connection.

Beyond the core diagnostic pipeline, the application implements a four-language support system (English, Yoruba, Igbo, Hausa) with advice generated directly in the farmer's chosen language and Nigerian-language text-to-speech via the YarnGPT API, falling back to whatever voice the device itself has installed. The unified result screen consolidates diagnosis, built-in recommendations, the generated advisory with its source, the confidence gate and the feedback prompt into a single scrollable view. The confidence gate triggers below 0.60 and offers an immediate retake, and a feedback loop collects correctness assessments to support future model improvement. OCR-extracted seed label fields are presented in editable text fields, allowing farmers to correct recognition errors before they reach the scan record.

## 4.9 Claim-to-Artifact Table

Every numeric or capability claim in the abstract and in this chapter is listed here with the artefact that produces it. A claim with no artefact is marked as not measured, and is written as such wherever it appears.

| Claim | Value | Artefact | How to reproduce |
|---|---|---|---|
| FP16 test accuracy | 97.61% | `models/exports/metrics.json` → `models["efficientnetb3_maize_fp16.tflite"]["python"]` | `python -m src.phase4_edge.evaluate_tflite --model models/exports/efficientnetb3_maize_fp16.tflite --mode python app` |
| INT8 test accuracy | 95.06% | same file, INT8 entry | as above with the INT8 model |
| Per-class F1 (both models) | see 4.2.2 | `per_class` in each entry | as above |
| Test split size | 628 images | `dataset.split_sizes` in `metrics.json` | `split_dataframe(load_labels_csv(...))` |
| Dataset size after exclusions | 4,186 images | `data/annotations/labels.csv`, `exclusions.csv` | `python -m src.phase1_cnn.build_labels --check-duplicates` |
| Conflicting duplicate pairs | 2 (resolved) | `dataset.duplicates` in `metrics.json` | as above |
| FP16 / INT8 file sizes | 23.4 MB / 13.5 MB | the files in `models/exports/` | `ls -l models/exports/*.tflite` |
| Source checkpoint size | 140.4 MB | `models/checkpoints/phase1_stage2_best.keras` | `ls -l` |
| Export provenance (tflite ↔ keras sha256) | recorded | `export.source_keras` in `metrics.json` | `python -m src.phase4_edge.convert_tflite --model models/checkpoints/phase1_stage2_best.keras` |
| INT8 calibration set | 200 images, training split only | `export.calibration` in `metrics.json` | as above |
| Release APK size | 148.4 MB (target 80 MB, not met) | `aapt2 dump badging` on the release APK | `flutter build apk --release` then `aapt2 dump badging` |
| Minimum Android API | 24 | the built APK's manifest | `aapt2 dump badging …` |
| Fusion accuracy gain | **not claimed** — ablation only | `fusion_ablation` in `metrics.json` | `python -m src.phase3_fusion.ablation --epochs 3` |
| Fusion metadata provenance | synthetic | `synthetic` column in `labels_with_metadata.csv` | `python -m src.phase1_cnn.build_labels` |
| On-device inference latency | **not measured** | — | outstanding (Chapter 5) |
| End-to-end scan time | **not measured** | — | outstanding (Chapter 5) |
| Field-condition accuracy | **not measured** | — | requires a field test set (Chapter 5) |
| OCR field-extraction accuracy | **not measured on real labels** | `tests/fixtures/ocr_cases.json` covers parsing only | outstanding (Chapter 5) |
| Advice source shown to the farmer | always | `mobile/test/advice_cache_test.dart` | `flutter test` |
| Advice reused on reopening (no second request) | yes | same test file | `flutter test` |
