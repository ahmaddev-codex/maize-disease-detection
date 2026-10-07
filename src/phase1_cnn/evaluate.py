"""
Phase 1 — Evaluation
Loads a trained model and a test dataset, then prints:
  - Overall accuracy
  - Per-class classification report
  - Confusion matrix (saved to models/exports/)

Run:
    python -m src.phase1_cnn.evaluate --model models/exports/efficientnetb3_maize.keras
"""

import os
import argparse
import numpy as np
import tensorflow as tf
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.metrics import classification_report, confusion_matrix

from src.phase1_cnn.data_pipeline import build_datasets, CLASS_NAMES

EXPORT_DIR = "models/exports"


def evaluate(model_path: str, csv_path: str, batch_size: int = 32, tta: bool = False):
    model = tf.keras.models.load_model(model_path)

    _, _, test_ds, _ = build_datasets(csv_path=csv_path, batch_size=batch_size)

    # Collect true labels and predictions
    y_true, y_pred = [], []
    for images, labels in test_ds:
        preds = model.predict(images, verbose=0)
        if tta:
            # 2-view TTA: average predictions of original and horizontally flipped images
            flipped = tf.image.flip_left_right(images)
            preds_flip = model.predict(flipped, verbose=0)
            preds = 0.5 * (preds + preds_flip)

        y_true.extend(labels.numpy())
        y_pred.extend(np.argmax(preds, axis=1))

    y_true = np.array(y_true)
    y_pred = np.array(y_pred)

    # Accuracy
    acc = np.mean(y_true == y_pred)
    mode_str = " (with TTA)" if tta else ""
    print(f"\nTest Accuracy{mode_str}: {acc * 100:.2f}%")

    # Per-class report
    print("\nClassification Report:")
    print(classification_report(y_true, y_pred, target_names=CLASS_NAMES))

    # Confusion matrix
    cm = confusion_matrix(y_true, y_pred)
    _plot_confusion_matrix(cm)

    return acc, y_true, y_pred


def _plot_confusion_matrix(cm: np.ndarray):
    os.makedirs(EXPORT_DIR, exist_ok=True)
    fig, ax = plt.subplots(figsize=(8, 7))
    sns.heatmap(
        cm, annot=True, fmt="d", cmap="Blues",
        xticklabels=CLASS_NAMES, yticklabels=CLASS_NAMES,
        ax=ax,
    )
    ax.set_xlabel("Predicted")
    ax.set_ylabel("True")
    ax.set_title("Confusion Matrix — Phase 1 CNN")
    save_path = os.path.join(EXPORT_DIR, "confusion_matrix_phase1.png")
    fig.savefig(save_path, bbox_inches="tight", dpi=150)
    print(f"Confusion matrix saved → {save_path}")
    plt.close(fig)


def parse_args():
    p = argparse.ArgumentParser(description="Evaluate Phase 1 CNN")
    p.add_argument("--model",      default="models/exports/efficientnetb3_maize.keras")
    p.add_argument("--csv",        default="data/annotations/labels.csv")
    p.add_argument("--batch-size", type=int, default=32)
    p.add_argument("--tta",        action="store_true", default=False,
                   help="Enable 2-view Test-Time Augmentation (original + horizontal flip)")
    return p.parse_args()


if __name__ == "__main__":
    args = parse_args()
    evaluate(args.model, args.csv, args.batch_size, tta=args.tta)
