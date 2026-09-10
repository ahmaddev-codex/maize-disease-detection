# MaizeGuard Audit Remediation — Task List

The full details for each task (acceptance criteria, verification, files) are in [plan.md](plan.md).

Legend: `[ ]` todo · `[~]` in progress · `[x]` done. Brackets after a title list its dependencies, then its scope (S/M/L).

## Pre-flight (user)
- [ ] Commit or stash WIP on `dev` (`camera_screen.dart`, `result_screen.dart`, `heatmap.py`), and decide whether to commit `notebooks/` and `research-papers/`
- [ ] Answer the Open Questions in plan.md (Q1–Q12)

## Phase 0: Baseline and decisions
- [x] T01 Reproducible TFLite evaluation → `metrics.json` [— · S]
- [x] T02 ADR-001…006 recorded, and `pubspec.lock` committed [T01 · S]
- [x] T03 Service providers and test fakes [— · S]
- [ ] **Checkpoint 0:** ADRs approved; baseline metrics committed; tests green

## Phase 1: Mobile release blockers
- [x] T04 Android release has network, GPS, app ID, signing and OSM attribution [T02 · M]
- [x] T05 Model load state visible and recoverable [T03 · M]
- [ ] T06 Result screen renders exactly one resolved scan [T03 · M]
- [ ] T07 Home, History and Map use `openScan`; legacy providers removed [T06 · M]
- [ ] T08 Feedback highlight updates; History no-feedback label [T06 · S]
- [ ] **Checkpoint 1:** release APK on a real phone — GPS pin, Groq advice, correct scan from History/Map

## Phase 2: Diagnosis correctness
- [ ] T09 Bilinear preprocessing with Dart↔Python parity test [T01 · M]
- [ ] T10 Inference off the UI thread; model vs total latency [T09 · M]
- [ ] T11 Ship the primary model chosen in ADR-001 [T02, T05, T09 · S]
- [ ] T12 On-device latency benchmark → `device_benchmark.json` [T10, T11, device · S]
- [x] T13 OCR parser fixes (dates, varieties, batch numbers) with shared fixtures [— · M]
- [ ] T14 Python extractor parity, `--image` CLI, Tesseract check [T13 · S]
- [ ] T15 One threshold set; urgency uses confidence and trend [T06 · M]
- [ ] T16 Farm stats by `class_id`; Home = Dashboard; empty state; local-day buckets [T03 · M]
- [ ] T17 Local time display helper [T16 · M]
- [ ] **Checkpoint 2:** DD/MM/YYYY parses; dashboard bars correct; app-mode metrics ≈ python mode

## Phase 3: Scan flow and data lifecycle
- [ ] T18 Result appears without waiting for GPS; location saved later [T03, T07 · M]
- [ ] T19 Crop to the on-screen box, behind a flag [T09 · M]
- [ ] T20 Camera stream lifecycle and real luma brightness hint [— · M]
- [ ] T21 Delete/Clear remove images, audio cache and stale state [T07 · M]
- [ ] T22 Back returns to origin; Retake button [T07 · S]
- [ ] T23 Seed metadata chip on camera and fields on Result [T06 · S]
- [ ] **Checkpoint 3:** full scan journey verified on a device

## Phase 4: AI advice and voice
- [ ] T24 Advice saved per scan (DB v3, additive migration) [T06, T16 · M]
- [ ] T25 Safe, diagnosis-aware prompts and per-disease voice scripts [T15 · M]
- [ ] T26 Groq client: deadline, stop on 401/offline, typed source, no `reasoning` [T24 · M]
- [ ] T27 Offline and non-English behaviour explicit; TTS fallbacks [T26 · M]
- [ ] T28 API keys: no dev paths, Remove persists, no embedded key in release [T02 · S]
- [ ] T29 Honest UI copy (remove "verified" and "fully offline" claims) [T26, T27 · S]
- [ ] **Checkpoint 4:** online/offline × English/Hausa; Healthy scan gets no spray advice; agronomist review

## Phase 5: ML pipeline integrity (parallel with Phases 1–4)
- [x] T30 Fusion training crash fixed (Prove-It) [— · S]
- [ ] T31 Fusion metadata policy and ablation (ADR-002) [T30, T01 · M]
- [ ] T32 Model provenance and train-only INT8 calibration [T01 · M]
- [ ] T33 Shared Python labels and post-processing [T01 · M]
- [ ] T34 Dataset hygiene: conflicting-label duplicates excluded [T01 · M]
- [ ] T35 Python 3.11 env, requirements, truthful `run_all` banner [— · S]
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
-
