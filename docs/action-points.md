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

---

## Phase 9 — UX Refinement & Practical Deployment

- [x] **F63 — Confidence gate** — `result_screen.dart`: if `result.confidence < 0.60`, amber warning banner shown above verdict card with lighting/framing/distance tips
- [] **F64 — Multi-leaf scan mode** — add a "Scan 3 leaves" flow in `home_screen.dart`; accumulate 3 `ClassificationResult` objects, compute modal class + mean confidence, push a summary screen before saving to DB
- [x] **F65 — Scan feedback loop** — `feedback` column (nullable int: 1=correct, 0=wrong, -1=unsure) added to `scan_records` (DB v2, `onUpgrade` migration); `DatabaseService.updateFeedback()` added; feedback prompt renders after AI advice loads in `result_screen.dart`
- [x] **F66 + F67 + F68 — Unified screen** — `result_screen.dart` rewritten as `ConsumerStatefulWidget`; `recommendation_screen.dart` and `ai_advice_sheet.dart` deleted; `/recommendation` route aliases to `/result`; verdict card above fold, on-device sections below, AI advice inline with "AI-enhanced" badge; class scores + About are collapsible `AnimatedCrossFade` cards
- [x] **F69 — OCR inline correction** — `ocr_screen.dart`: after extraction, `_EditableField` TextFields pre-filled with OCR values; `_attach()` reads corrected controller values instead of raw `OcrFields`; `_FieldRow` widget removed
- [~] **F70 — Text-to-speech** — English: device TTS via `flutter_tts`; Yoruba/Igbo/Hausa: `YarnTtsService` (POST `https://yarngpt.ai/api/v1/tts`, Bearer auth, MP3 bytes played via `audioplayers ^6.0.0`); voices: Idera (Yoruba), Chinenye (Igbo), Zainab (Hausa); button shows spinner during API call, stop icon during playback; device-test required to verify authentic Yoruba pronunciation
- [x] **Regression check** — `flutter analyze` passes with zero errors

---

## Phase 10 — Language & Translation

- [x] **F71 — `displayLanguageProvider`** added to `app_provider.dart` — `DisplayLanguage` enum (english/yoruba/igbo/hausa), `DisplayLanguageNotifier` persists to SharedPreferences key `display_language`
- [x] **F71 — Language selector in Settings** — `_LanguageSelector` `ConsumerWidget` with animated chip row; added between AI Advisor and Data & Privacy sections in `settings_screen.dart`
- [x] **F72 — `AiAdvisor.getAdvice()` language param** — `_prompt()` appends "Respond entirely in $language" instruction when language ≠ English
- [x] **F72 — Language passed to advice calls** — `recommendation_screen.dart` and `ai_advice_sheet.dart` both watch `displayLanguageProvider` and pass `lang.label` to `AiAdvisor.getAdvice()`
- [x] **F73 — `AiAdvisor.translateResult()`** — new method wraps English content in translation prompt; routes through Gemini→Groq fallback chain
- [x] **F73 — Translate button in recommendation_screen.dart** — when language ≠ English: shows "Translate advice to ${lang.label}" TextButton; on tap calls `_translateAdvice()`; translated text shown in `GlassCard` with "Translated · ${lang.label}" header
- [] **Verify on device** — switch to Igbo, fetch advice, confirm Igbo response; switch to English, confirm it reverts; confirm translate button for on-device sections works

---

## Phase 11 — AI Reliability (Gemini → Groq Fallback)

- [x] **F74 — `_groq()` in `AiAdvisor`** — added `_groq(String prompt)` using Groq's OpenAI-compatible endpoint (`https://api.groq.com/openai/v1/chat/completions`) with model `llama-3.3-70b-versatile`; same 512-token limit, 0.3 temperature
- [x] **F74 — `_geminiWithFallback()`** — wraps `_gemini()` in try/catch; on any exception, calls `_groq()` automatically; both `getAdvice()` and `translateResult()` route through this in release builds
- [x] **F75 — `AppEnv.groqApiKey`** — `String.fromEnvironment('GROQ_API_KEY')` compile-time constant; key already present in `.env.json`
- [x] **`.env.json` fix** — corrected missing comma after GROQ_API_KEY line (invalid JSON that would have caused build failures)
