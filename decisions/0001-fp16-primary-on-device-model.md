# ADR-001: Ship the FP16 model as the primary on-device classifier

## Status
Accepted

## Date
2026-09-10

## Context
The app bundles two TFLite exports of the same EfficientNetB3 classifier and currently loads INT8 first (`mobile/lib/services/classifier_service.dart`).

Measured on the stratified PlantVillage test split (629 images, `models/exports/metrics.json`):

| Model | Accuracy | GLS F1 | NCLB F1 | Size |
|---|---|---|---|---|
| FP16 | 91.10% | 0.727 | 0.847 | ~23 MB |
| INT8 | 88.08% | 0.658 | 0.802 | ~13 MB |

- INT8 loses 3 points and misses REQUIREMENTS NFR-06 (≥ 90%). The research papers claimed under 1% loss.
- INT8 was also 2.3× slower on desktop CPU in notebook 4 (115.8 ms vs 49.3 ms), because unsupported ops fall back to float kernels.
- Neither model meets NFR-07 (F1 ≥ 0.88 for every class).

## Decision
Load FP16 first. Keep INT8 only as a fallback when FP16 fails to load.

## Alternatives Considered

### Keep INT8 as primary
- Pros: smallest app; meets the INT8 size budget (NFR-22 ≤ 15 MB).
- Cons: lowest accuracy, and slower on CPU in our measurement.
- Rejected: accuracy matters more than 10 MB for a diagnosis tool.

### Re-quantise INT8 first, then decide
- Pros: could recover accuracy (calibrate on training images only; see T32).
- Cons: blocks the app fix on pipeline work, and the outcome is uncertain.
- Deferred: revisit once T32 lands (see Consequences).

## Consequences
- The app is about 10 MB larger. REQUIREMENTS NFR-22 must be updated in T46.
- The app's model-status text must say which variant actually loaded (T05).
- Revisit if a re-quantised INT8 comes within 0.5 points of FP16 and is faster on a real mid-range Android phone (T12 benchmark).
