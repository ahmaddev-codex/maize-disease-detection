"""
Phase 5 — UAV Orthomosaic Patch Inference Runner
Tiles a high-resolution orthomosaic image into overlapping patches, runs the
EfficientNetB3 TFLite model on each patch, and writes a georeferenced CSV of
disease predictions.

Usage:
    # From a real orthomosaic (GeoTIFF) + world file:
    python -m src.phase5_uav.patch_runner \
        --image  data/uav/orthomosaic.tif \
        --model  models/exports/efficientnetb3_maize_int8.tflite \
        --output data/uav/patch_predictions.csv

    # Quick demo on a synthetic image:
    python -m src.phase5_uav.patch_runner --demo

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
import math
import os
import time
import warnings
from typing import List, Tuple, Optional

import numpy as np

# ── TFLite runtime ─────────────────────────────────────────────────────────────
try:
    from tflite_runtime.interpreter import Interpreter
except ImportError:
    from tensorflow.lite.python.interpreter import Interpreter

# ── Image I/O — try rasterio (GeoTIFF) → OpenCV → PIL ──────────────────────
rasterio = None
Affine = None
try:
    import rasterio
    from rasterio.transform import Affine
    HAS_RASTERIO = True
except ImportError:
    HAS_RASTERIO = False

cv2 = None
try:
    import cv2
    HAS_CV2 = True
except ImportError:
    HAS_CV2 = False

from PIL import Image

from src.common.labels import SHORT_NAMES as CLASS_NAMES
from src.common.postprocess import postprocess

# ── Constants ──────────────────────────────────────────────────────────────────
PATCH_SIZE    = 300    # pixels — matches model input
DEFAULT_STRIDE = 150   # 50% overlap between patches
DEFAULT_MODEL  = "models/exports/efficientnetb3_maize_int8.tflite"


# ── Geotransform ───────────────────────────────────────────────────────────────

class GeoTransform:
    """Maps pixel (row, col) → (lat, lon) for a georeferenced image.

    There is deliberately no default: an image with no georeference and no
    stated origin produces no coordinates at all. The `dummy()` helper this
    replaces defaulted to a point near Ibadan, so a demo run drew a map of a
    field nobody had flown (T39).
    """

    def __init__(self, origin_lon: float, origin_lat: float,
                 pixel_width: float, pixel_height: float):
        self.origin_lon   = origin_lon
        self.origin_lat   = origin_lat
        self.pixel_width  = pixel_width    # degrees per pixel, positive eastward
        self.pixel_height = pixel_height   # degrees per pixel, negative southward

    @classmethod
    def from_origin_and_gsd(cls, origin_lat: float, origin_lon: float, gsd_m: float,
                            width_px: int = 0, height_px: int = 0) -> "GeoTransform":
        """Builds a transform from a stated top-left corner and ground sample distance.

        The operator supplies these with --origin-lat/--origin-lon/--gsd; they
        are their numbers, not ours.
        """
        deg_per_px_lat = gsd_m / 111_320.0
        # Longitude degrees shrink with latitude.
        cos_lat = max(math.cos(math.radians(origin_lat)), 1e-6)
        deg_per_px_lon = deg_per_px_lat / cos_lat
        return cls(
            origin_lon=origin_lon,
            origin_lat=origin_lat,
            pixel_width=deg_per_px_lon,
            pixel_height=-deg_per_px_lat,
        )

    def pixel_to_latlon(self, row: int, col: int) -> Tuple[float, float]:
        lon = self.origin_lon + col * self.pixel_width
        lat = self.origin_lat + row * self.pixel_height
        return lat, lon


def to_wgs84(crs, x: float, y: float) -> Tuple[float, float]:
    """Transforms a projected coordinate to (lat, lon) in EPSG:4326.

    Orthomosaics are usually in a UTM zone, and the old code read the affine
    transform as if its units were already degrees (T39).
    """
    from rasterio.warp import transform as warp_transform

    lons, lats = warp_transform(crs, "EPSG:4326", [x], [y])
    return float(lats[0]), float(lons[0])


def patch_coordinates(geo: Optional[GeoTransform], row: int, col: int):
    """(lat, lon) for a patch centre, or (None, None) with no georeference."""
    if geo is None:
        return None, None
    return geo.pixel_to_latlon(row, col)


def result_row(patch_row: int, patch_col: int, lat, lon, class_id: int,
               confidence: float, latency_ms: float, pixel_row: int = 0,
               pixel_col: int = 0) -> dict:
    """One CSV row. Coordinates are omitted entirely when unknown."""
    row = {
        "patch_row":  patch_row,
        "patch_col":  patch_col,
        "pixel_row":  pixel_row,
        "pixel_col":  pixel_col,
        "class_id":   class_id,
        "class_name": CLASS_NAMES[class_id],
        "confidence": round(confidence, 4),
        "latency_ms": round(latency_ms, 1),
    }
    if lat is not None and lon is not None:
        row["lat"] = round(lat, 7)
        row["lon"] = round(lon, 7)
    return row


# ── Vegetation filter ─────────────────────────────────────────────────────────

def excess_green(patch: np.ndarray) -> np.ndarray:
    """Excess Green index (2g − r − b) on chromatic coordinates.

    0 for any grey, positive for vegetation, negative for sky, soil and roads.
    """
    rgb = patch.astype(np.float32)
    total = rgb.sum(axis=2, keepdims=True)
    total[total == 0] = 1.0
    chroma = rgb / total
    return 2 * chroma[:, :, 1] - chroma[:, :, 0] - chroma[:, :, 2]


def is_vegetation(patch: np.ndarray, min_fraction: float = 0.25,
                  threshold: float = 0.05) -> bool:
    """True when enough of the patch is plant tissue to be worth classifying.

    The rule this replaces skipped any patch whose mean red beat 1.5× its mean
    green — which is what a rust-covered canopy looks like, so the survey threw
    away the disease it was flown to find (T39).
    """
    if patch.size == 0:
        return False
    return float((excess_green(patch) > threshold).mean()) >= min_fraction


# ── Image loading ─────────────────────────────────────────────────────────────

def load_image(path: str, origin_lat: Optional[float] = None,
               origin_lon: Optional[float] = None,
               gsd_m: Optional[float] = None) -> Tuple[np.ndarray, Optional[GeoTransform], Optional[object]]:
    """Loads an orthomosaic.

    Returns the pixels, a GeoTransform when one can be known, and the file's
    CRS when it has one. An image with no georeference and no stated origin
    gets no transform at all — the runner then reports pixel positions only,
    instead of coordinates nobody measured (T39).
    """
    if HAS_RASTERIO and path.endswith((".tif", ".tiff")):
        with rasterio.open(path) as src:
            arr = src.read([1, 2, 3])          # (3, H, W)
            arr = np.moveaxis(arr, 0, -1)      # → (H, W, 3)
            if arr.dtype != np.uint8:
                arr = (arr / arr.max() * 255).astype(np.uint8)
            return arr, None, (src.transform, src.crs)

    if HAS_CV2:
        bgr = cv2.imread(path)
        if bgr is None:
            raise FileNotFoundError(f"cv2.imread failed: {path}")
        arr = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
    else:
        arr = np.array(Image.open(path).convert("RGB"))

    h, w = arr.shape[:2]
    if origin_lat is not None and origin_lon is not None and gsd_m:
        return arr, GeoTransform.from_origin_and_gsd(origin_lat, origin_lon, gsd_m, w, h), None

    warnings.warn(
        f"{path} has no georeference and no --origin-lat/--origin-lon/--gsd was given; "
        "patches will be reported in pixel coordinates only.",
        stacklevel=2,
    )
    return arr, None, None


def make_demo_image(width: int = 1500, height: int = 1000) -> Tuple[np.ndarray, None]:
    """Synthetic 'aerial' image: green base with random disease patches.

    It carries no georeference: a demo used to be placed near Ibadan, which
    made an invented field look like a surveyed one (T39).
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

    return base, None


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

    # One shared rule for every phase and the app: dequantise with the
    # tensor's own parameters, renormalise, never softmax (T33/T39).
    probs = postprocess(raw, out_detail["quantization"])
    class_id = int(np.argmax(probs))
    return class_id, float(probs[class_id])


# ── Main patch loop ───────────────────────────────────────────────────────────

def run_orthomosaic(
    image: np.ndarray,
    geo: Optional[GeoTransform],
    interp: Interpreter,
    patch_size: int   = PATCH_SIZE,
    stride: int       = DEFAULT_STRIDE,
    min_vegetation_fraction: float = 0.25,
    georef=None,
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

            # Skip anything that is not plant tissue (road, sky, bare soil).
            if not is_vegetation(patch, min_fraction=min_vegetation_fraction):
                continue

            centre_row = r0 + patch_size // 2
            centre_col = c0 + patch_size // 2
            if georef is not None:
                # A GeoTIFF is usually in a UTM zone: project the patch centre
                # into WGS 84 rather than reading metres as degrees (T39).
                affine, crs = georef
                x, y = affine * (centre_col, centre_row)
                lat, lon = to_wgs84(crs, x, y)
            else:
                lat, lon = patch_coordinates(geo, centre_row, centre_col)

            t0 = time.perf_counter()
            class_id, confidence = run_patch(interp, patch)
            latency_ms = (time.perf_counter() - t0) * 1000

            results.append(result_row(
                patch_row=ri, patch_col=ci, lat=lat, lon=lon,
                class_id=class_id, confidence=confidence,
                latency_ms=latency_ms, pixel_row=r0, pixel_col=c0,
            ))
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
    p.add_argument("--origin-lat", type=float, default=None,
                   help="Latitude of the image's top-left corner (non-georeferenced images)")
    p.add_argument("--origin-lon", type=float, default=None,
                   help="Longitude of the image's top-left corner (non-georeferenced images)")
    p.add_argument("--gsd", type=float, default=None,
                   help="Ground sample distance in metres per pixel (non-georeferenced images)")
    return p.parse_args()


def main():
    args = _parse_args()

    georef = None
    if args.demo:
        print("Generating synthetic orthomosaic demo (1500×1000 px, no coordinates)...")
        image, geo = make_demo_image()
    elif args.image:
        print(f"Loading orthomosaic: {args.image}")
        image, geo, georef = load_image(
            args.image,
            origin_lat=args.origin_lat,
            origin_lon=args.origin_lon,
            gsd_m=args.gsd,
        )
    else:
        print("No image specified. Use --image <path> or --demo.")
        return

    print(f"Loading model: {args.model}")
    interp = load_interpreter(args.model)

    results = run_orthomosaic(image, geo, interp, args.patch_size, args.stride,
                              georef=georef)
    print_stats(results)
    write_csv(results, args.output)


if __name__ == "__main__":
    main()
