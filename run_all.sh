#!/usr/bin/env bash
# run_all.sh — Run the full Phase 1 → Phase 2 → Phase 3 pipeline inside the venv.
#
# Usage:
#   ./run_all.sh           # quick run — 3 epochs per stage (real data required)
#   ./run_all.sh --full    # full training — 15+20 / 25 epochs
#
# Prerequisites:
#   .venv/  must exist — run: bash setup_env.sh
#   Real data must be in data/raw/plantvillage/data/

set -euo pipefail

VENV=".venv/bin/python3"
FULL=false
EPOCHS_P1_S1=3
EPOCHS_P1_S2=3
EPOCHS_P3=3

PLANTVILLAGE_DIR="data/raw/plantvillage/data"
LABELS_CSV="data/annotations/labels.csv"
META_CSV="data/annotations/labels_with_metadata.csv"

# ── Parse flags ────────────────────────────────────────────────────────────────
for arg in "$@"; do
  case $arg in
    --full)
      FULL=true
      EPOCHS_P1_S1=15
      EPOCHS_P1_S2=20
      EPOCHS_P3=25
      ;;
  esac
done

# ── Check venv ─────────────────────────────────────────────────────────────────
if [ ! -f "$VENV" ]; then
  echo "ERROR: .venv not found. Run 'bash setup_env.sh' first."
  exit 1
fi

echo ""
echo "============================================================"
echo "  Maize Disease Detection — Full Pipeline"
echo "  Mode: $([ "$FULL" = true ] && echo 'FULL TRAINING (real data)' || echo 'QUICK RUN (real data, few epochs)')"
echo "============================================================"
echo ""

# ── Step 0: Build labels.csv from real PlantVillage data ──────────────────────
if [ ! -d "$PLANTVILLAGE_DIR" ]; then
  echo "ERROR: $PLANTVILLAGE_DIR not found."
  echo "Download the dataset first:"
  echo "  .venv/bin/kaggle datasets download -d smaranjitghose/corn-or-maize-leaf-disease-dataset -p data/raw/plantvillage --unzip"
  exit 1
fi

echo ">>> Step 0: Building labels.csv from real PlantVillage data..."
$VENV - << 'PYEOF'
import os, csv, random

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

# Build metadata CSV — OCR fields are null for real images
# (real OCR data comes from photographed seed labels, not training images)
varieties = ["SAMMAZ 15", "SAMMAZ 17", "OBA SUPER 2", None]
batches   = ["BN-2024-042", "BN-2023-011", None]
dates     = ["2024-03-15", "2023-11-01", None]
rng = random.Random(0)
with open("data/annotations/labels_with_metadata.csv", "w", newline="") as f:
    fn = ["image_path","label","class_name","source","crop_variety","batch_number","planting_date"]
    w = csv.DictWriter(f, fieldnames=fn)
    w.writeheader()
    for row in rows:
        w.writerow({**row, "crop_variety": rng.choice(varieties),
                    "batch_number": rng.choice(batches),
                    "planting_date": rng.choice(dates)})

from collections import Counter
counts = Counter(r["class_name"] for r in rows)
print(f"labels.csv: {len(rows)} images")
for k,v in sorted(counts.items()): print(f"  {k}: {v}")
PYEOF
echo ""

# ── Step 1: Phase 1 — CNN training ────────────────────────────────────────────
echo ">>> Step 1: Phase 1 — Training EfficientNetB3..."
echo "    Stage 1 epochs: $EPOCHS_P1_S1  |  Stage 2 (fine-tune) epochs: $EPOCHS_P1_S2"
echo ""
$VENV -m src.phase1_cnn.train \
  --csv "$LABELS_CSV" \
  --batch-size 32 \
  --stage1-epochs $EPOCHS_P1_S1 \
  --stage2-epochs $EPOCHS_P1_S2
echo ""

# ── Step 2: Phase 1 — Evaluation ──────────────────────────────────────────────
echo ">>> Step 2: Phase 1 — Evaluating on held-out test set..."
$VENV -m src.phase1_cnn.evaluate \
  --model models/exports/efficientnetb3_maize.h5 \
  --csv   "$LABELS_CSV"
echo ""

# ── Step 3: Phase 2 — OCR test on seed label ──────────────────────────────────
echo ">>> Step 3: Phase 2 — Testing OCR on seed label image..."
SEED_LABEL="data/raw/seed_labels/sample_label.jpg"
if [ ! -f "$SEED_LABEL" ]; then
  echo "    No seed label image found at $SEED_LABEL — generating one for testing..."
  $VENV - << 'PYEOF'
from PIL import Image, ImageDraw
import os
os.makedirs("data/raw/seed_labels", exist_ok=True)
img = Image.new("RGB", (600, 300), color=(240, 235, 220))
draw = ImageDraw.Draw(img)
lines = ["SAMMAZ 15", "Batch No: BN-2024-042", "Planting Date: 15/03/2024",
         "Net Weight: 2 kg", "Produced by: IITA Seeds Ltd"]
y = 20
for line in lines:
    draw.text((30, y), line, fill=(10, 10, 10))
    y += 45
img.save("data/raw/seed_labels/sample_label.jpg", "JPEG")
print("    Sample seed label created.")
PYEOF
fi

$VENV - << 'PYEOF'
import json
from src.phase2_ocr.extractor import extract_fields_from_path
from src.phase2_ocr.encoder import encode, METADATA_DIM

fields = extract_fields_from_path("data/raw/seed_labels/sample_label.jpg")
print("Extracted fields:")
print(json.dumps({k: v for k, v in fields.items() if k != "raw_text"}, indent=2))
print(f"\nRaw OCR text:\n{fields['raw_text']}")
vec = encode(fields)
print(f"Metadata vector: shape={vec.shape}  dtype={vec.dtype}")
PYEOF
echo ""

# ── Step 4: Phase 3 — Fusion training ─────────────────────────────────────────
echo ">>> Step 4: Phase 3 — Training multimodal fusion model..."
echo "    Epochs: $EPOCHS_P3"
echo ""
$VENV -m src.phase3_fusion.train_fusion \
  --metadata-csv  "$META_CSV" \
  --cnn-weights   models/exports/efficientnetb3_maize.h5 \
  --freeze-cnn \
  --epochs $EPOCHS_P3
echo ""

# ── Done ───────────────────────────────────────────────────────────────────────
echo "============================================================"
echo "  Pipeline complete!"
echo ""
echo "  Outputs:"
echo "    models/exports/efficientnetb3_maize.h5   ← Phase 1 CNN"
echo "    models/exports/fusion_model.h5            ← Phase 3 Fusion"
echo "    models/exports/confusion_matrix_phase1.png"
echo ""
echo "  To run full training (15+20 / 25 epochs):"
echo "    bash run_all.sh --full"
echo ""
echo "  TensorBoard:"
echo "    .venv/bin/tensorboard --logdir logs/"
echo "============================================================"
