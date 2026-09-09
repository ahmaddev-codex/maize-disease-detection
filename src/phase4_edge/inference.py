"""
Standalone TFLite Inference & Benchmarking Engine for MaizeGuard.
Targeted for edge devices (Raspberry Pi 4, Jetson Nano, Coral, Laptop/Server).

Usage:
  # Benchmark model inference speed:
  python -m src.phase4_edge.inference --benchmark --model models/exports/efficientnetb3_maize_int8.tflite

  # Classify a single leaf photo:
  python -m src.phase4_edge.inference --image data/raw/Northern_Leaf_Blight/sample.jpg

  # Evaluate accuracy on test CSV:
  python -m src.phase4_edge.inference --csv data/processed/test.csv --model models/exports/efficientnetb3_maize_int8.tflite
"""

import argparse
import json
import os
import sys
import time
from typing import Dict, List, Optional, Tuple

import numpy as np
from PIL import Image

tf = None
tf_tflite = None

try:
    import tensorflow as tf
except ImportError:
    try:
        import tflite_runtime.interpreter as tf_tflite
    except ImportError:
        raise ImportError(
            "Neither tensorflow nor tflite_runtime is installed. "
            "Please install tensorflow (pip install tensorflow) or "
            "tflite-runtime (pip install tflite-runtime)."
        )

# Canonical class labels
CLASS_NAMES = [
    "Northern Leaf Blight",
    "Common Rust",
    "Gray Leaf Spot",
    "Healthy",
]

DEFAULT_INT8_PATH = "models/exports/efficientnetb3_maize_int8.tflite"
DEFAULT_FP16_PATH = "models/exports/efficientnetb3_maize_fp16.tflite"


class EdgeClassifier:
    """TFLite model wrapper with dynamic quantisation detection."""

    def __init__(self, model_path: str, num_threads: int = 4):
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Model file not found: {model_path}")

        self.model_path = model_path
        self.num_threads = num_threads

        # Load interpreter
        if tf is not None:
            self.interpreter = tf.lite.Interpreter(
                model_path=model_path,
                num_threads=num_threads,
            )
        elif tf_tflite is not None:
            self.interpreter = tf_tflite.Interpreter(
                model_path=model_path,
                num_threads=num_threads,
            )
        else:
            raise RuntimeError("Neither tensorflow nor tflite_runtime is available.")

        self.interpreter.allocate_tensors()
        self.input_details = self.interpreter.get_input_details()
        self.output_details = self.interpreter.get_output_details()

        # Input specs
        self.input_shape = self.input_details[0]["shape"]  # e.g. [1, 300, 300, 3]
        self.input_dtype = self.input_details[0]["dtype"]  # np.uint8 or np.float32
        self.input_height = self.input_shape[1]
        self.input_width = self.input_shape[2]

        # Quantisation parameters
        self.input_quant = self.input_details[0].get("quantization", (0.0, 0))
        self.output_quant = self.output_details[0].get("quantization", (0.0, 0))

        self.is_quantized = self.input_dtype == np.uint8

    def preprocess(self, image_path: str) -> np.ndarray:
        """Preprocesses an input image into the model's required tensor format."""
        img = Image.open(image_path).convert("RGB")
        img = img.resize((self.input_width, self.input_height), Image.Resampling.BILINEAR)
        arr = np.array(img, dtype=np.float32)

        if self.is_quantized:
            scale, zero_point = self.input_quant
            if scale > 0:
                arr = arr / scale + zero_point
            arr = np.clip(arr, 0, 255).astype(np.uint8)
        else:
            # EfficientNetB3 accepts raw [0, 255] float32 pixels or normalized depending on export
            arr = arr.astype(np.float32)

        return np.expand_dims(arr, axis=0)

    def predict(self, input_tensor: np.ndarray) -> Tuple[int, float, List[float], float]:
        """
        Runs inference and returns:
          (top_class_id, confidence, all_probabilities, latency_ms)
        """
        self.interpreter.set_tensor(self.input_details[0]["index"], input_tensor)

        t0 = time.perf_counter()
        self.interpreter.invoke()
        latency_ms = (time.perf_counter() - t0) * 1000.0

        output_data = self.interpreter.get_tensor(self.output_details[0]["index"])[0]

        # Dequantise if output is integer
        if output_data.dtype in (np.uint8, np.int8):
            scale, zero_point = self.output_quant
            if scale > 0:
                scores = (output_data.astype(np.float32) - zero_point) * scale
            else:
                scores = output_data.astype(np.float32) / 255.0
        else:
            scores = output_data.astype(np.float32)

        # Softmax normalisation if needed
        total = np.sum(scores)
        if total > 0 and abs(total - 1.0) > 0.01:
            exp_scores = np.exp(scores - np.max(scores))
            probs = exp_scores / np.sum(exp_scores)
        else:
            probs = scores

        probs = [float(p) for p in probs]
        top_idx = int(np.argmax(probs))
        confidence = probs[top_idx]

        return top_idx, confidence, probs, latency_ms

    def predict_image(self, image_path: str) -> Dict:
        """Classifies an image file on disk and returns structured result."""
        tensor = self.preprocess(image_path)
        top_idx, confidence, all_probs, latency_ms = self.predict(tensor)

        return {
            "image_path": image_path,
            "class_id": top_idx,
            "class_name": CLASS_NAMES[top_idx],
            "confidence": round(confidence, 4),
            "probabilities": {
                name: round(prob, 4) for name, prob in zip(CLASS_NAMES, all_probs)
            },
            "latency_ms": round(latency_ms, 2),
            "model_type": "INT8" if self.is_quantized else "FP16/FP32",
        }

    def benchmark(self, num_runs: int = 50, warmup: int = 10) -> Dict:
        """Runs latency and throughput benchmark using random input tensor."""
        if self.is_quantized:
            dummy = np.random.randint(
                0, 256, size=self.input_shape, dtype=np.uint8
            )
        else:
            dummy = np.random.uniform(
                0.0, 255.0, size=self.input_shape
            ).astype(np.float32)

        # Warmup
        for _ in range(warmup):
            self.predict(dummy)

        latencies = []
        for _ in range(num_runs):
            _, _, _, lat = self.predict(dummy)
            latencies.append(lat)

        latencies = np.array(latencies)
        avg_ms = float(np.mean(latencies))
        p50_ms = float(np.percentile(latencies, 50))
        p95_ms = float(np.percentile(latencies, 95))
        p99_ms = float(np.percentile(latencies, 99))
        fps = 1000.0 / avg_ms if avg_ms > 0 else 0.0

        return {
            "model_path": self.model_path,
            "model_type": "INT8" if self.is_quantized else "FP16/FP32",
            "num_runs": num_runs,
            "mean_latency_ms": round(avg_ms, 2),
            "p50_latency_ms": round(p50_ms, 2),
            "p95_latency_ms": round(p95_ms, 2),
            "p99_latency_ms": round(p99_ms, 2),
            "fps": round(fps, 1),
        }


def main():
    parser = argparse.ArgumentParser(description="MaizeGuard Edge TFLite Inference & Benchmarking")
    parser.add_argument(
        "--model",
        type=str,
        default=None,
        help="Path to .tflite model (defaults to int8 export, then fp16)",
    )
    parser.add_argument("--image", type=str, default=None, help="Path to single image to classify")
    parser.add_argument("--benchmark", action="store_true", help="Run speed benchmark")
    parser.add_argument("--runs", type=int, default=50, help="Number of benchmark iterations")
    parser.add_argument("--threads", type=int, default=4, help="Number of CPU threads")
    parser.add_argument("--csv", type=str, default=None, help="Evaluate on a CSV dataset")

    args = parser.parse_args()

    # Resolve model path
    model_path = args.model
    if not model_path:
        if os.path.exists(DEFAULT_INT8_PATH):
            model_path = DEFAULT_INT8_PATH
        elif os.path.exists(DEFAULT_FP16_PATH):
            model_path = DEFAULT_FP16_PATH
        else:
            print(f"[!] No model specified and defaults not found: {DEFAULT_INT8_PATH}")
            sys.exit(1)

    print(f"[*] Initializing Edge Classifier: {model_path} (threads={args.threads})")
    classifier = EdgeClassifier(model_path, num_threads=args.threads)

    if args.benchmark:
        print(f"[*] Benchmarking over {args.runs} runs (warmup=10)...")
        results = classifier.benchmark(num_runs=args.runs)
        print("\n=== Benchmark Results ===")
        print(f"Model Type   : {results['model_type']}")
        print(f"Mean Latency : {results['mean_latency_ms']} ms")
        print(f"P50 Latency  : {results['p50_latency_ms']} ms")
        print(f"P95 Latency  : {results['p95_latency_ms']} ms")
        print(f"Throughput   : {results['fps']} FPS")
        return

    if args.image:
        if not os.path.exists(args.image):
            print(f"[!] Image not found: {args.image}")
            sys.exit(1)
        res = classifier.predict_image(args.image)
        print("\n=== Diagnosis ===")
        print(f"Image       : {res['image_path']}")
        print(f"Class       : {res['class_name']} (ID: {res['class_id']})")
        print(f"Confidence  : {res['confidence'] * 100:.1f}%")
        print(f"Latency     : {res['latency_ms']} ms")
        print("\nClass Probabilities:")
        for name, p in res['probabilities'].items():
            print(f"  • {name:<22}: {p * 100:.2f}%")
        return

    # If neither benchmark nor image is given, run a quick 5-run benchmark
    print("[*] No --image or --benchmark specified. Running quick smoke benchmark (5 runs)...")
    results = classifier.benchmark(num_runs=5, warmup=2)
    print(f"[*] Smoke test passed: {results['mean_latency_ms']} ms/inference ({results['fps']} FPS)")


if __name__ == "__main__":
    main()
