# Maize Disease Detection — Build Plan

**Project**: CNN + OCR multimodal system for maize disease detection in Nigerian smallholder farms
**Team**: Olapade (CNN/CV) · Tijani (OCR) · Oshodilawal (Edge/UI)
**Dataset**: PlantVillage (Kaggle: smaranjitghose/corn-or-maize-leaf-disease-dataset) — 4,188 images, 4 classes
**Targets**: ≥90% validation accuracy · <2s inference on-device

---

## Legend
- `[ ]` Not started
- `[~]` In progress
- `[x]` Complete

---

## Phase 1 — CNN Classifier
> Goal: train EfficientNetB3 on maize disease images; achieve ≥90% val accuracy.

### Data
- [x] `src/phase1_cnn/data_pipeline.py` — loader, augmentation, train/val/test split
- [x] `data/annotations/labels.csv` — 4,188 real images mapped and ready
- [x] Download PlantVillage dataset from Kaggle (`data/raw/plantvillage/`) ✅
- [ ] Collect and add Lagos field photos (`data/raw/field_photos/`)

### Model
- [x] `src/phase1_cnn/model.py` — EfficientNetB3 transfer learning definition
- [x] `src/phase1_cnn/train.py` — two-stage training (frozen → fine-tune), callbacks
- [x] `src/phase1_cnn/evaluate.py` — accuracy, confusion matrix, per-class report

### Outputs
- [x] `models/checkpoints/phase1_stage1_best.h5` ✅
- [x] `models/checkpoints/phase1_stage2_best.h5` ✅
- [x] `models/exports/efficientnetb3_maize.h5` ✅
- [~] Validation accuracy ≥ 90% — currently ~32% (3 epochs quick run); run `bash run_all.sh --full` for full training

### Classes
| Label | Disease | Images | Dataset folder |
|---|---|---|---|
| 0 | NCLB (Northern Corn Leaf Blight) | 1,146 | `Blight/` |
| 1 | Rust (Common Rust) | 1,306 | `Common_Rust/` |
| 2 | GLS (Gray Leaf Spot) | 574 | `Gray_Leaf_Spot/` |
| 3 | Healthy | 1,162 | `Healthy/` |

> **MSV**: not in PlantVillage — add `data/raw/field_photos/MSV/` images to enable as class 4.

---

## Phase 2 — OCR Subsystem
> Goal: extract structured fields from seed bag labels and handwritten farm records.

### Pipeline
- [x] `src/phase2_ocr/preprocessor.py` — grayscale, adaptive threshold, deskew, denoise  ✅
- [x] `src/phase2_ocr/extractor.py` — Tesseract 5 OCR + fuzzy field parsing  ✅
- [x] `src/phase2_ocr/encoder.py` — 24-d feature vector  ✅

### Outputs
- [x] Extractor handles: crop variety, batch number, planting date ✅
- [x] Feature vector: 17-d (13 varieties + batch flag + batch year + month sin/cos) ✅
- [ ] Test on at least 10 real seed label images

### Sample fields extracted
```
crop_variety  →  one-hot or embedding
batch_number  →  hashed or ordinal
planting_date →  days-since-epoch or seasonal bucket
```

---

## Phase 3 — Multimodal Fusion
> Goal: fuse CNN penultimate features + OCR metadata vector; target +5.8% accuracy gain.

### Model
- [x] `src/phase3_fusion/fusion_model.py` — concatenate CNN feature vector + OCR vector → dense head  ✅
- [x] `src/phase3_fusion/train_fusion.py` — end-to-end training with functional API  ✅

### Outputs
- [x] `models/exports/fusion_model.h5` ✅
- [~] Fusion accuracy ≥ baseline CNN + 5% — 42.3% fusion vs 27.8% CNN (quick run); gap will close with `--full`
- [ ] Ablation comparison logged (CNN-only vs fusion) — add after full training

---

## Phase 4 — Edge Deployment *(planned)*
> Goal: TFLite INT8 model running <2s inference on Raspberry Pi 4 and Jetson Nano.

- [ ] `src/phase4_edge/convert_tflite.py` — INT8 quantization with representative dataset
- [ ] `src/phase4_edge/inference.py` — inference runner for Pi / Jetson
- [ ] `deployment/raspberry_pi/app.py` — Tkinter GUI
- [ ] Inference time < 2 seconds on Pi 4

---

## Phase 5 — UAV Integration *(planned)*
> Goal: GPS-tagged disease heatmap from aerial imagery using OpenDroneMap + model inference.

- [ ] `deployment/uav/flight_planner.py` — grid mission over farm
- [ ] `deployment/uav/patch_runner.py` — tile orthomosaic, run TFLite on each patch
- [ ] `deployment/uav/heatmap.py` — Folium overlay of disease classifications
- [ ] Test with synthetic high-res aerial image before hardware

---

## Flutter Android App *(planned)*
> Primary farmer-facing tool. TFLite on-device inference, camera overlay, OCR capture.

- [ ] `deployment/android/` — Flutter project scaffolded
- [ ] Camera preview with blur/distance guidance overlay
- [ ] On-device TFLite inference
- [ ] OCR metadata capture screen
- [ ] Disease result + treatment recommendation screen

---

## Environment
```
Python        3.12  (via brew python@3.12)
TensorFlow    2.16.2
Keras         3.13.2
OpenCV        4.9.0
pytesseract   0.3.10  (requires tesseract 5 binary via brew)
fuzzywuzzy    0.18.0
tflite-runtime (install separately on Pi/Jetson)
venv          .venv/  (created with python3.12 -m venv .venv)
```

---

## Progress Tracker

| Phase | Status | Owner | Notes |
|---|---|---|---|
| 1 — CNN Classifier | 🟡 Trained (quick) | Olapade | Run `--full` for 90%+ target |
| 2 — OCR Subsystem | ✅ Working | Tijani | Needs real seed label photos |
| 3 — Multimodal Fusion | 🟡 Trained (quick) | Olapade + Tijani | Run `--full` to converge |
| 4 — Edge Deployment | ⬜ Not started | Oshodilawal | Depends on Phase 3 |
| 5 — UAV Integration | ⬜ Not started | Oshodilawal | Can run parallel to Phase 4 |
| Flutter App | ⬜ Not started | Oshodilawal | Primary delivery |
