# MaizeGuard — AI-Powered Maize Disease Detection

A multimodal AI system for detecting maize crop diseases, targeting Nigerian smallholder farmers. Combines an EfficientNetB3 CNN classifier with on-device OCR for seed label metadata, GPS-tagged history, AI agronomic advice, and a UAV live disease heatmap dashboard.

**Mobile:** Flutter 3.x (Android + iOS) · **ML:** Python 3.12 + TensorFlow 2.16  
**Team:** Tijani · Oshodilawal · Olapade

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Dataset](#dataset)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
  - [Prerequisites](#prerequisites)
  - [A. Mobile App — Android](#a-mobile-app--android)
  - [B. Mobile App — iOS](#b-mobile-app--ios)
  - [C. UAV Dashboard — Demo (no drone)](#c-uav-dashboard--demo-no-drone)
  - [D. UAV Dashboard — Live Drone](#d-uav-dashboard--live-drone)
  - [E. ML Training Pipeline](#e-ml-training-pipeline)t
- [Mobile App Reference](#mobile-app-reference)
- [UAV Reference](#uav-reference)
- [Roadmap](#roadmap)
- [Team](#team)

---

## Overview

Maize (*Zea mays*) is a staple crop across sub-Saharan Africa. Disease outbreaks — NCLB, Rust, and Gray Leaf Spot — can destroy up to 80% of a harvest if undetected. Smallholder farmers in Nigeria rarely have access to agronomists, making offline, on-device detection critical.

**MaizeGuard provides:**

- **Instant leaf disease classification** — EfficientNetB3 TFLite, fully offline, < 500 ms on mid-range Android
- **Seed label OCR** — reads crop variety, batch number, and planting date from seed bags via ML Kit
- **AI agronomic advice** — on-device rule engine + optional Gemini 2.0 Flash or local Ollama backend
- **GPS-tagged scan history** — filterable, with per-scan notes and an OpenStreetMap farm map
- **Dashboard analytics** — farm health score, 7-day trend, disease breakdown charts
- **UAV live heatmap** — Flask + Socket.IO dashboard with real-time Leaflet.js disease map

---

## Architecture

### System Layers

```
┌──────────────────────────────────────────────────────────────┐
│  PRESENTATION — Flutter (Android + iOS)                      │
│  Home · Camera · Result · OCR · Dashboard                    │
│  History · Map · Settings · AI Advice (bottom sheet)         │
├──────────────────────────────────────────────────────────────┤
│  BUSINESS LOGIC — Dart Services                              │
│  ClassifierService · OcrService · RecommendationEngine       │
│  AiAdvisor · LocationService · DatabaseService               │
├──────────────────────────────────────────────────────────────┤
│  DATA — Local Persistence                                    │
│  sqflite (scan history) · FlutterSecureStorage · SharedPrefs │
├──────────────────────────────────────────────────────────────┤
│  ML CORE — Bundled TFLite Models                             │
│  EfficientNetB3 INT8 (~13 MB) · FP16 fallback (~23 MB)       │
└──────────────────────────────────────────────────────────────┘
```

### ML Pipeline

```
Leaf Image (300×300 RGB)        Seed Label Photo
         │                              │
         ▼                              ▼
  EfficientNetB3              OCR Preprocessor
  (ImageNet weights)          grayscale → denoise
  frozen base +               → threshold → deskew
  custom 4-class head                   │
         │                              ▼
         │ 256-d features       Tesseract 5 LSTM
         │                      + Fuzzy Matching
         │                      → crop_variety
         │                      → batch_number
         │                      → planting_date
         │                              │
         │                              ▼
         │                      Metadata Encoder
         │                      24-d float32 vector
         │                              │
         └──────────────┬───────────────┘
                        │ Concatenate (288-d)
                        ▼
                  Fusion Head
                  Dense(128) → Dense(4) → Softmax
                        │
                        ▼
              NCLB · Rust · GLS · Healthy
```

---

## Dataset

**Source:** [PlantVillage Maize Disease Dataset](https://www.kaggle.com/datasets/smaranjitghose/corn-or-maize-leaf-disease-dataset) (Kaggle)

| Class | Disease | Images | Proportion |
|---|---|---|---|
| 0 | NCLB — Northern Corn Leaf Blight | 1,146 | 27.4% |
| 1 | Rust — Common Rust | 1,306 | 31.2% |
| 2 | GLS — Gray Leaf Spot | 574 | 13.7% |
| 3 | Healthy | 1,162 | 27.7% |
| **Total** | | **4,188** | **100%** |

**Split:** 70% train / 15% val / 15% test — stratified by class  
**Augmentation (train only):** Horizontal flip · Rotation ±20° · Zoom ±15% · Brightness ±10% · Contrast ±10%

---

## Project Structure

```
maize-disease-detection/
│
├── mobile/                        ← Flutter app (Android + iOS)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart               ← GoRouter + shell nav
│   │   ├── screens/               ← 8 screens (home, camera, result, ocr…)
│   │   ├── services/              ← TFLite · OCR · SQLite · AI advisor
│   │   ├── providers/             ← Riverpod state
│   │   ├── models/                ← ScanRecord · ClassificationResult
│   │   ├── constants/             ← Colors · diseases · varieties
│   │   ├── config/                ← AppEnv (.env.json reader)
│   │   └── widgets/               ← GlassCard · DuotoneIcon · AiAdviceSheet
│   ├── assets/models/             ← TFLite model files (.tflite)
│   ├── android/                   ← Android native project
│   ├── ios/                       ← iOS Xcode project
│   ├── pubspec.yaml               ← Flutter dependencies
│   ├── .env.json                  ← API keys (not committed)
│   ├── .env.json.example          ← Template
│   └── setup.sh                   ← One-shot setup (copies models, pod install)
│
├── src/                           ← Python ML training pipeline
│   ├── phase1_cnn/                ← EfficientNetB3 training & evaluation
│   ├── phase2_ocr/                ← Tesseract OCR extractor & encoder
│   ├── phase3_fusion/             ← Multimodal fusion model
│   └── phase4_edge/               ← TFLite conversion (INT8 + FP16 export)
│
├── deployment/
│   └── uav/
│       ├── flight_planner.py      ← Grid mission → QGC .waypoints file
│       ├── patch_runner.py        ← Orthomosaic tiling + TFLite inference
│       ├── heatmap.py             ← Folium HTML + matplotlib PNG heatmaps
│       ├── drone_telemetry.py     ← Live MAVLink drone connection + mission upload
│       └── live_server.py         ← Flask + Socket.IO real-time map dashboard
│
├── data/
│   ├── raw/plantvillage/          ← PlantVillage dataset images
│   ├── raw/seed_labels/           ← Seed label images for OCR testing
│   └── annotations/               ← labels.csv · labels_with_metadata.csv
│
├── models/
│   └── exports/                   ← Trained .keras + .tflite files
│
├── logs/                          ← TensorBoard training logs
├── setup_env.sh                   ← Python venv setup
├── run_all.sh                     ← Full pipeline runner (Phases 1–5)
└── requirements.txt               ← Python dependencies
```

---

## Quick Start

### Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Flutter | 3.x | `flutter doctor` must pass |
| Dart | 3.3+ | Bundled with Flutter |
| Xcode | 14+ | iOS only, macOS required |
| CocoaPods | latest | `sudo gem install cocoapods` |
| JDK | 17+ | Android builds |
| Android SDK | API 21+ | Android Studio or CLI |
| Python | 3.12 | TF 2.16 does not support 3.13+ |
| Tesseract | 5+ | `brew install tesseract` / `apt install tesseract-ocr` |
| Kaggle CLI | configured | `~/.kaggle/kaggle.json` for dataset download |

---

### A. Mobile App — Android

**1. One-time setup** — copies TFLite models into `assets/`, fetches packages, checks `minSdkVersion`:

```bash
bash mobile/setup.sh --android
```

**2. Configure environment** — copy the example and add your keys (optional for debug):

```bash
cp mobile/.env.json.example mobile/.env.json
# Edit .env.json:
# GEMINI_API_KEY  → production Gemini key (release builds only)
# OLLAMA_HOST     → Ollama server URL (debug builds, default: http://localhost:11434)
# OLLAMA_MODEL    → model name (debug builds, default: llama3.1:8b)
```

**3. Run:**

```bash
# Connect a device or start an emulator first
cd mobile
flutter run --dart-define-from-file=.env.json
```

**Build a release APK:**

```bash
cd mobile
flutter build apk --dart-define-from-file=.env.json
# Output: build/app/outputs/flutter-apk/app-release.apk
```

> **TFLite GPU errors?** Open [mobile/lib/services/classifier_service.dart](mobile/lib/services/classifier_service.dart) and remove the GPU delegate option.

---

### B. Mobile App — iOS

**Requires macOS + Xcode 14+.**

**1. One-time setup** — runs `pod install`, patches `Info.plist` with camera/location permissions:

```bash
bash mobile/setup.sh --ios
```

**2. Configure environment** (same `.env.json` as Android above).

**3. Run in Simulator:**

```bash
cd mobile
flutter run -d ios --dart-define-from-file=.env.json
```

**4. Run on a real device:**

```bash
cd mobile
flutter run -d <device-udid> --dart-define-from-file=.env.json
```

Find your device UDID with `flutter devices`.

**Build a release archive:**

```bash
cd mobile
flutter build ios --dart-define-from-file=.env.json
# Then open ios/Runner.xcworkspace in Xcode → Product → Archive
```

**Re-run CocoaPods** after adding native packages:

```bash
cd mobile && flutter pub get && (cd ios && pod install)
```

> **Camera denied on iOS?** Re-run `bash mobile/setup.sh --ios` to patch `Info.plist`, then rebuild.

---

### C. UAV Dashboard — Demo (no drone)

Runs the full UAV pipeline locally — generates a synthetic orthomosaic, classifies patches, and produces an interactive heatmap. No drone hardware required.

**1. Python environment setup (once):**

```bash
bash setup_env.sh
source .venv/bin/activate
```

**2. Install UAV extras:**

```bash
pip install flask flask-socketio
# For real GeoTIFF orthomosaics (optional):
# brew install gdal && pip install rasterio
```

**3. Generate a demo flight plan:**

```bash
python -m deployment.uav.flight_planner --demo --output data/uav/mission.waypoints
```

**4. Run patch inference on a synthetic orthomosaic:**

```bash
python -m deployment.uav.patch_runner \
  --demo \
  --model  models/exports/efficientnetb3_maize_int8.tflite \
  --output data/uav/patch_predictions.csv
```

**5. Generate the heatmap:**

```bash
python -m deployment.uav.heatmap \
  --csv    data/uav/patch_predictions.csv \
  --output data/uav/disease_heatmap.html
```

Open `data/uav/disease_heatmap.html` in a browser — it shows a Folium interactive map with disease density coloured by class.

**6. (Optional) Start the live web dashboard:**

```bash
python -m deployment.uav.live_server
# → Open http://localhost:5000
```

---

### D. UAV Dashboard — Live Drone

Connects to a real MAVLink drone (Pixhawk / ArduCopter / PX4), uploads the survey mission, and streams GPS position + disease detections to a live Leaflet.js map in your browser.

**Terminal 1 — Start the web dashboard:**

```bash
source .venv/bin/activate
python -m deployment.uav.live_server
# → Open http://localhost:5000
```

**Terminal 2 — Generate the mission file:**

```bash
python -m deployment.uav.flight_planner \
  --farm-geojson data/uav/farm_boundary.geojson \
  --altitude 30 \
  --output   data/uav/mission.waypoints
```

**Terminal 3 — Connect the drone:**

```bash
# USB / SiK radio (serial)
python -m deployment.uav.drone_telemetry \
  --connect /dev/ttyUSB0:57600 \
  --mission data/uav/mission.waypoints \
  --server  http://localhost:5000

# UDP — MAVProxy, SITL, or WiFi bridge
python -m deployment.uav.drone_telemetry \
  --connect udp:0.0.0.0:14550 \
  --mission data/uav/mission.waypoints \
  --server  http://localhost:5000

# TCP — companion computer or direct WiFi
python -m deployment.uav.drone_telemetry \
  --connect tcp:192.168.1.1:5760 \
  --mission data/uav/mission.waypoints \
  --server  http://localhost:5000

# Arm and enter AUTO mode automatically after mission upload
python -m deployment.uav.drone_telemetry \
  --connect udp:0.0.0.0:14550 \
  --mission data/uav/mission.waypoints \
  --server  http://localhost:5000 \
  --auto-arm
```

As the drone flies each waypoint, `drone_telemetry.py` runs TFLite inference on the captured patch and POSTs the result to the live server — appearing instantly as a coloured disease marker on the map.

**Test without real hardware using ArduCopter SITL:**

```bash
# Terminal A
sim_vehicle.py -v ArduCopter --console --map

# Terminal B — forward to UDP 14550
mavproxy.py --master tcp:127.0.0.1:5760 --out udp:127.0.0.1:14550

# Terminal C — connect drone_telemetry as normal
python -m deployment.uav.drone_telemetry \
  --connect udp:0.0.0.0:14550 \
  --mission data/uav/mission.waypoints \
  --server  http://localhost:5000
```

---

### E. ML Training Pipeline

**1. Python environment setup (once):**

```bash
bash setup_env.sh
source .venv/bin/activate
```

**2. Download the dataset:**

```bash
.venv/bin/kaggle datasets download \
  -d smaranjitghose/corn-or-maize-leaf-disease-dataset \
  -p data/raw/plantvillage --unzip
```

Expected layout:

```
data/raw/plantvillage/data/
  Blight/        ← NCLB (1,146 images)
  Common_Rust/   ← Rust (1,306 images)
  Gray_Leaf_Spot/ ← GLS (574 images)
  Healthy/       ← Healthy (1,162 images)
```

**3. Run the full pipeline:**

```bash
# Quick smoke-test (3 epochs per stage)
bash run_all.sh

# Full training (20+30 epochs CNN · 50 epochs fusion)
bash run_all.sh --full
```

**Pipeline outputs:**

| File | Description |
|---|---|
| `models/exports/efficientnetb3_maize.keras` | Phase 1 CNN |
| `models/exports/efficientnetb3_maize_int8.tflite` | INT8 quantised (~13 MB) |
| `models/exports/efficientnetb3_maize_fp16.tflite` | FP16 fallback (~23 MB) |
| `models/exports/fusion_model.keras` | Phase 3 multimodal fusion |
| `models/exports/confusion_matrix_phase1.png` | Phase 1 evaluation chart |
| `data/uav/mission.waypoints` | Phase 5 flight plan |
| `data/uav/patch_predictions.csv` | Phase 5 inference results |
| `data/uav/disease_heatmap.html` | Phase 5 interactive map |
| `data/uav/disease_heatmap.png` | Phase 5 static figure |

**Monitor training:**

```bash
.venv/bin/tensorboard --logdir logs/
# → Open http://localhost:6006
```

**Run individual phases:**

```bash
# Phase 1 — build dataset index
python -m src.phase1_cnn.data_pipeline

# Phase 1 — train CNN
python -m src.phase1_cnn.train \
  --csv data/annotations/labels.csv \
  --stage1-epochs 20 --stage2-epochs 30

# Phase 1 — evaluate
python -m src.phase1_cnn.evaluate \
  --model models/exports/efficientnetb3_maize.keras \
  --csv   data/annotations/labels.csv

# Phase 2 — OCR a seed label
python src/phase2_ocr/extractor.py --image data/raw/seed_labels/sample_label.jpg

# Phase 3 — train fusion model
python -m src.phase3_fusion.train_fusion \
  --metadata-csv data/annotations/labels_with_metadata.csv \
  --cnn-weights  models/exports/efficientnetb3_maize.keras \
  --epochs 50

# Phase 4 — export TFLite models (copies to mobile/assets/models/ automatically via setup.sh)
python -m src.phase4_edge.convert_tflite \
  --model models/exports/efficientnetb3_maize.keras \
  --csv   data/annotations/labels.csv
```

> After re-exporting TFLite models, re-run `bash mobile/setup.sh` to copy them into the Flutter asset bundle before running the app.

---

## Mobile App Reference

All inference runs on-device — no internet required for core features.

### Screens

| Screen | How to reach | Description |
|---|---|---|
| **Home** | App launch | Scan hero card, farm stats, recent scans, seed label shortcut |
| **Camera** | Centre scan button | Live camera with framing guide and brightness feedback |
| **Result** | After scan | Disease class, confidence bars, symptoms, treatments, prevention |
| **AI Advice** | "Get AI Advice" on Result | Bottom sheet — on-device rule engine + Gemini / Ollama advice |
| **OCR** | "Scan Seed Label" on Home | Extracts crop variety, batch number, planting date from seed bag |
| **Map** | Map icon on Home app bar | OpenStreetMap with GPS-tagged disease pins |
| **Dashboard** | Stats tab | Farm health score, 7-day bar chart, disease breakdown |
| **History** | History tab | All scans with filter chips, long-press to add notes or delete |
| **Settings** | Settings tab | Dark/light theme, Gemini API key, Ollama config, clear data |

### Key Flutter Packages

| Purpose | Package |
|---|---|
| TFLite inference | `tflite_flutter` |
| On-device OCR | `google_mlkit_text_recognition` |
| Camera | `camera` |
| Image picker | `image_picker` |
| Maps | `flutter_map` + OpenStreetMap tiles |
| Database | `sqflite` |
| State management | `flutter_riverpod` |
| Navigation | `go_router` |
| Charts | `fl_chart` |
| Secure storage | `flutter_secure_storage` |
| AI networking | `http` (Gemini API / Ollama) |
| Fonts | `google_fonts` (DM Sans) |

### Useful Flutter Commands (run from `mobile/`)

| Command | Description |
|---|---|
| `flutter run --dart-define-from-file=.env.json` | Run debug build |
| `flutter run -d android --dart-define-from-file=.env.json` | Run on Android device |
| `flutter run -d ios --dart-define-from-file=.env.json` | Run on iOS Simulator |
| `flutter build apk --dart-define-from-file=.env.json` | Build release APK |
| `flutter build ios --dart-define-from-file=.env.json` | Build iOS release archive |
| `flutter pub get` | Fetch / update packages |
| `flutter analyze` | Static analysis |
| `flutter test` | Run unit tests |
| `flutter devices` | List connected devices |
| `flutter clean` | Clear build cache |

---

## UAV Reference

### Live Dashboard Endpoints

| Method | Path | Called by |
|---|---|---|
| `GET` | `/` | Browser — Leaflet.js live map |
| `POST` | `/telemetry` | `drone_telemetry.py` — drone GPS + status |
| `POST` | `/patch` | `drone_telemetry.py` — disease detection per patch |
| `GET` | `/api/summary` | Any client — aggregate disease stats JSON |
| `GET` | `/api/patches` | Any client — full patch predictions list |

### Socket.IO Events (broadcast to all browser clients)

| Event | Payload |
|---|---|
| `telemetry_update` | `{lat, lon, alt, heading, battery, mode}` |
| `patch_result` | `{lat, lon, class_id, class_name, confidence}` |
| `mission_status` | `{status, waypoint, total_waypoints}` |

---

## Roadmap

| Component | Status | Notes |
|---|---|---|
| Phase 1 — CNN | 🟡 In progress | Full training run needed for ≥90% accuracy |
| Phase 2 — OCR | ✅ Complete | Tesseract + fuzzy matching |
| Phase 3 — Fusion | 🟡 In progress | Full training needed |
| Phase 4 — TFLite Export | ✅ Complete | INT8 + FP16 models |
| Phase 5 — UAV Demo | ✅ Complete | Offline demo + Folium heatmap |
| Phase 5 — UAV Live | ✅ Complete | MAVLink + Socket.IO live map |
| Mobile — Android | ✅ Complete | Flutter, 8 screens + AI bottom sheet |
| Mobile — iOS | ✅ Complete | CocoaPods, Info.plist, Simulator + device |
| Mobile — PDF Export | 🔲 Planned | Farm report with scan history + heatmap |

---

## Team

| Member | Role |
|---|---|
| Olapade | CNN model training and evaluation (Phase 1 & 3) |
| Tijani | OCR pipeline and metadata extraction, Flutter mobile app, UAV pipeline (Phase 2) |
| Oshodilawal | Edge deployment |

---

*For full specifications see [REQUIREMENTS.md](REQUIREMENTS.md), [SYSTEM.md](SYSTEM.md), and [DIAGRAMS.md](DIAGRAMS.md).*
