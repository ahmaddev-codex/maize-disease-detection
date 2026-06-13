# MaizeGuard — System Architecture & Developer Guide

> End-to-end maize disease detection for Nigerian smallholder farmers.  
> EfficientNetB3 · TFLite INT8 · On-device · Multi-platform.

---

> ⚠️ **Mobile platform updated 2026-06-13:** Flutter → React Native 0.73 (Android-first).  
> Active mobile source: `mobile/`   Flutter kept at `deployment/app/` for reference.

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Repository Layout](#2-repository-layout)
3. [Phase 1 — CNN Classifier](#3-phase-1--cnn-classifier)
4. [Phase 2 — OCR Subsystem](#4-phase-2--ocr-subsystem)
5. [Phase 3 — Multimodal Fusion](#5-phase-3--multimodal-fusion)
6. [Phase 4 — Edge Deployment](#6-phase-4--edge-deployment)
7. [Phase 5 — UAV Integration](#7-phase-5--uav-integration)
8. [React Native Mobile App](#8-react-native-mobile-app)
9. [Raspberry Pi GUI](#9-raspberry-pi-gui)
10. [Data Flow — End to End](#10-data-flow--end-to-end)
11. [Running the Full Pipeline](#11-running-the-full-pipeline)
12. [Environment Setup](#12-environment-setup)
13. [Model Performance Targets](#13-model-performance-targets)
14. [Team & Ownership](#14-team--ownership)

---

## 1. System Overview

MaizeGuard is a multi-platform AI system that detects maize leaf diseases from photographs
and aerial imagery, delivering actionable treatment recommendations entirely on-device with
no internet connection required.

```
┌──────────────────────────────────────────────────────────────────┐
│                       DATA SOURCES                               │
│  PlantVillage dataset (4,188 images)  ·  Field photographs       │
│  Seed bag labels (OCR)  ·  UAV orthomosaics                      │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                ┌────────▼────────┐
                │  Phase 1 — CNN  │  EfficientNetB3, two-stage fine-tune
                │  ≥90% val acc   │  Input: 300×300 RGB, Output: 4 classes
                └────────┬────────┘
                         │  Keras (.keras) → TFLite INT8 (13 MB)
            ┌────────────┼────────────┐
            │            │            │
   ┌────────▼──┐  ┌──────▼──────┐  ┌─▼────────────────┐
   │ Phase 2   │  │  Phase 3    │  │   Phase 4          │
   │ OCR       │  │  Fusion     │  │   TFLite Inference │
   │ Tesseract │  │  CNN+OCR    │  │   Pi / Jetson      │
   └────────┬──┘  └──────┬──────┘  └─┬────────────────-┘
            │             │            │
            └──────┬──────┘            │
                   │                   │
       ┌───────────▼──┐    ┌───────────▼──────────────────┐
       │  Phase 5     │    │  Mobile App (Flutter)         │
       │  UAV Survey  │    │  Android · macOS              │
       │  Heatmap     │    │  Camera · Gallery · OCR       │
       └──────────────┘    └──────────────────────────────-┘
```

### Disease Classes

| ID | Class | Description | Severity |
|----|-------|-------------|----------|
| 0 | NCLB | Northern Corn Leaf Blight (*Exserohilum turcicum*) — long grey-green lesions | High |
| 1 | Rust | Common Rust (*Puccinia sorghi*) — brick-red pustules on both surfaces | Medium |
| 2 | GLS | Gray Leaf Spot (*Cercospora zeae-maydis*) — rectangular grey-tan lesions | Medium |
| 3 | Healthy | No disease detected | — |

---

## 2. Repository Layout

```
maize-disease-detection/
│
├── src/
│   ├── phase1_cnn/
│   │   ├── data_pipeline.py    # Dataset loader, augmentation, train/val/test split
│   │   ├── model.py            # EfficientNetB3 architecture definition
│   │   ├── train.py            # Two-stage training loop + callbacks
│   │   └── evaluate.py         # Accuracy, confusion matrix, per-class report
│   │
│   ├── phase2_ocr/
│   │   ├── preprocessor.py     # Image: grayscale, threshold, deskew, denoise
│   │   ├── extractor.py        # Tesseract 5 OCR + field parsing (variety/batch/date)
│   │   └── encoder.py          # 24-d metadata feature vector
│   │
│   ├── phase3_fusion/
│   │   ├── fusion_model.py     # Functional API: CNN branch + OCR branch → dense head
│   │   └── train_fusion.py     # End-to-end fusion training
│   │
│   └── phase4_edge/
│       ├── convert_tflite.py   # INT8 + FP16 TFLite conversion with calibration
│       └── inference.py        # TFLite inference runner (Pi / Jetson / desktop)
│
├── deployment/
│   ├── app/                    # Flutter mobile app (Android + macOS)
│   │   ├── lib/
│   │   │   ├── main.dart
│   │   │   ├── screens/
│   │   │   │   ├── home_screen.dart      # Model status, action buttons
│   │   │   │   ├── camera_screen.dart    # Live camera with leaf framing guide
│   │   │   │   ├── result_screen.dart    # Confidence bars, treatment card
│   │   │   │   └── ocr_screen.dart       # Seed label scanner (Android/iOS)
│   │   │   ├── services/
│   │   │   │   ├── classifier.dart       # TFLite inference + preprocessing
│   │   │   │   └── ocr_service.dart      # ML Kit text recognition
│   │   │   ├── models/
│   │   │   │   └── prediction.dart       # Prediction + SeedLabelData + DiseaseInfo
│   │   │   └── theme/
│   │   │       └── app_theme.dart        # GitHub-dark colour palette
│   │   ├── android/                      # Android native configuration
│   │   ├── macos/                        # macOS native configuration + Podfile
│   │   └── assets/models/               # TFLite model files (copied from models/exports/)
│   │
│   ├── raspberry_pi/
│   │   └── app.py              # Tkinter dark-themed GUI for Pi 4 / Jetson
│   │
│   └── uav/
│       ├── flight_planner.py   # Grid mission waypoint generator → .waypoints file
│       ├── patch_runner.py     # Orthomosaic tiling + TFLite inference per patch
│       └── heatmap.py          # Folium interactive map + matplotlib static figure
│
├── models/
│   ├── checkpoints/            # Training checkpoints (ModelCheckpoint callbacks)
│   └── exports/
│       ├── efficientnetb3_maize.keras       # Full Keras model
│       ├── efficientnetb3_maize_int8.tflite # INT8 quantized (≈13 MB) ← deploy
│       ├── efficientnetb3_maize_fp16.tflite # FP16 fallback (≈23 MB)
│       └── fusion_model.keras               # Multimodal fusion model
│
├── data/
│   ├── raw/
│   │   ├── plantvillage/data/  # Blight/ Common_Rust/ Gray_Leaf_Spot/ Healthy/
│   │   ├── field_photos/       # Lagos field images (add to improve generalisation)
│   │   └── seed_labels/        # Seed bag label images for OCR testing
│   ├── annotations/
│   │   ├── labels.csv                # image_path, label, class_name, source
│   │   └── labels_with_metadata.csv  # + crop_variety, batch_number, planting_date
│   └── uav/
│       ├── farm_boundary.geojson    # Farm polygon for flight planning
│       ├── mission.waypoints        # Generated MAVLink mission file
│       ├── patch_predictions.csv    # Per-patch inference results
│       └── disease_heatmap.html     # Interactive Folium map
│
├── run_all.sh          # Full pipeline: Phases 1 → 2 → 3 → 4 → 5
├── setup_env.sh        # Python venv creation + pip install
├── requirements.txt
├── PLAN.md             # Build tracker (task checklist)
└── SYSTEM.md           # This file
```

---

## 3. Phase 1 — CNN Classifier

### Architecture

EfficientNetB3 (ImageNet pretrained) with a custom classification head:

```
Input (300×300×3, uint8 [0,255])
  └─ EfficientNetB3 backbone (internal Rescaling to [-1,1])
       └─ GlobalAveragePooling2D
            └─ BatchNormalization
                 └─ Dense(512, ReLU)
                      └─ Dropout(0.4)
                           └─ Dense(256, ReLU)
                                └─ Dropout(0.3)
                                     └─ Dense(4, Softmax)
```

**Critical**: EfficientNetB3 applies `Rescaling(1/127.5, offset=-1)` internally.
Input pixels must be in **[0, 255]** — do NOT divide by 255 before passing to the model.

### Two-Stage Training

| Stage | Layers frozen | LR | Optimizer | Epochs |
|-------|--------------|-----|-----------|--------|
| 1 — head only | All EfficientNetB3 layers | 1e-3 | AdamW (wd=1e-4) | 20 |
| 2 — fine-tune | Layers 0–100 frozen | 1e-5 | AdamW (wd=1e-4) | 30 |

**Stage 2 workaround**: Keras 3 has a bug where re-compiling an already-trained
model causes Adam slot variable shape mismatches. We work around this by:
1. Saving stage-1 weights to a temp `.weights.h5` file
2. Building a fresh model instance
3. Unfreezing layers 100+
4. Loading the saved weights
5. Compiling and training stage 2

### Key files

| File | Purpose |
|------|---------|
| `src/phase1_cnn/data_pipeline.py` | `load_and_preprocess()` — reads image, resizes to 300×300, casts to float32. Augmentation: flip, rotation, zoom, contrast, translation. |
| `src/phase1_cnn/model.py` | `build_model()`, `unfreeze_for_finetuning()` |
| `src/phase1_cnn/train.py` | CLI: `--csv`, `--batch-size`, `--stage1-epochs`, `--stage2-epochs` |
| `src/phase1_cnn/evaluate.py` | Confusion matrix, per-class precision/recall/F1 |

### Run

```bash
# Quick (3+3 epochs — sanity check):
python -m src.phase1_cnn.train --csv data/annotations/labels.csv

# Full training:
python -m src.phase1_cnn.train \
  --csv data/annotations/labels.csv \
  --stage1-epochs 20 --stage2-epochs 30

# Evaluate:
python -m src.phase1_cnn.evaluate \
  --model models/exports/efficientnetb3_maize.keras \
  --csv   data/annotations/labels.csv
```

---

## 4. Phase 2 — OCR Subsystem

Extracts structured metadata from seed bag label photographs entirely on-device.

### Pipeline

```
Raw image
  → Grayscale + adaptive threshold (preprocessor.py)
  → Deskew (Hough line detection)
  → Denoise (morphological open)
  → Tesseract 5 (Latin script, PSM 6 — uniform block)
  → Fuzzy field extraction (extractor.py)
  → 24-d feature vector (encoder.py)
```

### Extracted Fields

| Field | Method | Example |
|-------|--------|---------|
| `crop_variety` | Substring + fuzzy match against 13 known Nigerian varieties | `SAMMAZ 15` |
| `batch_number` | Regex: `BN-YYYY-NNN`, `LOT #`, `BATCH NO:` | `BN-2024-042` |
| `planting_date` | Regex: DD/MM/YYYY, YYYY-MM-DD, "15 March 2024" | `2024-03-15` |

### Feature vector (24 dimensions)

| Indices | Content |
|---------|---------|
| 0–12 | One-hot: 13 known variety names (all zeros = unknown) |
| 13 | `has_batch_number` (0/1) |
| 14 | Batch year normalised (0–1, 2020–2030 range) |
| 15 | Planting month sin component |
| 16 | Planting month cos component |
| 17–23 | Reserved (zeros) |

### Known varieties

SAMMAZ 15/17/29/34/50 · OBA SUPER 2 · EVDT 99 · POOL 16 DT · TZEE-W ·
ABA WHITE · ACROSS 97 · SUWAN 1 · EARLY THRIVING

### Run

```bash
python -m src.phase2_ocr.extractor --image data/raw/seed_labels/sample_label.jpg
```

---

## 5. Phase 3 — Multimodal Fusion

Fuses CNN image features with OCR metadata to improve prediction accuracy,
particularly for disease-variety correlations (e.g. NCLB risk in SAMMAZ varieties).

### Architecture

```
Image Input (300×300×3)               OCR vector (24-d)
  └─ EfficientNetB3 backbone (frozen)   └─ Dense(32, ReLU)
       └─ GlobalAveragePooling2D              └─ Dropout(0.2)
            └─ Dense(256, ReLU)                    │
                 └─ Dropout(0.3)                   │
                        └────────────┬─────────────┘
                                     │ Concatenate → (288-d)
                                     └─ Dense(128, ReLU)
                                          └─ Dropout(0.3)
                                               └─ Dense(4, Softmax)
```

### Run

```bash
python -m src.phase3_fusion.train_fusion \
  --metadata-csv  data/annotations/labels_with_metadata.csv \
  --cnn-weights   models/exports/efficientnetb3_maize.keras \
  --freeze-cnn \
  --epochs 25
```

---

## 6. Phase 4 — Edge Deployment

### TFLite Conversion

```bash
python -m src.phase4_edge.convert_tflite \
  --model models/exports/efficientnetb3_maize.keras \
  --csv   data/annotations/labels.csv
```

**INT8 quantization**: 200 representative images from the training set are used
to calibrate per-layer activation ranges. Input and output tensors are quantized
to uint8.

| Format | Size | Target |
|--------|------|--------|
| INT8 `.tflite` | ~13 MB | Raspberry Pi 4 · Android · Jetson Nano |
| FP16 `.tflite` | ~23 MB | Fallback for devices without INT8 delegate |

### Raspberry Pi Setup

```bash
# On the Pi:
pip install tflite-runtime pillow numpy
python deployment/raspberry_pi/app.py
```

### Benchmark

```bash
python -m src.phase4_edge.inference \
  --image  path/to/leaf.jpg \
  --model  models/exports/efficientnetb3_maize_int8.tflite \
  --benchmark
```

Target: **< 2 seconds** on Raspberry Pi 4 (4GB RAM).

---

## 7. Phase 5 — UAV Integration

Aerial survey of maize fields using a GPS-equipped drone, with on-ground or
edge-device disease mapping.

### Workflow

```
1. Mark farm boundary in QGroundControl → export GeoJSON
2. Generate flight plan (flight_planner.py) → .waypoints file
3. Upload .waypoints to Mission Planner / QGroundControl → fly
4. Process imagery with OpenDroneMap → orthomosaic GeoTIFF
5. Run patch inference (patch_runner.py) → patch_predictions.csv
6. Generate heatmap (heatmap.py) → disease_heatmap.html + .png
```

### Flight Parameters (defaults)

| Parameter | Value | Notes |
|-----------|-------|-------|
| Altitude AGL | 30 m | GSD ≈ 1.3 cm/px |
| Forward overlap | 80% | Required for photogrammetry |
| Side overlap | 70% | Required for photogrammetry |
| Patch size | 300×300 px | Matches model input |
| Stride | 150 px | 50% patch overlap |

### Step 1 — Flight Planning

```bash
# Demo (built-in 1-ha farm near Ibadan):
python -m deployment.uav.flight_planner --demo

# Real farm boundary:
python -m deployment.uav.flight_planner \
  --farm-geojson data/uav/farm_boundary.geojson \
  --altitude 30 \
  --overlap  80 \
  --sidelap  70 \
  --output   data/uav/mission.waypoints
```

Output `.waypoints` file is directly importable by:
- **Mission Planner** (File → Load WP File)
- **QGroundControl** (Plan → Import)
- **ArduPilot / PX4** autopilots

### Step 2 — Patch Inference

```bash
# Demo (synthetic orthomosaic):
python -m deployment.uav.patch_runner --demo

# Real GeoTIFF orthomosaic:
python -m deployment.uav.patch_runner \
  --image  data/uav/orthomosaic.tif \
  --model  models/exports/efficientnetb3_maize_int8.tflite \
  --output data/uav/patch_predictions.csv \
  --stride 150
```

### Step 3 — Disease Heatmap

```bash
python -m deployment.uav.heatmap \
  --csv    data/uav/patch_predictions.csv \
  --output data/uav/disease_heatmap.html
```

Opens `disease_heatmap.html` in any browser — interactive Esri satellite basemap
with colour-coded disease markers and a confidence heatmap overlay.

### Hardware Compatibility

| Platform | Notes |
|----------|-------|
| DJI Phantom 4 / Mavic | Default camera parameters pre-configured |
| Parrot Anafi | Adjust `--fov` for different sensor |
| ArduPilot SITL | Use `--demo` mode to test pipeline without hardware |
| Ground station laptop | Run inference post-flight using full TF |
| Raspberry Pi 4 | Run inference in the field with tflite-runtime |

---

## 8. React Native Mobile App

The primary farmer-facing tool. Runs EfficientNetB3 TFLite entirely on-device
with no network connection required.

### Supported Platforms

| Feature | Android | macOS |
|---------|---------|-------|
| TFLite inference | ✅ | ✅ |
| Live camera | ✅ | ❌ (camera package — Android/iOS only) |
| Gallery picker | ✅ | ✅ |
| OCR seed scanner | ✅ | ❌ (ML Kit — Android/iOS only) |

### Architecture

```
main.dart
  └─ HomeScreen
       ├─ MaizeClassifier (classifier.dart)
       │    ├─ Interpreter.fromAsset() — loads TFLite model from assets/models/
       │    ├─ compute() isolate — image decode + resize (300×300, [0,255])
       │    └─ interpreter.run() — INT8 quantized inference
       │
       ├─ CameraScreen (Android/iOS only)
       │    ├─ camera package — CameraController + CameraPreview
       │    ├─ Brightness hint (frame sampling every 15 frames)
       │    └─ Tap-to-focus + exposure point
       │
       ├─ ResultScreen
       │    ├─ LinearPercentIndicator — confidence bar
       │    ├─ Class score matrix (all 4 classes)
       │    └─ Treatment recommendation card
       │
       └─ OcrScreen (Android/iOS only)
            └─ OcrService → google_mlkit_text_recognition
```

### macOS Native Setup (required once)

```bash
cd deployment/app

# 1. Download the TFLite dylib (10 MB, one-time):
curl -L "https://github.com/CaptainDario/DaKanji-Dependencies/releases/download/v3.0.0/libtensorflowlite_c-mac.dylib.zip" \
  -o /tmp/tf.zip && unzip /tmp/tf.zip -d /tmp/
cp /tmp/libtensorflowlite_c-mac.dylib \
  ~/.pub-cache/hosted/pub.dev/tflite_flutter-0.12.1/macos/libtensorflowlite_c.dylib

# 2. Install CocoaPods dependencies:
cd macos && pod install && cd ..

# 3. Copy TFLite models to assets:
cp models/exports/efficientnetb3_maize_int8.tflite deployment/app/assets/models/
cp models/exports/efficientnetb3_maize_fp16.tflite deployment/app/assets/models/

# 4. Run:
flutter run -d macos
```

### Android Setup

```bash
cd deployment/app
flutter pub get
flutter run -d <device-id>     # or: flutter build apk --release
```

The Android build requires no manual native library steps — tflite_flutter
downloads the JNI `.so` via Gradle automatically.

### Inference Pipeline Detail

```dart
// classifier.dart

// 1. Load bytes from file (checks sandbox on macOS)
final bytes = await imageFile.readAsBytes();

// 2. Decode + resize in a Flutter compute isolate (avoids UI jank)
final input = await compute(_preprocessCompute, _PrepareArgs(bytes, tensorType, 300));
// → List<List<List<List<num>>>> shape [1, 300, 300, 3]

// 3. Allocate output list tflite_flutter can write into directly
final output = [List<int>.filled(4, 0)];  // INT8 model

// 4. Run inference (synchronous, fast — <500ms on modern Android)
interpreter.run(input, output);

// 5. Dequantize: score = (rawValue - zeroPoint) * scale
```

---

## 9. Raspberry Pi GUI

A standalone Tkinter application for field extension agents with desktop-class
hardware (Pi 4 + touchscreen or monitor + keyboard).

```bash
# On the Raspberry Pi:
pip install tflite-runtime pillow numpy
python deployment/raspberry_pi/app.py
```

Features:
- File browser to select leaf photo
- PiCamera2 capture (graceful fallback if no camera attached)
- Confidence bar (green ≥80%, amber ≥55%, red <55%)
- Per-class score bars for all 4 classes
- Treatment recommendation text
- Inference runs in a background thread (UI stays responsive)

---

## 10. Data Flow — End to End

```
┌────────────────────────────────────────────────────────────────┐
│  TRAINING  (runs on developer machine / Google Colab)          │
│                                                                 │
│  PlantVillage images  ──► data_pipeline.py                     │
│  (4,188 JPEG/PNG)           │ load_and_preprocess()            │
│                             │ cast to float32, [0, 255]        │
│                             ▼                                  │
│                       EfficientNetB3                           │
│                       Stage 1: 20 epochs (head only)           │
│                       Stage 2: 30 epochs (top layers unfrozen) │
│                             │                                  │
│                             ▼                                  │
│                  models/exports/efficientnetb3_maize.keras     │
│                             │                                  │
│                  convert_tflite.py                             │
│                  INT8 calibration (200 images)                 │
│                             │                                  │
│                             ▼                                  │
│                  efficientnetb3_maize_int8.tflite  (13 MB)     │
└───────────────────────────┬────────────────────────────────────┘
                            │  copy to deployment targets
              ┌─────────────┼───────────────────────┐
              │             │                       │
              ▼             ▼                       ▼
┌─────────────────┐  ┌─────────────┐   ┌──────────────────────┐
│  Flutter App    │  │ Raspberry   │   │  UAV Pipeline        │
│  assets/models/ │  │ Pi app.py   │   │  patch_runner.py     │
│                 │  │             │   │                      │
│  User picks a   │  │ User selects│   │ Orthomosaic tiled    │
│  leaf photo from│  │ photo or    │   │ into 300×300 patches │
│  gallery or     │  │ takes with  │   │                      │
│  camera         │  │ PiCamera2   │   │  TFLite inference    │
│       │         │  │      │      │   │  per patch           │
│       ▼         │  │      ▼      │   │       │              │
│  compute()      │  │  numpy      │   │  patch_predictions   │
│  isolate:       │  │  resize     │   │  .csv                │
│  PIL decode     │  │  [0,255]    │   │       │              │
│  + resize       │  │      │      │   │  heatmap.py          │
│  300×300 RGB    │  │      │      │   │       │              │
│       │         │  │      │      │   │  disease_heatmap     │
│       ▼         │  │      ▼      │   │  .html + .png        │
│  interpreter    │  │ Interpreter │   └──────────────────────┘
│  .run()         │  │ .invoke()   │
│       │         │  │      │      │
│       ▼         │  │      ▼      │
│  dequantize     │  │ dequantize  │
│  → confidence   │  │ → confidence│
│  + class        │  │ + class     │
│       │         │  └─────────────┘
│       ▼         │
│  ResultScreen   │
│  + treatment    │
└─────────────────┘
```

---

## 11. Running the Full Pipeline

```bash
# 0. Setup environment (once):
bash setup_env.sh

# 1. Download dataset (once):
.venv/bin/kaggle datasets download \
  -d smaranjitghose/corn-or-maize-leaf-disease-dataset \
  -p data/raw/plantvillage --unzip

# 2. Quick smoke-test (few epochs):
bash run_all.sh

# 3. Full training (targets ≥90% accuracy):
bash run_all.sh --full

# 4. Monitor training:
.venv/bin/tensorboard --logdir logs/
# Open http://localhost:6006

# 5. Individual phases:
python -m src.phase1_cnn.train    --csv data/annotations/labels.csv
python -m src.phase1_cnn.evaluate --model models/exports/efficientnetb3_maize.keras --csv data/annotations/labels.csv
python -m src.phase4_edge.convert_tflite
python -m deployment.uav.flight_planner --demo
python -m deployment.uav.patch_runner   --demo
python -m deployment.uav.heatmap        --demo
```

---

## 12. Environment Setup

### Python (training + edge + UAV)

```bash
# Requires Python 3.12, brew-installed tesseract 5
brew install tesseract

bash setup_env.sh       # creates .venv/, installs requirements.txt
source .venv/bin/activate
```

Key packages:
| Package | Version | Use |
|---------|---------|-----|
| tensorflow | 2.16.2 | Training + TFLite conversion |
| keras | 3.x | Model definition |
| opencv-python | 4.9+ | Image preprocessing |
| pytesseract | 0.3.10 | OCR (requires tesseract 5 binary) |
| fuzzywuzzy | 0.18.0 | Variety name matching |
| tflite-runtime | latest | Pi/Jetson inference (no full TF) |
| folium | latest | UAV interactive heatmap |
| rasterio | optional | GeoTIFF orthomosaic loading |
| pillow | 10+ | Image I/O |

### Flutter (mobile app)

```bash
# Install Flutter SDK: https://docs.flutter.dev/get-started/install
flutter --version   # should be 3.x

cd deployment/app
flutter pub get

# Android:
flutter run -d android

# macOS: follow Section 8 macOS Native Setup first, then:
flutter run -d macos
```

### Raspberry Pi

```bash
pip install tflite-runtime pillow numpy
# Optional PiCamera2:
sudo apt install python3-picamera2
python deployment/raspberry_pi/app.py
```

---

## 13. Model Performance Targets

| Metric | Target | Status |
|--------|--------|--------|
| Validation accuracy (CNN) | ≥ 90% | 🟡 Achieved after `--full` run |
| Inference latency — Android | < 500 ms | ✅ INT8 quantized |
| Inference latency — Pi 4 | < 2,000 ms | 🟡 Benchmark on device |
| Inference latency — macOS | < 300 ms | ✅ |
| UAV patch throughput | > 10 patches/s (desktop) | ✅ |
| Fusion accuracy gain | +5% over CNN alone | 🟡 After full training |
| TFLite INT8 model size | < 15 MB | ✅ 13 MB |

---

## 14. Team & Ownership

| Phase | Owner | Status |
|-------|-------|--------|
| 1 — CNN Classifier | Olapade | 🟡 Run `--full` for 90%+ target |
| 2 — OCR Subsystem | Tijani | ✅ Complete — test with real seed labels |
| 3 — Multimodal Fusion | Olapade + Tijani | 🟡 Run `--full` to converge |
| 4 — Edge Deployment | Oshodilawal | 🟡 Benchmark on Pi 4 |
| 5 — UAV Integration | Oshodilawal | ✅ Code complete — test with real orthomosaic |
| Flutter App | Oshodilawal | ✅ Android + macOS working |
| Raspberry Pi GUI | Oshodilawal | ✅ Complete |

### Adding New Maize Varieties / Diseases

1. Add images to `data/raw/field_photos/<ClassName>/`
2. Update `MAPPING` in `run_all.sh` step 0
3. Update `CLASS_NAMES` in `src/phase1_cnn/model.py` and all inference scripts
4. Update `classNames` in `deployment/app/lib/services/classifier.dart`
5. Add `DiseaseInfo` entry in `deployment/app/lib/models/prediction.dart`
6. Retrain: `bash run_all.sh --full`
