# Maize Disease Detection System

A multimodal deep learning system for detecting maize leaf diseases in Nigerian smallholder farms. Combines an EfficientNetB3 CNN classifier with a Tesseract OCR pipeline to fuse visual disease features with seed bag metadata — achieving improved accuracy over image-only baselines.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Dataset](#dataset)
- [Project Structure](#project-structure)
- [Setup](#setup)
- [Usage](#usage)
- [Results](#results)
- [Roadmap](#roadmap)
- [Team](#team)

---

## Overview

Maize (*Zea mays*) is a staple crop across sub-Saharan Africa. Disease outbreaks — particularly Northern Corn Leaf Blight, Rust, and Gray Leaf Spot — can destroy up to 80% of a harvest if undetected. Smallholder farmers in Nigeria rarely have access to agronomists, making on-device, offline-capable disease detection critical.

This system is designed to run on a smartphone or edge device (Raspberry Pi 4 / Jetson Nano) and provides:

- **Instant disease classification** from a photo of a maize leaf
- **Metadata-enhanced accuracy** by reading seed bag labels via OCR and fusing crop variety, batch number, and planting date into the prediction
- **UAV-scale mapping** (Phase 5) — GPS-tagged disease heatmaps from aerial imagery

---

## Architecture

```
┌─────────────────────┐        ┌──────────────────────┐
│   Leaf Image        │        │  Seed Bag Label Photo │
│   (300×300 RGB)     │        │  (any resolution)     │
└────────┬────────────┘        └──────────┬────────────┘
         │                                │
         ▼                                ▼
┌─────────────────────┐        ┌──────────────────────┐
│  EfficientNetB3     │        │  OCR Preprocessor    │
│  (ImageNet weights) │        │  grayscale → denoise  │
│  frozen base +      │        │  → threshold → deskew │
│  custom head        │        └──────────┬────────────┘
└────────┬────────────┘                   │
         │                                ▼
         │  256-d feature vector  ┌──────────────────────┐
         │                        │  Tesseract 5 OCR     │
         │                        │  + Fuzzy Matching    │
         │                        │  → crop_variety      │
         │                        │  → batch_number      │
         │                        │  → planting_date     │
         │                        └──────────┬────────────┘
         │                                   │
         │                                   ▼
         │                        ┌──────────────────────┐
         │                        │  Metadata Encoder    │
         │                        │  17-d float32 vector │
         │                        └──────────┬────────────┘
         │                                   │
         └──────────────┬────────────────────┘
                        │  concat [256 + 17] = 273-d
                        ▼
              ┌───────────────────┐
              │  Fusion Head      │
              │  Dense(128) →     │
              │  Dense(4)         │
              │  softmax          │
              └────────┬──────────┘
                       │
                       ▼
           ┌─────────────────────┐
           │  Disease Class      │
           │  NCLB / Rust /      │
           │  GLS / Healthy      │
           └─────────────────────┘
```

### Components

| Component | File | Description |
|---|---|---|
| Data pipeline | [src/phase1_cnn/data_pipeline.py](src/phase1_cnn/data_pipeline.py) | Image loader, augmentation, stratified split, class weights |
| CNN model | [src/phase1_cnn/model.py](src/phase1_cnn/model.py) | EfficientNetB3 + classification head, feature extractor |
| CNN training | [src/phase1_cnn/train.py](src/phase1_cnn/train.py) | Two-stage training (frozen base → fine-tune) |
| CNN evaluation | [src/phase1_cnn/evaluate.py](src/phase1_cnn/evaluate.py) | Accuracy, classification report, confusion matrix |
| OCR preprocessor | [src/phase2_ocr/preprocessor.py](src/phase2_ocr/preprocessor.py) | Grayscale, denoise, adaptive threshold, deskew |
| OCR extractor | [src/phase2_ocr/extractor.py](src/phase2_ocr/extractor.py) | Tesseract 5 + fuzzy field parsing |
| Metadata encoder | [src/phase2_ocr/encoder.py](src/phase2_ocr/encoder.py) | 17-d float32 vector from extracted fields |
| Fusion model | [src/phase3_fusion/fusion_model.py](src/phase3_fusion/fusion_model.py) | Two-input Keras model (image + metadata) |
| Fusion training | [src/phase3_fusion/train_fusion.py](src/phase3_fusion/train_fusion.py) | End-to-end fusion training script |

---

## Dataset

**Source**: [PlantVillage Maize Disease Dataset](https://www.kaggle.com/datasets/smaranjitghose/corn-or-maize-leaf-disease-dataset) (Kaggle)

| Class | Disease | Images | Folder |
|---|---|---|---|
| 0 | NCLB (Northern Corn Leaf Blight) | 1,146 | `Blight/` |
| 1 | Rust (Common Rust) | 1,306 | `Common_Rust/` |
| 2 | GLS (Gray Leaf Spot) | 574 | `Gray_Leaf_Spot/` |
| 3 | Healthy | 1,162 | `Healthy/` |
| **Total** | | **4,188** | |

**Split**: 70% train / 15% val / 15% test (stratified)

> **MSV (Maize Streak Virus)** is not available in PlantVillage. Add field photos to `data/raw/field_photos/MSV/` to enable it as a fifth class.

### Augmentation (training only)

- Random horizontal + vertical flip
- Random rotation ±20°
- Random zoom ±15%
- Random brightness ±10%
- Random contrast ±10%

---

## Project Structure

```
maize-disease-detection/
│
├── PLAN.md                          # Live progress tracker for all phases
├── run_all.sh                       # Pipeline orchestrator (quick + --full modes)
├── setup_env.sh                     # One-command environment setup
├── requirements.txt                 # Python dependencies
│
├── data/
│   ├── raw/
│   │   ├── plantvillage/data/       # Downloaded from Kaggle (gitignored)
│   │   ├── field_photos/            # Your own farm photos (gitignored)
│   │   └── seed_labels/             # Seed bag label photos for OCR
│   └── annotations/
│       ├── labels.csv               # image_path, label, class_name, source
│       └── labels_with_metadata.csv # + crop_variety, batch_number, planting_date
│
├── src/
│   ├── phase1_cnn/
│   │   ├── data_pipeline.py         # tf.data loader, augmentation, splits
│   │   ├── model.py                 # EfficientNetB3 + head + feature extractor
│   │   ├── train.py                 # Two-stage training CLI
│   │   └── evaluate.py              # Test set evaluation + confusion matrix
│   │
│   ├── phase2_ocr/
│   │   ├── preprocessor.py          # Image preprocessing for OCR
│   │   ├── extractor.py             # Tesseract OCR + field parsing
│   │   └── encoder.py               # 17-d metadata vector
│   │
│   ├── phase3_fusion/
│   │   ├── fusion_model.py          # Two-input Keras fusion model
│   │   └── train_fusion.py          # Fusion training CLI
│   │
│   ├── phase4_edge/                 # TFLite conversion + inference (planned)
│   └── phase5_uav/                  # UAV heatmap pipeline (planned)
│
├── models/
│   ├── checkpoints/                 # Best epoch weights per stage (gitignored)
│   └── exports/                     # Final .h5 models + confusion matrix PNG
│
├── deployment/
│   ├── android/                     # Flutter app (planned)
│   ├── raspberry_pi/                # Tkinter GUI (planned)
│   └── uav/                         # Flight planner + patch runner (planned)
│
├── scripts/
│   └── generate_test_data.py        # Synthetic data generator for smoke tests
│
└── notebooks/                       # Exploratory notebooks
```

---

## Setup

### Prerequisites

- macOS (Apple Silicon) or Linux
- [Homebrew](https://brew.sh) (macOS only)
- Python 3.12 — install via brew if needed:
  ```bash
  brew install python@3.12
  ```
- Tesseract 5:
  ```bash
  brew install tesseract        # macOS
  sudo apt install tesseract-ocr  # Ubuntu/Debian
  ```
- Kaggle account + API token (for dataset download)

### 1. Clone and create environment

```bash
git clone https://github.com/ahmaddev-codex/maize-disease-detection.git
cd maize-disease-detection
bash setup_env.sh
source .venv/bin/activate
```

### 2. Download the dataset

```bash
# Place your kaggle.json in ~/.kaggle/ first
# Get it from: kaggle.com → Settings → API → Create New Token
mkdir -p ~/.kaggle
cp /path/to/kaggle.json ~/.kaggle/kaggle.json
chmod 600 ~/.kaggle/kaggle.json

# Download and unzip PlantVillage maize dataset
.venv/bin/kaggle datasets download \
  -d smaranjitghose/corn-or-maize-leaf-disease-dataset \
  -p data/raw/plantvillage --unzip
```

---

## Usage

### Quick run — verify pipeline (3 epochs, ~15 min)

```bash
bash run_all.sh
```

### Full training — target ≥90% accuracy (~3–4 hours)

```bash
bash run_all.sh --full
```

Both modes automatically:
1. Build `data/annotations/labels.csv` from the real dataset
2. Train Phase 1 CNN (Stage 1: frozen base → Stage 2: fine-tune)
3. Evaluate on held-out test set + save confusion matrix
4. Test the OCR pipeline on a seed label image
5. Train Phase 3 fusion model

### Run phases individually

```bash
# Phase 1 — train CNN only
.venv/bin/python3 -m src.phase1_cnn.train \
  --csv data/annotations/labels.csv \
  --stage1-epochs 15 \
  --stage2-epochs 20

# Phase 1 — evaluate
.venv/bin/python3 -m src.phase1_cnn.evaluate \
  --model models/exports/efficientnetb3_maize.h5

# Phase 2 — test OCR on a seed label image
.venv/bin/python3 -c "
from src.phase2_ocr.extractor import extract_fields_from_path
from src.phase2_ocr.encoder import encode
import json
fields = extract_fields_from_path('data/raw/seed_labels/your_label.jpg')
print(json.dumps({k:v for k,v in fields.items() if k!='raw_text'}, indent=2))
print('Vector:', encode(fields))
"

# Phase 3 — train fusion model
.venv/bin/python3 -m src.phase3_fusion.train_fusion \
  --cnn-weights models/exports/efficientnetb3_maize.h5 \
  --metadata-csv data/annotations/labels_with_metadata.csv \
  --epochs 25
```

### TensorBoard

```bash
.venv/bin/tensorboard --logdir logs/
```

---

## Results

> Results below are from a 3-epoch quick run. Full training targets are shown in parentheses.

| Model | Test Accuracy | Notes |
|---|---|---|
| EfficientNetB3 (CNN only) | 27.8% | 3 epochs — underfitted |
| Fusion (CNN + OCR) | 42.3% | 3 epochs — fusion signal already visible |
| EfficientNetB3 (CNN only) | *(target ≥90%)* | Run `--full` |
| Fusion (CNN + OCR) | *(target ≥95.8%)* | +5.8% over CNN baseline |

**Confusion matrix** (quick run): [models/exports/confusion_matrix_phase1.png](models/exports/confusion_matrix_phase1.png)

---

## Roadmap

| Phase | Description | Status |
|---|---|---|
| 1 — CNN Classifier | EfficientNetB3 transfer learning | 🟡 Quick-trained, needs `--full` |
| 2 — OCR Subsystem | Tesseract 5 + metadata encoder | ✅ Complete |
| 3 — Multimodal Fusion | CNN + OCR feature fusion | 🟡 Quick-trained, needs `--full` |
| 4 — Edge Deployment | TFLite INT8 → Raspberry Pi 4 + Jetson Nano | ⬜ Not started |
| 5 — UAV Integration | OpenDroneMap + GPS disease heatmap | ⬜ Not started |
| Flutter App | On-device inference, camera overlay | ⬜ Not started |

See [PLAN.md](PLAN.md) for detailed task tracking.

### Phase 4 — Edge Deployment (next)

Convert the trained fusion model to TFLite INT8 and deploy to a Raspberry Pi 4:

```bash
# coming soon
python -m src.phase4_edge.convert_tflite \
  --model models/exports/fusion_model.h5 \
  --output models/exports/fusion_model.tflite
```

Target: <2 second inference on Raspberry Pi 4.

### Phase 5 — UAV Integration (planned)

1. Fly a pre-programmed grid mission over a farm (DJI / ArduPilot)
2. Stitch aerial images with [OpenDroneMap / WebODM](https://www.opendronemap.org/)
3. Run TFLite model on each image patch
4. Render GPS-tagged disease heatmap with [Folium](https://python-visualization.github.io/folium/)

---

## Team

| Name | Role |
|---|---|
| Olapade | CNN / Computer Vision |
| Tijani (sheutijani) | OCR Pipeline |
| Oshodilawal | Edge Deployment + Flutter UI |

---

## License

MIT
