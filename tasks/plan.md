# Implementation Plan: MaizeGuard Audit Remediation

## Overview

On 2026-09-10 two audits covered the whole platform:
- **Platform audit:** ML pipeline, notebooks, research papers, AI usage, UAV and docs.
- **Mobile audit:** the Flutter app, end to end.

Both found problems at three levels:
- **Release blockers:** the Android release build has no network or GPS permissions, and the model-load failure is swallowed.
- **Wrong results:** dashboard bars always read 0, DD/MM/YYYY dates are never parsed, and opening a past scan shows the wrong scan.
- **Unsafe or unbacked claims:** the AI recommends spraying healthy plants, and the papers report 95.8% fusion accuracy with no model behind it.

This plan fixes all of it in small, verifiable slices. The end state:
1. A release build works end-to-end on a real phone.
2. Advice is safe and honest about where it came from.
3. Every number in the research papers traces to a reproducible artifact.
4. Each concept (labels, thresholds, post-processing, UAV code) has exactly one source of truth.

**Measured baseline** (628-image test split, 2026-09-10; the eval script reports 629):

| Model | Pipeline | Accuracy | GLS F1 | NCLB F1 |
|---|---|---|---|---|
| FP16 | Python (bilinear) | 91.10% | 0.727 | 0.847 |
| INT8 | Python (bilinear) | 88.08% | 0.658 | 0.802 |
| INT8 | App (nearest) | 86.33% | 0.655 | 0.782 |

**Targets** from REQUIREMENTS.md:
- NFR-06: accuracy ≥ 90%.
- NFR-07: F1 ≥ 0.88 for every class.
- NFR-01: ≤ 2 s from capture to result.
- FR-14: fuzzy variety match score ≥ 60.

## Pre-flight (user action, before Task 1)

- Commit or stash the current work in progress on `dev`: `camera_screen.dart`, `result_screen.dart`, `src/phase5_uav/heatmap.py`. Also decide whether `notebooks/` and `research-papers/` get committed.
- Confirm that removing `docs/` was intentional. It was: only `research-papers/` was kept, and it now lives at the repo root.

## How the agent skills apply

| Skill | Where it applies |
|---|---|
| `planning-and-task-breakdown` | This document |
| `test-driven-development` (Prove-It) | Every bug task: write a failing reproduction test first, then fix, then run the full suite |
| `incremental-implementation` + `git-workflow-and-versioning` | One task = one commit on `dev`; the app and pipeline stay working after each task |
| `security-and-hardening` | T04, T26, T28, T49 (permissions, LLM output handling, API keys, secret scan) |
| `source-driven-development` | T04 (Android permissions, OSM tile policy), T10 (`IsolateInterpreter`), T20 (camera format groups), T26 (Groq model IDs), T39 (rasterio CRS) |
| `performance-optimization` | T10 (inference off the UI thread), T12 (on-device benchmark) |
| `deprecation-and-migration` | T24 (additive DB v3 migration), T37 (UAV consolidation), T47 (dead code) |
| `documentation-and-adrs` | T02 (ADRs), Phase 7 (docs and papers) |
| `doubt-driven-development` | T43, T44: fresh-context review of every research-paper claim |
| `frontend-ui-engineering` | Phases 1, 3 and 4 UI changes (states, copy, accessibility) |
| `ci-cd-and-automation` | T49 |
| `code-simplification` | T47 |

## Definition of Done (every task)

- A reproduction test was seen failing before the fix (bug tasks), and new behaviour has tests.
- Mobile: `cd mobile && flutter analyze` reports no issues, and `flutter test` passes.
- Python: `.venv/bin/python -m pytest -q` passes.
- Docs and research papers are updated in Phase 7 whenever a task changes behaviour they describe. Log the change in `tasks/todo.md` under "Doc impacts".
- No secrets, local paths or debug-only code are added.
- Committed as one focused commit, once the user approves committing.

## Architecture Decisions (proposed; need approval at Checkpoint 0)

Recorded as ADRs in `decisions/` at the repo root, matching the flattened layout now that `docs/` is gone.

- **ADR-001: Primary on-device model.** Ship FP16 as primary, with INT8 as fallback.
  - Rationale: FP16 is 3 points more accurate, and INT8 was 2.3× slower on CPU (notebook 4).
  - Revisit only if a re-quantised INT8 is within 0.5 points of FP16 and faster on a real device.
- **ADR-002: Fusion model status.** Mark fusion "experimental".
  - There is no real seed-label metadata; the current metadata is random (`run_all.sh:170-183`).
  - Remove all fusion accuracy claims until a real metadata dataset exists.
  - Keep the code running and add an ablation study.
- **ADR-003: AI provider and keys.** Groq is the only cloud provider, with offline templates as the fallback.
  - Release builds do not embed `GROQ_API_KEY`: the user enters a key, or a backend proxy is used later.
  - The papers must drop the claim that "keys cannot be extracted from the binary".
- **ADR-004: UAV code location.** `src/phase5_uav/` is the one canonical module.
  - Delete the root `uav/`.
  - `deployment/uav/*` stays as shims that emit a deprecation warning for one cycle.
- **ADR-005: App identity and signing.** Use one ID, `com.ahmaddev.maizeguard`, on Android and iOS.
  - Android release builds are signed from `key.properties`, never with debug keys.
- **ADR-006: Single sources of truth.**
  - Class labels and post-processing: `src/common/`.
  - Confidence thresholds: `mobile/lib/constants/thresholds.dart`.
  - OCR test cases: `tests/fixtures/ocr_cases.json`, shared by Dart and Python.
  - Model metrics: `models/exports/metrics.json`.

## Dependency Graph

```
Phase 0  Baseline: T01 eval script → T02 ADRs/lockfile;  T03 service seams
   │
   ├── Phase 1  Mobile release blockers (T04–T08)          ← Dart track
   │      └── Phase 2  Diagnosis correctness (T09–T17)
   │             └── Phase 3  Scan flow & data lifecycle (T18–T23)
   │                    └── Phase 4  AI advice & voice (T24–T29)
   │
   ├── Phase 5  ML pipeline integrity (T30–T36)             ← Python track, parallel with 1–4
   │      ├── Phase 5b Data acquisition (T50–T55)           ← field test set, seed labels, variety table
   │      └── Phase 6  UAV (T37–T40)
   │
   └── Phase 7  Notebooks → research papers → docs (T41–T46)   needs 2, 4, 5, 6
          └── Phase 8  Hardening: dead code, integration test, CI (T47–T49)
```

**Parallelisation:**
- The Dart track (Phases 1–4) and the Python track (Phases 5–6) touch no shared files, so they can run in parallel.
- The two tracks meet at T11, T12, T41 and T43, which consume `metrics.json` from T01 and T32.
- T13 (OCR fixture) must land before T14.
- Phase 7 runs last so the docs describe final behaviour.

---

## Phase 0: Baseline and decisions

### Task T01: Reproducible TFLite evaluation writes `metrics.json`

**Description:** Turn the audit's ad-hoc evaluation into `src/phase4_edge/evaluate_tflite.py`.
- Evaluate a `.tflite` model on the stratified test split.
- Support two preprocessing modes: `python` (bilinear) and `app` (matches `classifier_service.dart`).
- Write to `models/exports/metrics.json`: accuracy, per-class P/R/F1, confusion matrix, model sha256, git sha, split sizes, duplicate report.

This becomes the single source for model decisions and paper numbers.

**Acceptance criteria:**
- [ ] Reproduces INT8 88.08% and FP16 91.10% (±0.1) in `python` mode, and INT8 86.33% in `app` mode.
- [ ] `metrics.json` has a documented schema (docstring) with one entry per model × mode.
- [ ] Exits non-zero with a clear message if the model or `labels.csv` is missing.

**Verification:**
- [ ] `.venv/bin/python -m pytest -q tests/test_evaluate_tflite.py` passes. It uses a 4-image fixture and skips if the model is absent, like `test_tflite_inference.py`.
- [ ] Manual: `python -m src.phase4_edge.evaluate_tflite --model models/exports/efficientnetb3_maize_fp16.tflite`

**Dependencies:** None
**Files likely touched:** `src/phase4_edge/evaluate_tflite.py`, `tests/test_evaluate_tflite.py`
**Estimated scope:** Small

### Task T02: Record ADR-001…006 and commit the Dart lockfile

**Description:** Write the six ADRs above, using the metrics from T01 as evidence. Stop ignoring `mobile/pubspec.lock`, so dependency pins like `path_provider_foundation` stay reproducible.

**Acceptance criteria:**
- [ ] Six ADRs exist in `decisions/` with status Accepted after human review.
- [ ] `mobile/pubspec.lock` is tracked, and `flutter pub get --enforce-lockfile` succeeds.

**Verification:**
- [ ] `git ls-files mobile/pubspec.lock` prints the path.
- [ ] Manual: human approves ADRs at Checkpoint 0.

**Dependencies:** T01
**Files likely touched:** `decisions/0001…0006-*.md`, `.gitignore`, `mobile/pubspec.lock`
**Estimated scope:** Small

### Task T03: Service providers and test fakes (testing seam)

**Description:** Expose `ClassifierService`, `OcrService`, `LocationService`, `AiAdvisor`, `YarnTtsService` and `DatabaseService` through Riverpod providers, with the existing singletons as defaults. Add fakes under `test/fakes/`. Screens migrate to these providers inside the tasks that touch them, not here. No behaviour change.

**Acceptance criteria:**
- [ ] `lib/providers/service_providers.dart` exposes one provider per service.
- [ ] A sample widget test overrides the classifier provider with a fake.

**Verification:**
- [ ] `flutter analyze` and `flutter test` are green.

**Dependencies:** None
**Files likely touched:** `mobile/lib/providers/service_providers.dart`, `mobile/test/fakes/fake_services.dart`, `mobile/test/service_override_test.dart`
**Estimated scope:** Small

### Checkpoint 0
- [ ] ADRs approved; open questions answered, in particular Q1–Q5.
- [ ] `metrics.json` baseline committed; `flutter test` and `pytest` green.

---

## Phase 1: Mobile release blockers

### Task T04: Android release build has network, GPS and a real app identity

**Description:** The main `AndroidManifest.xml` declares no permissions; `INTERNET` exists only in the debug and profile manifests. In release builds this breaks four things: Groq advice, YarnGPT voice, map tiles and GPS.

Changes:
- Add `INTERNET`, `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`. `CAMERA` is merged in by the camera plugin, but declare it explicitly too.
- Apply ADR-005: change `applicationId` and `namespace`, and move the `MainActivity` package to match.
- Sign release builds from `key.properties`.
- Set the map's `userAgentPackageName` to the real app ID.
- Add the OpenStreetMap attribution the tile licence requires.

**Acceptance criteria:**
- [ ] `aapt dump permissions app-release.apk` lists `INTERNET`, `ACCESS_FINE_LOCATION` and `CAMERA`.
- [ ] The Android `applicationId` equals the iOS `PRODUCT_BUNDLE_IDENTIFIER`, and the release config no longer references `signingConfigs.debug`.
- [ ] The map screen shows OSM attribution.

**Verification:**
- [ ] `cd mobile && flutter build apk --release --dart-define-from-file=.env.json` succeeds.
- [ ] Manual, on a real Android phone with the release APK: a scan stores GPS and a map pin, map tiles load, and AI advice comes from Groq.

**Dependencies:** T02
**Files likely touched:** `mobile/android/app/src/main/AndroidManifest.xml`, `mobile/android/app/build.gradle.kts`, `mobile/android/app/src/main/kotlin/**/MainActivity.kt`, `mobile/lib/screens/map_screen.dart`, `mobile/ios/Runner.xcodeproj/project.pbxproj`
**Estimated scope:** Medium

### Task T05: Model load state is visible and recoverable

**Description:** Splash catches a model-load failure, then `home_screen.dart:25` calls `loadModel()` again with no error handling. The status stays "Loading Neural Checkpoint…" forever.

Changes:
- Make splash the single load path, sharing one in-flight future.
- Add a `classifierStateProvider` with states loading, ready(variant) and failed(message).
- Home shows the real variant from `modelStatus` and a Retry button.
- Disable camera entry while the model has failed.

**Acceptance criteria:**
- [ ] A failing fake classifier makes Home show an error and Retry, with no uncaught async exception.
- [ ] A successful load shows "EfficientNetB3 · FP16" or "· INT8" from the real loaded variant.
- [ ] Concurrent `loadModel()` calls load the model only once.

**Verification:**
- [ ] `flutter test test/model_load_state_test.dart`: RED on current code, then GREEN.
- [ ] Full `flutter test` passes.

**Dependencies:** T03
**Files likely touched:** `mobile/lib/services/classifier_service.dart`, `mobile/lib/providers/app_provider.dart`, `mobile/lib/screens/splash_screen.dart`, `mobile/lib/screens/home_screen.dart`, `mobile/test/model_load_state_test.dart`
**Estimated scope:** Medium

### Task T06: Result screen renders exactly one resolved scan

**Description:** Today ResultScreen mixes `lastResultProvider`, `lastImagePathProvider`, `lastScanVarietyProvider` and `activeScanRecordProvider` (`result_screen.dart:358-383`). History and Map therefore show the last camera photo and variety, and voice and AI fire with the previous diagnosis on the first frame.

Changes:
- Add an `openScan(ref, ScanRecord)` action.
- ResultScreen renders only from the resolved record: image, variety, result and feedback.
- Show a loader until the record resolves; voice auto-play and AI requests start only after that.
- Migrate the camera caller in this task.

**Acceptance criteria:**
- [ ] Prove-It widget test: camera scan A, then open scan B. Image, variety and diagnosis are B's, and the fake AI and voice are called only with B's class.
- [ ] Camera → Result still works, including the auto voice.

**Verification:**
- [ ] `flutter test test/result_screen_scan_identity_test.dart`: RED, then GREEN.

**Dependencies:** T03
**Files likely touched:** `mobile/lib/providers/app_provider.dart`, `mobile/lib/screens/result_screen.dart`, `mobile/lib/screens/camera_screen.dart`, `mobile/test/result_screen_scan_identity_test.dart`
**Estimated scope:** Medium

### Task T07: Home, History and Map open scans via `openScan`; remove legacy providers

**Description:** Migrate the remaining callers (`home_screen.dart:386`, `history_screen.dart:119`, `map_screen.dart:250`). Then delete `lastResultProvider`, `lastImagePathProvider` and `lastScanVarietyProvider`, and remove their resets in Settings.

**Acceptance criteria:**
- [ ] No references to the three legacy providers remain.
- [ ] The T06 test is extended to open scans from History and Map, and passes.

**Verification:**
- [ ] `grep -rn "lastResultProvider\|lastImagePathProvider\|lastScanVarietyProvider" mobile/lib` finds nothing.
- [ ] `flutter test` passes.

**Dependencies:** T06
**Files likely touched:** `mobile/lib/screens/home_screen.dart`, `mobile/lib/screens/history_screen.dart`, `mobile/lib/screens/map_screen.dart`, `mobile/lib/screens/settings_screen.dart`, `mobile/lib/providers/app_provider.dart`
**Estimated scope:** Medium

### Task T08: Feedback selection updates immediately; History labels are correct

**Description:**
- The feedback highlight reads from a FutureProvider that is never invalidated (`result_screen.dart:384`); invalidate or update it on save.
- History shows "Uncertain" when feedback is null (`history_screen.dart:253`); show no label in that case.

**Acceptance criteria:**
- [ ] Tapping "Correct" highlights immediately and stays highlighted after reopening.
- [ ] A scan with no feedback shows no feedback label in History; −1 shows "Uncertain".

**Verification:**
- [ ] `flutter test test/feedback_state_test.dart`: RED, then GREEN.

**Dependencies:** T06
**Files likely touched:** `mobile/lib/screens/result_screen.dart`, `mobile/lib/providers/app_provider.dart`, `mobile/lib/screens/history_screen.dart`, `mobile/test/feedback_state_test.dart`
**Estimated scope:** Small

### Checkpoint 1: Release blockers
- [ ] `flutter analyze` and `flutter test` are green, and the release APK builds.
- [ ] On a real phone (release build): scan → GPS pin on map → Groq advice, and opening from History or Map shows the correct scan.
- [ ] Human review before Phase 2.

---

## Phase 2: Diagnosis correctness

### Task T09: App preprocessing matches training (bilinear), proven by a parity test

**Description:** `img.copyResize` defaults to nearest-neighbour (`classifier_service.dart:67`), which costs 1.75 accuracy points on INT8. Extract a pure `preprocessForModel(bytes)` that uses `Interpolation.linear`. Add a Dart test comparing per-channel means against a Python-generated fixture for the same image. Update T01's `app` mode to match.

**Acceptance criteria:**
- [ ] Dart and Python preprocessing agree: mean absolute per-channel difference ≤ 1.0 on the fixture image.
- [ ] `evaluate_tflite --mode app` for INT8 is within 0.3 points of `python` mode.

**Verification:**
- [ ] `flutter test test/preprocess_parity_test.dart` passes.
- [ ] `metrics.json` shows the app-mode delta ≤ 0.3.

**Dependencies:** T01
**Files likely touched:** `mobile/lib/services/classifier_preprocess.dart`, `mobile/lib/services/classifier_service.dart`, `mobile/test/preprocess_parity_test.dart`, `mobile/test/fixtures/preprocess_fixture.json`, `src/phase4_edge/evaluate_tflite.py`
**Estimated scope:** Medium

### Task T10: Inference off the UI thread; latency reported honestly

**Description:**
- Run decode and resize in `Isolate.run`, and inference through `tflite_flutter`'s `IsolateInterpreter`. Verify that API against the 0.11.0 docs before using it.
- Split latency into `modelLatencyMs` (what gets stored) and `totalLatencyMs` (capture to result, shown on screen).
- Label both clearly on the result screen.

**Acceptance criteria:**
- [ ] No UI frame over 100 ms while classifying a 12 MP photo (Flutter DevTools timeline on a device).
- [ ] The result screen shows "Model: X ms · Total: Y ms".

**Verification:**
- [ ] `flutter test` passes, including a unit test of the latency fields with a fake interpreter.
- [ ] Manual DevTools performance trace attached to the task notes.

**Dependencies:** T09
**Files likely touched:** `mobile/lib/services/classifier_service.dart`, `mobile/lib/models/scan_record.dart`, `mobile/lib/screens/result_screen.dart`, `mobile/test/classifier_latency_test.dart`
**Estimated scope:** Medium

### Task T11: Ship the primary model chosen in ADR-001

**Description:** Apply the load order from ADR-001 (FP16 first). If the ADR chose re-quantised INT8, this waits for T32. `setup.sh` copies the chosen models only when `metrics.json` has a matching sha256.

**Acceptance criteria:**
- [ ] A fake-interpreter test shows the load order follows the ADR.
- [ ] `setup.sh` refuses (non-zero exit) when the model sha has no metrics entry.

**Verification:**
- [ ] `flutter test test/model_load_order_test.dart` passes.
- [ ] `bash mobile/setup.sh --android` succeeds with the current models.

**Dependencies:** T02, T05, T09
**Files likely touched:** `mobile/lib/services/classifier_service.dart`, `mobile/setup.sh`, `mobile/test/model_load_order_test.dart`
**Estimated scope:** Small

### Task T12: On-device latency benchmark recorded

**Description:** Measure model and total latency on at least one real mid-range Android phone, and on iOS if available. Use 30 runs after warm-up. Record device, OS, model variant, mean and p95 in `models/exports/device_benchmark.json`. This replaces the unbacked "~850 ms" claim in the papers.

**Acceptance criteria:**
- [ ] `device_benchmark.json` has at least one real-device entry per shipped model variant.
- [ ] NFR-01 (≤ 2 s from capture to result) is marked pass or fail from this data.

**Verification:**
- [ ] Manual: a debug-only benchmark action or `flutter drive` script; its output is committed.

**Dependencies:** T10, T11 (needs a physical device — see Q1)
**Files likely touched:** `mobile/lib/screens/settings_screen.dart` (debug-only action) or `mobile/integration_test/benchmark_test.dart`, `models/exports/device_benchmark.json`
**Estimated scope:** Small

### Task T13: OCR parser fixed and shared test fixtures (Dart)

**Description:** Extract a pure `ocr_parser.dart` and create `tests/fixtures/ocr_cases.json` from the audit's reproduction cases. Parser fixes:
- **Dates:** parse DD/MM/YYYY and D-M-YYYY, which currently throw a RangeError in `ocr_service.dart:88`. Reject impossible dates such as `31/13/2024`.
- **Varieties:** normalise hyphens and case, and match on token boundaries so `SAMMAZ-17` plus the date "15" no longer yields `SAMMAZ 15`. Use a Levenshtein ratio ≥ 60 per FR-14.
- **Batch numbers:** support `BATCH-2024-NG04` and `Lot 2024 007`, and return the value without its `BATCH NO:` prefix.
- **Form:** the OCR screen validates the planting-date field.

**Acceptance criteria:**
- [ ] Every case in `ocr_cases.json` passes; the date and variety cases are recorded failing on the old code.
- [ ] The planting-date field rejects values that aren't dates, with an inline error.

**Verification:**
- [ ] `flutter test test/ocr_parser_test.dart`: RED on the current regexes, then GREEN.

**Dependencies:** None
**Files likely touched:** `mobile/lib/services/ocr_parser.dart`, `mobile/lib/services/ocr_service.dart`, `mobile/lib/screens/ocr_screen.dart`, `mobile/test/ocr_parser_test.dart`, `tests/fixtures/ocr_cases.json`
**Estimated scope:** Medium

### Task T14: Python extractor matches the Dart parser and gains its CLI

**Description:**
- `src/phase2_ocr/extractor.py` passes the same `ocr_cases.json`.
- Add the `--image` CLI that the README and `run_all.sh` already reference.
- Fail loudly when the Tesseract binary is missing; notebook 2 silently got empty text.

**Acceptance criteria:**
- [ ] `pytest tests/test_ocr_extractor.py` passes on the shared fixture.
- [ ] `python -m src.phase2_ocr.extractor --image data/raw/seed_labels/sample_label.jpg` prints the fields, or exits non-zero with "tesseract not found".

**Verification:**
- [ ] `.venv/bin/python -m pytest -q tests/test_ocr_extractor.py` passes.

**Dependencies:** T13
**Files likely touched:** `src/phase2_ocr/extractor.py`, `tests/test_ocr_extractor.py`
**Estimated scope:** Small

### Task T15: One set of confidence thresholds; urgency consistent with confidence and trend

**Description:** Thresholds currently conflict:

| Where | Threshold |
|---|---|
| Retake banner | < 0.60 |
| Confidence meter "Low" | < 0.65 |
| Urgency medium / high | 0.55 / 0.70 |

Changes:
- Create `thresholds.dart` and make the banner, meter, urgency and spoken summary all read from it.
- Low confidence gives the urgency label "Verify — retake photo", and the voice says to retake instead of "immediate treatment".
- `RecommendationEngine` receives the real trend from `healthTrendProvider`, so "critical" becomes reachable.
- Delete the unused `getRecommendation()`.

**Acceptance criteria:**
- [ ] A table test for confidence {0.58, 0.62, 0.90} × trend {stable, worsening} gives a consistent banner, meter label, urgency and voice key.
- [ ] No numeric confidence literals remain in screens or components.

**Verification:**
- [ ] `flutter test test/thresholds_consistency_test.dart`: RED, then GREEN.
- [ ] `grep -rn "0\.[5-9][0-9]*" mobile/lib/screens mobile/lib/design_system/components` finds no confidence thresholds.

**Dependencies:** T06
**Files likely touched:** `mobile/lib/constants/thresholds.dart`, `mobile/lib/services/recommendation_engine.dart`, `mobile/lib/design_system/components/confidence_meter.dart`, `mobile/lib/screens/result_screen.dart`, `mobile/test/thresholds_consistency_test.dart`
**Estimated scope:** Medium

### Task T16: Farm statistics are correct and identical on Home and Dashboard

**Description:**
- **Bug:** the dashboard looks up `'NCLB'`, `'Rust'` and `'GLS'` (`dashboard_screen.dart:172`), but the database groups by the full `class_name`, so disease bars are always 0.
- **Fix:** aggregate by `class_id` in one `FarmStats` query, used by both Home and Dashboard, with an explicit window label.
- **Empty state:** show "No scans yet" instead of 100 "Crop Vigorous".
- **Totals:** use `COUNT(*)` rather than the list capped at 500.
- **Day buckets:** compute in local time.
- **New dev dependency:** `sqflite_common_ffi`, reviewed per the security skill.

**Acceptance criteria:**
- [ ] Database test: inserting 1 NCLB, 1 Rust and 2 Healthy gives breakdown 25/25/0/50%.
- [ ] An empty database gives an empty state rather than a score, and Home matches Dashboard for the same window.
- [ ] A scan at 00:30 WAT counts toward the local day.

**Verification:**
- [ ] `flutter test test/farm_stats_test.dart`: RED on current queries, then GREEN.

**Dependencies:** T03
**Files likely touched:** `mobile/lib/services/database_service.dart`, `mobile/lib/screens/dashboard_screen.dart`, `mobile/lib/screens/home_screen.dart`, `mobile/test/farm_stats_test.dart`, `mobile/pubspec.yaml`
**Estimated scope:** Medium

### Task T17: Scan times are shown in local time everywhere

**Description:** `scannedAt` stays UTC in storage but is formatted without converting to local time (for example `home_screen.dart:410`). Add a `formatScanTime` helper with an injectable clock and timezone offset, and use it on Home, History and Map.

**Acceptance criteria:**
- [ ] Helper test: 2026-09-10T23:30Z at +01:00 formats as "11 Sep · 00:30".
- [ ] No `DateFormat(...).format(scan.scannedAt)` call remains outside the helper.

**Verification:**
- [ ] `flutter test test/time_format_test.dart` passes.
- [ ] `grep -rn "format(scan.scannedAt)" mobile/lib` finds nothing.

**Dependencies:** T16
**Files likely touched:** `mobile/lib/utils/time_format.dart`, `mobile/lib/screens/home_screen.dart`, `mobile/lib/screens/history_screen.dart`, `mobile/lib/screens/map_screen.dart`, `mobile/test/time_format_test.dart`
**Estimated scope:** Medium

### Task T56: OCR preprocessing no longer rotates labels sideways (found during T14)

**Description:** `src/phase2_ocr/preprocessor.py::_deskew` computes `cv2.minAreaRect` over every white pixel after thresholding. That is the background, 99% of the image. On OpenCV 4.9 the angle comes back as 90.0, because the angle convention changed in 4.5, so the whole label is rotated 90° before OCR.

Measured on `data/raw/seed_labels/sample_label.jpg`:
- Resize + threshold only: Tesseract reads "SAMMAZ 15 | Batch No BN-2024-042 | Planting Date: 15/03/2024".
- Full pipeline: Tesseract reads "- 3".

This is why notebook 2 and the OCR demo extract nothing.

Fix: estimate skew from text pixels only (inverted binary), normalise the minAreaRect angle for OpenCV ≥ 4.5 to [-45, 45], and skip corrections beyond a sane limit.

**Acceptance criteria:**
- [ ] Deskew leaves an upright label unrotated, and corrects a label rotated by a few degrees back to within 1°.
- [ ] End-to-end on the synthetic sample label: variety SAMMAZ 15, batch BN-2024-042, date 2024-03-15 (skipped when Tesseract is absent).

**Verification:**
- [ ] `.venv/bin/python -m pytest -q tests/test_ocr_preprocessor.py`: RED on current deskew, then GREEN.
- [ ] `python -m src.phase2_ocr.extractor --image data/raw/seed_labels/sample_label.jpg` prints all three fields.

**Dependencies:** T14
**Files likely touched:** `src/phase2_ocr/preprocessor.py`, `tests/test_ocr_preprocessor.py`
**Estimated scope:** Small

### Task T57: Bundle fonts so the app never fetches them at runtime (found on device)

**Description:** `AppTypography` builds every style with `GoogleFonts.dmSans(...)`, and no font files are bundled. On a phone without internet, google_fonts tries to download each weight from `fonts.gstatic.com` and throws an unhandled exception per weight:

```
Unhandled Exception: Exception: Failed to load font with url https://fonts.gstatic.com/...ttf:
ClientException with SocketException: Failed host lookup: 'fonts.gstatic.com'
```

This contradicts the offline claim and spams errors at startup. Fix: bundle the five DM Sans weights the design system uses (400, 500, 600, 700, 800) plus the OFL licence under `mobile/google_fonts/`, declare the folder in `assets`, disable runtime fetching, and register the licence.

**Acceptance criteria:**
- [ ] The five weight files and `OFL.txt` are bundled and listed in `pubspec.yaml` assets.
- [ ] `GoogleFonts.config.allowRuntimeFetching` is false once the app configures fonts.
- [ ] Rendering app text in a test throws no exception; the font licence is registered with `LicenseRegistry`.

**Verification:**
- [ ] `flutter test test/bundled_fonts_test.dart`: RED before bundling, then GREEN.
- [ ] Manual: run on a device in airplane mode; no `google_fonts` exceptions in the log.

**Dependencies:** None
**Files likely touched:** `mobile/google_fonts/*`, `mobile/pubspec.yaml`, `mobile/lib/design_system/tokens/app_typography.dart`, `mobile/lib/main.dart`, `mobile/test/bundled_fonts_test.dart`
**Estimated scope:** Small

### Checkpoint 2: Diagnosis correctness
- [ ] `flutter test` and `pytest` green; `metrics.json` app mode ≈ python mode.
- [ ] Manual: a seed label with `15/03/2024` parses; dashboard bars match actual scans; times are local; the model status shows the ADR-001 variant.
- [ ] Human review.

---

## Phase 3: Scan flow and data lifecycle

### Task T18: The result appears without waiting for GPS

**Description:** Classification currently waits up to 10 s for a high-accuracy GPS fix (`camera_screen.dart:162`), and the permission prompt appears over the processing overlay.

Changes:
- Navigate to the result as soon as classification finishes.
- Fetch location in the background: last known position first, then a fresh fix within 10 s.
- Save it with `DatabaseService.updateLocation`.
- Ask for location permission with a short explainer on the first camera open.

**Acceptance criteria:**
- [ ] Widget test with a fake location that takes 10 s: the result route is pushed before location resolves, and the record gets lat/lon afterwards.
- [ ] Permission denied: the scan saves without GPS, and the map shows a hint explaining why no pins appear.

**Verification:**
- [ ] `flutter test test/scan_gps_async_test.dart`: RED, then GREEN.

**Dependencies:** T03, T07
**Files likely touched:** `mobile/lib/screens/camera_screen.dart`, `mobile/lib/services/location_service.dart`, `mobile/lib/services/database_service.dart`, `mobile/test/scan_gps_async_test.dart`
**Estimated scope:** Medium

### Task T19: Classify what the on-screen box frames

**Description:** The camera shows "ALIGN LEAF IN BOX", but the whole frame is classified. Map the reticle rectangle from preview coordinates to image coordinates, accounting for aspect ratio, sensor orientation and EXIF. Crop the capture before classifying; gallery images are unchanged. Put it behind a setting flag until field photos confirm it helps (Q6).

**Acceptance criteria:**
- [ ] A geometry unit test gives the expected crop rectangles for portrait and landscape sensors and different preview/picture sizes.
- [ ] With the flag on, the stored image shows only the boxed region.

**Verification:**
- [ ] `flutter test test/crop_geometry_test.dart` passes.
- [ ] Manual check on device.

**Dependencies:** T09
**Files likely touched:** `mobile/lib/services/crop_geometry.dart`, `mobile/lib/screens/camera_screen.dart`, `mobile/test/crop_geometry_test.dart`
**Estimated scope:** Medium

### Task T20: Camera stream lifecycle and a real brightness signal

**Description:** The brightness hint samples every 12th byte, so it reads compressed JPEG bytes on Android and only the blue channel of BGRA on iOS.

Changes:
- Stream in `yuv420` on Android and `bgra8888` on iOS; captures stay JPEG.
- Compute luma correctly with a pure function.
- Stop the stream while Result is on screen, and resume on return.
- Flip camera keeps the stream format and restarts the stream.
- Fix the dispose/resume race on app inactive → resumed.

**Acceptance criteria:**
- [ ] Luma unit tests on synthetic Y-plane and BGRA frames give the dark, OK and bright hints.
- [ ] Manual: covering the lens shows the low-light hint on both platforms, and the camera stops while on the Result screen.

**Verification:**
- [ ] `flutter test test/luma_test.dart` passes.
- [ ] Manual check on an Android and an iOS device.

**Dependencies:** None
**Files likely touched:** `mobile/lib/services/luma.dart`, `mobile/lib/screens/camera_screen.dart`, `mobile/test/luma_test.dart`
**Estimated scope:** Medium

### Task T21: Delete and Clear actually remove files, audio cache and stale state

**Description:** Today delete removes only the database row (`database_service.dart:91`), and Clear leaves the `scans/` images and the YarnGPT cache.

Changes:
- Delete removes the image file.
- Clear removes `scans/` and calls `YarnTtsService.clearCache()`.
- Deleting the active scan resets the active-scan state.
- A photo copied in before a failed classification is cleaned up.

**Acceptance criteria:**
- [ ] Temp-directory test: after delete the image file is gone, and after clear both `scans/` and the audio cache are empty.
- [ ] The dialog text matches what is removed.

**Verification:**
- [ ] `flutter test test/data_lifecycle_test.dart`: RED, then GREEN.

**Dependencies:** T07
**Files likely touched:** `mobile/lib/services/database_service.dart`, `mobile/lib/screens/history_screen.dart`, `mobile/lib/screens/settings_screen.dart`, `mobile/lib/screens/camera_screen.dart`, `mobile/test/data_lifecycle_test.dart`
**Estimated scope:** Medium

### Task T22: Back returns to where the user came from; Retake works

**Description:** Result's back button always does `context.go('/')`. Change it to pop when possible and fall back to Home otherwise, stopping audio either way. Add a "Retake photo" button on the low-confidence banner.

**Acceptance criteria:**
- [ ] Navigation test: History → Result → back lands on History; Map → Result → back lands on Map.
- [ ] Camera → Result → Retake opens the camera.

**Verification:**
- [ ] `flutter test test/result_navigation_test.dart`: RED, then GREEN.

**Dependencies:** T07
**Files likely touched:** `mobile/lib/screens/result_screen.dart`, `mobile/test/result_navigation_test.dart`
**Estimated scope:** Small

### Task T23: Seed metadata is visible where it is used

**Description:** Linked seed-label data is currently invisible after "Attach".
- Show a "Seed label linked: X [Clear]" chip on the camera screen.
- Show variety, batch and planting date on the Result screen, read from the record.
- Label the link as session-only.

**Acceptance criteria:**
- [ ] Widget test: pending OCR data shows the camera chip, and after a scan the Result shows the record's seed fields.

**Verification:**
- [ ] `flutter test test/seed_metadata_visibility_test.dart` passes.

**Dependencies:** T06
**Files likely touched:** `mobile/lib/screens/camera_screen.dart`, `mobile/lib/screens/result_screen.dart`, `mobile/test/seed_metadata_visibility_test.dart`
**Estimated scope:** Small

### Task T58: Cut the release APK below the size requirement (found in T04)

**Description:** The release APK is 148 MB against NFR-23's 80 MB, because it bundles every CPU architecture plus both models (FP16 ~23 MB and INT8 ~13 MB) and the ML Kit text recogniser. Options: build per-ABI APKs (`--split-per-abi`) or an app bundle, and decide whether both models need to ship now that FP16 is primary (ADR-001).

**Acceptance criteria:**
- [ ] A per-ABI release APK (arm64-v8a) is under the agreed limit, or REQUIREMENTS is updated with a measured, justified number.
- [ ] The size is recorded next to the model metrics so the papers can quote it.

**Verification:**
- [ ] `flutter build apk --release --split-per-abi` and record each output size.

**Dependencies:** T04, T11
**Files likely touched:** `mobile/android/app/build.gradle.kts`, `mobile/setup.sh`, `REQUIREMENTS.md`
**Estimated scope:** Small

### Checkpoint 3: Scan journey
- [ ] On a real device: OCR → attach chip → capture → result shows instantly → GPS pin appears later → delete removes the file → back goes to the origin screen.
- [ ] `flutter test` green; human review.

---

## Phase 4: AI advice and voice

### Task T24: Advice is saved per scan (additive DB v3 migration)

**Description:** Reopening a scan calls Groq again, and because the new text differs, the YarnGPT audio cache misses and charges again.
- Add nullable columns `ai_advice`, `ai_language`, `ai_source`, `ai_model` and `ai_created_at` in a `version: 3` `onUpgrade`, following the expand pattern.
- Load cached advice for the (scan, language) pair.
- Call Groq only when nothing is cached, or on Regenerate.

**Acceptance criteria:**
- [ ] Migration test: a v2 database with rows upgrades to v3 with all rows intact.
- [ ] Reopening a scan makes 0 HTTP calls (checked with `MockClient`), and replaying voice hits the audio cache.

**Verification:**
- [ ] `flutter test test/db_migration_v3_test.dart test/advice_cache_test.dart`: RED, then GREEN.

**Dependencies:** T06, T16 (ffi dev dependency)
**Files likely touched:** `mobile/lib/services/database_service.dart`, `mobile/lib/models/scan_record.dart`, `mobile/lib/screens/result_screen.dart`, `mobile/test/db_migration_v3_test.dart`, `mobile/test/advice_cache_test.dart`
**Estimated scope:** Medium

### Task T25: Diagnosis-aware, safe prompts and matching voice scripts

**Description:**
- **Current problem:** the prompt asks for three fungicide treatment steps with dosage for every class, Healthy included. It also names Ridomil Gold (an oomycete product) and Funguran (copper) for all diseases.
- **New prompt builder:** a pure `buildAdvicePrompt()` with three branches:
  - Healthy → monitoring only, and says explicitly that no fungicide is needed.
  - Low confidence → verify or retake, with no chemical steps.
  - Disease → active ingredients from a per-disease table in `diseases.dart`. No invented dosages; use "follow the product label and confirm with an extension officer".
- **Voice scripts:** the Yoruba, Hausa and Igbo treatment scripts come from the same table, so Rust says triazole in every language.
- **Review:** an agronomist signs off the table (Q5).

**Acceptance criteria:**
- [ ] Unit tests:
  - The Healthy prompt contains no fungicide or dosage instruction.
  - The low-confidence prompt has no treatment section.
  - The Rust prompt names triazole and never names Ridomil Gold or Funguran.
- [ ] The local-language Rust voice scripts mention triazole.
- [ ] The actives table is marked reviewed (reviewer and date).

**Verification:**
- [ ] `flutter test test/advice_prompt_test.dart`: RED on current prompts, then GREEN.

**Dependencies:** T15
**Files likely touched:** `mobile/lib/services/advice_prompt.dart`, `mobile/lib/services/ai_advisor.dart`, `mobile/lib/constants/diseases.dart`, `mobile/lib/l10n/voice_scripts.dart`, `mobile/lib/screens/result_screen.dart`, `mobile/test/advice_prompt_test.dart`
**Estimated scope:** Medium (~6 files, mostly moving existing strings)

### Task T26: Groq client is bounded, typed and honest about its source

**Description:** Today `_callGroq` tries 5 models with a 25 s timeout each, falls back to the model's `reasoning` text, and hides failures behind offline text labelled "Powered by GPT OSS 120B".
- Return an `AdviceResult` with `text`, `source` (groq or offline) and `model`.
- Give the whole request a 20 s deadline.
- Stop immediately on 401/403 and on SocketException.
- Keep the model list in config, validated against a recorded `/openai/v1/models` fixture; remove IDs Groq doesn't list.
- Never display `reasoning`.
- The card title and badge reflect the source, with a friendly offline reason.

**Acceptance criteria:**
- [ ] `MockClient` tests:
  - 401 → 1 request, source offline, reason "invalid key".
  - Hanging server → returns within 20 s (fake async).
  - Empty content plus `reasoning` → offline result, and the reasoning is not shown.
- [ ] Widget test: the offline result shows an "Offline guidance" badge, not "Powered by GPT OSS 120B".

**Verification:**
- [ ] `flutter test test/ai_advisor_client_test.dart`: RED, then GREEN.

**Dependencies:** T24
**Files likely touched:** `mobile/lib/services/ai_advisor.dart`, `mobile/lib/config/app_env.dart`, `mobile/lib/screens/result_screen.dart`, `mobile/test/ai_advisor_client_test.dart`, `mobile/test/fixtures/groq_models.json`
**Estimated scope:** Medium

### Task T27: Offline and non-English behaviour is explicit

**Description:**
- **Offline advice:** use reviewed static templates in the selected language (Q7), or label it clearly as "English (offline)".
- **Voice fallback:** when YarnGPT fails, use device TTS via `ttsLocaleFallbacks` if the locale exists. Otherwise show a friendly message, never a raw exception.
- **Picker labels:** the language picker shows the engine actually used (YarnGPT when a key exists).
- **Scope:** the setting is labelled "Voice & AI advice language" (Q8).

**Acceptance criteria:**
- [ ] Offline + Hausa → Hausa template, or the "English (offline)" label.
- [ ] YarnGPT throws SocketException → the snackbar text contains no exception class name.
- [ ] Picker subtitle for English with a key → "YarnGPT · Jude".

**Verification:**
- [ ] `flutter test test/offline_language_test.dart`: RED, then GREEN.

**Dependencies:** T26
**Files likely touched:** `mobile/lib/services/ai_advisor.dart`, `mobile/lib/screens/result_screen.dart`, `mobile/lib/providers/app_provider.dart`, `mobile/lib/l10n/offline_advice.dart`, `mobile/test/offline_language_test.dart`
**Estimated scope:** Medium

### Task T28: API keys under explicit user control, with no developer paths

**Description:**
- Remove `_tryReadEnvKey`, which reads `/Users/mac/...` (`app_provider.dart:96`).
- Seed from `AppEnv` once (a `*_seeded` flag), so "Remove key" persists across launches.
- Per ADR-003, release builds get no embedded Groq key; add a check for this.
- Remove the key-length debug logs in `main.dart`.

**Acceptance criteria:**
- [ ] Provider test: `clear()`, then a fresh notifier `_load()` → the key stays null.
- [ ] `grep -rn "/Users/" mobile/lib` finds nothing.
- [ ] `strings app-release.apk | grep -c gsk_` is 0 (per ADR-003).

**Verification:**
- [ ] `flutter test test/api_key_persistence_test.dart`: RED, then GREEN.
- [ ] Release APK strings check.

**Dependencies:** T02
**Files likely touched:** `mobile/lib/providers/app_provider.dart`, `mobile/lib/main.dart`, `mobile/test/api_key_persistence_test.dart`
**Estimated scope:** Small

### Task T29: Honest UI copy

**Description:** Replace wording that overclaims:

| Current | Replace with |
|---|---|
| "Offline Verified" | remove |
| "Verified by MaizeGuard Edge Neural Engine" | remove |
| "Agronomist Verification" | "Was this diagnosis right?" |
| "Works fully offline" | "Diagnosis works offline" |
| Dark mode "Optimized for direct sunlight" | remove the claim |
| Spec card "Field Validation" | remove |

**Acceptance criteria:**
- [ ] A banned-phrases test (grep in a test) finds none of these strings in `lib/`.
- [ ] Widget text updated with no layout overflow (widget test at a small screen size).

**Verification:**
- [ ] `flutter test test/ui_copy_test.dart` passes.

**Dependencies:** T26, T27
**Files likely touched:** `mobile/lib/screens/result_screen.dart`, `mobile/lib/screens/home_screen.dart`, `mobile/lib/screens/settings_screen.dart`, `mobile/test/ui_copy_test.dart`
**Estimated scope:** Small

### Checkpoint 4: AI and voice
- [ ] Release APK tested online and in airplane mode, in English and Hausa:
  - A Healthy scan gets no spray advice.
  - A low-confidence scan asks for a retake.
  - Reopening a scan makes no Groq call.
  - The advice source is always visible.
- [ ] Security checklist, AI/LLM section: model output shown only as plain text, no secrets in prompts, no embedded key.
- [ ] Human and agronomist review (Q5).

---

## Phase 5: ML pipeline integrity (parallel with Phases 1–4)

### Task T30: Fusion training runs (Prove-It)

**Description:**
- `train_fusion.py:68` calls `tf.image.resize(image, [IMG_SIZE, IMG_SIZE])` with a tuple and crashes; fix the call.
- Honour or remove the unused `augment` argument.
- Fix notebook 3's misleading "Trainable" printout by counting trainable weights.

**Acceptance criteria:**
- [ ] The `build_fusion_dataset` test on two generated images yields `(None,300,300,3)` batches (RED before the fix).
- [ ] `train_fusion --epochs 1` on a 16-row CSV subset completes.

**Verification:**
- [ ] `.venv/bin/python -m pytest -q tests/test_fusion_pipeline.py` passes.

**Dependencies:** None
**Files likely touched:** `src/phase3_fusion/train_fusion.py`, `tests/test_fusion_pipeline.py`
**Estimated scope:** Small

### Task T31: Fusion metadata policy and ablation (ADR-002)

**Description:**
- Stop presenting random metadata as real: write `labels_with_synthetic_metadata.csv` with `synthetic=1`, or stop generating it.
- Add `src/phase3_fusion/ablation.py`, comparing CNN-only, fusion, and fusion with shuffled metadata on the same split. Results go into `metrics.json`.
- `run_all.sh` drops the "+5% gate" wording.

**Acceptance criteria:**
- [ ] The ablation block exists in `metrics.json`, and synthetic data is flagged.
- [ ] On synthetic metadata, fusion versus shuffled is within noise, and this is documented.

**Verification:**
- [ ] `pytest tests/test_ablation.py` (tiny subset) passes.
- [ ] Manual full ablation run is logged.

**Dependencies:** T30, T01
**Files likely touched:** `run_all.sh`, `src/phase3_fusion/ablation.py`, `tests/test_ablation.py`, `decisions/0002-fusion-status.md`
**Estimated scope:** Medium

### Task T32: Model provenance and train-only calibration

**Description:**
- `convert_tflite.py` currently calibrates on the full `labels.csv`, test images included. It should sample from the training split only, and record the sha256 of the source `.keras`.
- `evaluate.py` and `train.py` write their results to `metrics.json` alongside the model sha.
- The missing `models/exports/efficientnetb3_maize.keras` is regenerated, or re-pointed to the checkpoint that actually produced the shipped TFLite files.

**Acceptance criteria:**
- [ ] Pure-function test: the calibration sample is a subset of the training split.
- [ ] `metrics.json` links each tflite sha to its source keras sha.

**Verification:**
- [ ] `pytest tests/test_convert_calibration.py` passes.
- [ ] Manual `convert_tflite` run updates `metrics.json`.

**Dependencies:** T01
**Files likely touched:** `src/phase4_edge/convert_tflite.py`, `src/phase1_cnn/evaluate.py`, `src/phase1_cnn/train.py`, `tests/test_convert_calibration.py`
**Estimated scope:** Medium

### Task T33: One label set and one post-processing path in Python

**Description:** The pipeline uses three different class-name sets and three confidence formulas (`inference.py:134` applies softmax to probabilities).
- Create `src/common/labels.py`, whose display names match `diseases.dart`.
- Create `src/common/postprocess.py`: dequantise using the tensor's quantisation parameters, then renormalise by the sum. Never apply softmax to probabilities.
- Use both in `inference.py` and `evaluate_tflite.py`.
- Implement `inference.py --csv` through `evaluate_tflite`, or remove the flag.

**Acceptance criteria:**
- [ ] Unit test: INT8 raw output [255,0,0,1] → probabilities sum to 1, argmax 0, matching the Dart normalisation fixture.
- [ ] Only one `CLASS_NAMES` definition exists outside `src/common/`; the UAV modules migrate in T39/T40.

**Verification:**
- [ ] `pytest tests/test_postprocess.py` passes.

**Dependencies:** T01
**Files likely touched:** `src/common/labels.py`, `src/common/postprocess.py`, `src/phase4_edge/inference.py`, `src/phase4_edge/evaluate_tflite.py`, `tests/test_postprocess.py`
**Estimated scope:** Medium

### Task T34: Dataset hygiene (duplicates with conflicting labels)

**Description:** Move the label-building script out of `run_all.sh` into `src/phase1_cnn/build_labels.py`. Apply `data/annotations/exclusions.csv`, which removes the 2 duplicate groups whose images carry conflicting labels. Re-evaluate and version the metrics.

**Acceptance criteria:**
- [ ] Test: exclusions are applied and no md5 duplicate with conflicting labels remains.
- [ ] `run_all.sh` calls `build_labels.py`; metrics are re-generated with a note about the split change.

**Verification:**
- [ ] `pytest tests/test_build_labels.py` passes.

**Dependencies:** T01
**Files likely touched:** `src/phase1_cnn/build_labels.py`, `data/annotations/exclusions.csv`, `run_all.sh`, `tests/test_build_labels.py`
**Estimated scope:** Medium

### Task T35: Python environment matches reality

**Description:**
- `setup_env.sh` defaults to Python 3.11, which is what `.venv` and the notebook kernel already use.
- `requirements.txt` adds pinned `ipykernel`, `pytest` and `kaggle`.
- The `run_all.sh` banner either prints hyperparameters from code or stops restating them. It currently says Adam, patience 5/3, 24-d and block=11; the code uses AdamW, patience 8/4, 17-d and block=31.

**Acceptance criteria:**
- [ ] A fresh `bash setup_env.sh` followed by `pytest` passes.
- [ ] The banner shows no values that contradict the code.

**Verification:**
- [ ] Fresh venv in the scratch directory: `setup_env.sh` then `pytest -q`.
- [ ] `grep -n "24-d\|patience=5\|block=11" run_all.sh` finds nothing.

**Dependencies:** None
**Files likely touched:** `setup_env.sh`, `requirements.txt`, `run_all.sh`
**Estimated scope:** Small

### Task T36 (stretch, gated by ADR-001 and Q9): GLS / NCLB F1 improvement

**Description:** Run experiments aimed at NFR-07 (F1 ≥ 0.88 per class): class-weight tuning, focal loss, fine-tuning depth, more GLS data. Break it into sub-tasks once approved.

**Acceptance criteria:**
- [ ] `metrics.json` per-class F1 ≥ 0.88 on the test split for the shipped model, or a documented stop decision.

**Verification:**
- [ ] `evaluate_tflite` results.

**Dependencies:** T32, T34
**Files likely touched:** `src/phase1_cnn/*`
**Estimated scope:** Large — must be split before starting

### Checkpoint 5: Pipeline
- [ ] `pytest` green, and `bash run_all.sh` (quick) completes every phase on the dataset.
- [ ] `metrics.json` reproduces; the ablation shows fusion is honestly marked experimental.
- [ ] Human review.

---

## Phase 5b: Data acquisition (Python track; T50–T53 core, T54–T55 stretch)

This phase fills data gaps that no single download fixes:
- **Seed-bag label photos:** no public dataset exists.
- **Leaf photos with seed metadata:** no public dataset pairs a leaf photo with its variety or planting date.
- **Evaluation:** the model has only been evaluated on lab-style PlantVillage images.

Every external dataset gets a recorded licence and citation. Raw data stays out of git (`data/raw/` is already ignored), and nothing is redistributed.

### Task T50: Real-field test set and lab-vs-field evaluation

**Description:** `src/data/fetch_field_datasets.py` downloads and verifies (checksums) public field datasets into `data/raw/field/`:
- **CD&S** (Purdue, field photos): northern leaf blight → NCLB, gray leaf spot → GLS; its northern leaf spot class is excluded.
- **Ghana field maize set** (Mendeley): all four classes; confirm the exact record and licence first.
- **PlantDoc:** corn rust.

Build `data/annotations/field_test.csv` (image, label, source, licence, citation). `evaluate_tflite` gains `--csv` to report a separate `field` block in `metrics.json`. The field set is never used for training or calibration.

**Acceptance criteria:**
- [ ] `field_test.csv` exists with a licence and citation for every source; any source whose licence forbids this use is excluded, with a note.
- [ ] `metrics.json` has `lab` and `field` blocks for each shipped model (accuracy, per-class F1, confusion matrix).
- [ ] A test proves no image hash appears in both `labels.csv` and `field_test.csv`.

**Verification:**
- [ ] `pytest tests/test_field_dataset.py` passes (class mapping, licence column present, no overlap).
- [ ] Manual: `python -m src.phase4_edge.evaluate_tflite --csv data/annotations/field_test.csv --model models/exports/efficientnetb3_maize_fp16.tflite`

**Dependencies:** T01, T33
**Files likely touched:** `src/data/fetch_field_datasets.py`, `src/data/field_sources.yaml`, `src/phase4_edge/evaluate_tflite.py`, `tests/test_field_dataset.py`
**Estimated scope:** Medium

### Task T51: Synthetic NASC seed-tag generator for OCR testing

**Description:** `src/phase2_ocr/synth_labels.py` renders seed tags using the field set NASC certification tags carry:
- **Fields:** crop/variety, seed class, lot number, producer, net weight, purity %, inert matter, germination %, moisture %, test date.
- **Tag colours:** blue for certified, white for foundation, purple for registered.
- **Values:** real variety names, several date and lot formats.
- **Augmentations:** rotation, perspective, blur, glare, JPEG noise, crumple texture.

It writes images plus ground-truth JSON with a fixed random seed. An OCR evaluation script reports per-field accuracy for the Python Tesseract pipeline. The generated set is also a manual test pack for ML Kit on the phone. It is never used for fusion training.

**Acceptance criteria:**
- [ ] `synth_labels.py --n 200 --seed 42` produces byte-identical output on re-run, with ground truth for every field.
- [ ] `ocr_eval.py` reports variety, batch and date accuracy separately and writes the results to `metrics.json` under `ocr.synthetic`.

**Verification:**
- [ ] `pytest tests/test_synth_labels.py` passes (determinism, ground-truth schema, every date format represented).
- [ ] Manual: inspect 10 samples.

**Dependencies:** T14
**Files likely touched:** `src/phase2_ocr/synth_labels.py`, `src/phase2_ocr/ocr_eval.py`, `tests/test_synth_labels.py`
**Estimated scope:** Medium

### Task T52: Real seed-bag photo set and the NFR-08 OCR accuracy measurement

**Description:** Write a short photo-collection protocol:
- where to get photos (agro-dealers, IAR/IITA seed units)
- consent and permission
- lighting and angle variety
- no personal data in the frame

Collect at least 30 real bag or tag photos into `data/raw/seed_labels/real/`, with a hand-entered ground-truth CSV. Run `ocr_eval.py` on them to measure NFR-08 (≥ 80% variety accuracy) for real. Retailer product photos found online may be viewed for reference only; they are not stored or used without permission.

**Acceptance criteria:**
- [ ] At least 30 real photos with ground truth and a provenance column.
- [ ] `metrics.json` `ocr.real` block has per-field accuracy, with NFR-08 marked pass or fail.

**Verification:**
- [ ] `ocr_eval.py --csv data/annotations/seed_labels_real.csv` output committed to `metrics.json`.

**Dependencies:** T51 (plus human photo collection — see Q14)
**Files likely touched:** `data/annotations/seed_labels_real.csv`, `data/raw/seed_labels/real/README.md` (protocol), `models/exports/metrics.json`
**Estimated scope:** Small (code); the collection effort is human

### Task T53: Cited variety reference table as a single source for OCR and advice

**Description:** Create `data/reference/maize_varieties.csv` with columns: variety, release year, maturity, reported tolerances, source URL, retrieved date.
- **Sources:** the Nigerian Seed Portal variety list (release year, yield, characteristics) and IAR/IITA release notes for disease tolerance (for example, SAMMAZ 72T–75T tolerance to rust and leaf blight). A trait without a source stays empty.
- **One variety list:** the OCR list is generated from this CSV for both Python (`extractor.KNOWN_VARIETIES`) and Dart (`kNigerianVarieties`). This replaces the two hand-copied lists of 13 and adds newer releases such as SAMMAZ 52, 70 and 72T–78.
- **Advice:** can cite a variety's reported tolerance ("reported rust tolerance — IAR, 2024"). It is a documented prior, not a model input.

**Acceptance criteria:**
- [ ] Every non-empty trait cell has a source URL and retrieved date (test enforces).
- [ ] The Dart and Python variety lists are generated from the CSV, and the test fixtures include at least one newly added variety.
- [ ] The advice prompt includes the cited tolerance only when the scan's variety is known.

**Verification:**
- [ ] `pytest tests/test_variety_table.py` passes.
- [ ] `flutter test test/ocr_parser_test.dart test/advice_prompt_test.dart` passes.
- [ ] Generator script is idempotent: re-running produces no diff.

**Dependencies:** T13, T14, T25
**Files likely touched:** `data/reference/maize_varieties.csv`, `tools/gen_varieties.py`, `mobile/lib/constants/varieties.g.dart`, `src/phase2_ocr/extractor.py`, `tests/test_variety_table.py`
**Estimated scope:** Medium

### Task T54 (stretch, needs Q13): Maize streak virus (MSV) as a fifth class

**Description:** The Tanzania smartphone maize dataset (18,148 images; 6,255 MSV; 3,982 maize lethal necrosis) can supply the class PLAN.md reserved for MSV.
- **Model:** retrain and re-export with 5 classes.
- **Code:** update `src/common/labels.py`, `diseases.dart` (MSV info and advice — vector control and resistant varieties, not fungicide), UI colours, dashboard, heatmap and OCR/advice tables.
- **Evaluation:** re-evaluate lab and field accuracy.

Large — split into sub-tasks (data + retrain → export → app class support → advice content review) before starting.

**Acceptance criteria:**
- [ ] The 5-class model meets the ADR-001 accuracy bar on both test sets, or a documented stop decision.
- [ ] The app handles class id 4 everywhere (no `classId == 3` or 4-class assumptions remain).

**Verification:**
- [ ] `metrics.json` and the full `flutter test` / `pytest` suites.

**Dependencies:** T36, T50, T47
**Files likely touched:** split before starting
**Estimated scope:** Large — split before starting

### Task T55 (stretch, experimental): Weather context from GPS + date

**Description:** `src/common/weather.py` is a cached client for the NASA POWER daily point API (humidity, temperature, rainfall) with Open-Meteo as a fallback.

Two uses, both clearly labelled experimental:
- **Research:** add weather features for field images that carry a location and date, and compare against CNN-only. Single-site datasets (for example CD&S) give little weather variance, so report that limitation.
- **Optional app note:** a "recent humid conditions raise leaf-disease risk" note for GPS-tagged scans when online. Never a diagnosis input.

**Acceptance criteria:**
- [ ] The client caches responses and handles API errors; a recorded-response test fixture is used (no network in tests).
- [ ] The experiment results and limitations are written up; no production claim is made without evidence.

**Verification:**
- [ ] `pytest tests/test_weather_client.py` passes.

**Dependencies:** T50
**Files likely touched:** `src/common/weather.py`, `tests/test_weather_client.py`, `tests/fixtures/nasa_power_daily.json`
**Estimated scope:** Medium

### Checkpoint 5b: Data
- [ ] Field test set evaluated, with the lab-vs-field gap recorded in `metrics.json`.
- [ ] OCR measured on synthetic tags, and on real bags if collected.
- [ ] Variety table cited and used as the single variety list.
- [ ] Every licence recorded; human review.

---

## Phase 6: UAV

### Task T37: Consolidate the UAV code into `src/phase5_uav` (ADR-004)

**Description:**
- Root `uav/` is stale and has diverged; `deployment/uav/` holds shims.
- Confirm `uav/` has no unique behaviour (diff against `src/phase5_uav`), then delete it.
- Keep the `deployment/uav` shims, emitting `DeprecationWarning`.
- Point `run_all.sh` and the README UAV section at `python -m src.phase5_uav.*`.

**Acceptance criteria:**
- [ ] No imports of the root `uav` package remain, and `uav/` is deleted.
- [ ] Shims warn and still run.

**Verification:**
- [ ] `grep -rn "^from uav\|^import uav" --include='*.py' .` finds nothing.
- [ ] `python -W error::DeprecationWarning -c "import deployment.uav.heatmap"` raises.
- [ ] `pytest` passes.

**Dependencies:** None
**Files likely touched:** `uav/*` (deleted), `deployment/uav/*.py`, `run_all.sh`, `README.md` (UAV section only)
**Estimated scope:** Medium (mechanical)

### Task T38: Heatmap summary is correct and safe to import in notebooks

**Description:**
- `_recommend` counts Healthy as a disease (`heatmap.py:316`), so it reports "Dominant: Healthy"; exclude Healthy.
- Derive one summary filename from the output stem, and update the docstring and notebook to match.
- Move `matplotlib.use("Agg")` into `main()`.
- Mark demo predictions `synthetic=True`, with no made-up latency.

**Acceptance criteria:**
- [ ] Test: counts {Healthy 127, Rust 59, NCLB 38, GLS 26} → "Dominant: Rust", with the Rust advice.
- [ ] Importing the module leaves the matplotlib backend unchanged.

**Verification:**
- [ ] `pytest tests/test_heatmap.py`: RED, then GREEN.

**Dependencies:** T37
**Files likely touched:** `src/phase5_uav/heatmap.py`, `tests/test_heatmap.py`
**Estimated scope:** Small

### Task T39: Patch runner — vegetation mask and real coordinates

**Description:**
- **Vegetation filter:** replace the `red > 1.5×green` skip with a vegetation index (ExG or HSV) that keeps rust-coloured tissue inside the canopy.
- **Projected GeoTIFFs:** transform patch centres to EPSG:4326 with `rasterio.warp`, checked against the rasterio docs.
- **Non-georeferenced images:** require `--origin-lat/--origin-lon/--gsd`, or output pixel coordinates only; no more made-up Ibadan coordinates.
- Use `src/common` labels and post-processing.

**Acceptance criteria:**
- [ ] Rust-coloured patch inside a green field → classified. Grey road or sky → skipped.
- [ ] A UTM fixture point converts within 1 m; a missing georeference gives no lat/lon columns and a warning.

**Verification:**
- [ ] `pytest tests/test_patch_runner.py`: RED, then GREEN.

**Dependencies:** T37, T33
**Files likely touched:** `src/phase5_uav/patch_runner.py`, `tests/test_patch_runner.py`
**Estimated scope:** Medium

### Task T40: Drone telemetry classifies each new capture once, at the right event

**Description:**
- Trigger on `MISSION_ITEM_REACHED`, not on `MISSION_CURRENT` changing.
- Process only captures newer than the last processed one; with no new capture, skip with a warning.
- Use `src/common` labels and post-processing.
- The README documents the capture pipeline this depends on, and that the leaf model is not validated on aerial imagery.

**Acceptance criteria:**
- [ ] Temp-directory test with fake MAVLink messages: the same file is never posted twice, and no new capture means no POST.

**Verification:**
- [ ] `pytest tests/test_drone_telemetry.py`: RED, then GREEN.

**Dependencies:** T37, T33
**Files likely touched:** `src/phase5_uav/drone_telemetry.py`, `tests/test_drone_telemetry.py`
**Estimated scope:** Medium

### Checkpoint 6: UAV
- [ ] `pytest` green; the demo `patch_runner` → `heatmap` run gives a consistent summary with the correct dominant disease.
- [ ] Human review.

---

## Phase 7: Notebooks, research papers and docs (behaviour is now final)

### Task T41: Notebooks 1 and 4 use the real evaluation

**Description:**
- NB1 evaluates on the test split (via `metrics.json` / `evaluate_tflite`) instead of displaying a stale PNG.
- NB4's narrative matches the measured INT8-vs-FP16 result, with desktop CPU and device numbers kept separate.
- Clear outputs and re-execute.

**Acceptance criteria:**
- [ ] Both notebooks execute top to bottom, and no markdown claim contradicts an output.

**Verification:**
- [ ] `.venv/bin/jupyter nbconvert --to notebook --execute notebooks/01_*.ipynb notebooks/04_*.ipynb --output-dir /tmp/nbcheck` succeeds.

**Dependencies:** T01, T11, T32
**Files likely touched:** `notebooks/01_phase1_cnn_classification.ipynb`, `notebooks/04_phase4_edge_inference.ipynb`
**Estimated scope:** Small

### Task T42: Notebooks 2, 3 and 5 re-run against the fixed code

**Description:**
- NB2 shows parsed fields, or fails loudly without Tesseract.
- NB3 is labelled experimental and shows the ablation.
- NB5 uses real `patch_runner` output (or is labelled synthetic) and shows the freshly generated PNG.

**Acceptance criteria:**
- [ ] All three execute; NB2 extracts at least 2 fields from its synthetic label; NB5's PNG was written during the run.

**Verification:**
- [ ] `nbconvert --execute` succeeds for all three.

**Dependencies:** T14, T30, T31, T35, T38, T39
**Files likely touched:** `notebooks/02_*.ipynb`, `notebooks/03_*.ipynb`, `notebooks/05_*.ipynb`
**Estimated scope:** Medium

### Task T43: Research papers — results backed by artifacts (abstract, chapter 4)

**Description:**
- Replace the unbacked claims with values from `metrics.json`, the ablation and `device_benchmark.json`, or mark them "not measured":
  - INT8 accuracy 89.2%
  - fusion 95.8% (+5.8 points)
  - 47 MB Keras model
  - ~850 ms on Android
  - "field validated"
  - the comparison-table row
- Fix the chapter 4 contradiction: 27.8% test accuracy, then "convergence over 50 epochs".
- Add an appendix table mapping every number to its source file.

**Acceptance criteria:**
- [ ] Every numeric claim in the abstract and chapter 4 appears in the claim-to-artifact table.
- [ ] Chapter 4 reports lab (PlantVillage) and field (T50) accuracy side by side, plus OCR accuracy from T51/T52.
- [ ] A fresh-context review (doubt-driven-development) finds no unsupported claim.

**Verification:**
- [ ] `grep -n "95.8\|89.2\|850 ms\|+5.8" research-papers/abstract.md research-papers/chapter-4.md` finds nothing, unless re-measured.
- [ ] Reviewer checklist signed off.

**Dependencies:** T12, T31, T32, T41, T50, T51 (T52 if collected)
**Files likely touched:** `research-papers/abstract.md`, `research-papers/chapter-4.md`
**Estimated scope:** Medium

### Task T44: Research papers — system description matches the app (chapters 1, 3, 5)

**Description:** Update the system description to the final behaviour:
- Groq-only AI with offline templates, plus the source badge and saved advice.
- Remove Gemini, Ollama and regex-retry.
- Key handling per ADR-003.
- Remove the claim of OCR image preprocessing on mobile, unless implemented.
- GPS behaviour from T18; thresholds from T15; language scope; one consistent latency target.
- Limitations: lab-only PlantVillage data, GLS F1, synthetic fusion metadata, UAV domain mismatch.

**Acceptance criteria:**
- [ ] `grep -n "Gemini\|Ollama\|llama-3.3\|cannot be extracted" research-papers/*.md` finds nothing.
- [ ] A per-section reviewer checklist confirms each architecture statement against the code.

**Verification:**
- [ ] The grep check above, plus reviewer sign-off.

**Dependencies:** T18, T24–T29, T39
**Files likely touched:** `research-papers/chapter-1.md`, `research-papers/chapter-3.md`, `research-papers/chapter-5.md`
**Estimated scope:** Medium

### Task T45: README, SYSTEM and mobile docs reflect the real platform

**Description:**
- Flutter only; remove React Native and `deployment/app`.
- Groq and YarnGPT env keys.
- Python 3.11.
- Working commands: extractor CLI, `src.phase5_uav`, `evaluate_tflite`.
- Model metrics, 17-d metadata, and training configuration taken from code.
- Real minSdk and app IDs.
- Project structure including `notebooks/`, `research-papers/`, `decisions/` and `tasks/`.

**Acceptance criteria:**
- [ ] Every command in the README runs successfully; keep a run log.
- [ ] `grep -n "React Native\|Gemini\|Ollama\|24-d\|3\.12\|deployment/app" README.md SYSTEM.md mobile/README.md mobile/setup.sh` finds nothing.

**Verification:**
- [ ] Command run log and grep check.

**Dependencies:** Phases 1–6
**Files likely touched:** `README.md`, `SYSTEM.md`, `mobile/README.md`, `mobile/setup.sh`, `.env.json.example` comments
**Estimated scope:** Medium

### Task T46: REQUIREMENTS, DIAGRAMS, PLAN and WORKFLOW brought in line

**Description:**
- **REQUIREMENTS:** platform; AI requirements FR-28..32 (Gemini → Groq); Rescaling 1/255; AdamW and sparse categorical cross-entropy; 17-d; minSdk; latency target.
- **DIAGRAMS:** update to match.
- **PLAN.md:** archive, or point to `tasks/todo.md`.
- **Team:** names and roles consistent across README, PLAN and the `run_all.sh` banner (Q10).

**Acceptance criteria:**
- [ ] The same grep set as T45 is clean across these files.
- [ ] Team names and roles are identical in all three places.

**Verification:**
- [ ] Grep check and human confirmation of the team table.

**Dependencies:** T45
**Files likely touched:** `REQUIREMENTS.md`, `DIAGRAMS.md`, `PLAN.md`, `WORKFLOW.md`, `run_all.sh`
**Estimated scope:** Medium

### Checkpoint 7: Truth
- [ ] Notebooks execute; the research-paper claim table has been reviewed by the team; the docs greps are clean.
- [ ] Human review.

---

## Phase 8: Hardening

### Task T47: Remove dead code and legacy aliases

**Description:**
- Remove `geminiKeyProvider`, the `/recommendation` route, unused `widgets/ds.dart`, and unused `promptName`.
- Replace the magic `classId == 3` with a constant.
- Optional follow-up: migrate `constants/colors.dart` imports (about 12 files, mechanical) to the design-system tokens.

**Acceptance criteria:**
- [ ] `flutter analyze` is clean, and grep finds none of the removed symbols.

**Verification:**
- [ ] `flutter test` passes.

**Dependencies:** Phase 4
**Files likely touched:** `mobile/lib/providers/app_provider.dart`, `mobile/lib/app.dart`, `mobile/lib/widgets/ds.dart` (deleted), `mobile/lib/models/scan_record.dart`
**Estimated scope:** Small

### Task T48: Critical-path integration test

**Description:** `integration_test/scan_flow_test.dart`, using fake classifier, location and AI services:
1. OCR attach → the camera chip appears.
2. Gallery capture → the Result shows diagnosis, seed fields and the source badge.
3. History opens the same scan.
4. Delete removes the scan.

**Acceptance criteria:**
- [ ] `flutter test integration_test` passes on the iOS simulator and an Android emulator.

**Verification:**
- [ ] The command above.

**Dependencies:** Phases 1–4
**Files likely touched:** `mobile/integration_test/scan_flow_test.dart`, `mobile/pubspec.yaml`, `mobile/test/fakes/fake_services.dart`
**Estimated scope:** Medium

### Task T49: CI gate

**Description:** Add a GitHub Actions workflow that runs:
- `flutter pub get --enforce-lockfile`, `flutter analyze` and `flutter test`
- `pytest` on CPU TensorFlow, skipping tests that need model files
- a secret scan for `gsk_` and `AIza`
- the banned-claims greps from T29, T43, T44 and T45

**Acceptance criteria:**
- [ ] The workflow is green on a PR to `main`, and a deliberately failing test blocks it.

**Verification:**
- [ ] `gh run list` shows a green run on the PR.

**Dependencies:** T48 (optional), T02
**Files likely touched:** `.github/workflows/ci.yml`
**Estimated scope:** Small

### Checkpoint 8: Complete
- [ ] Every acceptance criterion is met, and CI is green.
- [ ] Release checklist (shipping-and-launch): signed release builds on real devices; permissions; offline behaviour; NFR-01 latency from T12.
- [ ] Ready for final human review.

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| No physical Android device for T12, so latency claims stay unverifiable | High | Papers say "not measured"; borrow a mid-range device (Q1) |
| GLS F1 stays below the 0.88 target | High (papers) | Report honestly; T36 stretch track; limitations section |
| Agronomic advice causes harm (wrong active ingredient or dose) | High | No model-generated doses; agronomist sign-off gate in T25 and Checkpoint 4 |
| App ID / namespace change resets installs and secure storage | Medium | Do T04 before any wider distribution; testers reinstall |
| DB v3 migration corrupts existing scan history | Medium | Additive nullable columns only; v2 → v3 migration test (T24) |
| Crop-to-box lowers accuracy when the leaf isn't framed | Medium | Setting flag, default off until field photos confirm the benefit (Q6) |
| Groq model IDs change or are retired | Medium | Model list in config plus a fixture test (T26); offline fallback is explicit |
| Local-language offline templates are low quality | Medium | Native-speaker review, or show "English (offline)" (Q7) |
| Uncommitted WIP on `dev` conflicts with Phase 1 edits | Low | Pre-flight: user commits or stashes first |
| Research-paper deadline shorter than full scope | Unknown | Priority lane below |
| A public dataset's licence forbids this use (e.g. non-commercial or no-derivatives terms) | Medium | Record licences in T50; evaluate only, never redistribute; drop sources that don't allow it |
| Field accuracy far below lab accuracy | High (papers) | That is the honest finding — report it, and scope the claims to lab conditions |
| No real seed-bag photos collected | Medium | Report synthetic-tag OCR accuracy only and say NFR-08 is unmeasured on real labels |

**Priority lane if time is short:** T01, T04, T05, T06, T07, T13, T16, T25, T26, T28, T30, T32, T50, T43, T44.

## Open Questions (need human input)

1. **Devices:** is a real mid-range Android phone (and an iPhone) available for T04, T12 and Checkpoint 1?
2. **ADR-001:** accept FP16 as the primary model (+10 MB APK), or invest in re-quantising INT8 first?
3. **ADR-002:** drop all fusion accuracy claims and mark fusion experimental (recommended)? The alternative is collecting real seed-label metadata, which needs field data collection.
4. **ADR-003:** release builds with no embedded Groq key, entered by the user (recommended for the thesis), or keep an embedded demo key and document the risk?
5. **Agronomy review:** who signs off the per-disease active-ingredient table and the advice policy (T25)?
6. **Crop to box (T19):** ship behind a flag, default off?
7. **Offline advice in Yoruba, Hausa and Igbo:** can native speakers review templates (T27), or label offline advice English-only?
8. **Language scope:** translate the whole UI, or define the setting as "voice and AI advice language" only?
9. **Retraining (T36):** is reaching NFR-07 (F1 ≥ 0.88) in scope before submission?
10. **Team and ownership:** the correct names and roles (README says Olapade/Tijani/Oshodilawal; PLAN also lists "Olayinka").
11. **ADR location:** is `decisions/` at the repo root OK now that `docs/` was removed?
12. **Notebooks in git:** commit them with outputs, or with outputs stripped?
13. **MSV fifth class (T54):** in scope before submission, or future work?
14. **Real seed-bag photos (T52):** who can photograph at least 30 bags or tags, and by when?
15. **Weather context (T55):** worth an experimental chapter section, or skip?
