"""
Phase 1 — EfficientNetB3 Model
Two-stage transfer learning:
  Stage 1: base frozen, train classification head only
  Stage 2: unfreeze top N layers of base, fine-tune end-to-end
"""

import tensorflow as tf
from tensorflow.keras import layers, Model

NUM_CLASSES        = 4   # NCLB, Rust, GLS, Healthy
IMG_SIZE           = (300, 300)
DROPOUT_RATE       = 0.3
FINE_TUNE_AT_LAYER = 100   # unfreeze from this layer index during stage 2


def build_model(num_classes: int = NUM_CLASSES) -> Model:
    """
    Build EfficientNetB3 with a custom classification head.
    Base weights pre-loaded from ImageNet; base is frozen by default.
    """
    base = tf.keras.applications.EfficientNetB3(
        include_top=False,
        weights="imagenet",
        input_shape=(*IMG_SIZE, 3),
    )
    base.trainable = False   # freeze for Stage 1

    inputs = tf.keras.Input(shape=(*IMG_SIZE, 3), name="image_input")

    # EfficientNetB3 includes its own internal preprocessing (rescaling + normalisation)
    x = base(inputs, training=False)

    # Classification head
    x = layers.GlobalAveragePooling2D(name="gap")(x)
    x = layers.BatchNormalization(name="bn_head")(x)
    x = layers.Dense(256, activation="relu", name="dense_256")(x)
    x = layers.Dropout(DROPOUT_RATE, name="dropout")(x)
    outputs = layers.Dense(num_classes, activation="softmax", name="predictions")(x)

    model = Model(inputs, outputs, name="EfficientNetB3_Maize")
    return model


def compile_model(
    model: Model,
    learning_rate: float = 1e-3,
) -> Model:
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=learning_rate),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    return model


def unfreeze_for_finetuning(
    model: Model,
    fine_tune_at: int = FINE_TUNE_AT_LAYER,
    learning_rate: float = 1e-5,
) -> Model:
    """
    Stage 2: unfreeze all layers from fine_tune_at onwards in the base model.
    Use a much lower learning rate to avoid destroying pre-trained weights.
    """
    base = model.get_layer("efficientnetb3")
    base.trainable = True

    for layer in base.layers[:fine_tune_at]:
        layer.trainable = False

    total     = len(base.layers)
    trainable = sum(1 for l in base.layers if l.trainable)
    print(f"Fine-tuning: {trainable}/{total} base layers unfrozen (from layer {fine_tune_at})")

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=learning_rate),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    return model


def get_feature_extractor(model: Model) -> Model:
    """
    Return a sub-model that outputs the penultimate dense layer (256-d).
    Used by Phase 3 fusion to extract CNN feature vectors.
    """
    return Model(
        inputs=model.input,
        outputs=model.get_layer("dense_256").output,
        name="feature_extractor",
    )
