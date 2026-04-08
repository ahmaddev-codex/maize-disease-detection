"""
Phase 4 — TFLite Inference Runner
Runs a single image through the quantized TFLite model and returns the
predicted class, confidence score, and inference time.

Works on any platform that has TFLite runtime installed:
  - macOS / Linux dev machine: tensorflow package includes tflite interpreter
  - Raspberry Pi / Jetson:     install tflite-runtime wheel instead of full TF

Run:
    python -m src.phase4_edge.inference --image path/to/leaf.jpg
    python -m src.phase4_edge.inference --image leaf.jpg --model models/exports/efficientnetb3_maize_int8.tflite
"""
import os
import time
import argparse
import numpy as np

# Try the lightweight tflite-runtime first (Pi/Jetson), fall back to full TF
try:
    from tflite_runtime.interpreter import Interpreter
except ImportError:
    from tensorflow.lite.python.interpreter import Interpreter

CLASS_NAMES  = ["NCLB (Northern Corn Leaf Blight)", "Rust (Common Rust)",
                "GLS (Gray Leaf Spot)", "Healthy"]
IMG_SIZE     = (300, 300)
DEFAULT_MODEL = "models/exports/efficientnetb3_maize_int8.tflite"


# ── Core inference ────────────────────────────────────────────────────────────

def load_interpreter(model_path: str) -> Interpreter:
    """Load TFLite model and allocate tensors. Call once; reuse for many images."""
    if not os.path.exists(model_path):
        raise FileNotFoundError(
            f"TFLite model not found: {model_path}\n"
            "Run conversion first: python -m src.phase4_edge.convert_tflite"
        )
    interp = Interpreter(model_path=model_path)
    interp.allocate_tensors()
    return interp


def preprocess_image(image_path: str, input_dtype: np.dtype) -> np.ndarray:
    """
    Load and resize an image to match the TFLite model's expected input.

    INT8-quantized models expect uint8 [0, 255].
    FP16/dynamic models expect float32 [0, 255] (EfficientNetB3 rescales internally).
    """
    # Use cv2 if available (faster on Pi), else fall back to PIL
    try:
        import cv2
        img = cv2.imread(image_path)
        if img is None:
            raise ValueError(f"Could not read image: {image_path}")
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        img = cv2.resize(img, IMG_SIZE)
    except ImportError:
        from PIL import Image
        img = Image.open(image_path).convert("RGB").resize(IMG_SIZE)
        img = np.array(img)

    img = img.astype(np.float32)

    if input_dtype == np.uint8:
        img = np.clip(img, 0, 255).astype(np.uint8)

    return np.expand_dims(img, axis=0)   # [1, H, W, 3]


def run_inference(interp: Interpreter, image_path: str) -> dict:
    """
    Run a single image through the interpreter.

    Returns a dict with:
        class_id    (int)   — predicted class index
        class_name  (str)   — human-readable label
        confidence  (float) — softmax probability [0, 1]
        all_scores  (list)  — probabilities for all 4 classes
        latency_ms  (float) — wall-clock inference time in milliseconds
    """
    inp_details  = interp.get_input_details()[0]
    outp_details = interp.get_output_details()[0]

    image = preprocess_image(image_path, inp_details["dtype"])

    interp.set_tensor(inp_details["index"], image)

    t0 = time.perf_counter()
    interp.invoke()
    latency_ms = (time.perf_counter() - t0) * 1000

    output = interp.get_tensor(outp_details["index"])   # [1, 4]

    # Dequantize uint8 output if needed
    if outp_details["dtype"] == np.uint8:
        scale, zero_point = outp_details["quantization"]
        output = (output.astype(np.float32) - zero_point) * scale

    scores   = output[0].tolist()
    class_id = int(np.argmax(scores))

    return {
        "class_id":   class_id,
        "class_name": CLASS_NAMES[class_id],
        "confidence": scores[class_id],
        "all_scores": scores,
        "latency_ms": latency_ms,
    }


def benchmark(interp: Interpreter, image_path: str, runs: int = 10) -> dict:
    """Run inference `runs` times and return mean / min / max latency."""
    latencies = [run_inference(interp, image_path)["latency_ms"] for _ in range(runs)]
    return {
        "mean_ms": float(np.mean(latencies)),
        "min_ms":  float(np.min(latencies)),
        "max_ms":  float(np.max(latencies)),
        "runs":    runs,
    }


# ── CLI ───────────────────────────────────────────────────────────────────────

def parse_args():
    p = argparse.ArgumentParser(description="TFLite inference on a maize leaf image")
    p.add_argument("--image",     required=True,  help="Path to input image (JPEG/PNG)")
    p.add_argument("--model",     default=DEFAULT_MODEL,
                   help="Path to .tflite model file")
    p.add_argument("--benchmark", action="store_true",
                   help="Run 10 inference passes and report latency stats")
    return p.parse_args()


if __name__ == "__main__":
    args = parse_args()

    interp = load_interpreter(args.model)
    result = run_inference(interp, args.image)

    print(f"\nPrediction : {result['class_name']}")
    print(f"Confidence : {result['confidence'] * 100:.1f}%")
    print(f"Latency    : {result['latency_ms']:.1f} ms")
    print("\nAll class scores:")
    for name, score in zip(CLASS_NAMES, result["all_scores"]):
        bar = "█" * int(score * 30)
        print(f"  {name:<35} {score * 100:5.1f}%  {bar}")

    if args.benchmark:
        stats = benchmark(interp, args.image)
        print(f"\nBenchmark ({stats['runs']} runs):")
        print(f"  Mean : {stats['mean_ms']:.1f} ms")
        print(f"  Min  : {stats['min_ms']:.1f} ms")
        print(f"  Max  : {stats['max_ms']:.1f} ms")
        target = 2000  # 2s target
        status = "PASS" if stats["mean_ms"] < target else "FAIL"
        print(f"  <2s target: {status}")
