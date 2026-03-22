"""
Phase 3 — Multimodal Fusion Model
Concatenates the 256-d CNN feature vector (from Phase 1 penultimate layer)
with the 24-d OCR metadata vector (from Phase 2 encoder) and adds a small
dense classification head on top.

Architecture:
  image  → EfficientNetB3 (frozen/fine-tuned) → Dense(256) → 256-d vector ─┐
                                                                              concat → Dense(128) → Dense(5)
  label_image → Tesseract → encode() → 24-d vector ───────────────────────┘

Total input dims: 256 + 24 = 280
"""

import tensorflow as tf
from tensorflow.keras import layers, Model

from src.phase1_cnn.model import build_model as build_cnn, get_feature_extractor
from src.phase2_ocr.encoder import METADATA_DIM

NUM_CLASSES  = 4   # NCLB, Rust, GLS, Healthy
CNN_FEAT_DIM = 256
DROPOUT_RATE = 0.3


def build_fusion_model(
    cnn_weights_path: str = None,
    freeze_cnn: bool = True,
) -> Model:
    """
    Build the full fusion model.

    Args:
        cnn_weights_path: Path to a Phase 1 trained .h5 file. If None, CNN
                          weights are random (useful for testing the graph).
        freeze_cnn:       If True, CNN weights are frozen during fusion training.
                          Set False to fine-tune end-to-end.

    Returns:
        Compiled Keras Model with two inputs:
          - "image_input"    shape (300, 300, 3)
          - "metadata_input" shape (METADATA_DIM,)
    """
    # ── CNN branch ────────────────────────────────────────────────────────
    if cnn_weights_path:
        # Load the full saved model directly (avoids Keras 3 by_name shape mismatches)
        cnn_full = tf.keras.models.load_model(cnn_weights_path)
        print(f"Loaded CNN model from {cnn_weights_path}")
    else:
        cnn_full = build_cnn(num_classes=NUM_CLASSES)

    cnn_full.trainable = not freeze_cnn
    feature_extractor  = get_feature_extractor(cnn_full)

    image_input = tf.keras.Input(shape=(300, 300, 3), name="image_input")
    cnn_features = feature_extractor(image_input, training=not freeze_cnn)   # (B, 256)

    # ── Metadata branch ───────────────────────────────────────────────────
    metadata_input = tf.keras.Input(shape=(METADATA_DIM,), name="metadata_input")
    meta_x = layers.Dense(32, activation="relu", name="meta_dense")(metadata_input)
    meta_x = layers.BatchNormalization(name="meta_bn")(meta_x)   # (B, 32)

    # ── Fusion head ───────────────────────────────────────────────────────
    fused = layers.Concatenate(name="fusion_concat")([cnn_features, meta_x])  # (B, 288)
    fused = layers.Dense(128, activation="relu", name="fusion_dense_128")(fused)
    fused = layers.Dropout(DROPOUT_RATE, name="fusion_dropout")(fused)
    outputs = layers.Dense(NUM_CLASSES, activation="softmax", name="predictions")(fused)

    model = Model(
        inputs=[image_input, metadata_input],
        outputs=outputs,
        name="FusionModel_Maize",
    )
    return model


def compile_fusion_model(
    model: Model,
    learning_rate: float = 5e-4,
) -> Model:
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=learning_rate),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    return model
