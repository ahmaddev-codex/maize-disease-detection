# Chapter 3: System Design and Implementation

## 3.1 Overview of System Architecture

MaizeGuard is a multi-phase, end-to-end platform for the detection and management of maize leaf diseases. The architecture spans a Python-based machine learning pipeline for model training and a cross-platform Flutter mobile application for field deployment. The two components are connected by a TFLite model artefact: the Python pipeline produces it; the Flutter application consumes it.

The system was designed around five sequential development phases:

- **Phase 1** — EfficientNetB3 CNN image classifier
- **Phase 2** — OCR-based seed label metadata extraction
- **Phase 3** — Multimodal late-fusion of CNN and OCR features
- **Phase 4** — INT8 TFLite quantisation for edge deployment
- **Phase 5** — Cross-platform Flutter mobile application

Each phase builds on the outputs of the previous. The CNN classifier (Phase 1) was trained and evaluated before the OCR subsystem (Phase 2) was built, ensuring that any baseline accuracy problems were identified and resolved before the fusion architecture (Phase 3) was designed. The fusion model was trained with knowledge of where the CNN alone underperformed. Only after the TFLite artefact was validated (Phase 4) was the mobile application layer (Phase 5) assembled.

The Flutter application integrates the TFLite inference engine, the on-device OCR pipeline, GPS location services, a SQLite scan database, an OpenStreetMap display, a context-aware recommendation engine, an optional cloud advisory through a single provider (Groq) with built-in rules as the alternative, a four-language display and TTS system, and a unified result screen into one tool for Android and iOS whose diagnostic path runs without connectivity.

## 3.2 Dataset and Preprocessing

### 3.2.1 Dataset

The primary training dataset is the PlantVillage maize subset — a widely used benchmark repository of plant disease images captured under controlled conditions. The dataset contains 4,188 images distributed across four classes:

| Class | Label | Image Count |
|-------|-------|-------------|
| 0 | Northern Corn Leaf Blight (NCLB) | 1,146 |
| 1 | Common Rust | 1,306 |
| 2 | Gray Leaf Spot (GLS) | 574 |
| 3 | Healthy | 1,162 |

The under-representation of GLS (574 images against 1,306 for Rust) posed a class imbalance risk. Per-class training weights were computed using scikit-learn's `compute_class_weight` function with the "balanced" strategy, which assigns each class a weight inversely proportional to its frequency. This penalises the model proportionally more for misclassifying GLS examples, counteracting the model's natural tendency to favour majority-class predictions.

The dataset was split into training, validation, and test sets using stratified sampling at a 70:15:15 ratio, yielding approximately 2,932 training images, 628 validation images, and 628 test images. Stratification ensures proportional class representation across all three splits.

### 3.2.2 Data Augmentation Pipeline

Augmentation was implemented as a Keras sequential preprocessing model applied on-the-fly during training using `tf.data`, so each training epoch sees stochastically varied versions of each image without generating new files on disk. The pipeline comprised:

- `RandomFlip` — horizontal and vertical
- `RandomRotation` — ±20 degrees
- `RandomZoom` — height and width factors ±15%
- `RandomTranslation` — height and width factors ±10%
- `RandomBrightness` — factor ±20%
- `RandomContrast` — factor ±20%

These transformations simulate field-capture variability: a farmer does not hold a phone level with a leaf, sunlight changes throughout the day, and the distance from leaf to camera varies with each capture. The `tf.data` pipeline was configured with prefetching and parallel map calls to keep GPU utilisation high during training.

## 3.3 Machine Learning Pipeline

### 3.3.1 Phase 1: CNN Classifier Architecture

The image classification backbone is EfficientNetB3, introduced by Tan and Le (2019). EfficientNets apply compound scaling — simultaneously increasing network depth, width, and input resolution using a fixed set of scaling coefficients — to achieve state-of-the-art accuracy with fewer parameters than prior architectures such as ResNet and VGG. EfficientNetB3 accepts 300 × 300-pixel inputs and was pre-trained on ImageNet-1K, providing rich low-level and mid-level feature representations appropriate for transfer learning.

The classification head appended for the four-class task is:

```
Input:  300 × 300 × 3 RGB image, float32, pixel range [0, 255]
EfficientNetB3 base (frozen in Stage 1)
GlobalAveragePooling2D
BatchNormalization
Dense(512, activation='relu')
Dropout(rate=0.4)
Dense(256, activation='relu')
Dropout(rate=0.3)
Dense(4, activation='softmax')  →  [NCLB, Rust, GLS, Healthy]
```

EfficientNetB3 includes an internal rescaling layer that normalises input values from [0, 255] to the expected float range. Input images are therefore passed as raw uint8-valued float32 tensors without prior division by 255; manual normalisation before the model would double-scale the inputs and degrade accuracy.

### 3.3.2 Two-Stage Transfer Learning

Training proceeded in two stages, following the standard transfer learning protocol of head-only training followed by selective fine-tuning.

**Stage 1 — Head Training (Frozen Base).** All EfficientNetB3 layers were frozen; only the custom head was trained.
- Optimiser: AdamW (learning rate: 1×10⁻³, weight decay: 1×10⁻⁴)
- Epochs: 20
- Callbacks: `EarlyStopping` (patience=8), `ReduceLROnPlateau` (factor=0.4, patience=4)

**Stage 2 — Fine-Tuning (Partial Unfreeze).** The top EfficientNetB3 layers (from index 100 onward) were unfrozen to allow domain-specific adaptation of higher-level feature representations. A Keras 3 compatibility issue required saving Stage 1 weights, rebuilding a fresh model, loading the weights, then recompiling — this worked around an Adam optimiser slot variable shape mismatch that arose when freezing and unfreezing an already-compiled model.
- Optimiser: AdamW (learning rate: 1×10⁻⁵, weight decay: 1×10⁻⁴)
- Epochs: 30

The lower learning rate in Stage 2 prevents catastrophic forgetting of pretrained ImageNet representations by keeping weight updates small during domain adaptation.

### 3.3.3 Phase 2: OCR-Based Seed Label Extraction

Seed packages in Nigerian agro-dealer markets carry printed labels with the crop variety name, planting date, and batch or lot number. This information influences disease risk — certain varieties (e.g., SAMMAZ 15) have documented susceptibility ratings from the International Institute of Tropical Agriculture (IITA) — and enables more targeted treatment recommendations.

On Android and iOS, OCR is performed on-device using Google's ML Kit Text Recognition SDK (package: `google_mlkit_text_recognition ^0.13.1`), which requires no server round-trip and runs without connectivity. The mobile application passes the captured photograph to ML Kit as it is: the grayscale, adaptive-threshold, deskew and denoise pipeline described below exists in the Python implementation (`src/phase2_ocr/preprocessor.py`), where it is used for evaluation, and has not been ported to the application. Whether it is worth porting is an open question — ML Kit performs its own binarisation internally, so the gain measured on the Python path may not transfer.

The Python preprocessing pipeline comprises:

1. Grayscale conversion
2. Adaptive thresholding (binarisation)
3. Deskew by the minimum-area rectangle of the dark text pixels, applied only for angles within ±30°
4. Morphological denoising

After OCR, a rule-based extraction layer — shared between the application and the Python implementation through the test fixtures in `tests/fixtures/ocr_cases.json` — parses the raw text output to recover three fields:

- **Crop Variety**: Substring matching and fuzzy word-token overlap against a curated list of 13 known Nigerian maize varieties: SAMMAZ 15, 17, 29, 34, 50; OBA SUPER 2; EVDT 99; POOL 16 DT; TZEE-W; ABA WHITE; ACROSS 97; SUWAN 1; EARLY THRIVING.
- **Batch Number**: Regular expressions for patterns including `BN-YYYY-NNN`, `BATCH NO: ...`, and `LOT #...`.
- **Planting Date**: Multi-format date parsing for DD/MM/YYYY, YYYY-MM-DD, and textual formats such as "15 March 2024".

The extracted fields are encoded into a 17-dimensional metadata vector (`METADATA_DIM = NUM_VARIETIES + 4`) for fusion with CNN features in Phase 3:

- Indices 0–12: One-hot encoding of known variety (13 classes)
- Index 13: Binary flag — batch number present
- Index 14: Batch year normalised (year / 2030)
- Indices 15–16: Planting month encoded as sin/cos (cyclical encoding to preserve month continuity)
- Indices 17–23: Reserved (zero-padded)

On macOS — where ML Kit is not available — the application presents a manual form entry dialog allowing direct input of seed label data.

### 3.3.4 Phase 3: Multimodal Fusion

The fusion model combines the 256-dimensional feature vector from the CNN's penultimate Dense layer with the 17-dimensional OCR metadata vector using late fusion:

```
CNN Branch (frozen):
  EfficientNetB3 → Dense(256) → 256-d feature vector

OCR Branch:
  17-d input → Dense(32, ReLU) → BatchNormalization → 32-d vector

Fusion Head:
  Concatenate(288-d) → Dense(128, ReLU) → Dropout(0.3) → Dense(4, Softmax)
```

The CNN branch is frozen during fusion training to preserve learned visual features and prevent overfitting on the relatively small fused dataset. Only the OCR branch and fusion head weights are updated.
- Optimiser: Adam (learning rate: 5×10⁻⁴)
- Epochs: 25

The expected accuracy gain from fusion over the CNN-only baseline is approximately +5–8 percentage points, driven primarily by improved disambiguation of early-stage NCLB and GLS cases where visual features alone are ambiguous and variety susceptibility data provides a decisive prior.

### 3.3.5 Phase 4: Edge Deployment — TFLite Quantisation

The trained Keras model was converted to TFLite format in two quantisation levels:

**INT8 Post-Training Quantisation (Primary — ~13 MB).** A representative calibration dataset of 200 images sampled from the training set was used to compute per-layer activation ranges. Full integer quantisation reduces model size approximately 4× and inference latency 2–4× on devices with INT8-accelerated hardware (ARM NEON SIMD).

**FP16 Quantisation (Fallback — ~23 MB).** Half-precision quantisation was generated as a fallback for devices lacking INT8 acceleration, providing ~2× size reduction with minimal accuracy loss.

Both artefacts were verified on 20 random test images before deployment. Both `.tflite` files are bundled as Flutter assets within the application binary, ensuring the model is available offline immediately on first launch.

## 3.4 Software Development Model

MaizeGuard was developed using the Iterative and Incremental Development (IID) model. Agricultural AI operates at the intersection of machine learning uncertainty, mobile development complexity, and domain-specific knowledge gaps that are difficult to fully specify in advance. IID was chosen because it allows each phase to be delivered, tested, and validated independently before the next phase begins.

Concretely, this meant that the CNN classifier (Phase 1) was trained and evaluated before the OCR subsystem (Phase 2) was built — any baseline accuracy problems were identified early when they were cheapest to fix. The fusion architecture (Phase 3) was then designed with empirical knowledge of the cases where the CNN alone underperformed. Each phase also underwent independent unit and integration testing.

### 3.4.1 Development Phases and Iteration Cycles

| Iteration | Phase | Primary Input | Deliverable |
|-----------|-------|---------------|-------------|
| 1 | CNN Classifier | PlantVillage dataset (4,188 images) | Trained EfficientNetB3 `.keras` model |
| 2 | OCR Subsystem | Seed label photographs | 17-d metadata vector extractor |
| 3 | Multimodal Fusion | CNN features + OCR vector | Fused classification model |
| 4 | Edge Deployment | Trained Keras model | INT8 TFLite artefact (~13 MB) |
| 5 | Mobile Application | TFLite model, OCR engine, GPS APIs | Flutter Android/iOS application |

## 3.5 Architectural Diagram

*(Refer to architectural diagram figure in the submitted document)*

## 3.6 Data Flow Diagram

The Data Flow Diagram captures how data moves through MaizeGuard from user interaction through to the final recommendation output.

### 3.6.1 Level 0 (Context Diagram)

*(Refer to Level 0 DFD figure)*

### 3.6.2 Level 1

*(Refer to Level 1 DFD figure)*

## 3.7 Entity Relationship Diagram

MaizeGuard uses a single SQLite database managed via the `sqflite ^2.3.3` package. Because MaizeGuard is a single-user mobile application, the data model is intentionally denormalised: all scan metadata — seed label fields, per-class confidence scores, GPS coordinates, inference latency, and user notes — is stored in a single `scan_records` table. This eliminates join overhead and simplifies the query path for the common operation of loading all scans ordered by date.

The `DatabaseService` singleton exposes the following async methods:

- `insertScan(ScanRecord)` — persists a new scan record and returns the assigned row ID
- `getScans({int? classIdFilter})` — retrieves all records, optionally filtered by class, ordered by `scanned_at DESC`
- `deleteScan(int id)` — removes a record by primary key
- `updateNotes(int id, String notes)` — updates the user notes field for a record
- `updateFeedback(int id, int feedback)` — records the farmer's diagnostic feedback for a scan (1 = correct, 0 = incorrect, −1 = unsure)
- `clearAll()` — deletes all scan records
- `getDailyScans({int days})` — returns daily scan counts for the last *n* days (used by the Dashboard trend chart)
- `getHealthTrend()` — computes the change in healthy scan rate between the most recent 7-day window and the preceding 7-day window

The database was extended to schema version 2 with the addition of a nullable `feedback` INTEGER column on `scan_records`. The `onUpgrade` handler applies `ALTER TABLE scan_records ADD COLUMN feedback INTEGER` for existing installations, preserving all prior scan data while enabling the scan feedback feature. The schema includes indexes on `scanned_at` (descending) and `class_id` to support the date-ordered history view and class-filtered queries without full table scans.

*(Refer to ERD figure in the submitted document)*

## 3.8 Application Architecture

### 3.8.1 Technology Stack

| Component | Package | Version |
|-----------|---------|---------|
| UI framework | Flutter / Dart SDK | `>=3.3.0 <4.0.0` |
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
| Map coordinates | latlong2 | ^0.9.1 |
| Device TTS | flutter_tts | ^4.0.2 |
| MP3 audio playback | audioplayers | ^6.0.0 |

### 3.8.2 State Management

Application state is managed entirely through Riverpod. The principal providers are:

- `scanListProvider` (`StateNotifierProvider`) — holds the in-memory list of scan records, synchronised with the SQLite database
- `lastResultProvider` (`StateProvider`) — holds the `ClassificationResult` of the most recently completed scan
- `lastImagePathProvider` (`StateProvider`) — holds the absolute image path for the active result view
- `lastScanVarietyProvider` (`StateProvider`) — holds the crop variety associated with the scan currently being viewed, ensuring the recommendation screen shows the correct variety regardless of scan history order
- `groqKeyProvider` and `yarnGptKeyProvider` (`StateNotifierProvider`) — manage the user-supplied API keys through `FlutterSecureStorage`
- `isDarkModeProvider` (`StateNotifierProvider`) — persists the theme preference via `SharedPreferences`
- `classifierReadyProvider` (`StateProvider`) — signals when the `ClassifierService` has completed model loading
- `healthTrendProvider` (`FutureProvider`) — computes the health trend delta via `DatabaseService.getHealthTrend()`
- `pendingOcrProvider` (`StateProvider`) — holds OCR-extracted seed label fields between the OCR screen and the next disease scan
- `displayLanguageProvider` (`StateNotifierProvider<DisplayLanguageNotifier, DisplayLanguage>`) — manages the user's chosen display language (English, Yoruba, Igbo, or Hausa), persisted to `SharedPreferences` and read by the AI advisory, translation, and TTS subsystems

### 3.8.3 Navigation

Navigation uses `go_router ^14.1.4` with a `ShellRoute` wrapping the four tab destinations. A floating glassmorphic pill navigation bar, rendered by the `_FloatingPillNav` widget, provides access to the tabs. A central scan button in the pill nav is styled as a raised action button and pushes directly to `/camera`.

**Tab routes (within ShellRoute):**

| Tab | Route | Screen |
|-----|-------|--------|
| 0 | `/` | `HomeScreen` |
| 1 | `/history` | `HistoryScreen` |
| 2 | `/dashboard` | `DashboardScreen` |
| 3 | `/settings` | `SettingsScreen` |

**Push routes (outside ShellRoute):**

| Route | Screen |
|-------|--------|
| `/camera` | `CameraScreen` |
| `/result` | `ResultScreen` |
| `/ocr` | `OcrScreen` |
| `/map` | `MapScreen` |
| `/recommendation` | Alias for `/result` — `RecommendationScreen` no longer exists as a separate screen; its content was merged into the unified `ResultScreen` |

Push routes render over the shell, temporarily hiding the bottom navigation bar. This is the correct behaviour for full-screen flows — camera capture, scan results, and advisory content — that are not persistent tab destinations. The `/recommendation` alias is retained for backward compatibility with scan history rows that push to this route from `HomeScreen`.

### 3.8.4 Environment Configuration

Build-time configuration is injected via `--dart-define-from-file=.env.json`. The `AppEnv` class reads these compile-time defines:

```dart
abstract final class AppEnv {
  static const groqApiKey    = String.fromEnvironment('GROQ_API_KEY');
  static const groqModel     = String.fromEnvironment('GROQ_MODEL',
      defaultValue: 'openai/gpt-oss-120b');
  static const yarnGptApiKey = String.fromEnvironment('YARNGPT_API_KEY');
}
```

Two points need stating precisely, because an earlier version of this chapter overstated both.

**A compile-time constant is not a secret.** A value passed through `--dart-define` is compiled into the application binary, where it can be recovered from the installed package with standard tooling. It is protected from source control, not from the user of the device or anyone who obtains the APK. MaizeGuard therefore treats keys as belonging to the farmer rather than to the build: release builds ship with no key, the farmer enters their own in Settings, and it is stored through `FlutterSecureStorage` (ADR-003).

**A key the farmer removes stays removed.** A build-time key, when one is present at all — for development builds — seeds secure storage exactly once, guarded by a persisted flag. Removing the key in Settings is therefore permanent rather than undone at the next launch, and a key the farmer saved is never overwritten by the build's.

### 3.8.5 Image Path Persistence

iOS assigns a new application container UUID on every reinstall, which changes the absolute path to the application's Documents directory. If scan image paths are stored as absolute paths in the SQLite database, they become invalid after each rebuild or reinstall — a silent failure that causes history images to disappear.

MaizeGuard addresses this through two mechanisms:

1. **Relative path storage.** The `CameraScreen` copies captured images from the OS temporary directory to `<Documents>/scans/<microseconds>.jpg`, then stores only the relative path `scans/<filename>.jpg` in the `ScanRecord`. The absolute path is reconstructed at display time.

2. **PathResolver service.** The `PathResolver` singleton, initialised at application startup, caches the current Documents directory path. Its `resolve(String imagePath)` method handles all three storage cases: relative paths (new records), current absolute paths (same session), and stale absolute paths with an outdated container UUID (records created before a reinstall). For stale paths, the resolver extracts the filename and rebuilds the path under the current Documents directory.

```dart
class PathResolver {
  static String _docsDir = '';
  static Future<void> init() async {
    _docsDir = (await getApplicationDocumentsDirectory()).path;
  }
  static String resolve(String imagePath) {
    if (imagePath.isEmpty) return imagePath;
    if (!imagePath.startsWith('/')) return p.join(_docsDir, imagePath);
    if (imagePath.startsWith(_docsDir)) return imagePath;
    return p.join(_docsDir, 'scans', p.basename(imagePath)); // stale UUID
  }
}
```

`PathResolver.init()` is called in `main()` before `runApp()`, ensuring the cached path is available before any image is loaded.

### 3.8.6 Where Advice Comes From, and What Happens When It Cannot Be Fetched

MaizeGuard uses one cloud provider. `AiAdvisor` sends the prompt to Groq and, when that is not possible, answers from the built-in rules in `diseases.dart`. There is no provider chain and no silent substitution: the result screen always names the source of the text it is showing (ADR-003).

**One budget for the whole request.** The advisory has a single 20-second deadline covering every attempt, and each attempt receives whatever remains of it. A rejected key (HTTP 401 or 403) or a failed connection stops the request immediately rather than being retried against further models, since neither can succeed a second time. A transient server error falls through to a backup model id while time remains. The model list is held in `AppEnv.groqModels` and checked in the test suite against a recorded copy of Groq's served models, so an id that Groq stops serving fails a test rather than a farmer's scan.

**Only the answer is shown.** Where a response carries the model's own `reasoning` field alongside an empty `content`, the reasoning is discarded and the built-in rules answer instead. Model deliberation is not agronomic advice and is never displayed as such.

**The farmer is told which it was.** The advisory card reads either "Answered online by *model id*" or "Offline guidance · built-in agronomic rules", with the reason in plain words — that the key was rejected, that there is no connection, that the service did not answer in time. The generated text is then stored with the scan, so reopening the scan makes no further request and the wording does not change underneath the farmer.

**Advice is language-tagged.** The built-in rules exist only in English. When a farmer working in Hausa is answered from them, the card is labelled "English (offline)" and the text is cached under English, so a later online request in Hausa is still made rather than satisfied from an English cache.

| Condition | What answers | What the screen says |
|---|---|---|
| Key present, network available | Groq, model id recorded | "Answered online by *model*" |
| Key rejected | Built-in rules | "That API key was rejected…" |
| No connection | Built-in rules | "No internet connection…" |
| No key set | Built-in rules | "No API key is set…" |
| Response empty or reasoning-only | Built-in rules | "The model returned nothing usable…" |

### 3.8.7 Language and Translation System

MaizeGuard supports four display languages through the `DisplayLanguage` enum:

```dart
enum DisplayLanguage { english, yoruba, igbo, hausa }
```

Language selection is managed by `DisplayLanguageNotifier`, a `StateNotifier` subclass whose state is persisted to `SharedPreferences` under the key `display_language`. The `displayLanguageProvider` (`StateNotifierProvider<DisplayLanguageNotifier, DisplayLanguage>`) exposes the current language to all widgets and services that need it.

The language selector is presented in `SettingsScreen` as an animated chip row — one chip per language — allowing the farmer to switch languages with a single tap. The selection takes effect immediately across the application.

**AI prompt localisation.** When an advisory request is dispatched by `AiAdvisor`, a language instruction is appended to the prompt if a non-English language is selected (for example: "Write the whole answer in Yoruba, but keep the active ingredient names in English so they can be matched on a product label"). The model generates the advisory in the target language without a separate translation step.

**Translate advice button.** Where advice was produced in English — because the language was changed after the scan, or because the built-in rules answered — a "Translate advice" button appears on the result screen for non-English selections. Tapping it invokes `AiAdvisor.translateResult()`, which sends the existing text to Groq with a translation instruction; it therefore requires the same key and connection as any other generated advice. The translated text is rendered in a `GlassCard` with a "Translated · [Language]" header below the original sections. The translate button does not appear when language is set to English.

### 3.8.8 Text-to-Speech

MaizeGuard implements a dual-engine text-to-speech system managed by the `YarnTtsService` singleton (`lib/services/yarn_tts_service.dart`).

**English TTS.** For English-language output, `flutter_tts ^4.0.2` invokes the device's native speech synthesis engine. This requires no API key and no network round-trip, and works on any device that has a voice installed. Where YarnGPT is unavailable — no key, no connection, or a failed request — the same engine is used for Nigerian languages too, in the closest locale the device has installed; where it has none, the application says so rather than failing silently.

**Nigerian-language TTS.** For Yoruba, Igbo, and Hausa output, `YarnTtsService` sends a POST request to the YarnGPT API (`https://yarngpt.ai/api/v1/tts`) with a Bearer token (`AppEnv.yarnGptApiKey`) and a voice selected by language:

| Language | YarnGPT Voice | Character |
|----------|--------------|-----------|
| Yoruba | Idera | Melodic, gentle |
| Igbo | Chinenye | Engaging, warm |
| Hausa | Zainab | Soothing, gentle |

The API returns binary MP3 bytes. `YarnTtsService` writes these bytes to a temporary `.mp3` file and plays the file via `audioplayers ^6.0.0` using a `DeviceFileSource`. This approach sidesteps the limitations of `audioplayers`' `BytesSource` on iOS, which does not support MP3 decoding from a raw byte buffer.

**Speaker buttons.** A speaker icon button on the verdict card reads the disease diagnosis aloud in the selected language. Additional speaker icons appear on the translated sections card and on the AI advice card header. TTS content priority follows a deterministic hierarchy: translated sections text (if present) → AI advice in the target language → English verdict as a final fallback. This ensures the most contextually complete content is spoken, not merely the disease name.

### 3.8.9 Unified Result Screen, Confidence Gate, Scan Feedback, and OCR Correction

**Unified result screen.** The `ResultScreen` (`result_screen.dart`) was rewritten as a `ConsumerStatefulWidget` that consolidates what were previously three separate screens — `ResultScreen`, `RecommendationScreen`, and an `AiAdviceSheet` bottom sheet — into a single scrollable view. The scroll layout proceeds as follows:

1. Hero image `SliverAppBar` with the captured leaf photograph
2. Low-confidence amber banner (conditional — see below)
3. Verdict card — disease name, urgency badge, confidence percentage, latency, TTS button
4. Class scores card — all four per-class confidence values, always visible
5. Context row — current growing season, inference time, OCR-captured crop variety
6. On-device recommendation sections — immediate actions, fungicide selection, FRAC rotation guidance
7. Translate advice button (non-English only) and translated text card
8. AI advice section — loads in-place with an "AI-enhanced" badge; no modal sheet or navigation required
9. Feedback prompt — appears after AI advice loads
10. Collapsible "About this disease" section

`RecommendationScreen` and `AiAdviceSheet` were removed. The `/recommendation` route is retained as a router alias that resolves to `ResultScreen`, preserving backward compatibility with history-row navigation.

**Confidence gate (F63).** When the top-class confidence score is below 60%, an amber warning banner is displayed above the verdict card. The banner reads "Low confidence — consider a retake" and provides inline guidance on lighting conditions, camera distance, framing, and ensuring the leaf fills the frame. The complete diagnosis result is displayed below the banner; the low-confidence state does not suppress the result.

**Scan feedback loop (F65).** After AI advice finishes loading, a "Was this diagnosis correct?" prompt appears with three buttons: Yes, No, and Unsure. The farmer's response is written to the `feedback` column of the corresponding `scan_records` row via `DatabaseService.updateFeedback()` using the values 1 (correct), 0 (incorrect), or −1 (unsure). The prompt is replaced by a "Feedback saved — thank you!" confirmation message. Feedback data is intended to support future supervised fine-tuning on field-collected labels.

**OCR inline correction (F69).** After OCR extraction on `OcrScreen`, the extracted fields — variety, batch number, and planting date — are pre-filled into editable `TextField` widgets rather than displayed as read-only text. The farmer can review and correct any OCR errors before proceeding. When the farmer taps the attach button, `_attach()` reads values from the corrected `TextEditingController` instances rather than from the raw OCR output, ensuring that corrected values — not unchecked OCR output — propagate to the next scan.
