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
- [x] T31 Fusion metadata policy and ablation (ADR-002) [T30, T01 · M] — full run recorded: fusion beats shuffled by 0.16 pts, inside the noise band
- [x] T32 Model provenance and train-only INT8 calibration [T01 · M] — code landed with the T34 commit (4b36697); exports re-made and re-measured
- [x] T33 Shared Python labels and post-processing [T01 · M] — UAV modules still hold their own names (T39/T40)
- [x] T34 Dataset hygiene: conflicting-label duplicates excluded [T01 · M] — split changed, metrics regenerated (INT8 88.08→87.26, FP16 91.10→93.15 on the new split)
- [x] T35 Python 3.11 env, requirements, truthful `run_all` banner [— · S]
- [ ] T36 (stretch) GLS/NCLB F1 ≥ 0.88 — split before starting [T32, T34 · L]
- [ ] **Checkpoint 5:** `pytest` green; `run_all.sh` quick completes; metrics reproduce

## Phase 5b: Data acquisition
- [ ] T50 Real-field test set (CD&S, Ghana, PlantDoc) with licences → lab vs field metrics [T01, T33 · M]
- [ ] T51 Synthetic NASC seed-tag generator and OCR evaluation [T14 · M]
- [ ] T52 Real seed-bag photo set (≥ 30) and NFR-08 measurement [T51, human collection · S]
- [x] T53 Cited variety table as the single OCR/advice variety source [T13, T14, T25 · M] — single source done; the citations themselves are still outstanding (every row is `verified=no`)
- [ ] T54 (stretch) MSV fifth class from the Tanzania dataset — split before starting [T36, T50, T47 · L]
- [ ] T55 (stretch) Weather context via NASA POWER / Open-Meteo, experimental [T50 · M]
- [ ] **Checkpoint 5b:** field gap recorded; OCR measured; licences recorded

## Phase 6: UAV
- [x] T37 Consolidate into `src/phase5_uav`; delete `uav/`; shims warn [— · M]
- [x] T38 Heatmap dominant disease, summary filename, Agg backend only in `main()` [T37 · S]
- [x] T39 Patch runner vegetation mask and CRS / no fabricated coordinates [T37, T33 · M] — the UTM reprojection test skips unless rasterio (GDAL) is installed
- [x] T40 Drone telemetry: each new capture once, on `MISSION_ITEM_REACHED` [T37, T33 · M]
- [~] **Checkpoint 6:** demo UAV pipeline gives a correct summary — run 2026-09-25: 45 patches, Rust dominant (53%), no coordinates invented, pytest 116 green; human review outstanding

## Phase 7: Notebooks, papers, docs
- [x] T41 Notebooks 1 and 4 use the real evaluation [T01, T11, T32 · S] — both execute clean via nbconvert
- [x] T42 Notebooks 2, 3 and 5 re-run against fixed code [T14, T30, T31, T35, T38, T39 · M]
- [x] T43 Papers: abstract and chapter 4 numbers backed by artifacts [T12, T31, T32, T41, T50, T51 · M] — lab numbers done with a claim-to-artifact table (§4.9); the field and OCR rows read "not measured" until T50/T51/T12
- [x] T44 Papers: chapters 1, 3 and 5 describe the real system [T18, T24–T29, T39 · M] — per-section reviewer sign-off still outstanding
- [x] T45 README, SYSTEM and mobile docs reflect the real platform [Phases 1–6 · M] — run log in `tasks/logs/readme-commands.md`
- [x] T46 REQUIREMENTS, DIAGRAMS, PLAN and WORKFLOW aligned [T45 · M] — PLAN.md marked historical; the team table (Q10) still needs the user's confirmation
- [~] **Checkpoint 7:** notebooks execute (all five, 2026-09-25) and the docs greps are clean via `scripts/check_claims.sh`; the claim table still needs a human review

## Phase 8: Hardening
- [x] T47 Remove dead code and legacy aliases [Phase 4 · S] — the colors.dart → design-token migration stays deferred
- [x] T48 Critical-path integration test [Phases 1–4 · M] — written as a runnable widget/data test in `test/critical_path_test.dart`; the on-device `integration_test` run stays with the device checkpoints
- [x] T49 CI gate: analyze, test, pytest, secret scan, banned-claims grep [T48, T02 · S] — workflow written and the claims gate runs clean locally; a green PR run still needs pushing
- [ ] **Checkpoint 8:** CI green; release checklist on real devices; final review

## Doc impacts log
Behaviour changes to carry into Phase 7 (add one line per task as it lands):
- T53: the thirteen variety names now live in `data/reference/maize_varieties.csv`; Python reads it directly, the Dart list is generated by `scripts/sync_varieties.py`, and a test in each language fails if they drift. Every row is marked `verified=no` with its provenance ("inherited from the original project list") — so nothing may describe them as registered Nigerian varieties, or attach a susceptibility claim to one, until they are checked against the NASC catalogue.
- T42: notebook 2 fails loudly when Tesseract is missing and now asserts that at least two fields were recovered — which caught the demo label being drawn at ~11 px, so OCR misread "SAMMAZ 15" as "SAMMAZ 16" and lost the date; the label is now rendered at a size a camera would resolve. Notebook 3 is labelled experimental and prints the ablation. Notebook 5 states that its predictions are synthetic and that the UAV pipeline applies a leaf model never evaluated at altitude. Running them also exposed two real breaks in `heatmap.py` (a map popup and the summary line both assumed a latency that demo rows no longer carry).
- T41: notebook 1 reads the recorded test-split results (accuracy, per-class F1, split sizes, remaining conflicting duplicates) instead of displaying a stored confusion-matrix PNG, and notebook 4 states the measured INT8 cost (5.4 points, most of it GLS) and separates this machine's interpreter timings from the device benchmark that has not been run. Both execute top to bottom.
- T31: the fusion metadata is flagged `synthetic=1` at the point it is generated, and the ablation has been run on the full split: cnn_only 93.63%, fusion 93.79%, fusion_shuffled 93.63%. Fusion beats shuffled by 0.16 points — inside the noise band — so the metadata carries no signal, which is what invented values should produce. Chapters 4 and 5 and ADR-002 now quote those numbers instead of a +5.8-point gain.
- T48: `mobile/test/critical_path_test.dart` walks the seam between the pieces — a seed label scanned before a capture reaches storage with the scan, history lists and opens that scan, deleting it removes the row, the photo and the active-scan state, and the result screen shows the diagnosis, the seed card and the advice source (fetched once and stored). Real database work runs in a plain test and the screens run against the in-memory fake, because a real sqflite future never completes under `testWidgets`' clock.
- T43: chapter 4 reports measured numbers only — FP16 93.15% / INT8 87.74% with per-class F1, real file sizes, the calibration-leak correction, the duplicate exclusions and the split change — and marks device latency, field accuracy and OCR accuracy as not measured. The comparison-table row no longer claims field validation. A new §4.9 maps every claim to the artefact that produces it and the command that reproduces it. The 3-epoch pipeline check is explicitly separated from the 50-epoch results, which removes the "27.8% then convergence" contradiction.
- T49: `scripts/check_claims.sh` gates the banned claims, the unsupported figures, stale platform references, committed API keys and the single class-name source; `.github/workflows/ci.yml` runs Flutter analyze/test, pytest and that script.
- T47: the `geminiKeyProvider` alias, the `/recommendation` route, the unused `widgets/ds.dart` re-export shim and the duplicate `promptName` are gone, and the remaining `classId == 3` literals now use `kHealthyClassId`.
- T46: REQUIREMENTS now states the Flutter stack, minSdk 24 and app id read from the built APK, the 17-d metadata layout, AdamW with sparse categorical cross-entropy, `Rescaling(1/255)`, and the advisory requirements as built (source always shown, no dose, healthy and low-confidence branches). NFR-01 is marked not-yet-measured, NFR-22 needs restating now that FP16 is primary, and NFR-23 is marked not met (148.4 MB vs 80 MB, T58). DIAGRAMS follows. PLAN.md is marked historical and points at `tasks/plan.md`.
- T45: README and SYSTEM describe the Flutter app that exists (the "moved to React Native, Flutter kept at deployment/app" note was false — that directory does not exist), Python 3.11, the 17-d metadata vector, Groq/YarnGPT keys, and `src.phase5_uav` commands rather than the deprecated `deployment.uav` shims. Running the documented commands found one that could not work as written (`python src/phase2_ocr/extractor.py` breaks the `src.` package import); it is now the module form.
- T44: the papers now describe the app that exists — one advisory provider (no Gemini, no Ollama, no provider chain), keys that belong to the farmer with the compile-time-constant claim corrected, no mobile OCR preprocessing claim, the FP16-first decision with measured costs, and a limitations section that states lab-only data, the GLS gap, synthetic fusion metadata, the UAV domain mismatch and the unmeasured device latency.
- Checkpoint 6 found that the heatmap required lat/lon, which T39 stopped inventing: coordinates are now optional there — a non-georeferenced survey still gets its class summary and recommendation, and the maps are skipped with a message instead of crashing.
- T40: the drone classifies on `MISSION_ITEM_REACHED` (not when it starts flying to a waypoint), takes each capture at most once and only if it is newer than the last, skips a waypoint with a message when the camera has not written a photo yet, and uses the shared labels and post-processing. The README now says who is expected to supply the captures and states plainly that the leaf model has never been evaluated on aerial imagery.
- T32: INT8 calibration now samples the training split only (it used to draw from the whole label set, test images included), so the INT8 model was re-converted and re-measured: 87.74% on the cleaned test split. Both exports record the checkpoint they came from — FP16 rebuilt byte-for-byte from `models/checkpoints/phase1_stage2_best.keras`, which confirms that checkpoint is the source of the shipped models — and `metrics.json` now links each tflite sha256 to its source keras sha256, with the calibration split and image count. The app's bundled assets were refreshed via `mobile/setup.sh`.
- T39: UAV patches are selected by an Excess Green vegetation index instead of a red/green ratio (shaded canopy is kept; roads, sky and bare soil are still skipped, and a wholly brown canopy is a documented limitation); GeoTIFF patch centres are reprojected from the file's CRS to WGS 84, and an image with neither a georeference nor `--origin-lat/--origin-lon/--gsd` now produces pixel coordinates with a warning instead of invented coordinates near Ibadan. Demo output carries no coordinates at all.
- T37/T38: the diverged root `uav/` copy is deleted (ADR-004: `src/phase5_uav` is canonical) and `deployment.uav.*` are warning shims; the UAV survey no longer reports "Dominant: Healthy" for a mostly healthy field, demo rows are flagged `synthetic` with no invented latency, a run without timings reports no latency at all, and importing the module no longer switches matplotlib to Agg.
- T34: `labels.csv` is now generated by a tested module (`build_labels.py`) that applies `data/annotations/exclusions.csv`; the two byte-identical pairs carrying conflicting Blight/GLS labels are resolved (one copy of each dropped after visual review — still to be confirmed by an agronomist) and `run_all.sh` refuses to write a set that still has one. The split therefore changed (4,188 → 4,186 images) and metrics.json was regenerated: INT8 87.26%, FP16 93.15% on the new test split — papers must quote the new numbers and note the split change.
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
