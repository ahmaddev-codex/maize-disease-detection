"""
Phase 3 — Fusion Training Script
Loads the Phase 1 image dataset + pre-computed OCR metadata vectors,
then trains the fusion model end-to-end.

Run:
    python -m src.phase3_fusion.train_fusion \
        --cnn-weights models/exports/efficientnetb3_maize.h5 \
        --metadata-csv data/annotations/labels_with_metadata.csv

Expected CSV columns:
    image_path, label, class_name, source,
    crop_variety, batch_number, planting_date
"""

import os
import argparse
import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.model_selection import train_test_split

from src.phase1_cnn.data_pipeline import IMG_SIZE, CLASS_NAMES, AUTOTUNE
from src.phase2_ocr.extractor import extract_fields_from_path
from src.phase2_ocr.encoder import encode, METADATA_DIM
from src.phase3_fusion.fusion_model import build_fusion_model, compile_fusion_model

BATCH_SIZE     = 32
FUSION_EPOCHS  = 25
EXPORT_PATH    = "models/exports/fusion_model.h5"
CHECKPOINT_DIR = "models/checkpoints"


# ── Metadata helpers ───────────────────────────────────────────────────────────

def compute_or_load_metadata(df: pd.DataFrame) -> np.ndarray:
    """
    If the CSV already has crop_variety / batch_number / planting_date columns,
    encode those directly. Otherwise run OCR on each seed-label image path.
    """
    meta_cols = {"crop_variety", "batch_number", "planting_date"}
    has_meta  = meta_cols.issubset(df.columns)

    vectors = []
    for _, row in df.iterrows():
        if has_meta:
            fields = {
                "crop_variety":  row.get("crop_variety"),
                "batch_number":  row.get("batch_number"),
                "planting_date": row.get("planting_date"),
            }
        else:
            label_path = row.get("label_image_path")
            if label_path and os.path.exists(label_path):
                fields = extract_fields_from_path(label_path)
            else:
                fields = {"crop_variety": None, "batch_number": None, "planting_date": None}
        vectors.append(encode(fields))

    return np.stack(vectors, axis=0).astype(np.float32)


# ── tf.data builder ────────────────────────────────────────────────────────────

def _load_image(path: str) -> tf.Tensor:
    raw   = tf.io.read_file(path)
    image = tf.image.decode_jpeg(raw, channels=3)
    image = tf.image.resize(image, IMG_SIZE)
    return tf.cast(image, tf.float32) / 255.0


def build_fusion_dataset(
    df: pd.DataFrame,
    metadata_vecs: np.ndarray,
    augment: bool = False,
    shuffle: bool = True,
    batch_size: int = BATCH_SIZE,
) -> tf.data.Dataset:
    paths    = df["image_path"].values
    labels   = df["label"].values.astype(np.int32)

    img_ds   = tf.data.Dataset.from_tensor_slices(paths)
    img_ds   = img_ds.map(_load_image, num_parallel_calls=AUTOTUNE)

    meta_ds  = tf.data.Dataset.from_tensor_slices(metadata_vecs)
    label_ds = tf.data.Dataset.from_tensor_slices(labels)

    ds = tf.data.Dataset.zip(((img_ds, meta_ds), label_ds))

    if shuffle:
        ds = ds.shuffle(buffer_size=len(df), seed=42)

    ds = ds.batch(batch_size).prefetch(AUTOTUNE)
    return ds


# ── Callbacks ──────────────────────────────────────────────────────────────────

def get_callbacks() -> list:
    os.makedirs(CHECKPOINT_DIR, exist_ok=True)
    return [
        tf.keras.callbacks.ModelCheckpoint(
            filepath=os.path.join(CHECKPOINT_DIR, "phase3_fusion_best.h5"),
            monitor="val_accuracy",
            save_best_only=True,
            verbose=1,
        ),
        tf.keras.callbacks.EarlyStopping(
            monitor="val_accuracy",
            patience=6,
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
        tf.keras.callbacks.TensorBoard(log_dir="logs/phase3_fusion"),
    ]


# ── Training ───────────────────────────────────────────────────────────────────

def train(args):
    df = pd.read_csv(args.metadata_csv)
    print(f"Loaded {len(df)} records from {args.metadata_csv}")

    metadata_vecs = compute_or_load_metadata(df)
    print(f"Metadata vectors shape: {metadata_vecs.shape}")

    # Stratified split
    train_df, tmp_df, train_meta, tmp_meta = train_test_split(
        df, metadata_vecs, test_size=0.30,
        stratify=df["label"], random_state=42
    )
    val_df, test_df, val_meta, test_meta = train_test_split(
        tmp_df, tmp_meta, test_size=0.50,
        stratify=tmp_df["label"], random_state=42
    )

    train_ds = build_fusion_dataset(train_df, train_meta, augment=True,  shuffle=True)
    val_ds   = build_fusion_dataset(val_df,   val_meta,   augment=False, shuffle=False)
    test_ds  = build_fusion_dataset(test_df,  test_meta,  augment=False, shuffle=False)

    # Build + compile
    model = build_fusion_model(
        cnn_weights_path=args.cnn_weights,
        freeze_cnn=args.freeze_cnn,
    )
    model = compile_fusion_model(model, learning_rate=args.lr)
    model.summary()

    # Train
    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=args.epochs,
        callbacks=get_callbacks(),
    )

    # Evaluate on held-out test set
    loss, acc = model.evaluate(test_ds, verbose=1)
    print(f"\nFusion Test Accuracy: {acc * 100:.2f}%")

    # Export
    os.makedirs(os.path.dirname(EXPORT_PATH), exist_ok=True)
    model.save(EXPORT_PATH)
    print(f"Fusion model saved → {EXPORT_PATH}")

    return model, history


# ── CLI ────────────────────────────────────────────────────────────────────────

def parse_args():
    p = argparse.ArgumentParser(description="Train Phase 3 fusion model")
    p.add_argument("--metadata-csv",  default="data/annotations/labels_with_metadata.csv",
                   help="CSV with image_path, label, and OCR metadata columns")
    p.add_argument("--cnn-weights",   default="models/exports/efficientnetb3_maize.h5",
                   help="Path to trained Phase 1 weights")
    p.add_argument("--freeze-cnn",    action="store_true", default=True,
                   help="Freeze CNN weights during fusion training")
    p.add_argument("--no-freeze-cnn", dest="freeze_cnn", action="store_false")
    p.add_argument("--epochs",        type=int,   default=FUSION_EPOCHS)
    p.add_argument("--lr",            type=float, default=5e-4)
    return p.parse_args()


if __name__ == "__main__":
    args = parse_args()
    train(args)
