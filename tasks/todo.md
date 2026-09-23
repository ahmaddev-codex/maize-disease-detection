# MaizeGuard Audit Remediation — Task List

The full details for each task (acceptance criteria, verification, files) are in [plan.md](plan.md).

Legend: `[ ]` todo · `[~]` in progress · `[x]` done. Brackets after a title list its dependencies, then its scope (S/M/L).

## Pre-flight (user)
- [x] Commit or stash WIP on `dev` (`camera_screen.dart`, `result_screen.dart`, `heatmap.py`), and decide whether to commit `notebooks/` and `research-papers/`
- [x] Answer the Open Questions in plan.md (Q1–Q3 answered; devices, agronomist and native speakers available; Q4–Q15 still open)

## Phase 0: Baseline and decisions
- [x] T01 Reproducible TFLite evaluation → `metrics.json` [— · S]
- [x] T02 ADR-001…006 recorded, and `pubspec.lock` committed [T01 · S]
- [x] T03 Service providers and test fakes [— · S]
- [x] **Checkpoint 0:** ADRs approved; baseline metrics committed; tests green

## Phase 1: Mobile release blockers
- [x] T04 Android release has network, GPS, app ID, signing and OSM attribution [T02 · M]
- [x] T05 Model load state visible and recoverable [T03 · M]
- [x] T06 Result screen renders exactly one resolved scan [T03 · M]
- [x] T07 Home, History and Map use `openScan`; legacy providers removed [T06 · M]
- [x] T08 Feedback highlight updates; History no-feedback label [T06 · S]
- [~] **Checkpoint 1:** device run done 2026-09-23; app launches, but fonts crashed offline (T57) and the run had no API keys (needs `--dart-define-from-file=.env.json`)

## Phase 2: Diagnosis correctness
- [x] T09 Bilinear preprocessing with Dart↔Python parity test [T01 · M]
- [~] T10 Inference off the UI thread; latency is model-only [T09 · M] — code done; on-device jank check pending (Checkpoint 2)
- [x] T11 Ship the primary model chosen in ADR-001 [T02, T05, T09 · S]
- [ ] T12 On-device latency benchmark → `device_benchmark.json` [T10, T11, device · S]
- [x] T13 OCR parser fixes (dates, varieties, batch numbers) with shared fixtures [— · M]
- [x] T14 Python extractor parity, `--image` CLI, Tesseract check [T13 · S]
- [x] T56 OCR deskew no longer rotates labels 90° (found in T14) [T14 · S]
- [x] T57 Bundle DM Sans so fonts never fetch at runtime (found on device) [— · S]
- [x] T15 One threshold set; urgency uses confidence and trend [T06 · M]
- [x] T16 Farm stats by `class_id`; Home = Dashboard; empty state; local-day buckets [T03 · M]
- [x] T17 Local time display helper [T16 · M]
- [ ] **Checkpoint 2:** DD/MM/YYYY parses; dashboard bars correct; app-mode metrics ≈ python mode

## Phase 3: Scan flow and data lifecycle
- [x] T18 Result appears without waiting for GPS; location saved later [T03, T07 · M] — pre-permission explainer deferred to T20
- [x] T19 Crop to the on-screen box, behind a flag [T09 · M] — default off; keep off until field photos confirm it helps (Q6)
- [x] T20 Camera stream lifecycle and real luma brightness hint [— · M] — device check of both hints still pending
- [x] T21 Delete/Clear remove images, audio cache and stale state [T07 · M]
- [x] T22 Back returns to origin; Retake button [T07 · S]
- [x] T23 Seed metadata chip on camera and fields on Result [T06 · S]
- [ ] T58 Release APK size: 148 MB vs the 80 MB requirement (found in T04) [T04, T11 · S]
- [ ] **Checkpoint 3:** full scan journey verified on a device

## Phase 4: AI advice and voice
- [x] T24 Advice saved per scan (DB v3, additive migration) [T06, T16 · M] — brought forward part of T26: getAdvice now reports its source
- [x] T25 Safe, diagnosis-aware prompts and per-disease voice scripts [T15 · M] — actives table marked `pending-agronomist-review`; Q5 sign-off still open
- [x] T26 Groq client: deadline, stop on 401/offline, typed source, no `reasoning` [T24 · M] — model fixture transcribed from Groq's published list, not a live capture
- [x] T27 Offline and non-English behaviour explicit; TTS fallbacks [T26 · M] — offline templates stay English-only (Q7 open), labelled "English (offline)"
- [x] T28 API keys: no dev paths, Remove persists, no embedded key in release [T02 · S] — APK `strings | grep gsk_` check still to run at Checkpoint 4
- [x] T29 Honest UI copy (remove "verified" and "fully offline" claims) [T26, T27 · S]
- [ ] **Checkpoint 4:** online/offline × English/Hausa; Healthy scan gets no spray advice; agronomist review

## Phase 5: ML pipeline integrity (parallel with Phases 1–4)
- [x] T30 Fusion training crash fixed (Prove-It) [— · S]
- [ ] T31 Fusion metadata policy and ablation (ADR-002) [T30, T01 · M]
- [ ] T32 Model provenance and train-only INT8 calibration [T01 · M]
- [x] T33 Shared Python labels and post-processing [T01 · M] — UAV modules still hold their own names (T39/T40)
- [ ] T34 Dataset hygiene: conflicting-label duplicates excluded [T01 · M]
- [x] T35 Python 3.11 env, requirements, truthful `run_all` banner [— · S]
- [ ] T36 (stretch) GLS/NCLB F1 ≥ 0.88 — split before starting [T32, T34 · L]
- [ ] **Checkpoint 5:** `pytest` green; `run_all.sh` quick completes; metrics reproduce

## Phase 5b: Data acquisition
- [ ] T50 Real-field test set (CD&S, Ghana, PlantDoc) with licences → lab vs field metrics [T01, T33 · M]
- [ ] T51 Synthetic NASC seed-tag generator and OCR evaluation [T14 · M]
- [ ] T52 Real seed-bag photo set (≥ 30) and NFR-08 measurement [T51, human collection · S]
- [ ] T53 Cited variety table as the single OCR/advice variety source [T13, T14, T25 · M]
- [ ] T54 (stretch) MSV fifth class from the Tanzania dataset — split before starting [T36, T50, T47 · L]
- [ ] T55 (stretch) Weather context via NASA POWER / Open-Meteo, experimental [T50 · M]
- [ ] **Checkpoint 5b:** field gap recorded; OCR measured; licences recorded

## Phase 6: UAV
- [ ] T37 Consolidate into `src/phase5_uav`; delete `uav/`; shims warn [— · M]
- [ ] T38 Heatmap dominant disease, summary filename, Agg backend only in `main()` [T37 · S]
- [ ] T39 Patch runner vegetation mask and CRS / no fabricated coordinates [T37, T33 · M]
- [ ] T40 Drone telemetry: each new capture once, on `MISSION_ITEM_REACHED` [T37, T33 · M]
- [ ] **Checkpoint 6:** demo UAV pipeline gives a correct summary

## Phase 7: Notebooks, papers, docs
- [ ] T41 Notebooks 1 and 4 use the real evaluation [T01, T11, T32 · S]
- [ ] T42 Notebooks 2, 3 and 5 re-run against fixed code [T14, T30, T31, T35, T38, T39 · M]
- [ ] T43 Papers: abstract and chapter 4 numbers backed by artifacts, lab + field [T12, T31, T32, T41, T50, T51 · M]
- [ ] T44 Papers: chapters 1, 3 and 5 describe the real system [T18, T24–T29, T39 · M]
- [ ] T45 README, SYSTEM and mobile docs reflect the real platform [Phases 1–6 · M]
- [ ] T46 REQUIREMENTS, DIAGRAMS, PLAN and WORKFLOW aligned; team table [T45 · M]
- [ ] **Checkpoint 7:** notebooks execute; claim table reviewed; docs greps clean

## Phase 8: Hardening
- [ ] T47 Remove dead code and legacy aliases [Phase 4 · S]
- [ ] T48 Critical-path integration test [Phases 1–4 · M]
- [ ] T49 CI gate: analyze, test, pytest, secret scan, banned-claims grep [T48, T02 · S]
- [ ] **Checkpoint 8:** CI green; release checklist on real devices; final review

## Doc impacts log
Behaviour changes to carry into Phase 7 (add one line per task as it lands):
- T33: one label set (`src/common/labels.py`, display names matching diseases.dart) and one post-processing rule (dequantise → renormalise, never softmax) shared by Python and the app through `tests/fixtures/postprocess_cases.json`; `inference.py` no longer double-softmaxes (its printed confidence used to disagree with the metrics) and its `--csv` flag now really evaluates instead of silently benchmarking.
- T29: claims the app cannot back are gone — "Offline Verified", "Verified by MaizeGuard Edge Neural Engine", "Agronomist Verification", "Works fully offline", "Field Validation" and the dark-mode sunlight claim; the feedback card now asks "Was this diagnosis right?" and Home says the diagnosis works offline while advice and local-language voice need a connection. A test greps `lib/` for those phrases and checks the result screen at 320px.
- T27: offline advice is labelled "English (offline)" when another language was chosen and is cached under the language it is really in; a YarnGPT failure now falls back to a device voice in the closest installed locale (not English only), and failures are explained in plain words instead of showing an exception; the language picker names the engine that will actually speak.
- T28: a key removed in Settings stays removed — a build-time key seeds the app once and never again; the app no longer reads `.env.json` from a developer's home directory, and key lengths are no longer logged at startup.
- T26: advice requests have one 20 s budget for all attempts (was 5 models × 25 s), stop immediately on a rejected key or no connection, never show the model's private `reasoning`, and the card says whether the text came from a model (naming it) or from the built-in rules, with the reason.
- T25: advice is now diagnosis-aware — a healthy leaf gets monitoring only and is told no fungicide is needed, a low-confidence scan is asked for a better photo with no chemical named, and a confident diagnosis names active ingredients from one reviewed-pending table (no brands, no invented dosages; rate and pre-harvest interval come from the product label). Ridomil Gold and Funguran are gone from every prompt, offline text, voice script and the chemical tab.
- T24: advice is generated once per (scan, language) and stored with the scan, so reopening a result makes no request and replays the cached voice; schema is v3 (additive) and the advisor now reports whether the text came from Groq or the offline rules.
- T19: a settings toggle ("Diagnose Only the Aligned Box", default off) crops camera captures to the on-screen box before diagnosis; gallery photos are untouched and the stored image is the cropped one.
- T20: the brightness hint is computed from real luma (yuv420 on Android, bgra8888 on iOS) instead of raw stream bytes, the preview stream stops while a result is on screen and while the app is backgrounded, and flipping the camera keeps the stream running.
- T21: deleting a scan now deletes its photo, Purge All also removes `scans/` and the cached speech (dialog and snackbar reworded to match), deleting the open scan clears the active-scan state, and a capture whose diagnosis fails is removed instead of orphaned.
- T23: a scanned seed label is shown on the camera before capture (with a clear action) and on the result of the scan it was attached to; the camera screen now degrades to a message instead of a blank spinner when no camera is available.
- T22: back returns to the screen a scan was opened from, low-confidence results offer a retake, and navigation no longer waits on the audio engine.
- T18: results appear immediately and the GPS fix is attached afterwards, so scan-to-result latency no longer includes a location wait.
- T10: preprocessing and inference run off the UI thread; stored latency_ms is now model-only (papers must not quote it as capture-to-result).
- T15: one confidence threshold set (low 0.60 / high 0.85); low-confidence scans ask for a retake in speech and urgency; 'critical' now reachable via the real trend.
- T17: scan times and day buckets render in the device timezone (README/papers should stop implying UTC).
- T16: dashboard and Home share one 30-day stats source counted by class id; empty farms show an empty state instead of 100%.
- T35: run_all.sh banner, setup_env.sh and requirements now match the code (Python 3.11, AdamW, 17-d metadata, FP16 primary); NFR-22 needs revisiting in REQUIREMENTS.
- T09/T11: the app resizes bilinearly and loads FP16 first (INT8 fallback); setup.sh only ships models listed in metrics.json.
- T57: fonts are bundled; the app no longer downloads DM Sans at runtime (affects any 'works offline' claim in README/papers).
