# MaizeGuard — Action Points

Manual steps you need to complete at the end of each phase before moving to the next.

**Status:** `[x]` done · `[~]` started / partially done · `[]` not yet done

---

## Phase 1 — Model Training & Validation

- [x] **Download PlantVillage dataset** — placed in `data/raw/` (NCLB / Rust / GLS / Healthy folders)
- [x] **Run training pipeline** — `bash run_all.sh` — model files generated
- [x] **Verify gate conditions** — confusion matrix exported at `models/exports/confusion_matrix_phase1.png`
- [x] **Confirm TFLite exports exist** — `models/exports/efficientnetb3_maize_int8.tflite` and `_fp16.tflite`

---

## Phase 2 — Mobile Core

- [] **Install Flutter** — https://flutter.dev/docs/get-started/install (≥ 3.19)
- [] **Run setup script** — `bash mobile/setup.sh` (auto-detects Android/iOS)
- [] **Test on Android** — connect device or start emulator, then `flutter run -d android` from `mobile/`
- [] **Verify model loads** — home screen chip should show "GPU delegate" or "CPU fallback" (not "Loading…")
- [] **Take a test scan** — confirm result screen shows class, confidence, and latency

---

## Phase 3 — Seed Label OCR

- [] **Grant photo/camera permissions** on device when prompted by the OCR screen
- [] **Test with a real seed bag label** — photograph it and check that variety, batch, and date are extracted correctly
- [] **Verify attach flow** — after attaching an OCR result, confirm the scan record in History shows `crop_variety` and `batch_number`

---

## Phase 4 — Farm Map & GPS

- [] **Grant location permission** on device when prompted
- [] **Enable GPS** — take at least 3 scans outdoors (or with mock GPS in emulator)
- [] **Verify map pins** — open Farm Map and confirm coloured markers appear at scan locations

---

## Phase 5 — Analytics Dashboard & History

- [] **Accumulate at least 7 scans** across different days (use gallery picker if needed)
- [] **Verify bar chart** — dashboard 7-day chart should show scan counts per day
- [] **Test delete** — long-press a History entry and confirm it is removed from DB

---

## Phase 6 — Recommendations & AI Advisor

- [] **Get a Gemini API key** — https://aistudio.google.com/app/apikey (free tier is enough)
- [] **Enter key in Settings** — Settings → AI Advisor → Save key
- [] **Test Gemini advice** — open a scan result → Recommendation → tap "Ask Gemini" — confirm non-empty response
- [] **Test offline rule engine** — disable network and open Recommendation screen — confirm on-device advice still appears

---

## Phase 7 — Polish & Settings

- [] **Run `flutter test`** from `mobile/` — all unit tests must pass
- [] **Run `flutter analyze`** — fix any warnings
- [] **Test theme toggle** — Settings → Dark mode — confirm app re-renders, preference survives app restart
- [] **Test clear data** — Settings → Clear all scan data — confirm History is empty afterwards

---

## Phase 8 — UAV / Drone Integration

- [] **Install Python deps** — `pip install -r requirements.txt` (includes pymavlink, flask, flask-socketio)
- [] **Connect drone** — USB serial (e.g. `/dev/ttyUSB0`), UDP (`udp:127.0.0.1:14550`), or TCP
- [] **Start live server** — `python deployment/uav/live_server.py`
- [] **Start telemetry script** — `python deployment/uav/drone_telemetry.py --connection /dev/ttyUSB0`
- [] **Open web dashboard** — http://localhost:5001 — confirm drone position marker appears
- [] **Fly a test mission** — confirm patches are classified and disease markers appear on the heatmap
- [] **Export heatmap** — confirm `data/uav/disease_heatmap.html` and `patch_predictions.csv` are generated
