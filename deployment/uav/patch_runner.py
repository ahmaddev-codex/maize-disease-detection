"""
Phase 5 — UAV Orthomosaic Patch Inference Runner
Tiles a high-resolution orthomosaic image into overlapping patches, runs the
EfficientNetB3 TFLite model on each patch, and writes a georeferenced CSV of
disease predictions.

Usage:
    # From a real orthomosaic (GeoTIFF) + world file:
    python -m deployment.uav.patch_runner \
        --image  data/uav/orthomosaic.tif \
        --model  models/exports/efficientnetb3_maize_int8.tflite \
        --output data/uav/patch_predictions.csv

    # Quick demo on a synthetic image:
    python -m deployment.uav.patch_runner --demo

Pipeline:
    1. Load orthomosaic (GeoTIFF via rasterio if available, else PIL/OpenCV)
    2. Extract geotransform (origin + pixel size) for lat/lon computation
    3. Tile image into 300×300 patches with configurable stride
    4. Run TFLite INT8 inference on each patch
    5. Write CSV: patch_row, patch_col, lat, lon, class, confidence, latency_ms
"""
from __future__ import annotations

import argparse
import csv
import os
import time
from typing import List, Tuple, Optional

import numpy as np

# ── TFLite runtime ─────────────────────────────────────────────────────────────
try:
    from tflite_runtime.interpreter import Interpreter
except ImportError:
    from tensorflow.lite.python.interpreter import Interpreter

# ── Image I/O — try rasterio (GeoTIFF) → OpenCV → PIL ──────────────────────
try:
    import rasterio
    from rasterio.transform import Affine
    HAS_RASTERIO = True
except ImportError:
    HAS_RASTERIO = False

try:
    import cv2
    HAS_CV2 = True
except ImportError:
    HAS_CV2 = False

from PIL import Image

# ── Constants ──────────────────────────────────────────────────────────────────
CLASS_NAMES   = ["NCLB", "Rust", "GLS", "Healthy"]
PATCH_SIZE    = 300    # pixels — matches model input
DEFAULT_STRIDE = 150   # 50% overlap between patches
DEFAULT_MODEL  = "models/exports/efficientnetb3_maize_int8.tflite"


# ── Geotransform ───────────────────────────────────────────────────────────────

class GeoTransform:
    """Maps pixel (row, col) → (lat, lon) for a georeferenced image."""
    def __init__(self, origin_lon: float, origin_lat: float,
                 pixel_width: float, pixel_height: float):
        self.origin_lon   = origin_lon
        self.origin_lat   = origin_lat
        self.pixel_width  = pixel_width    # degrees per pixel, positive eastward
        self.pixel_height = pixel_height   # degrees per pixel, negative southward

    @classmethod
    def dummy(cls, image_width_px: int, image_height_px: int,
              centre_lat: float = 7.3775, centre_lon: float = 3.9470,
              gsd_m: float = 0.05) -> "GeoTransform":
        """Create a plausible geotransform for a demo image."""
        deg_per_px = gsd_m / 111_320
        return cls(
            origin_lon   = centre_lon - (image_width_px  / 2) * deg_per_px,
            origin_lat   = centre_lat + (image_height_px / 2) * deg_per_px,
            pixel_width  =  deg_per_px,
            pixel_height = -deg_per_px,
        )

    def pixel_to_latlon(self, row: int, col: int) -> Tuple[float, float]:
        lon = self.origin_lon + col * self.pixel_width
        lat = self.origin_lat + row * self.pixel_height
        return lat, lon


# ── Image loading ─────────────────────────────────────────────────────────────

def load_image(path: str) -> Tuple[np.ndarray, GeoTransform]:
    """
    Load an orthomosaic and return (H, W, 3) uint8 array + GeoTransform.
    Tries rasterio → OpenCV → PIL in order.
    """
    if HAS_RASTERIO and path.endswith((".tif", ".tiff")):
        with rasterio.open(path) as src:
            arr = src.read([1, 2, 3])          # (3, H, W)
            arr = np.moveaxis(arr, 0, -1)      # → (H, W, 3)
            if arr.dtype != np.uint8:
                arr = (arr / arr.max() * 255).astype(np.uint8)
            t: Affine = src.transform
            gt = GeoTransform(t.c, t.f, t.a, t.e)
        return arr, gt

    if HAS_CV2:
        bgr = cv2.imread(path)
        if bgr is None:
            raise FileNotFoundError(f"cv2.imread failed: {path}")
        arr = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
    else:
        arr = np.array(Image.open(path).convert("RGB"))

    h, w = arr.shape[:2]
    gt = GeoTransform.dummy(w, h)
    return arr, gt


def make_demo_image(width: int = 1500, height: int = 1000) -> Tuple[np.ndarray, GeoTransform]:
    """
    Synthetic 'aerial' image: green base with random disease patches for testing.
    """
    rng  = np.random.default_rng(42)
    base = np.zeros((height, width, 3), dtype=np.uint8)

    # Green field background
    base[:, :, 0] = rng.integers(40,  80, (height, width))
    base[:, :, 1] = rng.integers(90, 160, (height, width))
    base[:, :, 2] = rng.integers(20,  50, (height, width))

    # Random disease patches (brownish / rusty colours)
    for _ in range(12):
        r = rng.integers(0, height - 100)
        c = rng.integers(0, width  - 100)
        ph = rng.integers(50, 150)
        pw = rng.integers(50, 150)
        colour_type = rng.integers(0, 3)
        if colour_type == 0:     # NCLB — greyish tan
            base[r:r+ph, c:c+pw] = [160, 140, 100]
        elif colour_type == 1:   # Rust — brick red
            base[r:r+ph, c:c+pw] = [180,  80,  40]
        else:                    # GLS — grey
            base[r:r+ph, c:c+pw] = [130, 130, 120]

    gt = GeoTransform.dummy(width, height)
    return base, gt


# ── TFLite inference ──────────────────────────────────────────────────────────

def load_interpreter(model_path: str) -> Interpreter:
    if not os.path.exists(model_path):
        raise FileNotFoundError(
            f"Model not found: {model_path}\n"
            "Run: python -m src.phase4_edge.convert_tflite"
        )
    interp = Interpreter(model_path=model_path, num_threads=4)
    interp.allocate_tensors()
    return interp


def run_patch(interp: Interpreter, patch_rgb: np.ndarray) -> Tuple[int, float]:
    """
    Classify a single 300×300 RGB patch.
    Returns (class_id, confidence).
    """
    inp_detail  = interp.get_input_details()[0]
    out_detail  = interp.get_output_details()[0]
    dtype       = inp_detail["dtype"]

    patch = patch_rgb.astype(np.float32) if dtype == np.float32 else patch_rgb.astype(np.uint8)
    interp.set_tensor(inp_detail["index"], patch[np.newaxis])
    interp.invoke()
    raw = interp.get_tensor(out_detail["index"])[0]  # shape (4,)

    # Dequantize uint8 output if quantized
    if out_detail["dtype"] == np.uint8:
        scale, zero_point = out_detail["quantization"]
        raw = (raw.astype(np.float32) - zero_point) * scale

    # Softmax if logits (values outside [0,1])
    if raw.max() > 1.0 or raw.min() < 0.0:
        e = np.exp(raw - raw.max())
        raw = e / e.sum()

    class_id = int(np.argmax(raw))
    return class_id, float(raw[class_id])


# ── Main patch loop ───────────────────────────────────────────────────────────

def run_orthomosaic(
    image: np.ndarray,
    geo: GeoTransform,
    interp: Interpreter,
    patch_size: int   = PATCH_SIZE,
    stride: int       = DEFAULT_STRIDE,
    min_green_ratio: float = 0.05,  # skip patches with < 5% green (sky / road)
) -> List[dict]:
    """
    Slide a window over the orthomosaic; return list of patch result dicts.
    """
    h, w = image.shape[:2]
    results = []
    n_rows = max(1, (h - patch_size) // stride + 1)
    n_cols = max(1, (w - patch_size) // stride + 1)
    total  = n_rows * n_cols

    print(f"Image: {w}×{h} px  |  Patches: {n_rows}×{n_cols} = {total}")
    print(f"Patch size: {patch_size}  |  Stride: {stride}")

    count = 0
    for ri in range(n_rows):
        for ci in range(n_cols):
            r0 = ri * stride
            c0 = ci * stride
            patch = image[r0:r0+patch_size, c0:c0+patch_size]
            if patch.shape[:2] != (patch_size, patch_size):
                continue

            # Skip non-vegetation patches (very low green channel ratio)
            green_mean = patch[:, :, 1].mean()
            red_mean   = patch[:, :, 0].mean()
            if green_mean < min_green_ratio * 255 or red_mean > green_mean * 1.5:
                continue

            centre_row = r0 + patch_size // 2
            centre_col = c0 + patch_size // 2
            lat, lon   = geo.pixel_to_latlon(centre_row, centre_col)

            t0 = time.perf_counter()
            class_id, confidence = run_patch(interp, patch)
            latency_ms = (time.perf_counter() - t0) * 1000

            results.append({
                "patch_row":    ri,
                "patch_col":    ci,
                "pixel_row":    r0,
                "pixel_col":    c0,
                "lat":          round(lat, 7),
                "lon":          round(lon, 7),
                "class_id":     class_id,
                "class_name":   CLASS_NAMES[class_id],
                "confidence":   round(confidence, 4),
                "latency_ms":   round(latency_ms, 1),
            })
            count += 1
            if count % 50 == 0:
                pct = count / total * 100
                print(f"  {count}/{total} patches ({pct:.0f}%)  last: {CLASS_NAMES[class_id]} {confidence:.0%}")

    return results


def write_csv(results: List[dict], path: str) -> None:
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    if not results:
        print("No results to write.")
        return
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=results[0].keys())
        w.writeheader()
        w.writerows(results)
    print(f"\nPredictions written: {path}  ({len(results)} patches)")


def print_stats(results: List[dict]) -> None:
    from collections import Counter
    counts = Counter(r["class_name"] for r in results)
    total  = len(results)
    print("\n──── Patch classification summary ───────────────────")
    for cls in CLASS_NAMES:
        n   = counts.get(cls, 0)
        pct = n / total * 100 if total else 0
        bar = "█" * int(pct / 2)
        print(f"  {cls:<34} {n:4d}  ({pct:5.1f}%)  {bar}")
    print("─────────────────────────────────────────────────────")
    avg_ms = sum(r["latency_ms"] for r in results) / total if total else 0
    print(f"  Total patches: {total}  |  Avg latency: {avg_ms:.1f} ms/patch\n")


# ── CLI ───────────────────────────────────────────────────────────────────────

def _parse_args():
    p = argparse.ArgumentParser(description="Maize UAV Patch Inference Runner")
    p.add_argument("--image",  default=None, help="Path to orthomosaic (GeoTIFF or JPEG/PNG)")
    p.add_argument("--model",  default=DEFAULT_MODEL)
    p.add_argument("--output", default="data/uav/patch_predictions.csv")
    p.add_argument("--patch-size", type=int, default=PATCH_SIZE)
    p.add_argument("--stride",     type=int, default=DEFAULT_STRIDE)
    p.add_argument("--demo",    action="store_true",
                   help="Run on a synthetic demo image (no real data needed)")
    return p.parse_args()


def main():
    args = _parse_args()

    if args.demo:
        print("Generating synthetic orthomosaic demo (1500×1000 px)...")
        image, geo = make_demo_image()
    elif args.image:
        print(f"Loading orthomosaic: {args.image}")
        image, geo = load_image(args.image)
    else:
        print("No image specified. Use --image <path> or --demo.")
        return

    print(f"Loading model: {args.model}")
    interp = load_interpreter(args.model)

    results = run_orthomosaic(image, geo, interp, args.patch_size, args.stride)
    print_stats(results)
    write_csv(results, args.output)


if __name__ == "__main__":
    main()
