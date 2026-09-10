# ADR-006: Single sources of truth for labels, thresholds, fixtures and metrics

## Status
Accepted

## Date
2026-09-10

## Context
The audit found the same concept defined several times, with different values:

| Concept | Conflicting definitions |
|---|---|
| Class names | "NCLB" in the data pipeline, "Northern Leaf Blight" in `inference.py`, "Northern Corn Leaf Blight" in the app |
| Confidence normalisation | divide by sum (app), softmax of probabilities (`inference.py`), softmax only outside [0, 1] (`patch_runner`) |
| Confidence thresholds | banner < 0.60, meter < 0.65, urgency 0.55 / 0.70 |
| Variety lists | hand-copied in Python and Dart |
| Reported model numbers | papers, README, features docs and `run_all.sh` all disagree with each other and with measurement |

## Decision

| Concept | Single source |
|---|---|
| Class ids and labels, Python post-processing | `src/common/labels.py`, `src/common/postprocess.py` |
| Mobile confidence thresholds | `mobile/lib/constants/thresholds.dart` |
| OCR parsing test cases (Dart and Python) | `tests/fixtures/ocr_cases.json` |
| Maize varieties and cited traits | `data/reference/maize_varieties.csv` (Dart and Python lists generated from it) |
| Model and OCR evaluation results | `models/exports/metrics.json`, written only by evaluation scripts |

Docs and papers quote numbers from `metrics.json` and cite it.

## Alternatives Considered

### Keep per-module definitions and sync them by review
- Pros: no refactor.
- Cons: that is how the current drift happened.
- Rejected.

## Consequences
- New tasks must read from these sources instead of adding literals (T13–T16, T33, T53).
- CI can check that docs contain no model numbers absent from `metrics.json` (T49).
