# MaizeGuard — AI-Powered Maize Disease Detection System

A multimodal AI system for detecting diseases in maize (corn) crops targeting Nigerian smallholder farmers. Combines an EfficientNetB3 CNN classifier with a Tesseract OCR pipeline for seed label metadata fusion — delivering on-device inference with no internet connection required.

**Mobile Platform:** React Native 0.73 (Android-first)  
**ML Backend:** Python 3.12 + TensorFlow 2.16  
**Team:** Olapade (CNN/CV) · Tijani (OCR) · Oshodilawal (Edge/UI)

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Mobile App (React Native)](#mobile-app-react-native)
- [ML Pipeline](#ml-pipeline)
- [Dataset](#dataset)
- [Project Structure](#project-structure)
- [Setup](#setup)
- [Usage](#usage)
- [Diagrams](#diagrams)
- [Roadmap](#roadmap)
- [Team](#team)

---

## Overview

Maize (*Zea mays*) is a staple crop across sub-Saharan Africa. Disease outbreaks — particularly Northern Corn Leaf Blight (NCLB), Rust, and Gray Leaf Spot (GLS) — can destroy up to 80% of a harvest if undetected. Smallholder farmers in Nigeria rarely have access to agronomists, making on-device, offline-capable disease detection critical.

MaizeGuard provides:

- **Instant disease classification** from a leaf photo — runs fully offline on Android
- **OCR seed label scanning** — reads crop variety, batch number, and planting date from seed bags
- **Metadata-enhanced accuracy** — fuses seed label data with visual features via the multimodal fusion model
- **GPS-tagged scan history** — tracks disease spread across a farm over time
- **AI-powered recommendations** — on-device rule engine + optional Gemini AI advice
- **UAV-scale mapping** (Phase 5) — disease heatmaps from aerial imagery

---

## Architecture

### System Layers

```
┌──────────────────────────────────────────────────────────┐
│  PRESENTATION — React Native (Android)                   │
│  Home · Camera · Result · OCR · Dashboard                │
│  History · Map · Recommendation · Settings               │
├──────────────────────────────────────────────────────────┤
│  BUSINESS LOGIC — TypeScript Services                    │
│  classifier · ocrService · recommendationEngine          │
│  aiAdvisor · locationService · database                  │
├──────────────────────────────────────────────────────────┤
│  DATA — Local Persistence                                │
│  op-sqlite (scan history) · AsyncStorage · Keychain      │
├──────────────────────────────────────────────────────────┤
│  ML CORE — Bundled TFLite Models                         │
│  EfficientNetB3 INT8 (~13MB) · FP16 fallback (~23MB)    │
└──────────────────────────────────────────────────────────┘
```

### ML Pipeline

```
Leaf Image (300×300 RGB)        Seed Label Photo
         │                              │
         ▼                              ▼
  EfficientNetB3              OCR Preprocessor
  (ImageNet weights)          grayscale → denoise
  frozen base +               → threshold → deskew
  custom head                          │
         │                             ▼
         │ 256-d features       Tesseract 5 LSTM
         │                      + Fuzzy Matching
         │                      → crop_variety
         │                      → batch_number
         │                      → planting_date
         │                             │
         │                             ▼
         │                      Metadata Encoder
         │                      24-d float32 vector
         │                             │
         └──────────────┬──────────────┘
                        │ Concatenate (280-d)
                        ▼
                  Fusion Head
                  Dense(128) → Dense(4) → Softmax
                        │
                        ▼
              NCLB · Rust · GLS · Healthy
```

---

## Mobile App (React Native)

The primary farmer-facing tool. All inference runs on-device — no internet required for core features.

### Screens

| Screen | Description |
|---|---|
| **Home** | Scan entry point — camera, gallery, and seed label OCR options |
| **Camera** | Full-screen VisionCamera v4 with framing guide and brightness hints |
| **Result** | Disease class, confidence percentage, 4-class score bars, treatments |
| **OCR** | Seed label scanner — extracts variety, batch number, planting date |
| **Dashboard** | Farm health score, 7-day trend chart, disease breakdown |
| **History** | Filterable scan history with GPS markers and swipe-to-delete |
| **Map** | OpenStreetMap with GPS-tagged disease markers |
| **Recommendation** | On-device advice or Gemini AI-powered agronomic guidance |
| **Settings** | Dark/light theme, Gemini API key, model metadata |

### Key Libraries

| Purpose | Library |
|---|---|
| TFLite inference | `react-native-fast-tflite` (JSI, GPU delegate) |
| Camera | `react-native-vision-camera` v4 |
| Image preprocessing | `@shopify/react-native-skia` |
| OCR | `@react-native-ml-kit/text-recognition` |
| Database | `@op-engineering/op-sqlite` |
| Maps | `react-native-maps` + OSM tiles |
| Charts | `victory-native` |
| State | Zustand |

### Quick Start (Android)

```bash
# 1. Copy TFLite models and install dependencies
bash mobile/setup.sh

# 2. Connect Android device (API 24+) or start emulator
# 3. Run
cd mobile
npx react-native run-android
```

---

## ML Pipeline

### Phase 1 — CNN Classifier

```bash
# Full training (~50 epochs, targets ≥90% accuracy)
bash run_all.sh --full

# Quick smoke test (3 epochs)
bash run_all.sh --quick
```

Model: `models/exports/efficientnetb3_maize_int8.tflite` (~13 MB)

### Phase 2 — OCR Pipeline

```bash
python src/phase2_ocr/extractor.py --image data/raw/seed_labels/sample.jpg
```

### Phase 3 — Multimodal Fusion

```bash
python src/phase3_fusion/train_fusion.py
```

### Phase 4 — Edge Deployment (Raspberry Pi / Jetson)

```bash
python src/phase4_edge/inference.py --image leaf.jpg
```

### Phase 5 — UAV Heatmap (Demo)

```bash
python deployment/uav/patch_runner.py --demo
python deployment/uav/heatmap.py
```

---

## Dataset

**Source:** [PlantVillage Maize Disease Dataset](https://www.kaggle.com/datasets/smaranjitghose/corn-or-maize-leaf-disease-dataset) (Kaggle)

| Class | Disease | Images |
|---|---|---|
| 0 | NCLB — Northern Corn Leaf Blight | 1,146 |
| 1 | Rust — Common Rust | 1,306 |
| 2 | GLS — Gray Leaf Spot | 574 |
| 3 | Healthy | 1,162 |
| **Total** | | **4,188** |

**Split:** 70% train / 15% val / 15% test (stratified by class)

**Augmentation (train only):** Horizontal flip · Rotation ±20° · Zoom ±15° · Brightness ±10% · Contrast ±10%

---

## Project Structure

```
maize-disease-detection/
├── mobile/                        ← React Native Android app (primary)
│   ├── android/                   ← Android native project
│   ├── src/
│   │   ├── screens/               ← 9 screens
│   │   ├── services/              ← TFLite · OCR · SQLite · Gemini
│   │   ├── components/            ← Reusable UI components
│   │   ├── navigation/            ← Stack + Tab navigators
│   │   ├── hooks/                 ← useClassifier · useScans
│   │   ├── store/                 ← Zustand app state
│   │   ├── constants/             ← Colors · diseases · varieties
│   │   └── types/                 ← TypeScript interfaces
│   └── assets/models/             ← TFLite model files
│
├── src/                           ← Python ML training pipeline
│   ├── phase1_cnn/                ← EfficientNetB3 training
│   ├── phase2_ocr/                ← Tesseract OCR pipeline
│   ├── phase3_fusion/             ← Multimodal fusion model
│   └── phase4_edge/               ← TFLite conversion + inference
│
├── deployment/
│   ├── raspberry_pi/              ← Tkinter GUI for edge devices
│   └── uav/                       ← UAV mission + disease heatmap
│
├── data/
│   ├── raw/plantvillage/          ← PlantVillage dataset images
│   └── annotations/labels.csv    ← 4,188 labelled image paths
│
├── models/
│   └── exports/                   ← Trained .keras + .tflite files
│
├── REQUIREMENTS.md                ← Full software requirements spec
├── DIAGRAMS.md                    ← System diagrams (ASCII)
├── PLAN.md                        ← Phase-by-phase build checklist
├── SYSTEM.md                      ← Architecture & developer guide
└── WORKFLOW.md                    ← Git branching workflow
```

---

## Setup

### Python ML Environment

```bash
bash setup_env.sh
source .venv/bin/activate
```

**Requirements:** Python 3.12, TensorFlow 2.16, OpenCV, Tesseract 5

### React Native App

```bash
bash mobile/setup.sh
cd mobile && npx react-native run-android
```

**Requirements:** Node 18+, Android SDK (API 24+), JDK 17+

---

## Diagrams

Full system diagrams — architecture, DFD (Level 0 & 1), ERD, CNN architecture, inference flowchart — are in [DIAGRAMS.md](DIAGRAMS.md).

Software requirements specification is in [REQUIREMENTS.md](REQUIREMENTS.md).

---

## Roadmap

| Phase | Status | Description |
|---|---|---|
| Phase 1 — CNN | 🟡 In progress | Full training run needed for ≥90% accuracy |
| Phase 2 — OCR | ✅ Complete | Tesseract + fuzzy matching implemented |
| Phase 3 — Fusion | 🟡 In progress | Full training needed |
| Phase 4 — Edge | ✅ Complete | TFLite INT8 + FP16 models exported |
| Phase 5 — UAV | 🟡 Demo ready | Real orthomosaic testing pending |
| Mobile App — Core | ✅ Complete | React Native, all 9 screens |
| Mobile App — Polish | 🔲 Planned | PDF export, offline map tiles |

---

## Team

| Member | Role |
|---|---|
| Olapade | CNN model training and evaluation (Phase 1 & 3) |
| Tijani | OCR pipeline and metadata extraction (Phase 2) |
| Oshodilawal | Edge deployment, React Native mobile app (Phase 4 & App) |

---

*For academic documentation see [REQUIREMENTS.md](REQUIREMENTS.md) and [DIAGRAMS.md](DIAGRAMS.md).*
