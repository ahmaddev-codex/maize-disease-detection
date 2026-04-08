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

- [x] `src/phase4_edge/convert_tflite.py` — INT8 quantization with representative dataset
- [x] `src/phase4_edge/inference.py` — inference runner for Pi / Jetson
- [x] `deployment/raspberry_pi/app.py` — Tkinter GUI
- [ ] Inference time < 2 seconds on Pi 4 — benchmark with `--benchmark` flag on device

---

## Phase 5 — UAV Integration ✅
> Goal: GPS-tagged disease heatmap from aerial imagery using OpenDroneMap + model inference.

- [x] `deployment/uav/flight_planner.py` — grid mission generator → MAVLink .waypoints (QGC/Mission Planner)
- [x] `deployment/uav/patch_runner.py` — tile orthomosaic → TFLite inference per patch → CSV
- [x] `deployment/uav/heatmap.py` — Folium interactive HTML map + matplotlib static PNG
- [x] Demo mode (`--demo`) works without hardware — synthetic orthomosaic + predictions
- [ ] Test with real GeoTIFF orthomosaic from OpenDroneMap

---

## Flutter App — Phase A (Core) ✅
> Primary farmer-facing tool. TFLite on-device inference, camera overlay, OCR capture.

- [x] `deployment/app/` — Flutter project scaffolded (Android + macOS)
- [x] Camera preview with leaf framing guide, brightness hints, tap-to-focus
- [x] On-device TFLite inference — INT8 with FP16 fallback (`tflite_flutter`)
- [x] OCR metadata capture screen (ML Kit, Android/iOS only)
- [x] Disease result + treatment recommendation screen
- [x] Inference runs in compute isolate — UI stays responsive

---

## Flutter App — Phase B: Professional UI  `[~]`
> Goal: production-grade UI — dashboard, farm map, scan history, field report export.

### B1 — Dashboard screen
- [ ] Farm health score card (aggregate of recent scans)
- [ ] Disease trend sparklines (last 7 / 30 days)
- [ ] Recent scans strip with thumbnails + quick stats
- [ ] Quick-action FAB (camera / gallery / UAV)

### B2 — Map screen (offline-capable)
- [ ] `flutter_map` + OpenStreetMap tiles (cached for offline use)
- [ ] Farm boundary polygon (drawn by user or imported from GeoJSON)
- [ ] Disease hotspot markers from past UAV surveys
- [ ] UAV live position marker (when connected)

### B3 — Scan history
- [ ] SQLite persistence (`drift` package) — store all scan results with image path, class, confidence, GPS, timestamp
- [ ] Filterable list: by disease type, date range, confidence threshold
- [ ] Tap to re-open result screen for any past scan

### B4 — Field report export
- [ ] PDF generation (`pdf` package) — cover page, disease summary, map screenshot, treatment plan
- [ ] Share via WhatsApp / email (`share_plus` package)
- [ ] Offline-first — report generated entirely on-device

---

## Flutter App — Phase C: AI Recommendations  `[ ]`
> Goal: contextualised, intelligent treatment recommendations beyond static lookup tables.

### C1 — On-device contextual engine
- [ ] Rule engine factoring in: disease class + confidence, crop variety (from OCR), season, scan history trend, Nigerian state (fungicide availability)
- [ ] `lib/services/recommendation_engine.dart`

### C2 — Claude API integration (online)
- [ ] Call Anthropic API with structured context: disease, confidence, variety, planting date, field history, region
- [ ] Returns detailed agronomic advice: specific fungicide brands in Nigeria, application rates, growth-stage timing, resistance management
- [ ] `lib/services/ai_advisor.dart` — graceful offline fallback to C1 rule engine

### C3 — Trend prediction (on-device)
- [ ] Lightweight LSTM / time-series model (<1 MB TFLite) trained on scan history
- [ ] Predicts disease progression for next 7 days
- [ ] Alert system: push notification if model predicts outbreak

---

## Flutter App — Phase D: UAV Control  `[ ]`
> Goal: control ArduPilot/PX4 drones directly from the app over WiFi/UDP MAVLink.

### D1 — MAVLink telemetry (read-only)
- [ ] UDP socket on port 14550 via `dart:io` (raw MAVLink v2 parsing)
- [ ] `lib/services/mavlink_service.dart` — parse HEARTBEAT, GPS_RAW_INT, SYS_STATUS, ATTITUDE, BATTERY_STATUS
- [ ] Telemetry dashboard: altitude, speed, battery %, GPS lock, flight mode, armed state

### D2 — UAV control screen
- [ ] Artificial horizon (attitude indicator widget)
- [ ] Compass rose + heading
- [ ] Telemetry gauges (altitude, ground speed, battery)
- [ ] Arm / Disarm / Takeoff / RTL / Land buttons (with confirmation dialogs)
- [ ] Flight mode selector (Loiter, Auto, Guided)

### D3 — Mission planning & upload
- [ ] Farm boundary drawing tool on map screen
- [ ] Auto-generate grid waypoints (port of `flight_planner.py` logic to Dart)
- [ ] Upload mission to drone via MAVLink MISSION_ITEM messages
- [ ] Mission progress tracking (current waypoint, % complete, ETA)

### D4 — Live video + real-time inference
- [ ] RTSP stream from drone companion computer → Flutter video player
- [ ] Frame capture → TFLite inference → overlay disease label on video
- [ ] Requires companion computer (Raspberry Pi) on drone

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
