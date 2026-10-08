"""
Phase 1 — Training Script
Run:
    python -m src.phase1_cnn.train

Two-stage training:
  Stage 1 — frozen base, 20 epochs, lr=1e-3  (train head only)
  Stage 2 — unfreeze top layers, 30 epochs, lr=1e-5  (fine-tune end-to-end)

Target: ≥90% validation accuracy on 4-class PlantVillage maize dataset.
"""

import os
import argparse
import tensorflow as tf

from src.phase1_cnn.data_pipeline import build_datasets, build_datasets_from_directory
from src.phase1_cnn.model import build_model, compile_model, unfreeze_for_finetuning

# ── Defaults ───────────────────────────────────────────────────────────────────

STAGE1_EPOCHS   = 20
STAGE2_EPOCHS   = 30
BATCH_SIZE      = 32
STAGE1_LR       = 1e-3
STAGE2_LR       = 3e-5
FINE_TUNE_AT    = 50
CHECKPOINT_DIR  = "models/checkpoints"
EXPORT_PATH     = "models/exports/efficientnetb3_maize.keras"


# ── Callbacks ──────────────────────────────────────────────────────────────────

def get_callbacks(stage: int, patience: int = 10) -> list:
    os.makedirs(CHECKPOINT_DIR, exist_ok=True)
    return [
        tf.keras.callbacks.ModelCheckpoint(
            filepath=os.path.join(CHECKPOINT_DIR, f"phase1_stage{stage}_best.keras"),
            monitor="val_accuracy",
            save_best_only=True,
            verbose=1,
        ),
        tf.keras.callbacks.EarlyStopping(
            monitor="val_accuracy",
            patience=patience,
            restore_best_weights=True,
            verbose=1,
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss",
            factor=0.3,
            patience=max(3, patience // 2),
            min_lr=1e-8,
            verbose=1,
        ),
        tf.keras.callbacks.TensorBoard(
            log_dir=f"logs/phase1_stage{stage}",
            histogram_freq=1,
        ),
    ]


# ── Training ───────────────────────────────────────────────────────────────────

def train(args):
    use_one_hot = args.one_hot or args.label_smoothing > 0 or args.mix != "none"

    # Load data
    if args.data_dir:
        train_ds, val_ds, test_ds, class_weights = build_datasets_from_directory(
            args.data_dir, batch_size=args.batch_size
        )
    else:
        train_ds, val_ds, test_ds, class_weights = build_datasets(
            csv_path=args.csv,
            batch_size=args.batch_size,
            one_hot=use_one_hot,
            mix=args.mix,
            mix_prob=args.mix_prob,
        )

    # Build model
    model = build_model(backbone=args.backbone)
    model = compile_model(
        model,
        learning_rate=args.stage1_lr,
        one_hot=use_one_hot,
        label_smoothing=args.label_smoothing,
    )
    model.summary()

    # ── Stage 1: frozen base ────────────────────────────────────────────────
    print("\n=== Stage 1: Training head (base frozen) ===")
    history1 = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=args.stage1_epochs,
        class_weight=class_weights,
        callbacks=get_callbacks(stage=1, patience=args.patience),
    )

    # ── Stage 2: fine-tune ──────────────────────────────────────────────────
    # Keras 3 / TF 2.16 bug: calling compile() on an existing model instance
    # leaves Adam's slot variables (m, v) sized for the frozen variable set.
    # When newly-unfrozen convolution layers produce gradients, their shapes
    # don't match the empty slots → "Incompatible shapes: [0] vs [...]".
    # Fix: save weights → rebuild fresh model (clean optimizer slots) →
    #      reload weights → train stage 2 from epoch 0.
    print(f"\n=== Stage 2: Fine-tuning (layers from index {args.fine_tune_at} unfrozen) ===")
    tmp_weights = os.path.join(CHECKPOINT_DIR, "tmp_stage1.weights.h5")
    model.save_weights(tmp_weights)

    model2 = build_model(backbone=args.backbone)
    model2 = unfreeze_for_finetuning(
        model2,
        fine_tune_at=args.fine_tune_at,
        learning_rate=args.stage2_lr,
        one_hot=use_one_hot,
        label_smoothing=args.label_smoothing,
        freeze_bn=not args.unfreeze_bn,
    )
    model2.load_weights(tmp_weights)

    history2 = model2.fit(
        train_ds,
        validation_data=val_ds,
        epochs=args.stage2_epochs,
        class_weight=class_weights,
        callbacks=get_callbacks(stage=2, patience=args.patience),
    )
    model = model2

    # Reload best checkpoint from Stage 2 if available
    best_checkpoint = os.path.join(CHECKPOINT_DIR, "phase1_stage2_best.keras")
    if os.path.exists(best_checkpoint):
        try:
            print(f"\nReloading best checkpoint from {best_checkpoint}...")
            model = tf.keras.models.load_model(best_checkpoint)
        except Exception as e:
            print(f"Note: Could not reload {best_checkpoint} directly ({e}), keeping in-memory weights.")

    # Remove temp weights file
    if os.path.exists(tmp_weights):
        os.remove(tmp_weights)

    # ── Export ──────────────────────────────────────────────────────────────
    export_path = args.export or EXPORT_PATH
    os.makedirs(os.path.dirname(export_path), exist_ok=True)
    model.save(export_path)
    print(f"\nModel saved → {export_path}")

    return model, history1, history2


# ── CLI ────────────────────────────────────────────────────────────────────────

def parse_args():
    p = argparse.ArgumentParser(description="Train Phase 1 CNN classifier")
    p.add_argument("--backbone",        choices=["efficientnetb3", "efficientnetv2_s", "efficientnetv2_m"],
                   default="efficientnetb3", help="CNN backbone architecture")
    p.add_argument("--csv",             default="data/annotations/labels.csv")
    p.add_argument("--data-dir",        default=None,
                   help="Use directory-based loading instead of CSV")
    p.add_argument("--batch-size",      type=int,   default=BATCH_SIZE)
    p.add_argument("--stage1-epochs",   type=int,   default=STAGE1_EPOCHS)
    p.add_argument("--stage2-epochs",   type=int,   default=STAGE2_EPOCHS)
    p.add_argument("--stage1-lr",       type=float, default=STAGE1_LR)
    p.add_argument("--stage2-lr",       type=float, default=STAGE2_LR)
    p.add_argument("--fine-tune-at",    type=int,   default=FINE_TUNE_AT,
                   help="Layer index from which to unfreeze the base (lower = more layers unfrozen)")
    p.add_argument("--one-hot",         action="store_true", default=False,
                   help="Use one-hot encoded labels")
    p.add_argument("--label-smoothing", type=float, default=0.05,
                   help="Label smoothing epsilon (0.0 to disable)")
    p.add_argument("--mix",             choices=["none", "mixup", "cutmix", "both"], default="none",
                   help="Data mixing regularization method")
    p.add_argument("--mix-prob",        type=float, default=0.5,
                   help="Probability of applying MixUp/CutMix per batch")
    p.add_argument("--unfreeze-bn",     action="store_true", default=False,
                   help="Unfreeze BatchNormalization layers during Stage 2 (default: keep frozen)")
    p.add_argument("--patience",        type=int,   default=10,
                   help="Early stopping patience")
    p.add_argument("--export",          default=EXPORT_PATH,
                   help="Destination for saved Keras model")
    return p.parse_args()


if __name__ == "__main__":
    args = parse_args()
    train(args)
