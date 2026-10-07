"""
Turnkey training runner for Google Colab or remote GPU environments.
Executes the full high-accuracy training, evaluation, TFLite conversion,
and metrics recording.

Usage in Colab:
    python scripts/train_colab.py
"""

import os
import sys
import shutil
import subprocess

def run(cmd: str):
    print(f"\n>>> Running: {cmd}")
    res = subprocess.run(cmd, shell=True)
    if res.returncode != 0:
        print(f"Error executing: {cmd}", file=sys.stderr)
        sys.exit(res.returncode)

def main():
    print("=" * 70)
    print(" MaizeGuard — High-Accuracy Model Training Pipeline")
    print("=" * 70)

    # 1. Download PlantVillage dataset if not already present
    data_dir = "data/raw/plantvillage/data"
    if not (os.path.exists(data_dir) and any(os.scandir(data_dir))):
        print("\n[1/5] Downloading PlantVillage dataset via kagglehub...")
        try:
            import kagglehub
        except ImportError:
            run("pip install kagglehub")
            import kagglehub

        download_path = kagglehub.dataset_download("smaranjitghose/corn-or-maize-leaf-disease-dataset")
        print(f"Downloaded to: {download_path}")
        os.makedirs(os.path.dirname(data_dir), exist_ok=True)
        src_dir = os.path.join(download_path, "data") if os.path.exists(os.path.join(download_path, "data")) else download_path
        shutil.copytree(src_dir, data_dir, dirs_exist_ok=True)
        print("Dataset ready in", data_dir)
    else:
        print("\n[1/5] Dataset already present in", data_dir)

    # 2. Check/build labels
    print("\n[2/5] Checking labels index...")
    run(
        f"{sys.executable} -m src.phase1_cnn.build_labels "
        f"--root {data_dir} "
        f"--labels data/annotations/labels.csv "
        f"--metadata data/annotations/labels_with_metadata.csv "
        f"--check-duplicates"
    )

    # 3. Train Phase 1 CNN with improved transfer learning
    print("\n[3/5] Training EfficientNetB3 (Stage 1 Head + Stage 2 Fine-Tuning)...")
    run(
        f"{sys.executable} -m src.phase1_cnn.train "
        f"--csv data/annotations/labels.csv "
        f"--batch-size 32 "
        f"--stage1-epochs 20 "
        f"--stage2-epochs 35 "
        f"--stage1-lr 1e-3 "
        f"--stage2-lr 3e-5 "
        f"--fine-tune-at 50 "
        f"--label-smoothing 0.05 "
        f"--patience 12"
    )

    # 4. Evaluate Keras model on held-out test split
    print("\n[4/5] Evaluating Keras model on held-out test split...")
    run(
        f"{sys.executable} -m src.phase1_cnn.evaluate "
        f"--model models/exports/efficientnetb3_maize.keras "
        f"--csv data/annotations/labels.csv"
    )

    # 5. Convert to TFLite (FP16 + INT8) and evaluate both
    print("\n[5/5] Converting to TFLite and evaluating on test split...")
    run(
        f"{sys.executable} -m src.phase4_edge.convert_tflite "
        f"--model models/exports/efficientnetb3_maize.keras "
        f"--csv data/annotations/labels.csv "
        f"--calib-images 300"
    )

    run(
        f"{sys.executable} -m src.phase4_edge.evaluate_tflite "
        f"--model models/exports/efficientnetb3_maize_fp16.tflite "
        f"--model models/exports/efficientnetb3_maize_int8.tflite "
        f"--csv data/annotations/labels.csv"
    )

    print("\n" + "=" * 70)
    print(" Pipeline complete! models/exports/metrics.json has been updated.")
    print("=" * 70)

if __name__ == "__main__":
    main()
