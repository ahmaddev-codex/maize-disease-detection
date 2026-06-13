# MaizeGuard — Software Requirements Specification

**Project Title:** MaizeGuard — AI-Powered Maize Disease Detection System  
**Team:** Olapade (CNN/CV) · Tijani (OCR) · Oshodilawal (Edge/UI)  
**Platform:** React Native (Android-first) + Python ML backend  
**Version:** 1.0  

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Stakeholders and Users](#2-stakeholders-and-users)
3. [Functional Requirements](#3-functional-requirements)
4. [Non-Functional Requirements](#4-non-functional-requirements)
5. [Data Requirements](#5-data-requirements)
6. [Machine Learning Requirements](#6-machine-learning-requirements)
7. [System Architecture Requirements](#7-system-architecture-requirements)
8. [Software Development Model](#8-software-development-model)
9. [Academic Documentation Requirements (Chapter 3 & 4)](#9-academic-documentation-requirements)
10. [Diagrams Reference](#10-diagrams-reference)

---

## 1. Project Overview

MaizeGuard is a multimodal AI system for detecting diseases in maize (corn) crops. It combines a Convolutional Neural Network (CNN) for leaf image classification with an Optical Character Recognition (OCR) subsystem for seed label parsing. The system targets Nigerian smallholder farmers and delivers on-device inference via a React Native Android application, with optional cloud-assisted AI advice through the Google Gemini API.

### Problem Statement
Maize diseases such as Northern Corn Leaf Blight (NCLB), Common Rust, and Gray Leaf Spot cause significant yield losses among smallholder farmers in Nigeria who lack timely access to agronomic expertise. Early detection and treatment recommendations can prevent losses of up to 40–70% per season.

### Solution Summary
A mobile application running a quantised EfficientNetB3 model fully on-device (no internet required) that classifies maize leaf images into 4 categories, records GPS-tagged scan history, and provides disease-specific treatment and prevention advice.

---

## 2. Stakeholders and Users

| Stakeholder | Role | Primary Need |
|---|---|---|
| Smallholder farmer | End user | Fast, offline disease diagnosis in the field |
| Extension worker | Secondary user | Survey tool for multiple farms |
| Agronomist / Researcher | Data consumer | Historical scan data and trend analysis |
| Developer team | Builders | Clear specifications and testable criteria |

---

## 3. Functional Requirements

### 3.1 Disease Classification (Core)

| ID | Requirement | Priority |
|---|---|---|
| FR-01 | The app SHALL classify a maize leaf image into one of four classes: NCLB, Rust, GLS, Healthy | Must Have |
| FR-02 | Classification SHALL run fully on-device using a TFLite INT8 model with no internet connection required | Must Have |
| FR-03 | The app SHALL display confidence scores for all four classes after each scan | Must Have |
| FR-04 | The app SHALL display the classification result within 2 seconds of image capture on Android API 24+ devices | Must Have |
| FR-05 | The app SHALL provide a disease description, treatment options, and prevention steps for each diagnosis | Must Have |
| FR-06 | The app SHALL fall back to the FP16 TFLite model if the INT8 GPU delegate fails to load | Should Have |

### 3.2 Image Capture

| ID | Requirement | Priority |
|---|---|---|
| FR-07 | The app SHALL allow image capture via the device camera with a viewfinder framing guide | Must Have |
| FR-08 | The app SHALL allow image selection from the device gallery | Must Have |
| FR-09 | The camera screen SHALL display a brightness warning when the scene is too dark (<60 luma) or too bright (>200 luma) | Should Have |
| FR-10 | The camera SHALL support tap-to-focus and auto-exposure | Should Have |

### 3.3 OCR — Seed Label Scanning

| ID | Requirement | Priority |
|---|---|---|
| FR-11 | The app SHALL extract crop variety from seed bag labels using ML Kit Text Recognition v2 | Must Have |
| FR-12 | The app SHALL extract batch number from seed labels using regex pattern matching | Must Have |
| FR-13 | The app SHALL extract planting date from seed labels and normalise it to ISO 8601 (YYYY-MM-DD) | Must Have |
| FR-14 | The OCR system SHALL match extracted variety text against 13 known Nigerian varieties using fuzzy string matching with a minimum score of 60 | Must Have |
| FR-15 | OCR-extracted metadata SHALL be associatable with a subsequent disease scan | Should Have |

**Supported Nigerian varieties:** SAMMAZ 15, SAMMAZ 17, SAMMAZ 29, SAMMAZ 34, SAMMAZ 50, OBA SUPER 2, EVDT 99, POOL 16 DT, TZEE-W, ABA WHITE, ACROSS 97, SUWAN 1, EARLY THRIVING

### 3.4 Scan History and Persistence

| ID | Requirement | Priority |
|---|---|---|
| FR-16 | The app SHALL persist all scan records locally in an SQLite database | Must Have |
| FR-17 | Each scan record SHALL store: image path, class ID, class name, confidence, all 4 scores, inference latency, GPS coordinates (if available), OCR fields (if scanned), and timestamp | Must Have |
| FR-18 | The History screen SHALL display all past scans in reverse chronological order | Must Have |
| FR-19 | The History screen SHALL support filtering by disease class | Should Have |
| FR-20 | The user SHALL be able to delete individual scan records | Should Have |

### 3.5 Dashboard and Analytics

| ID | Requirement | Priority |
|---|---|---|
| FR-21 | The Dashboard SHALL display a Farm Health Score (0–100) based on the ratio of healthy to diseased scans in the last 30 days | Must Have |
| FR-22 | The Dashboard SHALL display a 7-day scan activity bar chart | Should Have |
| FR-23 | The Dashboard SHALL display a disease breakdown showing count and percentage of each class | Should Have |

### 3.6 Farm Map

| ID | Requirement | Priority |
|---|---|---|
| FR-24 | The Map screen SHALL display GPS-tagged scan records as coloured markers on an OpenStreetMap base map | Should Have |
| FR-25 | Tapping a marker SHALL display the scan's disease class, confidence, and timestamp | Should Have |
| FR-26 | The map SHALL function offline using cached tiles | Could Have |

### 3.7 AI-Powered Advice

| ID | Requirement | Priority |
|---|---|---|
| FR-27 | The app SHALL generate agronomic recommendations using an on-device rule engine when no API key is configured | Must Have |
| FR-28 | When a Gemini API key is configured, the app SHALL send a structured prompt to Gemini 2.0 Flash and display the AI-generated response | Should Have |
| FR-29 | On-device recommendations SHALL account for: disease class, confidence level, scan trend (worsening/stable/improving), Nigerian farming season (main/off/dry), and specific fungicide options available in Nigeria | Must Have |
| FR-30 | The Gemini API key SHALL be stored in encrypted device secure storage (Keychain), not in plain text | Must Have |

### 3.8 Settings

| ID | Requirement | Priority |
|---|---|---|
| FR-31 | The app SHALL support light and dark mode themes | Should Have |
| FR-32 | The user SHALL be able to save or clear the Gemini API key from settings | Must Have |
| FR-33 | The settings screen SHALL display model status and metadata (model name, size, class count) | Should Have |

---

## 4. Non-Functional Requirements

### 4.1 Performance

| ID | Requirement | Target |
|---|---|---|
| NFR-01 | Inference latency (image capture → result displayed) | ≤ 2,000ms on Android API 24+, mid-range device |
| NFR-02 | App cold start to Home screen ready | ≤ 4 seconds |
| NFR-03 | TFLite model load time | ≤ 3 seconds (GPU delegate) / ≤ 5 seconds (CPU fallback) |
| NFR-04 | Database write per scan | ≤ 50ms |
| NFR-05 | Dashboard query (last 30 days) | ≤ 200ms |

### 4.2 Accuracy

| ID | Requirement | Target |
|---|---|---|
| NFR-06 | Overall classification accuracy on held-out test set | ≥ 90% |
| NFR-07 | Per-class F1 score (NCLB, Rust, GLS, Healthy) | ≥ 0.88 for each class |
| NFR-08 | OCR crop variety extraction accuracy on seed label test set | ≥ 80% |

### 4.3 Reliability

| ID | Requirement |
|---|---|
| NFR-09 | The app SHALL remain functional without an internet connection for all core features (FR-01 to FR-23) |
| NFR-10 | The app SHALL handle TFLite GPU delegate failure gracefully by falling back to CPU without crashing |
| NFR-11 | The app SHALL handle image decode failures gracefully and display a user-friendly error message |
| NFR-12 | The database SHALL not lose existing scan records on app update |

### 4.4 Compatibility

| ID | Requirement |
|---|---|
| NFR-13 | The app SHALL support Android API level 24 (Android 7.0) and above |
| NFR-14 | The app SHALL support arm64-v8a and armeabi-v7a CPU architectures |
| NFR-15 | The app SHALL be tested on Android API 24, 30, and 33 |

### 4.5 Security

| ID | Requirement |
|---|---|
| NFR-16 | API keys SHALL be stored using Android Keystore-backed secure storage, never in SharedPreferences or plain files |
| NFR-17 | All network communication (Gemini API) SHALL use HTTPS only |
| NFR-18 | The app SHALL NOT transmit captured images to external servers |

### 4.6 Usability

| ID | Requirement |
|---|---|
| NFR-19 | The app SHALL be operable by a user with basic smartphone literacy (no prior ML or agronomy knowledge required) |
| NFR-20 | Disease results SHALL be displayed in plain language with actionable recommendations |
| NFR-21 | The UI SHALL be legible in bright outdoor sunlight (high-contrast GitHub-dark theme) |

### 4.7 Model Size

| ID | Requirement | Target |
|---|---|---|
| NFR-22 | TFLite INT8 model size | ≤ 15MB bundled in APK |
| NFR-23 | Total APK size | ≤ 80MB |

---

## 5. Data Requirements

### 5.1 Source of Data

| Dataset | Source | Purpose |
|---|---|---|
| **PlantVillage** | Kaggle: `smaranjitghose/corn-or-maize-leaf-disease-dataset` | Primary training dataset for CNN classifier |
| **Field photos** | Collected from Lagos farms | Domain adaptation; supplementary training images |
| **Seed label images** | Collected from local agro-dealers | OCR pipeline testing and validation |

### 5.2 Dataset Statistics

| Class | Label | Image Count | Proportion |
|---|---|---|---|
| 0 | NCLB (Northern Corn Leaf Blight) | 1,146 | 27.4% |
| 1 | Rust (Common Rust) | 1,306 | 31.2% |
| 2 | GLS (Gray Leaf Spot) | 574 | 13.7% |
| 3 | Healthy | 1,162 | 27.7% |
| **Total** | | **4,188** | **100%** |

### 5.3 Data Splits

| Split | Proportion | Count (approx.) |
|---|---|---|
| Training | 70% | 2,932 |
| Validation | 15% | 628 |
| Test | 15% | 628 |

All splits are **stratified** by class to preserve class proportions across sets.

### 5.4 Data Preprocessing

| Step | Detail |
|---|---|
| Resize | All images resized to 300×300 pixels (EfficientNetB3 native resolution) |
| Normalisation | **None applied externally.** EfficientNetB3 includes an internal `Rescaling(1/127.5, offset=-1)` layer; inputs are passed as raw [0, 255] uint8 |
| Augmentation (train only) | Horizontal flip, rotation ±20°, zoom ±15%, brightness ±10%, contrast ±10% |

### 5.5 Data Annotation Format

Annotations are stored in `data/annotations/labels.csv`:
```
image_path, class_id, class_name
data/raw/plantvillage/Blight/image001.jpg, 0, NCLB
...
```

Extended annotations with OCR metadata in `data/annotations/labels_with_metadata.csv`.

---

## 6. Machine Learning Requirements

### 6.1 CNN Classifier (Phase 1)

**Architecture: EfficientNetB3 with Transfer Learning**

```
Input: [1, 300, 300, 3]  uint8 [0, 255]
  └─► EfficientNetB3 backbone (ImageNet pretrained)
       Internal: Rescaling(1/127.5, offset=-1)
       MBConv blocks with Squeeze-Excitation
  └─► GlobalAveragePooling2D → (1536,)
  └─► BatchNormalization
  └─► Dense(512, activation='relu')
  └─► Dropout(0.4)
  └─► Dense(256, activation='relu')
  └─► Dropout(0.3)
  └─► Dense(4, activation='softmax')
Output: [1, 4]  float32  (class probabilities)
```

**Training Protocol:**

| Stage | Epochs | Learning Rate | Frozen Layers |
|---|---|---|---|
| Stage 1 — Feature extraction | 20 | 1×10⁻³ | All EfficientNetB3 layers frozen |
| Stage 2 — Fine-tuning | 30 | 1×10⁻⁵ | Layers 0–99 frozen; 100+ trainable |

**Training Configuration:**
- Optimizer: Adam
- Loss: Categorical Crossentropy
- Callbacks: EarlyStopping (patience=5), ReduceLROnPlateau (patience=3), ModelCheckpoint
- Class weights: Applied to address GLS class imbalance (574 vs 1,306 images)

**Acceptance Criteria:**
- Validation accuracy ≥ 90%
- Per-class F1 ≥ 0.88
- No single class precision < 0.80

### 6.2 OCR Subsystem (Phase 2)

**Pipeline:**
1. Grayscale conversion
2. Adaptive thresholding (Gaussian, block=11, C=2)
3. Deskew via Hough line detection
4. Morphological denoising
5. Tesseract 5 (LSTM) OCR — Page Segmentation Mode 6
6. Fuzzy field extraction (FuzzyWuzzy partial ratio, threshold=60)

**Extracted Fields:**
| Field | Method | Example |
|---|---|---|
| `crop_variety` | Fuzzy match against 13 known varieties | "SAMMAZ 15" |
| `batch_number` | Regex (BN-YYYY-NNN / LOT # / BATCH NO:) | "BN-2024-001" |
| `planting_date` | Multi-pattern regex + ISO normalisation | "2024-03-15" |

**Feature Encoding:** 24-dimensional vector: 13-d one-hot (variety) + 1 (batch present) + 1 (batch year) + 2 (planting month sin/cos) + 7 (padding)

### 6.3 Multimodal Fusion (Phase 3)

**Architecture: Dual-input Keras Functional Model**

```
Image branch:
  Input (300,300,3) → EfficientNetB3 (frozen) → Dense(256) → 256-d

OCR branch:
  Input (24,) → Dense(32) → BatchNorm → 32-d

Fusion:
  Concatenate → (288,) → Dense(128, relu) → Dropout(0.3) → Dense(4, softmax)
```

- Target: ≥ CNN baseline + 5% accuracy gain
- Training: Adam (LR=5×10⁻⁴), 50 epochs, same augmentation as Phase 1

### 6.4 Edge Deployment (Phase 4)

**TFLite Quantisation:**
| Format | Size | Target Device |
|---|---|---|
| INT8 (primary) | ~13MB | Android phones, Raspberry Pi 4 |
| FP16 (fallback) | ~23MB | Android phones (GPU fallback) |

- INT8 calibration: 200 representative images from training set
- INT8 output dequantisation: `score = (raw_uint8 − zero_point) × scale` where scale=0.00390625, zero_point=0

### 6.5 UAV Integration (Phase 5)

- Grid mission waypoint generation (QGC/Mission Planner `.waypoints` format)
- Orthomosaic tiling → per-patch TFLite inference → disease classification per grid cell
- Output: Folium interactive HTML heatmap + Matplotlib static PNG
- Inference target: < 2s per 300×300 patch on Raspberry Pi 4

---

## 7. System Architecture Requirements

### 7.1 Architectural Layers

```
┌─────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER                                      │
│  React Native screens (Android)                         │
│  Home · Camera · Result · OCR · Dashboard               │
│  History · Map · Recommendation · Settings              │
├─────────────────────────────────────────────────────────┤
│  BUSINESS LOGIC LAYER                                    │
│  classifier.ts   — TFLite inference + INT8 dequant      │
│  ocrService.ts   — ML Kit OCR + regex field extraction  │
│  recommendationEngine.ts — on-device rule engine        │
│  aiAdvisor.ts    — Gemini 2.0 Flash API client          │
│  locationService.ts — GPS tagging                        │
├─────────────────────────────────────────────────────────┤
│  DATA LAYER                                              │
│  op-sqlite (local SQLite) — scan_records table          │
│  AsyncStorage — theme preference                        │
│  Android Keychain — Gemini API key                      │
│  react-native-fast-tflite — model in memory             │
├─────────────────────────────────────────────────────────┤
│  ML CORE                                                 │
│  efficientnetb3_maize_int8.tflite  (~13MB)              │
│  efficientnetb3_maize_fp16.tflite  (~23MB, fallback)    │
│  Trained on PlantVillage, 4 classes, 300×300 input      │
└─────────────────────────────────────────────────────────┘
```

### 7.2 Technology Stack

| Component | Technology | Version |
|---|---|---|
| Mobile framework | React Native | 0.73.6 |
| Language | TypeScript | 5.0.4 |
| TFLite inference | react-native-fast-tflite | ^1.3.0 |
| Camera | react-native-vision-camera | ^4.3.2 |
| Image preprocessing | @shopify/react-native-skia | ^1.2.3 |
| OCR | @react-native-ml-kit/text-recognition | ^1.1.0 |
| Database | @op-engineering/op-sqlite | ^8.0.5 |
| Maps | react-native-maps + OSM UrlTile | ^1.14.0 |
| Charts | victory-native | ^41.6.0 |
| Navigation | @react-navigation/native | ^6.1.17 |
| State management | Zustand | ^4.5.2 |
| Secure storage | react-native-keychain | ^8.2.0 |
| GPS | react-native-geolocation-service | ^5.3.1 |
| ML training | TensorFlow / Keras | 2.16.2 |
| OCR training pipeline | Python + Tesseract 5 | 3.12 |
| Minimum Android API | API 24 (Android 7.0) | — |

### 7.3 Data Flow

**Disease Scan Flow:**
```
[Farmer] → Take photo (Camera / Gallery)
         → Skia decode + resize to 300×300
         → rgbaToRgb() strip alpha channel
         → TFLite model.run([rgbUint8])
         → INT8 dequantise → softmax scores [4]
         → argmax → class_id + confidence
         → GPS tag (if permitted)
         → SQLite INSERT scan_records
         → Navigate to Result screen
         → (Optional) Navigate to Recommendation
         → aiAdvisor (Gemini API or on-device engine)
```

**OCR Flow:**
```
[Farmer] → Take photo of seed label
         → ML Kit TextRecognition.recognize(imagePath)
         → extractFields(rawText):
             fuzzyMatchVariety() → crop_variety
             regex BATCH_PATTERNS → batch_number
             regex DATE_PATTERNS  → planting_date
         → Store as pendingLabel in Zustand
         → Associate with next disease scan
```

### 7.4 Database Schema

**Table: `scan_records`**

| Column | Type | Description |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | Unique scan identifier |
| `image_path` | TEXT NOT NULL | Absolute path to captured JPEG |
| `class_id` | INTEGER NOT NULL | 0=NCLB, 1=Rust, 2=GLS, 3=Healthy |
| `class_name` | TEXT NOT NULL | Full disease name |
| `short_name` | TEXT NOT NULL | Abbreviation (NCLB / Rust / GLS / Healthy) |
| `confidence` | REAL NOT NULL | Top class confidence [0.0, 1.0] |
| `all_scores` | TEXT NOT NULL | JSON array of 4 scores |
| `latency_ms` | REAL NOT NULL | Inference time in milliseconds |
| `latitude` | REAL (nullable) | GPS latitude if location was granted |
| `longitude` | REAL (nullable) | GPS longitude if location was granted |
| `crop_variety` | TEXT (nullable) | OCR-extracted variety name |
| `batch_number` | TEXT (nullable) | OCR-extracted batch number |
| `planting_date` | TEXT (nullable) | OCR-extracted date (ISO 8601) |
| `scanned_at` | TEXT NOT NULL | ISO 8601 datetime (UTC) |
| `notes` | TEXT (nullable) | User-edited notes |

**Indexes:** `idx_scanned_at` (DESC), `idx_class_id`

---

## 8. Software Development Model

### Model: Iterative Phased Development

The project follows an **iterative, phase-gated development model** structured around 5 technical phases plus a mobile application track. Each phase has defined deliverables and acceptance criteria that must be met before the next phase begins.

```
Phase 1 ──► Phase 2 ──► Phase 3 ──► Phase 4 ──► Phase 5
CNN         OCR         Fusion      Edge         UAV
Classifier  Pipeline    Model       Deployment   Integration
   │           │           │           │            │
   └───────────┴───────────┴───────────┴────────────┘
                        Mobile App (parallel track)
                   React Native (Android-first)
```

**Phase Gate Criteria:**

| Phase | Gate Condition |
|---|---|
| Phase 1 → 2 | Validation accuracy ≥ 90% on held-out test set |
| Phase 2 → 3 | OCR extracts ≥ 80% of variety fields correctly on 10 seed label test images |
| Phase 3 → 4 | Fusion model accuracy ≥ CNN-only + 5% |
| Phase 4 → 5 | TFLite INT8 inference < 2s on Raspberry Pi 4 |
| Phase 5 | UAV demo generates disease heatmap from synthetic orthomosaic |

**Why iterative over waterfall:**
- ML model accuracy is empirically discovered — it cannot be fully specified upfront
- Each phase produces a working, testable artefact
- Mobile app development runs in parallel and integrates phase outputs as they are validated
- Feedback from real seed label images can revise OCR regex patterns without re-specifying the entire system

---

## 9. Academic Documentation Requirements

*This section maps directly to the supervisor observation for Chapter 3 and Chapter 4.*

### Chapter 3 Requirements

#### 9.1 Architectural Diagram
Present the four-layer architecture diagram from Section 7.1 with explanations:
- **Presentation Layer** — React Native UI, handles user interaction, camera, display
- **Business Logic Layer** — Services that orchestrate inference, OCR, database operations, and AI advice
- **Data Layer** — Local SQLite for persistence, secure storage for API keys, in-memory TFLite model
- **ML Core** — Quantised TFLite models bundled with the APK

#### 9.2 Data Flow Diagram (DFD)

**Level 0 (Context Diagram):**
- External entities: Farmer, PlantVillage Dataset, Gemini API
- System: MaizeGuard
- Flows: Image → MaizeGuard → Disease Report; Training Data → MaizeGuard (model training)

**Level 1 (System DFD):**
- Process 1.0: Image Capture (Camera / Gallery)
- Process 2.0: Image Preprocessing (Skia resize, RGBA→RGB)
- Process 3.0: TFLite Inference (EfficientNetB3)
- Process 4.0: Result Generation (dequantise, argmax, disease lookup)
- Process 5.0: Persistence (GPS tag, SQLite INSERT)
- Process 6.0: Recommendation (on-device engine / Gemini API)
- Data store: D1 — scan_records (SQLite)

#### 9.3 Entity Relationship Diagram (ERD)

The system has one primary entity:

```
┌─────────────────────────────────┐
│          SCAN_RECORD            │
├─────────────────────────────────┤
│ PK  id           INTEGER        │
│     image_path   TEXT           │
│     class_id     INTEGER        │
│     class_name   TEXT           │
│     short_name   TEXT           │
│     confidence   REAL           │
│     all_scores   TEXT (JSON)    │
│     latency_ms   REAL           │
│     latitude     REAL (null)    │
│     longitude    REAL (null)    │
│     crop_variety TEXT (null)    │
│     batch_number TEXT (null)    │
│     planting_date TEXT (null)   │
│     scanned_at   TEXT           │
│     notes        TEXT (null)    │
└─────────────────────────────────┘
```

Future extension: a `FARM` entity with a one-to-many relationship to `SCAN_RECORD` (one farm → many scans), enabling multi-farm tracking by extension workers.

#### 9.4 Software Development Model (Chapter 3)
Present the **Iterative Phased Model** from Section 8 with a diagram showing the 5 phases, gate conditions, and the parallel mobile app track. Explain why iterative was chosen over waterfall for ML projects.

#### 9.5 Source of Data (Chapter 3 — Data-Driven Section)
- **PlantVillage dataset** — public benchmark; cite Hughes & Salathé (2015)
- 4,188 images across 4 classes (full breakdown in Section 5.2)
- Stratified 70/15/15 split
- Supplementary field photos from Lagos farms (pending collection)

#### 9.6 Data Size
Total dataset: 4,188 images  
Training set: ~2,932 images  
Validation set: ~628 images  
Test set: ~628 images  
Storage: ~340MB raw (average ~81KB per JPEG, 300×300 after resize)

#### 9.7 Model Diagram (Chapter 3)
Present the EfficientNetB3 architecture diagram from Section 6.1 showing:
- Input tensor shape [1, 300, 300, 3]
- Backbone (MBConv blocks with SE)
- Classification head (GAP → BN → Dense → Dropout chain)
- Output tensor shape [1, 4]
- INT8 quantisation box around the deployment model

#### 9.8 Explanation of ML Algorithms (Chapter 3)

**EfficientNetB3 (Convolutional Neural Network):**
EfficientNetB3 uses compound scaling to simultaneously scale model depth, width, and input resolution using a fixed scaling coefficient. It employs Mobile Inverted Bottleneck Convolution (MBConv) blocks with Squeeze-and-Excitation (SE) attention, which adaptively recalibrates channel-wise feature responses. Transfer learning from ImageNet is applied using a two-stage protocol: (1) freezing the backbone and training only the classification head to rapidly learn disease-specific features, then (2) unfreezing deeper layers for fine-tuning at a lower learning rate.

**INT8 Post-Training Quantisation:**
Reduces model weight and activation precision from 32-bit floating point to 8-bit integer. A representative calibration dataset of 200 images is used to determine the optimal quantisation scale and zero-point parameters per layer. This reduces model size from ~49MB to ~13MB and enables GPU-accelerated inference on mobile devices via the TensorFlow Lite GPU delegate.

**Tesseract LSTM + Fuzzy Matching (OCR):**
Tesseract 5 uses a Long Short-Term Memory (LSTM) recurrent neural network for sequence-to-sequence character recognition. After raw text extraction, fuzzy string matching (Levenshtein edit distance with a sliding partial-ratio window) identifies crop variety names even when OCR introduces character substitutions or spacing errors.

---

### Chapter 4 Requirements

#### 9.9 Screenshots with Explanation (Software Dev Project)

| Screen | What to Show | What to Explain |
|---|---|---|
| Home Screen | Model status "EfficientNetB3 ready", action buttons, recent scans list | Entry point; shows model is loaded on-device; no internet needed |
| Camera Screen | Viewfinder with green corner markers, brightness hint banner | Guided framing improves classification accuracy |
| Result Screen | Disease label, confidence percentage, 4-class score bars, treatment list | Communicates diagnosis confidence; non-technical language |
| OCR Screen | Extracted crop variety, batch number, planting date vs raw OCR text | Enables seed traceability linked to disease records |
| Dashboard | Health score arc (e.g. 72/100), 7-day bar chart, disease breakdown | Trend monitoring over time, not just per-scan |
| History Screen | Filterable list with disease colour labels, GPS icon, confidence | Full audit trail of all scans |
| Map Screen | OSM map with coloured disease markers | Spatial disease distribution across the farm |
| Recommendation | On-device vs Gemini AI advice badge, formatted action steps | Two-tier advice system explained |
| Settings | Dark/light toggle, API key input, model metadata | User control and transparency |

#### 9.10 Model Training, Testing and Evaluation Results (Data-Driven Project)

Run after full training (`bash run_all.sh --full`):

```bash
python src/phase1_cnn/evaluate.py
```

**Graphs to include:**
1. **Training curves** — Loss and accuracy vs epoch for both stages (Stage 1: epochs 1–20, Stage 2: epochs 21–50)
2. **Confusion matrix** — 4×4 heatmap showing predicted vs actual class
3. **Per-class metrics bar chart** — Precision, Recall, F1 side-by-side for each class
4. **ROC curves** — One-vs-rest ROC curve per class with AUC values
5. **Fusion vs CNN-only comparison** — Bar chart comparing accuracy of: CNN-only vs CNN+OCR fusion

**Expected result format:**

| Class | Precision | Recall | F1-Score | Support |
|---|---|---|---|---|
| NCLB | ≥0.90 | ≥0.88 | ≥0.89 | ~172 |
| Rust | ≥0.92 | ≥0.91 | ≥0.91 | ~196 |
| GLS | ≥0.85 | ≥0.88 | ≥0.86 | ~86 |
| Healthy | ≥0.91 | ≥0.90 | ≥0.90 | ~174 |
| **Overall** | | | **≥ 0.90** | **628** |

#### 9.11 Comparison with Existing Research

| Study | Model | Dataset | Accuracy |
|---|---|---|---|
| Mohanty et al. (2016) ¹ | AlexNet / GoogLeNet | PlantVillage (26 diseases, 54,306 images) | 99.35% (lab); 31.4% (field) |
| Hughes & Salathé (2015) ² | SVM + HOG features | PlantVillage | 72–99% per crop |
| Ramcharan et al. (2017) ³ | Inception V3 | Cassava (field photos) | 93% |
| **MaizeGuard (This work)** | **EfficientNetB3 INT8** | **PlantVillage (4 classes, 4,188 images)** | **Target ≥ 90%** |

**Key differentiators of this work:**
1. **On-device inference** — no server required; runs fully offline on Android
2. **Multimodal fusion** — combines visual classification with OCR seed label metadata
3. **Targeted deployment** — Nigerian smallholder context with variety-specific advice
4. **INT8 quantisation** — 13MB model vs 49MB+ for floating-point alternatives
5. **UAV integration** — field-scale disease heatmap generation

¹ Mohanty, S.P., Hughes, D.P. & Salathé, M. (2016). Using Deep Learning for Image-Based Plant Disease Detection. *Frontiers in Plant Science*, 7, 1419.  
² Hughes, D. & Salathé, M. (2015). An open access repository of images on plant health to enable the development of mobile disease diagnostics. *arXiv:1511.08060*.  
³ Ramcharan, A., Baranowski, K., McCloskey, P., Ahmed, B., Legg, J. & Hughes, D. (2017). Deep Learning for Image-Based Cassava Disease Detection. *Frontiers in Plant Science*, 8, 1852.

---

## 10. Diagrams Reference

All diagrams listed below should be drawn in a tool such as draw.io, Lucidchart, or Microsoft Visio and included in Chapter 3 of the project report.

| Diagram | Type | Section in this doc |
|---|---|---|
| System Architecture | Layered box diagram | 7.1 |
| Data Flow Diagram Level 0 | Context DFD | 9.2 |
| Data Flow Diagram Level 1 | Process DFD | 9.2 |
| Entity Relationship Diagram | ERD | 9.3 |
| Development Model | Phase-gate flowchart | 8 |
| CNN Architecture | Neural net layer diagram | 6.1 |
| Inference Pipeline | Flowchart | 7.3 |

---

*Last updated: 2026-06-13*
