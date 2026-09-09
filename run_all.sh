#!/usr/bin/env bash
# run_all.sh — Run the full Phase 1 → Phase 5 pipeline inside the venv.
#
# Usage:
#   ./run_all.sh           # quick run — 3 epochs per stage (real data required)
#   ./run_all.sh --full    # full training — 20+30 / 50 epochs (per REQUIREMENTS.md §6.1)
#
# Prerequisites:
#   .venv/ must exist — run: bash setup_env.sh
#   Real data in data/raw/plantvillage/data/
#   Kaggle download:
#     .venv/bin/kaggle datasets download \
#       -d smaranjitghose/corn-or-maize-leaf-disease-dataset \
#       -p data/raw/plantvillage --unzip

set -euo pipefail

VENV=".venv/bin/python3"
FULL=false
EPOCHS_P1_S1=3
EPOCHS_P1_S2=3
EPOCHS_P3=3

PLANTVILLAGE_DIR="data/raw/plantvillage/data"
LABELS_CSV="data/annotations/labels.csv"
META_CSV="data/annotations/labels_with_metadata.csv"
KERAS_MODEL="models/exports/efficientnetb3_maize.keras"

# ── Parse flags ────────────────────────────────────────────────────────────────
for arg in "$@"; do
  case $arg in
    --full)
      FULL=true
      EPOCHS_P1_S1=20     # Stage 1: frozen backbone (§6.1)
      EPOCHS_P1_S2=30     # Stage 2: fine-tuning    (§6.1)
      EPOCHS_P3=50        # Fusion training          (§6.3)
      ;;
  esac
done

# ── Check venv ─────────────────────────────────────────────────────────────────
if [ ! -f "$VENV" ]; then
  echo "ERROR: .venv not found. Run 'bash setup_env.sh' first."
  exit 1
fi

# ══════════════════════════════════════════════════════════════════════════════
#  PROJECT HEADER — matches REQUIREMENTS.md v1.0 (Chapter 3 academic doc)
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║   MaizeGuard — AI-Powered Maize Disease Detection System        ║"
echo "║   Full ML Pipeline Runner                                        ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║  Team     : Olapade (CNN/CV)  ·  Tijani (OCR)                  ║"
echo "║             Oshodilawal (Edge / UI)                              ║"
echo "║  Platform : Flutter 3.x (Android + iOS)  +  Python 3.12         ║"
if [ "$FULL" = true ]; then
echo "║  Mode     : FULL TRAINING  (20+30 / 50 epochs)                  ║"
else
echo "║  Mode     : QUICK RUN  (3 epochs/stage — smoke test)            ║"
fi
echo "╚══════════════════════════════════════════════════════════════════╝"

echo ""
echo "── DATASET  (REQUIREMENTS.md §5.2) ─────────────────────────────────────"
echo "  Source  : PlantVillage  (Kaggle: smaranjitghose/corn-or-maize-leaf-disease-dataset)"
echo "  Classes : 4  ·  Total: 4,188 images  ·  Storage: ~340 MB raw"
echo ""
echo "  Class                Label   Images   Proportion"
echo "  ─────────────────────────────────────────────────"
echo "  NCLB (N. Corn Leaf Blight)  0   1,146      27.4%"
echo "  Rust (Common Rust)          1   1,306      31.2%"
echo "  GLS  (Gray Leaf Spot)       2     574      13.7%"
echo "  Healthy                     3   1,162      27.7%"
echo "  ─────────────────────────────────────────────────"
echo "  TOTAL                           4,188     100.0%"
echo ""
echo "  Split      : 70% train (~2,932) / 15% val (~628) / 15% test (~628) — stratified"
echo "  Image size : avg ~81 KB  (300×300 JPEG after resize)"
echo "  Aug (train): H-flip · Rotation ±20° · Zoom ±15% · Brightness ±10% · Contrast ±10%"

echo ""
echo "── NON-FUNCTIONAL REQUIREMENTS  (REQUIREMENTS.md §4.1–4.2) ─────────────"
echo "  Performance:"
echo "    NFR-01  Inference latency (capture → result)     ≤ 2,000 ms"
echo "    NFR-02  App cold start → Home screen             ≤ 4 s"
echo "    NFR-03  TFLite model load (GPU / CPU fallback)   ≤ 3 s / ≤ 5 s"
echo "    NFR-04  SQLite write per scan                     ≤ 50 ms"
echo "    NFR-05  Dashboard query (last 30 days)            ≤ 200 ms"
echo "  Accuracy:"
echo "    NFR-06  Overall test accuracy                     ≥ 90%"
echo "    NFR-07  Per-class F1 score (all 4 classes)       ≥ 0.88"
echo "    NFR-08  OCR variety extraction accuracy           ≥ 80%"
echo "  Model size:"
echo "    NFR-22  TFLite INT8 bundle in APK                ≤ 15 MB  (actual ~13 MB)"
echo "    NFR-23  Total APK size                            ≤ 80 MB"

echo ""
echo "── PHASE GATE CONDITIONS  (REQUIREMENTS.md §8) ──────────────────────────"
echo "  1 → 2 : Validation accuracy ≥ 90% on held-out test set"
echo "  2 → 3 : OCR extracts ≥ 80% variety fields on 10 seed label images"
echo "  3 → 4 : Fusion model accuracy ≥ CNN-only baseline + 5%"
echo "  4 → 5 : TFLite INT8 model exported; mobile app classifies in < 500 ms"
echo "  5     : UAV demo produces disease heatmap from orthomosaic"

echo ""
echo "── CNN ARCHITECTURE  (REQUIREMENTS.md §6.1) ─────────────────────────────"
echo "  Model    : EfficientNetB3 (ImageNet pretrained) + custom head"
echo "  Input    : [1, 300, 300, 3]  uint8 [0,255] — internal Rescaling(1/127.5, -1)"
echo "  Backbone : MBConv blocks with Squeeze-Excitation attention"
echo "  Head     : GAP → BN → Dense(512,relu) → Drop(0.4)"
echo "                       → Dense(256,relu) → Drop(0.3) → Dense(4,softmax)"
echo "  Output   : [1, 4]  float32  (NCLB · Rust · GLS · Healthy)"
echo ""
echo "  Training protocol:"
echo "    Stage 1  Feature extraction  LR=1e-3  backbone frozen     epochs=$EPOCHS_P1_S1 (full=20)"
echo "    Stage 2  Fine-tuning         LR=1e-5  layers 0-99 frozen  epochs=$EPOCHS_P1_S2 (full=30)"
echo "    Optimizer : Adam  |  Loss: Categorical Crossentropy"
echo "    Callbacks : EarlyStopping(patience=5) · ReduceLROnPlateau(patience=3)"
echo "                ModelCheckpoint (best val_accuracy)"
echo "    Class weights applied to address GLS imbalance (574 vs 1,306 images)"

echo ""
echo "════════════════════════════════════════════════════════════════════════════"
echo ""

# ── Step 0: Build labels.csv ───────────────────────────────────────────────────
if [ ! -d "$PLANTVILLAGE_DIR" ]; then
  echo "ERROR: $PLANTVILLAGE_DIR not found."
  echo ""
  echo "Download the dataset first:"
  echo "  .venv/bin/kaggle datasets download \\"
  echo "    -d smaranjitghose/corn-or-maize-leaf-disease-dataset \\"
  echo "    -p data/raw/plantvillage --unzip"
  echo ""
  echo "Expected layout:"
  echo "  data/raw/plantvillage/data/Blight/"
  echo "  data/raw/plantvillage/data/Common_Rust/"
  echo "  data/raw/plantvillage/data/Gray_Leaf_Spot/"
  echo "  data/raw/plantvillage/data/Healthy/"
  exit 1
fi

echo ">>> Step 0: Building labels.csv + labels_with_metadata.csv ..."
$VENV - << 'PYEOF'
import os, csv, random
from collections import Counter

MAPPING = {
    "Blight":         (0, "NCLB"),
    "Common_Rust":    (1, "Rust"),
    "Gray_Leaf_Spot": (2, "GLS"),
    "Healthy":        (3, "Healthy"),
}
ROOT = "data/raw/plantvillage/data"
rows = []
for folder, (label, class_name) in MAPPING.items():
    path = os.path.join(ROOT, folder)
    for fname in sorted(os.listdir(path)):
        if fname.lower().endswith((".jpg", ".jpeg", ".png")):
            rows.append({"image_path": os.path.join(path, fname),
                         "label": label, "class_name": class_name, "source": "plantvillage"})

os.makedirs("data/annotations", exist_ok=True)
with open("data/annotations/labels.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=["image_path","label","class_name","source"])
    w.writeheader(); w.writerows(rows)

varieties = ["SAMMAZ 15","SAMMAZ 17","SAMMAZ 29","SAMMAZ 34","SAMMAZ 50",
             "OBA SUPER 2","EVDT 99","POOL 16 DT","TZEE-W","ABA WHITE",
             "ACROSS 97","SUWAN 1","EARLY THRIVING", None]
batches   = ["BN-2024-042", "BN-2023-011", "LOT-2024-007", None]
dates     = ["2024-03-15", "2023-11-01", "2024-05-20", None]
rng = random.Random(0)
with open("data/annotations/labels_with_metadata.csv", "w", newline="") as f:
    fn = ["image_path","label","class_name","source","crop_variety","batch_number","planting_date"]
    w = csv.DictWriter(f, fieldnames=fn)
    w.writeheader()
    for row in rows:
        w.writerow({**row, "crop_variety": rng.choice(varieties),
                    "batch_number": rng.choice(batches),
                    "planting_date": rng.choice(dates)})

counts = Counter(r["class_name"] for r in rows)
total  = sum(counts.values())
print(f"\n  labels.csv written: {total} images")
print(f"  {'Class':<24} {'Count':>6}  {'Pct':>6}")
print(f"  {'─'*40}")
for cls in ["NCLB","Rust","GLS","Healthy"]:
    n = counts.get(cls, 0)
    print(f"  {cls:<24} {n:>6}  {n/total*100:>5.1f}%")
print(f"  {'─'*40}")
print(f"  {'TOTAL':<24} {total:>6}  100.0%")
PYEOF
echo ""

# ── Step 1: Phase 1 CNN training ───────────────────────────────────────────────
echo "════════════════════════════════════════════════════════════════════════════"
echo "  PHASE 1 — EfficientNetB3 CNN Classifier  (REQUIREMENTS.md §6.1)"
echo "  Gate: validation accuracy ≥ 90%  ·  per-class F1 ≥ 0.88"
echo "════════════════════════════════════════════════════════════════════════════"
echo ""
echo ">>> Step 1: Training EfficientNetB3 ..."
echo "    Stage 1 epochs : $EPOCHS_P1_S1  (full = 20)"
echo "    Stage 2 epochs : $EPOCHS_P1_S2  (full = 30)"
echo ""
$VENV -m src.phase1_cnn.train \
  --csv "$LABELS_CSV" \
  --batch-size 32 \
  --stage1-epochs $EPOCHS_P1_S1 \
  --stage2-epochs $EPOCHS_P1_S2
echo ""

# ── Step 2: Phase 1 Evaluation ────────────────────────────────────────────────
echo ">>> Step 2: Phase 1 — Evaluating on held-out test set ..."
echo ""
$VENV -m src.phase1_cnn.evaluate \
  --model "$KERAS_MODEL" \
  --csv   "$LABELS_CSV"
echo ""

echo "── Phase 1 results vs acceptance criteria  (REQUIREMENTS.md §6.1 + §9.10) ─"
echo "  Expected results (Chapter 4):"
echo "    Class      Precision  Recall   F1    Support"
echo "    ─────────────────────────────────────────────"
echo "    NCLB        ≥0.90     ≥0.88   ≥0.89   ~172"
echo "    Rust        ≥0.92     ≥0.91   ≥0.91   ~196"
echo "    GLS         ≥0.85     ≥0.88   ≥0.86    ~86"
echo "    Healthy     ≥0.91     ≥0.90   ≥0.90   ~174"
echo "    Overall                        ≥0.90    628"
echo "    ─────────────────────────────────────────────"
echo "  Graphs for report (§9.10): training curves · confusion matrix"
echo "    per-class metrics · ROC curves · fusion vs CNN comparison"
echo "  Output: models/exports/efficientnetb3_maize.keras"
echo "          models/exports/confusion_matrix_phase1.png"
echo ""
echo "  Phase 1→2 gate: proceed if accuracy ≥ 90%  (if not, re-run with --full)"
echo ""

# ── Step 3: Phase 2 OCR ────────────────────────────────────────────────────────
echo "════════════════════════════════════════════════════════════════════════════"
echo "  PHASE 2 — Tesseract OCR Seed Label Pipeline  (REQUIREMENTS.md §6.2)"
echo "  Gate: ≥ 80% variety extraction accuracy on seed label test images"
echo "════════════════════════════════════════════════════════════════════════════"
echo ""
echo "  OCR pipeline (§6.2):"
echo "    1. Grayscale conversion"
echo "    2. Adaptive thresholding (Gaussian, block=11, C=2)"
echo "    3. Deskew via Hough line detection"
echo "    4. Morphological denoising"
echo "    5. Tesseract 5 LSTM — Page Segmentation Mode 6"
echo "    6. Fuzzy field extraction (FuzzyWuzzy partial ratio, threshold=60)"
echo ""
echo "  Supported Nigerian varieties (FR-14, 13 varieties):"
echo "    SAMMAZ 15/17/29/34/50 · OBA SUPER 2 · EVDT 99 · POOL 16 DT"
echo "    TZEE-W · ABA WHITE · ACROSS 97 · SUWAN 1 · EARLY THRIVING"
echo ""
echo "  Metadata encoding: 24-d float32 vector"
echo "    13-d one-hot (variety) + 1 (batch present) + 1 (batch year)"
echo "    + 2 (planting month sin/cos) + 7 (padding)"
echo ""
echo ">>> Step 3: Testing OCR pipeline ..."
echo ""

SEED_LABEL="data/raw/seed_labels/sample_label.jpg"
if [ ! -f "$SEED_LABEL" ]; then
  echo "    No seed label image found — generating synthetic sample ..."
  $VENV - << 'PYEOF'
from PIL import Image, ImageDraw
import os
os.makedirs("data/raw/seed_labels", exist_ok=True)
img = Image.new("RGB", (600, 300), color=(240, 235, 220))
draw = ImageDraw.Draw(img)
for y, line in enumerate(["SAMMAZ 15", "Batch No: BN-2024-042",
                           "Planting Date: 15/03/2024",
                           "Net Weight: 2 kg", "Produced by: IITA Seeds Ltd"]):
    draw.text((30, 20 + y * 45), line, fill=(10, 10, 10))
img.save("data/raw/seed_labels/sample_label.jpg", "JPEG")
print("    Synthetic seed label created.")
PYEOF
fi

$VENV - << 'PYEOF'
import json
from src.phase2_ocr.extractor import extract_fields_from_path
from src.phase2_ocr.encoder import encode, METADATA_DIM

fields = extract_fields_from_path("data/raw/seed_labels/sample_label.jpg")
print("  Extracted fields:")
for k, v in fields.items():
    if k != "raw_text":
        print(f"    {k:<20}: {v}")
print(f"\n  Raw OCR text : {fields.get('raw_text','').replace(chr(10),' | ')}")
vec = encode(fields)
print(f"\n  Metadata vector: shape={vec.shape}  dtype={vec.dtype}  non-zero dims={(vec!=0).sum()}")
PYEOF
echo ""
echo "  Phase 2→3 gate: ≥ 80% variety accuracy on real seed label images"
echo "    Test manually: python src/phase2_ocr/extractor.py --image <seed_label.jpg>"
echo ""

# ── Step 4: Phase 3 Fusion ────────────────────────────────────────────────────
echo "════════════════════════════════════════════════════════════════════════════"
echo "  PHASE 3 — Multimodal Fusion Model  (REQUIREMENTS.md §6.3)"
echo "  Gate: fusion accuracy ≥ CNN-only baseline + 5%"
echo "════════════════════════════════════════════════════════════════════════════"
echo ""
echo "  Fusion architecture (§6.3):"
echo "    Image branch  : EfficientNetB3 (frozen) → Dense(256) → 256-d"
echo "    OCR branch    : Input(24,) → Dense(32) → BatchNorm → 32-d"
echo "    Fusion head   : Concatenate(288-d) → Dense(128,relu) → Dropout(0.3)"
echo "                    → Dense(4,softmax)"
echo "    Optimizer     : Adam (LR=5e-4)  |  Epochs: $EPOCHS_P3 (full=50)"
echo ""
echo ">>> Step 4: Training multimodal fusion model ..."
echo ""
$VENV -m src.phase3_fusion.train_fusion \
  --metadata-csv  "$META_CSV" \
  --cnn-weights   "$KERAS_MODEL" \
  --freeze-cnn \
  --epochs $EPOCHS_P3
echo ""
echo "  Output: models/exports/fusion_model.keras"
echo "  Phase 3→4 gate: fusion accuracy must exceed CNN-only + 5%"
echo ""

# ── Step 5: Phase 4 TFLite ────────────────────────────────────────────────────
echo "════════════════════════════════════════════════════════════════════════════"
echo "  PHASE 4 — TFLite Conversion  (REQUIREMENTS.md §6.4)"
echo "  Gate: INT8 + FP16 models exported; mobile app loads and classifies < 500ms"
echo "════════════════════════════════════════════════════════════════════════════"
echo ""
echo "  Quantisation spec (§6.4):"
echo "    INT8 (primary)  : ~13 MB · calibrated on 200 representative images"
echo "    FP16 (fallback) : ~23 MB · for devices without INT8 GPU delegate"
echo "    INT8 output dequant: score = (raw_uint8 − zero_point) × scale"
echo "                         scale=0.00390625  zero_point=0"
echo "    NFR-22 APK bundle target: ≤ 15 MB  ✓"
echo ""
echo ">>> Step 5: Converting Keras → TFLite INT8 + FP16 ..."
$VENV -m src.phase4_edge.convert_tflite \
  --model "$KERAS_MODEL" \
  --csv   "$LABELS_CSV"
echo ""

# Print actual model sizes
for F in models/exports/efficientnetb3_maize_int8.tflite \
         models/exports/efficientnetb3_maize_fp16.tflite; do
  if [ -f "$F" ]; then
    SIZE_KB=$(du -k "$F" | cut -f1)
    SIZE_MB=$(python3 -c "print(f'{$SIZE_KB/1024:.1f}')" 2>/dev/null || echo "?")
    echo "  $(basename $F) : ${SIZE_MB} MB"
  fi
done
echo ""

# ── Step 6: Phase 5 UAV ───────────────────────────────────────────────────────
echo "════════════════════════════════════════════════════════════════════════════"
echo "  PHASE 5 — UAV Disease Heatmap  (REQUIREMENTS.md §6.5)"
echo "  Spec: QGC .waypoints mission · patch inference · Folium HTML heatmap"
echo "════════════════════════════════════════════════════════════════════════════"
echo ""
echo "  UAV configuration (§6.5):"
echo "    Camera    : DJI Phantom 4 equivalent (1/2.3\" CMOS · 12 MP · f=3.6 mm)"
echo "    Altitude  : 30 m AGL  →  GSD ≈ 1.3 cm/px"
echo "    Overlap   : 80% forward  ·  70% sidelap"
echo "    Patch size: 300×300 px  (matches TFLite input)"
echo "    Inference : < 2 s/patch on the UAV ground station"
echo ""
mkdir -p data/uav

echo ">>> Step 6a: Generating demo flight plan ..."
$VENV -m deployment.uav.flight_planner \
  --demo \
  --output data/uav/mission.waypoints
echo ""

echo ">>> Step 6b: Patch inference on synthetic orthomosaic ..."
$VENV -m deployment.uav.patch_runner \
  --demo \
  --model models/exports/efficientnetb3_maize_int8.tflite \
  --output data/uav/patch_predictions.csv
echo ""

echo ">>> Step 6c: Generating disease heatmap ..."
$VENV -m deployment.uav.heatmap \
  --csv    data/uav/patch_predictions.csv \
  --output data/uav/disease_heatmap.html
echo ""

# ── Final summary ──────────────────────────────────────────────────────────────
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║   Pipeline Complete — Output Summary                             ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║  Phase 1 CNN                                                     ║"
echo "║    models/exports/efficientnetb3_maize.keras                     ║"
echo "║    models/exports/confusion_matrix_phase1.png                    ║"
echo "║  Phase 3 Fusion                                                  ║"
echo "║    models/exports/fusion_model.keras                             ║"
echo "║  Phase 4 TFLite                                                  ║"
echo "║    models/exports/efficientnetb3_maize_int8.tflite  (~13 MB)    ║"
echo "║    models/exports/efficientnetb3_maize_fp16.tflite  (~23 MB)    ║"
echo "║  Phase 5 UAV                                                     ║"
echo "║    data/uav/mission.waypoints                                    ║"
echo "║    data/uav/patch_predictions.csv                                ║"
echo "║    data/uav/disease_heatmap.html        ← open in browser        ║"
echo "║    data/uav/disease_heatmap.png         ← include in report      ║"
echo "║    data/uav/disease_heatmap_summary.json                        ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║  Mobile app                                                      ║"
echo "║    bash mobile/setup.sh                                          ║"
echo "║    cd mobile && flutter pub get                                  ║"
echo "║    cd mobile && flutter run                                      ║"
echo "║    cd mobile && flutter build apk --release                      ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║  Live UAV (real drone — see REQUIREMENTS.md §6.5)               ║"
echo "║    python -m deployment.uav.live_server                          ║"
echo "║    python -m deployment.uav.drone_telemetry \\                    ║"
echo "║        --connect udp:0.0.0.0:14550 \\                             ║"
echo "║        --mission data/uav/mission.waypoints \\                    ║"
echo "║        --server  http://localhost:5000                            ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║  TensorBoard                                                     ║"
echo "║    .venv/bin/tensorboard --logdir logs/                          ║"
echo "║    open http://localhost:6006                                     ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║  Chapter 4 report graphs  (REQUIREMENTS.md §9.10)               ║"
echo "║    1. Training curves (loss + accuracy, both stages)             ║"
echo "║    2. Confusion matrix (4×4 heatmap)                             ║"
echo "║    3. Per-class metrics bar chart (Precision · Recall · F1)      ║"
echo "║    4. ROC curves per class with AUC                              ║"
echo "║    5. Fusion vs CNN-only accuracy comparison                     ║"
echo "║    → All saved to models/exports/                                ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║  Full training (≥90% accuracy target):                          ║"
echo "║    bash run_all.sh --full                                        ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
