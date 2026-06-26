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

## Phase 4 — TFLite Export ✅
> Goal: Export quantized TFLite models for mobile deployment.

- [x] `src/phase4_edge/convert_tflite.py` — INT8 + FP16 quantization with representative dataset

---

## Phase 5 — UAV Integration ✅
> Goal: GPS-tagged disease heatmap from aerial imagery using OpenDroneMap + model inference.

- [x] `deployment/uav/flight_planner.py` — grid mission generator → MAVLink .waypoints (QGC/Mission Planner)
- [x] `deployment/uav/patch_runner.py` — tile orthomosaic → TFLite inference per patch → CSV
- [x] `deployment/uav/heatmap.py` — Folium interactive HTML map + matplotlib static PNG
- [x] Demo mode (`--demo`) works without hardware — synthetic orthomosaic + predictions
- [ ] Test with real GeoTIFF orthomosaic from OpenDroneMap

---

## React Native App — Sprint A: Core ✅
> ⚠️ Platform migrated from Flutter → React Native 0.73 (Android-first) on 2026-06-13.
> Source: `mobile/`   Flutter source kept at `deployment/app/` for reference only.

- [x] `mobile/` — React Native project scaffolded (Android-first)
- [x] Camera screen — VisionCamera v4, green corner guide, brightness frame processor
- [x] On-device TFLite inference — INT8 (GPU delegate) with FP16 CPU fallback (`react-native-fast-tflite`)
- [x] Image preprocessing — Skia resize to 300×300, RGBA→RGB strip
- [x] OCR screen — ML Kit Text Recognition v2, full Android implementation
- [x] OCR field extraction — crop variety (fuzzy match, 13 Nigerian varieties), batch number, planting date
- [x] Result screen — disease class, confidence bars (animated), 4-class score matrix
- [x] SQLite persistence — op-sqlite, `scan_records` table, GPS tagging
- [x] Recommendation screen — on-device rule engine (season/urgency/fungicide)
- [x] Gemini 2.0 Flash API advisor — HTTPS with offline fallback
- [x] Dashboard — farm health score, 7-day bar chart (victory-native), disease breakdown
- [x] History — filterable list, swipe-to-delete, disease colour labels
- [x] Map screen — react-native-maps + OSM tiles + GPS-tagged disease markers
- [x] Settings — dark/light theme, Gemini API key (Keychain), model status
- [x] Navigation — bottom tabs (Home/Dashboard/History/Map) + stack (Camera/Result/OCR/Recommendation)
- [x] GitHub-dark theme — DarkColors + LightColors matching Flutter palette
- [x] TFLite models copied to `mobile/assets/models/`

---

## React Native App — Sprint B: Polish  `[ ]`
> Goal: PDF export, offline map caching, PDF sharing.

- [ ] PDF report generation (`react-native-html-to-pdf`) — disease summary + treatment plan
- [ ] Share PDF via WhatsApp/email (`react-native-share`)
- [ ] Offline OSM tile caching for map screen
- [ ] Pull-to-refresh on History and Dashboard screens
- [ ] Notes editing for past scan records

---

## React Native App — Sprint C: UAV Integration  `[ ]`
> Goal: MAVLink telemetry view in app, live mission monitoring.

- [ ] UDP MAVLink v2 socket via `react-native-udp`
- [ ] Parse HEARTBEAT, GPS_RAW_INT, BATTERY_STATUS messages
- [ ] UAV status overlay on Map screen (altitude, battery, mode)
- [ ] Trigger UAV scan from app, receive heatmap results

### D4 — Live video + real-time inference
- [ ] RTSP stream from drone companion computer → Flutter video player
- [ ] Frame capture → TFLite inference → overlay disease label on video

---

## Flutter App — Phase E: PDF Export & Sharing  `[ ]`
> Agronomist-ready field report, shareable offline.

- [ ] Multi-page PDF: farm summary, scan history table, UAV heatmap image, per-disease treatment protocols
- [ ] Auto-generated filename: `MaizeGuard_Report_YYYY-MM-DD.pdf`
- [ ] WhatsApp deep-link share (dominant in Nigerian smallholder context)
- [ ] Email share via `share_plus`

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
| 1 — CNN Classifier | 🟡 Trained (quick) | Tijani | Run `--full` for 90%+ target |
| 2 — OCR Subsystem | ✅ Working | Tijani | Needs real seed label photos |
| 3 — Multimodal Fusion | 🟡 Trained (quick) | Olayinka + Tijani | Run `--full` to converge |
| 4 — Edge Deployment | 🟡 Code done | Oshodilawal | Benchmark <2s on Pi 4 |
| 5 — UAV Integration | ✅ Code complete | Oshodilawal | Test with real orthomosaic GeoTIFF |
| App Phase A — Core | ✅ Working | Tijani | Android + macOS inference working |
| App Phase B — Pro UI | 🟡 In progress | Tijani | Dashboard → Map → History → Export |
| App Phase C — AI | ⬜ Not started | Oshodilawal | Rule engine → Claude API → Trend model |
| App Phase D — UAV Control | ⬜ Not started | Tijani | MAVLink UDP → Telemetry → Mission upload |
| App Phase E — PDF Export | ⬜ Not started | Olayinka | After Phase B history screen is done |
