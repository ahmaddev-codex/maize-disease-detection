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
DROPOUT_RATE       = 0.4
FINE_TUNE_AT_LAYER = 100   # unfreeze from this layer index during stage 2


def build_model(num_classes: int = NUM_CLASSES) -> Model:
    """
    Build EfficientNetB3 with a custom classification head.

    Input must be [0, 255] float32 — EfficientNetB3 contains an internal
    Rescaling(1/255) layer; do NOT pre-normalise in the data pipeline.

    Head: GAP → BN → Dense(512, relu) → Dropout(0.4) → Dense(256, relu)
          → Dropout(0.3) → softmax(4)
    A two-layer head gives the model more capacity for Stage 1 head training.
    """
    base = tf.keras.applications.EfficientNetB3(
        include_top=False,
        weights="imagenet",
        input_shape=(*IMG_SIZE, 3),
    )
    base.trainable = False   # freeze for Stage 1

    inputs = tf.keras.Input(shape=(*IMG_SIZE, 3), name="image_input")

    # EfficientNetB3 includes its own internal preprocessing (rescaling + normalisation).
    # Pass training=False so base BN layers always use stored population statistics
    # during Stage 1 — this is the standard fine-tuning pattern.
    x = base(inputs, training=False)

    # Classification head
    x = layers.GlobalAveragePooling2D(name="gap")(x)
    x = layers.BatchNormalization(name="bn_head")(x)
    x = layers.Dense(512, activation="relu", name="dense_512")(x)
    x = layers.Dropout(DROPOUT_RATE, name="dropout_1")(x)
    x = layers.Dense(256, activation="relu", name="dense_256")(x)
    x = layers.Dropout(0.3, name="dropout_2")(x)
    outputs = layers.Dense(num_classes, activation="softmax", name="predictions")(x)

    model = Model(inputs, outputs, name="EfficientNetB3_Maize")
    return model


def compile_model(
    model: Model,
    learning_rate: float = 1e-3,
    one_hot: bool = False,
    label_smoothing: float = 0.0,
    weight_decay: float = 1e-4,
) -> Model:
    if one_hot or label_smoothing > 0:
        loss = tf.keras.losses.CategoricalCrossentropy(label_smoothing=label_smoothing)
    else:
        loss = "sparse_categorical_crossentropy"

    model.compile(
        optimizer=tf.keras.optimizers.AdamW(
            learning_rate=learning_rate, weight_decay=weight_decay
        ),
        loss=loss,
        metrics=["accuracy"],
    )
    return model


def unfreeze_for_finetuning(
    model: Model,
    fine_tune_at: int = FINE_TUNE_AT_LAYER,
    learning_rate: float = 1e-5,
    one_hot: bool = False,
    label_smoothing: float = 0.0,
    freeze_bn: bool = True,
    weight_decay: float = 1e-5,
) -> Model:
    """
    Stage 2: unfreeze base model layers from fine_tune_at onwards.
    Keep BatchNormalization layers frozen so population statistics stay stable.
    Use a lower learning rate to preserve pre-trained feature extractors.

    NOTE: always call this on a *freshly built* model and load Stage 1 weights
    afterwards — reusing the same model instance causes Keras 3 / TF 2.16 to
    retain Adam slot variables sized for the frozen variable set.
    """
    base = model.get_layer("efficientnetb3")
    base.trainable = True

    for i, layer in enumerate(base.layers):
        if i < fine_tune_at:
            layer.trainable = False
        elif freeze_bn and isinstance(layer, layers.BatchNormalization):
            layer.trainable = False
        else:
            layer.trainable = True

    total     = len(base.layers)
    trainable = sum(1 for l in base.layers if l.trainable)
    print(f"Fine-tuning: {trainable}/{total} base layers trainable (from layer {fine_tune_at}, freeze_bn={freeze_bn})")

    if one_hot or label_smoothing > 0:
        loss = tf.keras.losses.CategoricalCrossentropy(label_smoothing=label_smoothing)
    else:
        loss = "sparse_categorical_crossentropy"

    model.compile(
        optimizer=tf.keras.optimizers.AdamW(
            learning_rate=learning_rate, weight_decay=weight_decay
        ),
        loss=loss,
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
