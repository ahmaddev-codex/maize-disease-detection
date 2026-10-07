"""
Phase 1 — Data Pipeline
Loads images from data/raw/, applies augmentation, and creates
train/val/test tf.data datasets ready for EfficientNetB3.
"""

import os
import pandas as pd
import numpy as np
import tensorflow as tf
from sklearn.model_selection import train_test_split

# ── Constants ─────────────────────────────────────────────────────────────────

# Folder names, plot labels and metric keys use the short form; the display
# names live beside them in src/common/labels.py (ADR-006).
from src.common.labels import SHORT_NAMES as CLASS_NAMES  # noqa: E402
from src.common.labels import NUM_CLASSES  # noqa: E402,F401  # MSV excluded — not in PlantVillage
IMG_SIZE    = (300, 300)   # EfficientNetB3 native resolution
BATCH_SIZE  = 32
AUTOTUNE    = tf.data.AUTOTUNE

# ── Augmentation layers (training only) ───────────────────────────────────────

def build_augmentation():
    return tf.keras.Sequential([
        tf.keras.layers.RandomFlip("horizontal_and_vertical"),
        tf.keras.layers.RandomRotation(0.2),
        tf.keras.layers.RandomZoom(0.15),
        tf.keras.layers.RandomTranslation(0.1, 0.1),
        tf.keras.layers.RandomBrightness(factor=0.2),
        tf.keras.layers.RandomContrast(0.2),
    ], name="augmentation")


# ── Image loading ──────────────────────────────────────────────────────────────

def load_and_preprocess(image_path: str, label: int):
    """Read image from disk, decode (JPEG or PNG), resize to [0, 255] float32.

    EfficientNetB3 includes its own internal Rescaling(1/255) + Normalization
    layers.  Do NOT divide by 255 here — passing pre-normalized [0,1] values
    causes a double-rescaling that collapses activations and tanks accuracy.
    """
    raw   = tf.io.read_file(image_path)
    image = tf.image.decode_image(raw, channels=3, expand_animations=False)
    image = tf.image.resize(image, IMG_SIZE)
    image = tf.cast(image, tf.float32)   # keep in [0, 255]; model rescales internally
    return image, label


# ── CSV → train / val / test split ────────────────────────────────────────────

def load_labels_csv(csv_path: str) -> pd.DataFrame:
    """
    Expects columns: image_path, label (int 0-4), class_name, source.
    image_path must be absolute or relative to the repo root.
    """
    df = pd.read_csv(csv_path)
    assert {"image_path", "label", "class_name"}.issubset(df.columns), (
        "labels.csv must have columns: image_path, label, class_name"
    )
    return df


def split_dataframe(
    df: pd.DataFrame,
    val_size: float = 0.15,
    test_size: float = 0.15,
    random_state: int = 42,
):
    """Stratified split → (train_df, val_df, test_df)."""
    train_df, tmp_df = train_test_split(
        df, test_size=(val_size + test_size),
        stratify=df["label"], random_state=random_state
    )
    relative_test = test_size / (val_size + test_size)
    val_df, test_df = train_test_split(
        tmp_df, test_size=relative_test,
        stratify=tmp_df["label"], random_state=random_state
    )
    return train_df.reset_index(drop=True), \
           val_df.reset_index(drop=True), \
           test_df.reset_index(drop=True)


# ── tf.data builders ───────────────────────────────────────────────────────────

def df_to_dataset(
    df: pd.DataFrame,
    augment: bool = False,
    shuffle: bool = True,
    batch_size: int = BATCH_SIZE,
) -> tf.data.Dataset:
    """Convert a labelled DataFrame into a batched tf.data.Dataset."""
    paths  = df["image_path"].values
    labels = df["label"].values.astype(np.int32)

    ds = tf.data.Dataset.from_tensor_slices((paths, labels))

    if shuffle:
        ds = ds.shuffle(buffer_size=len(df), seed=42)

    ds = ds.map(load_and_preprocess, num_parallel_calls=AUTOTUNE)

    if augment:
        aug = build_augmentation()
        ds  = ds.map(
            lambda x, y: (aug(x, training=True), y),
            num_parallel_calls=AUTOTUNE
        )

    ds = ds.batch(batch_size).prefetch(AUTOTUNE)
    return ds


# ── Public entry point ─────────────────────────────────────────────────────────

def build_datasets(
    csv_path: str = "data/annotations/labels.csv",
    batch_size: int = BATCH_SIZE,
):
    """
    Load labels.csv and return (train_ds, val_ds, test_ds, class_weights).

    class_weights is a dict {int: float} suitable for model.fit().
    """
    df = load_labels_csv(csv_path)

    if len(df) == 0:
        raise ValueError(
            "labels.csv is empty. Populate it with image paths and labels first."
        )

    train_df, val_df, test_df = split_dataframe(df)

    print(f"Dataset split — train: {len(train_df)} | val: {len(val_df)} | test: {len(test_df)}")

    train_ds = df_to_dataset(train_df, augment=True,  shuffle=True,  batch_size=batch_size)
    val_ds   = df_to_dataset(val_df,   augment=False, shuffle=False, batch_size=batch_size)
    test_ds  = df_to_dataset(test_df,  augment=False, shuffle=False, batch_size=batch_size)

    # Compute class weights to handle imbalance
    counts = train_df["label"].value_counts().sort_index()
    total  = len(train_df)
    class_weights = {
        cls: total / (NUM_CLASSES * count)
        for cls, count in counts.items()
    }

    return train_ds, val_ds, test_ds, class_weights


# ── Utility: build datasets directly from a raw image directory ───────────────

def build_datasets_from_directory(
    root_dir: str,
    batch_size: int = BATCH_SIZE,
):
    """
    Alternative entry point: load from a directory where each sub-folder
    is named after a class (PlantVillage layout).

    Expects:
        root_dir/
            NCLB/       *.jpg   (or Blight/)
            Rust/       *.jpg   (or Common_Rust/)
            GLS/        *.jpg   (or Gray_Leaf_Spot/)
            Healthy/    *.jpg
    """
    rows = []
    for label_idx, class_name in enumerate(CLASS_NAMES):
        class_dir = os.path.join(root_dir, class_name)
        if not os.path.isdir(class_dir):
            print(f"[warn] Missing class directory: {class_dir}")
            continue
        for fname in os.listdir(class_dir):
            if fname.lower().endswith((".jpg", ".jpeg", ".png")):
                rows.append({
                    "image_path": os.path.join(class_dir, fname),
                    "label":      label_idx,
                    "class_name": class_name,
                    "source":     "directory",
                })

    df = pd.DataFrame(rows)

    if len(df) == 0:
        raise ValueError(f"No images found under {root_dir}")

    # Save labels.csv so it can be reused
    os.makedirs("data/annotations", exist_ok=True)
    df.to_csv("data/annotations/labels.csv", index=False)
    print(f"Saved {len(df)} records to data/annotations/labels.csv")

    return build_datasets(csv_path="data/annotations/labels.csv", batch_size=batch_size)
