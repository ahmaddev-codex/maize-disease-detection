"""
Phase 4 — TFLite INT8 Conversion
Converts the trained EfficientNetB3 Keras model to a TFLite flatbuffer with
full INT8 post-training quantization using a representative calibration dataset.

Run:
    python -m src.phase4_edge.convert_tflite

Outputs:
    models/exports/efficientnetb3_maize_int8.tflite   ← quantized model
    models/exports/efficientnetb3_maize_fp16.tflite   ← FP16 fallback

INT8 requires a representative dataset (100–500 images) so the converter can
compute per-layer activation ranges.  We sample from labels.csv for this.
"""

import os
import argparse
import numpy as np
import tensorflow as tf

from src.phase1_cnn.data_pipeline import load_labels_csv, IMG_SIZE

KERAS_MODEL  = "models/exports/efficientnetb3_maize.keras"
EXPORT_DIR   = "models/exports"
INT8_PATH    = os.path.join(EXPORT_DIR, "efficientnetb3_maize_int8.tflite")
FP16_PATH    = os.path.join(EXPORT_DIR, "efficientnetb3_maize_fp16.tflite")
CALIB_IMAGES = 200   # number of images used for INT8 calibration


# ── Representative dataset ────────────────────────────────────────────────────

def make_representative_dataset(csv_path: str, n: int = CALIB_IMAGES):
    """
    Generator that yields calibration batches (1 image each) as float32
    in the [0, 255] range that EfficientNetB3 expects.
    """
    df = load_labels_csv(csv_path)
    sample = df.sample(min(n, len(df)), random_state=42)

    def _gen():
        for path in sample["image_path"].values:
            raw   = tf.io.read_file(path)
            image = tf.image.decode_image(raw, channels=3, expand_animations=False)
            image = tf.image.resize(image, IMG_SIZE)
            image = tf.cast(image, tf.float32)          # [0, 255] — model rescales internally
            image = tf.expand_dims(image, axis=0)       # [1, H, W, 3]
            yield [image]

    return _gen


# ── Converters ────────────────────────────────────────────────────────────────

def _load_as_saved_model(model_path: str, saved_model_dir: str) -> str:
    """
    Keras 3 / TF 2.16 compatibility:
      - TFLiteConverter.from_keras_model() crashes (tracing returns None).
      - tf.saved_model.save() crashes on Keras 3 _DictWrapper objects.
      - model.export() is the Keras 3 API that produces a proper SavedModel.
    We then convert from the SavedModel directory.
    """
    model = tf.keras.models.load_model(model_path)
    model.export(saved_model_dir)   # Keras 3 export API
    return saved_model_dir


def convert_fp16(model_path: str, out_path: str):
    """FP16 quantization — good speed/accuracy tradeoff, no calibration needed."""
    import tempfile, shutil
    tmp_dir = tempfile.mkdtemp(prefix="tflite_saved_model_")
    try:
        saved_model_dir = _load_as_saved_model(model_path, tmp_dir)
        converter = tf.lite.TFLiteConverter.from_saved_model(saved_model_dir)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]

        tflite_model = converter.convert()
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        with open(out_path, "wb") as f:
            f.write(tflite_model)

        size_mb = os.path.getsize(out_path) / 1e6
        print(f"FP16 model saved → {out_path}  ({size_mb:.1f} MB)")
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


def convert_int8(model_path: str, csv_path: str, out_path: str):
    """
    Full INT8 quantization — smallest size, fastest on Pi/Jetson NPU.
    Both weights and activations are quantized; requires representative data.
    """
    import tempfile, shutil
    tmp_dir = tempfile.mkdtemp(prefix="tflite_saved_model_")
    try:
        saved_model_dir = _load_as_saved_model(model_path, tmp_dir)
        converter = tf.lite.TFLiteConverter.from_saved_model(saved_model_dir)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.representative_dataset = make_representative_dataset(csv_path)

        # Force all ops to INT8 (fallback to float for unsupported ops)
        converter.target_spec.supported_ops = [
            tf.lite.OpsSet.TFLITE_BUILTINS_INT8,
            tf.lite.OpsSet.TFLITE_BUILTINS,   # fallback for ops without INT8 kernel
        ]
        converter.inference_input_type  = tf.uint8
        converter.inference_output_type = tf.uint8

        print(f"Running INT8 calibration on {CALIB_IMAGES} images — this takes a minute...")
        tflite_model = converter.convert()

        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        with open(out_path, "wb") as f:
            f.write(tflite_model)

        size_mb = os.path.getsize(out_path) / 1e6
        print(f"INT8 model saved → {out_path}  ({size_mb:.1f} MB)")
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


# ── Verification ──────────────────────────────────────────────────────────────

def verify_tflite(tflite_path: str, csv_path: str, n: int = 20):
    """
    Run n images through the TFLite interpreter and print accuracy.
    Quick sanity check that quantization didn't break predictions.
    """
    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()

    inp  = interpreter.get_input_details()[0]
    outp = interpreter.get_output_details()[0]

    df      = load_labels_csv(csv_path)
    sample  = df.sample(min(n, len(df)), random_state=99)
    correct = 0

    for _, row in sample.iterrows():
        raw   = tf.io.read_file(row["image_path"])
        image = tf.image.decode_image(raw, channels=3, expand_animations=False)
        image = tf.image.resize(image, IMG_SIZE)
        image = tf.cast(image, tf.float32)
        image = tf.expand_dims(image, axis=0)

        # Cast to uint8 if model expects it
        if inp["dtype"] == np.uint8:
            image = tf.cast(tf.clip_by_value(image, 0, 255), tf.uint8)

        interpreter.set_tensor(inp["index"], image.numpy())
        interpreter.invoke()
        output = interpreter.get_tensor(outp["index"])
        pred   = int(np.argmax(output, axis=1)[0])

        if pred == row["label"]:
            correct += 1

    acc = correct / len(sample)
    print(f"TFLite verification ({n} samples): {acc * 100:.1f}% accuracy")
    return acc


# ── CLI ───────────────────────────────────────────────────────────────────────

def parse_args():
    p = argparse.ArgumentParser(description="Convert Keras model to TFLite")
    p.add_argument("--model",    default=KERAS_MODEL,
                   help="Path to trained .keras model")
    p.add_argument("--csv",      default="data/annotations/labels.csv",
                   help="labels.csv used to sample calibration images")
    p.add_argument("--fp16",     action="store_true", default=True,
                   help="Export FP16 model (default: on)")
    p.add_argument("--int8",     action="store_true", default=True,
                   help="Export INT8 model (default: on)")
    p.add_argument("--no-fp16",  dest="fp16", action="store_false")
    p.add_argument("--no-int8",  dest="int8", action="store_false")
    p.add_argument("--verify",   action="store_true", default=True,
                   help="Run quick accuracy check on converted models")
    p.add_argument("--no-verify", dest="verify", action="store_false")
    return p.parse_args()


if __name__ == "__main__":
    args = parse_args()

    if not os.path.exists(args.model):
        raise FileNotFoundError(
            f"Keras model not found: {args.model}\n"
            "Run Phase 1 training first: python -m src.phase1_cnn.train"
        )

    if args.fp16:
        convert_fp16(args.model, FP16_PATH)
        if args.verify:
            verify_tflite(FP16_PATH, args.csv)

    if args.int8:
        convert_int8(args.model, args.csv, INT8_PATH)
        if args.verify:
            verify_tflite(INT8_PATH, args.csv)

    print("\nConversion complete.")
    print("  Copy the .tflite file to your Pi/Jetson and run:")
    print("  python -m src.phase4_edge.inference --model <path>.tflite --image <image.jpg>")
