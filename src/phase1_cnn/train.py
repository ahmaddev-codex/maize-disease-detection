"""
Phase 1 — Training Script
Run:
    python -m src.phase1_cnn.train

Two-stage training:
  Stage 1 — frozen base, 15 epochs, lr=1e-3
  Stage 2 — unfreeze top layers, 20 epochs, lr=1e-5
"""

import os
import argparse
import tensorflow as tf

from src.phase1_cnn.data_pipeline import build_datasets, build_datasets_from_directory
from src.phase1_cnn.model import build_model, compile_model, unfreeze_for_finetuning

# ── Defaults ───────────────────────────────────────────────────────────────────

STAGE1_EPOCHS   = 15
STAGE2_EPOCHS   = 20
BATCH_SIZE      = 32
CHECKPOINT_DIR  = "models/checkpoints"
EXPORT_PATH     = "models/exports/efficientnetb3_maize.h5"


# ── Callbacks ──────────────────────────────────────────────────────────────────

def get_callbacks(stage: int) -> list:
    os.makedirs(CHECKPOINT_DIR, exist_ok=True)
    return [
        tf.keras.callbacks.ModelCheckpoint(
            filepath=os.path.join(CHECKPOINT_DIR, f"phase1_stage{stage}_best.h5"),
            monitor="val_accuracy",
            save_best_only=True,
            verbose=1,
        ),
        tf.keras.callbacks.EarlyStopping(
            monitor="val_accuracy",
            patience=5,
            restore_best_weights=True,
            verbose=1,
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss",
            factor=0.5,
            patience=3,
            min_lr=1e-7,
            verbose=1,
        ),
        tf.keras.callbacks.TensorBoard(
            log_dir=f"logs/phase1_stage{stage}",
            histogram_freq=1,
        ),
    ]


# ── Training ───────────────────────────────────────────────────────────────────

def train(args):
    # Load data
    if args.data_dir:
        train_ds, val_ds, test_ds, class_weights = build_datasets_from_directory(
            args.data_dir, batch_size=args.batch_size
        )
    else:
        train_ds, val_ds, test_ds, class_weights = build_datasets(
            csv_path=args.csv, batch_size=args.batch_size
        )

    # Build model
    model = build_model()
    model = compile_model(model, learning_rate=1e-3)
    model.summary()

    # ── Stage 1: frozen base ────────────────────────────────────────────────
    print("\n=== Stage 1: Training head (base frozen) ===")
    history1 = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=args.stage1_epochs,
        class_weight=class_weights,
        callbacks=get_callbacks(stage=1),
    )

    # ── Stage 2: fine-tune ──────────────────────────────────────────────────
    print("\n=== Stage 2: Fine-tuning (top layers unfrozen) ===")
    model = unfreeze_for_finetuning(model, learning_rate=1e-5)
    stage1_completed = len(history1.history["loss"])
    history2 = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=stage1_completed + args.stage2_epochs,
        class_weight=class_weights,
        callbacks=get_callbacks(stage=2),
        initial_epoch=stage1_completed,
    )

    # ── Export ──────────────────────────────────────────────────────────────
    os.makedirs(os.path.dirname(EXPORT_PATH), exist_ok=True)
    model.save(EXPORT_PATH)
    print(f"\nModel saved → {EXPORT_PATH}")

    return model, history1, history2


# ── CLI ────────────────────────────────────────────────────────────────────────

def parse_args():
    p = argparse.ArgumentParser(description="Train Phase 1 CNN classifier")
    p.add_argument("--csv",           default="data/annotations/labels.csv")
    p.add_argument("--data-dir",      default=None,
                   help="Use directory-based loading instead of CSV")
    p.add_argument("--batch-size",    type=int, default=BATCH_SIZE)
    p.add_argument("--stage1-epochs", type=int, default=STAGE1_EPOCHS)
    p.add_argument("--stage2-epochs", type=int, default=STAGE2_EPOCHS)
    return p.parse_args()


if __name__ == "__main__":
    args = parse_args()
    train(args)
