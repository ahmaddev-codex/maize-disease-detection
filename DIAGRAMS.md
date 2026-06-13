# MaizeGuard — System Diagrams

> All diagrams below are text-based representations (ASCII art) suitable for
> inclusion in the project report. Use draw.io or Lucidchart to redraw them
> in a polished format for the final submission.

---

## Diagram 1 — System Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        MAIZEGUARD SYSTEM ARCHITECTURE                    │
└──────────────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────────┐
  │  LAYER 1 — PRESENTATION (React Native UI)                            │
  │                                                                      │
  │   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐           │
  │   │  Home    │  │ Camera   │  │ Result   │  │   OCR    │           │
  │   │ Screen   │  │ Screen   │  │ Screen   │  │  Screen  │           │
  │   └──────────┘  └──────────┘  └──────────┘  └──────────┘           │
  │   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐           │
  │   │Dashboard │  │ History  │  │   Map    │  │Settings  │           │
  │   │ Screen   │  │ Screen   │  │  Screen  │  │  Screen  │           │
  │   └──────────┘  └──────────┘  └──────────┘  └──────────┘           │
  └─────────────────────────┬────────────────────────────────────────────┘
                             │ calls
  ┌──────────────────────────▼───────────────────────────────────────────┐
  │  LAYER 2 — BUSINESS LOGIC (Services)                                 │
  │                                                                      │
  │  ┌───────────────┐  ┌───────────────┐  ┌──────────────────────┐    │
  │  │ classifier.ts │  │ ocrService.ts │  │ recommendationEngine  │    │
  │  │ TFLite infer  │  │ ML Kit + Regex│  │ On-device rules      │    │
  │  └───────────────┘  └───────────────┘  └──────────────────────┘    │
  │  ┌───────────────┐  ┌───────────────┐  ┌──────────────────────┐    │
  │  │  aiAdvisor.ts │  │ locationSvc   │  │     database.ts      │    │
  │  │  Gemini API   │  │ GPS Tagging   │  │  op-sqlite (DAO)     │    │
  │  └───────────────┘  └───────────────┘  └──────────────────────┘    │
  └─────────────────────────┬────────────────────────────────────────────┘
                             │ reads/writes
  ┌──────────────────────────▼───────────────────────────────────────────┐
  │  LAYER 3 — DATA                                                       │
  │                                                                      │
  │   ┌─────────────────┐  ┌─────────────────┐  ┌──────────────────┐   │
  │   │  SQLite DB       │  │  AsyncStorage   │  │ Android Keychain │   │
  │   │ scan_records tbl │  │ theme prefs     │  │ Gemini API key   │   │
  │   └─────────────────┘  └─────────────────┘  └──────────────────┘   │
  └─────────────────────────┬────────────────────────────────────────────┘
                             │ loads
  ┌──────────────────────────▼───────────────────────────────────────────┐
  │  LAYER 4 — ML CORE (Bundled TFLite Models)                           │
  │                                                                      │
  │   ┌────────────────────────────────────────────────────────────┐    │
  │   │  efficientnetb3_maize_int8.tflite  (~13 MB)  ← PRIMARY    │    │
  │   │  Input:  [1, 300, 300, 3]  uint8   [0–255]                │    │
  │   │  Output: [1, 4]            uint8   (dequantised → float)   │    │
  │   └────────────────────────────────────────────────────────────┘    │
  │   ┌────────────────────────────────────────────────────────────┐    │
  │   │  efficientnetb3_maize_fp16.tflite  (~23 MB)  ← FALLBACK   │    │
  │   └────────────────────────────────────────────────────────────┘    │
  └──────────────────────────────────────────────────────────────────────┘

   External Services (optional, online only):
   ┌─────────────────────────────────────────┐
   │  Google Gemini 2.0 Flash API (HTTPS)    │
   │  AI-powered agronomic advice            │
   └─────────────────────────────────────────┘
```

---

## Diagram 2 — Data Flow Diagram: Level 0 (Context Diagram)

```
                         ┌───────────────────────────────┐
                         │                               │
   ┌──────────┐          │         MAIZEGUARD            │          ┌──────────────────┐
   │          │  Image   │                               │  Prompt  │                  │
   │  FARMER  │─────────►│    AI-Powered Maize Disease   │─────────►│   Gemini 2.0     │
   │          │◄─────────│    Detection System           │◄─────────│   Flash API      │
   │          │ Disease  │                               │  Advice  │                  │
   └──────────┘  Report  │                               │          └──────────────────┘
                         │                               │
   ┌──────────┐          │                               │
   │PlantVill.│ Training │                               │
   │ Dataset  │─────────►│                               │
   │(Kaggle)  │  Images  │                               │
   └──────────┘          └───────────────────────────────┘
```

**Explanation:**
- The **Farmer** sends a leaf image to the system and receives a disease report (diagnosis + treatment advice)
- The **PlantVillage Dataset** provides training images used offline during model training (not at runtime)
- The **Gemini 2.0 Flash API** is an optional external service; the system works fully offline without it

---

## Diagram 3 — Data Flow Diagram: Level 1

```
┌────────┐
│ FARMER │
└───┬────┘
    │ Leaf photo / seed label photo
    ▼
┌──────────────────────────────────────────────────────────────────────┐
│  1.0  IMAGE CAPTURE                                                  │
│  (Camera / Gallery / OCR Camera)                                     │
└──────┬──────────────────────────────────────────────────────────────┘
       │ JPEG file path
       ▼
┌──────────────────────────────────────────────────────────────────────┐
│  2.0  IMAGE PREPROCESSING                                            │
│  • Skia decode JPEG → pixel buffer                                   │
│  • Draw onto 300×300 offscreen surface                               │
│  • readPixels() → RGBA Uint8Array                                    │
│  • rgbaToRgb() → strip alpha → RGB Uint8Array [270,000 bytes]        │
└──────┬──────────────────────────────────────────────────────────────┘
       │ RGB [1, 300, 300, 3]
       ▼
┌──────────────────────────────────────────────────────────────────────┐
│  3.0  TFLITE INFERENCE                                               │
│  • model.run([rgbUint8])                                             │
│  • EfficientNetB3 forward pass (INT8 quantised)                      │
│  • Raw output: [1, 4] uint8                                          │
└──────┬──────────────────────────────────────────────────────────────┘
       │ Raw uint8 scores [4]
       ▼
┌──────────────────────────────────────────────────────────────────────┐
│  4.0  RESULT GENERATION                                              │
│  • Dequantise: score = (raw − 0) × 0.00390625                       │
│  • Normalise to sum = 1                                              │
│  • argmax → class_id (0=NCLB, 1=Rust, 2=GLS, 3=Healthy)            │
│  • Lookup DiseaseInfo (name, treatments, severity)                   │
└──────┬──────────────────────────┬───────────────────────────────────┘
       │ class_id, confidence      │ (parallel)
       ▼                           ▼
┌──────────────────┐    ┌──────────────────────────────────────────────┐
│  5.0  GPS TAG    │    │  6.0  OCR PIPELINE (if seed scanned)         │
│  getCurrentPos() │    │  • ML Kit TextRecognition.recognize()        │
│  → lat, long     │    │  • fuzzyMatchVariety() → crop_variety        │
└──────┬───────────┘    │  • regex → batch_number, planting_date       │
       │                └──────────────────┬───────────────────────────┘
       │ lat/long                          │ SeedLabelData
       ▼                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│  7.0  PERSISTENCE                                                    │
│  INSERT INTO scan_records                                            │
│  (image_path, class_id, confidence, all_scores, lat, long,          │
│   crop_variety, batch_number, planting_date, scanned_at)            │
│                              ┌─────────────────┐                    │
│                              │  D1: scan_records│                    │
│                              │   (SQLite)       │                    │
│                              └─────────────────┘                    │
└──────┬───────────────────────────────────────────────────────────────┘
       │ ScanRecord
       ▼
┌──────────────────────────────────────────────────────────────────────┐
│  8.0  RECOMMENDATION ENGINE                                          │
│  ┌─────────────────────┐       ┌──────────────────────────────┐     │
│  │  On-device rules    │  OR   │  Gemini 2.0 Flash API        │     │
│  │  (season / urgency  │       │  (POST with structured prompt │     │
│  │   / fungicides)     │       │   → formatted advice text)   │     │
│  └─────────────────────┘       └──────────────────────────────┘     │
└──────┬───────────────────────────────────────────────────────────────┘
       │ Disease report + treatment advice
       ▼
┌────────┐
│ FARMER │  ← Result Screen + Recommendation Screen
└────────┘
```

---

## Diagram 4 — Entity Relationship Diagram (ERD)

```
 ┌─────────────────────────────────────────────────────────────────┐
 │                        SCAN_RECORD                              │
 ├──────────────────┬──────────────┬──────────────────────────────┤
 │  ATTRIBUTE       │  DATA TYPE   │  NOTES                       │
 ├──────────────────┼──────────────┼──────────────────────────────┤
 │ PK  id           │ INTEGER      │ Auto-increment               │
 │     image_path   │ TEXT         │ Absolute path to JPEG file   │
 │     class_id     │ INTEGER      │ FK → DISEASE_CLASS.id        │
 │     class_name   │ TEXT         │ e.g. "Northern Corn Leaf…"   │
 │     short_name   │ TEXT         │ NCLB / Rust / GLS / Healthy  │
 │     confidence   │ REAL         │ [0.0, 1.0]                   │
 │     all_scores   │ TEXT (JSON)  │ "[0.12, 0.75, 0.08, 0.05]"  │
 │     latency_ms   │ REAL         │ Inference time               │
 │     latitude     │ REAL (null)  │ GPS — nullable               │
 │     longitude    │ REAL (null)  │ GPS — nullable               │
 │     crop_variety │ TEXT (null)  │ OCR-extracted — nullable     │
 │     batch_number │ TEXT (null)  │ OCR-extracted — nullable     │
 │     planting_date│ TEXT (null)  │ ISO 8601 — nullable          │
 │     scanned_at   │ TEXT         │ ISO 8601 datetime (UTC)      │
 │     notes        │ TEXT (null)  │ User notes — nullable        │
 └──────────────────┴──────────────┴──────────────────────────────┘
          │
          │ class_id references
          ▼
 ┌─────────────────────────────────────────────────────────────────┐
 │                       DISEASE_CLASS  (lookup, not stored in DB) │
 ├──────────────────┬──────────────┬──────────────────────────────┤
 │ PK  id           │ INTEGER      │ 0, 1, 2, 3                   │
 │     short_name   │ TEXT         │ NCLB / Rust / GLS / Healthy  │
 │     full_name    │ TEXT         │ Northern Corn Leaf Blight…   │
 │     severity     │ TEXT         │ high / medium / low / none   │
 │     color_hex    │ TEXT         │ #F85149 / #E3B341 / …        │
 └──────────────────┴──────────────┴──────────────────────────────┘

  Relationship:
  SCAN_RECORD ──── (class_id) ──── DISEASE_CLASS
  Many scan records may share the same disease class.
  Cardinality: SCAN_RECORD (M) ──── (1) DISEASE_CLASS

  Future extension:
  ┌──────────┐         ┌──────────────┐
  │  FARM    │─────────│ SCAN_RECORD  │
  │ id (PK)  │ 1     M │ farm_id (FK) │
  │ name     │         │ ...          │
  │ location │         └──────────────┘
  └──────────┘
```

---

## Diagram 5 — Software Development Model (Iterative Phased)

```
┌──────────────────────────────────────────────────────────────────────────┐
│            MAIZEGUARD — ITERATIVE PHASED DEVELOPMENT MODEL               │
└──────────────────────────────────────────────────────────────────────────┘

 ┌──────────────┐
 │   PLANNING   │  ← Dataset acquisition, system design, team role assignment
 └──────┬───────┘
        │
        ▼
 ┌──────────────────────────────────────────────────────────────────────┐
 │  PHASE 1 — CNN CLASSIFIER                                            │
 │  Build: data_pipeline.py → model.py → train.py → evaluate.py        │
 │  Output: EfficientNetB3 trained model (.keras)                       │
 │  ────────────────────────────────────────────────────────────────    │
 │  GATE: Validation accuracy ≥ 90%  ✔ / ✘ → iterate (more epochs)     │
 └──────┬───────────────────────────────────────────────────────────────┘
        │ PASS
        ▼
 ┌──────────────────────────────────────────────────────────────────────┐
 │  PHASE 2 — OCR SUBSYSTEM                                             │
 │  Build: preprocessor.py → extractor.py → encoder.py                 │
 │  Output: 24-d feature vector from seed label photos                  │
 │  ────────────────────────────────────────────────────────────────    │
 │  GATE: ≥ 80% variety extraction accuracy on 10 test labels  ✔ / ✘   │
 └──────┬───────────────────────────────────────────────────────────────┘
        │ PASS
        ▼
 ┌──────────────────────────────────────────────────────────────────────┐
 │  PHASE 3 — MULTIMODAL FUSION                                         │
 │  Build: fusion_model.py → train_fusion.py                            │
 │  Output: Dual-input Keras model (CNN + OCR vector)                   │
 │  ────────────────────────────────────────────────────────────────    │
 │  GATE: Fusion accuracy ≥ CNN-only + 5%  ✔ / ✘                       │
 └──────┬───────────────────────────────────────────────────────────────┘
        │ PASS
        ▼
 ┌──────────────────────────────────────────────────────────────────────┐
 │  PHASE 4 — EDGE DEPLOYMENT                                           │
 │  Build: convert_tflite.py → inference.py                             │
 │  Output: INT8 (.tflite, ~13 MB) + FP16 (.tflite, ~23 MB)            │
 │  ────────────────────────────────────────────────────────────────    │
 │  GATE: Inference < 2 s on Raspberry Pi 4  ✔ / ✘                     │
 └──────┬───────────────────────────────────────────────────────────────┘
        │ PASS
        ▼
 ┌──────────────────────────────────────────────────────────────────────┐
 │  PHASE 5 — UAV INTEGRATION                                           │
 │  Build: flight_planner.py → patch_runner.py → heatmap.py            │
 │  Output: Disease heatmap HTML + PNG from aerial imagery              │
 │  ────────────────────────────────────────────────────────────────    │
 │  GATE: Demo heatmap generated from synthetic orthomosaic  ✔ / ✘     │
 └──────┬───────────────────────────────────────────────────────────────┘
        │

  ════════════════ PARALLEL TRACK ════════════════════════════════════════
        │
        ▼
 ┌──────────────────────────────────────────────────────────────────────┐
 │  MOBILE APP — React Native (Android-first)                           │
 │  ┌─────────────────┐ ┌──────────────────┐ ┌─────────────────────┐  │
 │  │ Sprint A — Core │ │ Sprint B — UI    │ │ Sprint C — AI/Map   │  │
 │  │ Camera + TFLite │ │ Dashboard +      │ │ Gemini advisor +    │  │
 │  │ SQLite + OCR    │ │ History + Export │ │ Map + Settings      │  │
 │  └─────────────────┘ └──────────────────┘ └─────────────────────┘  │
 └──────────────────────────────────────────────────────────────────────┘
        │
        ▼
 ┌──────────────┐
 │   TESTING    │  ← Unit tests, device testing, user acceptance testing
 └──────┬───────┘
        │
        ▼
 ┌──────────────┐
 │  DEPLOYMENT  │  ← APK release + field evaluation
 └──────────────┘

  Legend:  ✔ = gate passed → proceed   ✘ = gate failed → iterate current phase
```

---

## Diagram 6 — CNN Architecture (EfficientNetB3)

```
 INPUT
 ┌──────────────────────────────┐
 │  Leaf Image                  │
 │  [1 × 300 × 300 × 3]        │  uint8  [0–255]  (RGB, no normalisation)
 └──────────────┬───────────────┘
                │
                ▼
 ┌──────────────────────────────┐
 │  EfficientNetB3 BACKBONE     │  ImageNet pretrained weights
 │                              │
 │  Internal Rescaling Layer    │  pixel = pixel/127.5 − 1  →  [−1, 1]
 │                              │
 │  ┌──────────────────────┐   │
 │  │  Stem Conv 3×3 /2    │   │  40 filters
 │  └──────────┬───────────┘   │
 │             │               │
 │  ┌──────────▼───────────┐   │
 │  │  MBConv Block ×2     │   │  Expand → Depthwise Conv → SE → Project
 │  │  (k=3, filters=24)   │   │  Squeeze-and-Excitation ratio 0.25
 │  └──────────┬───────────┘   │
 │             │               │
 │  ┌──────────▼───────────┐   │
 │  │  MBConv Block ×3     │   │  Stride 2 (downsample)
 │  │  (k=3, filters=32)   │   │
 │  └──────────┬───────────┘   │
 │             │               │
 │  ┌──────────▼───────────┐   │
 │  │  MBConv Block ×3     │   │
 │  │  (k=5, filters=48)   │   │
 │  └──────────┬───────────┘   │
 │             │               │
 │  ┌──────────▼───────────┐   │
 │  │  MBConv Block ×5     │   │  Stride 2 (downsample)
 │  │  (k=3, filters=96)   │   │
 │  └──────────┬───────────┘   │
 │             │               │
 │  ┌──────────▼───────────┐   │
 │  │  MBConv Block ×5     │   │
 │  │  (k=5, filters=136)  │   │
 │  └──────────┬───────────┘   │
 │             │               │
 │  ┌──────────▼───────────┐   │
 │  │  MBConv Block ×6     │   │  Stride 2 (downsample)
 │  │  (k=5, filters=232)  │   │
 │  └──────────┬───────────┘   │
 │             │               │
 │  ┌──────────▼───────────┐   │
 │  │  MBConv Block ×2     │   │
 │  │  (k=3, filters=384)  │   │
 │  └──────────┬───────────┘   │
 │             │               │
 │  ┌──────────▼───────────┐   │
 │  │  Head Conv 1×1       │   │  1536 filters → feature map
 │  └──────────┬───────────┘   │
 └─────────────┼───────────────┘
               │ Feature map (1536 channels)
               ▼
 ┌─────────────────────────────────────┐
 │  GlobalAveragePooling2D             │  → vector (1536,)
 └─────────────┬───────────────────────┘
               │
               ▼
 ┌─────────────────────────────────────┐
 │  BatchNormalization                 │  Stabilise activations
 └─────────────┬───────────────────────┘
               │
               ▼
 ┌─────────────────────────────────────┐
 │  Dense(512)  ReLU                   │  Learned disease features
 └─────────────┬───────────────────────┘
               │
               ▼
 ┌─────────────────────────────────────┐
 │  Dropout(0.4)                       │  Regularisation (training only)
 └─────────────┬───────────────────────┘
               │
               ▼
 ┌─────────────────────────────────────┐
 │  Dense(256)  ReLU                   │
 └─────────────┬───────────────────────┘
               │
               ▼
 ┌─────────────────────────────────────┐
 │  Dropout(0.3)                       │
 └─────────────┬───────────────────────┘
               │
               ▼
 ┌─────────────────────────────────────┐
 │  Dense(4)  Softmax                  │  One score per disease class
 └─────────────┬───────────────────────┘
               │  [p_NCLB,  p_Rust,  p_GLS,  p_Healthy]
               ▼
 OUTPUT
 ┌──────────────────────────────────────────────┐
 │  Class probabilities  [1 × 4]  float32       │
 │  e.g.  [0.05,  0.82,  0.09,  0.04]          │
 │         NCLB   Rust   GLS   Healthy          │
 │                  ▲                           │
 │            argmax → class_id = 1 (Rust)      │
 │            confidence = 82%                  │
 └──────────────────────────────────────────────┘

 ┌─────────────────────────────────────────────────────────────────┐
 │  INT8 QUANTISATION WRAPPER (deployment)                         │
 │  Full model above → TFLite converter with 200-image calibration │
 │  Weights: float32 → int8   (scale = 1/256, zeropoint = 0)      │
 │  Input:  uint8 [0–255]   Output: uint8 (dequantised in app)     │
 │  Size:   ~49 MB (float32)  →  ~13 MB (INT8)                    │
 └─────────────────────────────────────────────────────────────────┘
```

---

## Diagram 7 — Inference Pipeline (Flowchart)

```
  ┌─────────────────────────────┐
  │      FARMER OPENS APP       │
  └──────────────┬──────────────┘
                 │
                 ▼
  ┌─────────────────────────────┐     NO
  │  TFLite model loaded?       │──────────► Load model (GPU delegate)
  └──────────────┬──────────────┘                    │
                 │ YES                               │
                 │◄──────────────────────────────────┘
                 ▼
  ┌─────────────────────────────┐
  │  Select image source        │
  │  ○ Camera  ○ Gallery        │
  └──────────────┬──────────────┘
                 │
        ┌────────┴────────┐
        │                 │
        ▼                 ▼
  ┌──────────┐      ┌──────────┐
  │  Camera  │      │ Gallery  │
  │ takePho  │      │ launchIm │
  │ to()     │      │ agePick  │
  └────┬─────┘      └────┬─────┘
       │                 │
       └────────┬─────────┘
                │ JPEG file path
                ▼
  ┌─────────────────────────────┐
  │  RNFS.readFile(base64)      │
  │  Skia decode → pixel buffer │
  └──────────────┬──────────────┘
                 │
                 ▼
  ┌─────────────────────────────┐
  │  Draw on 300×300 Skia       │
  │  offscreen surface          │
  │  (bilinear resize)          │
  └──────────────┬──────────────┘
                 │
                 ▼
  ┌─────────────────────────────┐
  │  readPixels()               │
  │  → RGBA Uint8Array          │
  │  rgbaToRgb() strip alpha    │
  │  → RGB Uint8Array [270,000] │
  └──────────────┬──────────────┘
                 │
                 ▼
  ┌─────────────────────────────┐
  │  model.run([rgbUint8])      │
  │  EfficientNetB3 INT8        │
  │  forward pass               │
  └──────────────┬──────────────┘
                 │ raw uint8[4]
                 ▼
  ┌─────────────────────────────┐
  │  Dequantise:                │
  │  score = raw × 0.00390625  │
  │  Normalise → sum = 1.0      │
  │  argmax → class_id          │
  └──────────────┬──────────────┘
                 │
                 ▼
  ┌─────────────────────────────┐     YES  ┌─────────────────────┐
  │  Location permission        │─────────►│ getCurrentPosition() │
  │  granted?                   │          │ → lat, long          │
  └──────────────┬──────────────┘          └──────────┬──────────┘
                 │ NO                                  │
                 └──────────────────┬──────────────────┘
                                    │ (lat/long or null)
                                    ▼
                       ┌─────────────────────────────┐
                       │  INSERT scan_records        │
                       │  (SQLite via op-sqlite)     │
                       └──────────────┬──────────────┘
                                      │ scanId
                                      ▼
                       ┌─────────────────────────────┐
                       │  Navigate → Result Screen   │
                       │  Show: disease, confidence, │
                       │  4-class bars, treatments   │
                       └──────────────┬──────────────┘
                                      │ User taps "Get AI Advice"
                                      ▼
                       ┌─────────────────────────────┐
                       │  Gemini API key set?         │
                       └───────┬─────────────┬────────┘
                               │ YES          │ NO
                               ▼             ▼
                    ┌──────────────┐  ┌──────────────────────┐
                    │ POST Gemini  │  │ On-device engine:    │
                    │ 2.0 Flash    │  │ season + urgency +   │
                    │ API (HTTPS)  │  │ fungicide rules      │
                    └──────┬───────┘  └──────────┬───────────┘
                           └──────────┬───────────┘
                                      │ advice text
                                      ▼
                       ┌─────────────────────────────┐
                       │  Recommendation Screen      │
                       │  Display formatted advice   │
                       └─────────────────────────────┘
```

---

## Diagram 8 — Multimodal Fusion Architecture

```
        IMAGE INPUT                         OCR INPUT
   [1 × 300 × 300 × 3]                      [24-d vector]
          │                                       │
          ▼                                       ▼
  ┌───────────────────┐                  ┌──────────────────┐
  │  EfficientNetB3   │                  │   Dense(32)      │
  │  (frozen weights) │                  │   ReLU           │
  │                   │                  └────────┬─────────┘
  │  GlobalAvgPool2D  │                           │
  └────────┬──────────┘                  ┌────────▼─────────┐
           │                             │  BatchNorm       │
  ┌────────▼──────────┐                  └────────┬─────────┘
  │  Dense(256) ReLU  │                           │
  └────────┬──────────┘                           │
           │ 256-d features                        │ 32-d features
           └──────────────────┬────────────────────┘
                              │ Concatenate → 288-d
                              ▼
                   ┌─────────────────────┐
                   │   Dense(128) ReLU   │   Fusion layer
                   └──────────┬──────────┘
                              │
                   ┌──────────▼──────────┐
                   │    Dropout(0.3)     │
                   └──────────┬──────────┘
                              │
                   ┌──────────▼──────────┐
                   │   Dense(4) Softmax  │
                   └──────────┬──────────┘
                              │
                   [NCLB, Rust, GLS, Healthy]

  CNN-only accuracy:   ~27.8% (quick run) → target ≥ 90% (full training)
  Fusion accuracy:     ~42.3% (quick run) → target ≥ 95.8% (full training)
  Fusion gain:         +5% over CNN-only (design target)
```

---

*All diagrams above correspond to sections in [REQUIREMENTS.md](REQUIREMENTS.md).*  
*Redraw using draw.io (free at app.diagrams.net) for the final project report.*
