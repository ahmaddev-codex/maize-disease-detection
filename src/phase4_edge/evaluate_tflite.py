"""
Phase 4 — TFLite Evaluation → models/exports/metrics.json
Evaluates exported .tflite models on the stratified test split and records the
results in one machine-readable file. metrics.json is the single source of truth
for model decisions (ADR-001) and for every number quoted in the research papers.

Run:
    python -m src.phase4_edge.evaluate_tflite \
        --model models/exports/efficientnetb3_maize_fp16.tflite \
        --model models/exports/efficientnetb3_maize_int8.tflite

Preprocessing modes:
    python — bilinear resize, matching tf.image.resize used during training
    app    — mirrors mobile/lib/services/classifier_preprocess.dart (also bilinear
             since T09; it used nearest-neighbour before, costing ~1.8 points)

Both modes dequantize integer outputs with the tensor's quantization params and
renormalize scores by their sum — the same normalization the mobile app applies.

metrics.json schema:
    {
      "models": {
        "<model file name>": {
          "path": str, "sha256": str,
          "input":  {"dtype": str, "quantization": [scale, zero_point]},
          "output": {"dtype": str, "quantization": [scale, zero_point]},
          "<mode>": {                               # "python" | "app"
            "n": int, "accuracy": float,
            "per_class": {"<class>": {"precision", "recall", "f1", "support"}},
            "confusion_matrix": [[int]],            # rows = true, cols = predicted
            "csv": str, "split": "test",
            "git_sha": str | null, "git_dirty": bool | null,
            "evaluated_at": ISO-8601 UTC timestamp
          }
        }
      },
      "dataset": {
        "csv": str,
        "split_sizes": {"train": int, "val": int, "test": int},
        "duplicates": {"duplicate_files", "duplicate_groups",
                       "conflicting_label_groups", "groups_spanning_train_and_test",
                       "conflicting_groups": [[image_path, ...]]}
      }
    }
"""

import argparse
import datetime
import hashlib
import json
import os
import subprocess
import sys
from typing import Dict, List, Optional, Sequence, Tuple

import numpy as np
import pandas as pd
from PIL import Image
from sklearn.metrics import confusion_matrix, precision_recall_fscore_support

from src.common.labels import SHORT_NAMES as CLASS_NAMES
from src.common.postprocess import postprocess
from src.phase1_cnn.data_pipeline import load_labels_csv, split_dataframe

DEFAULT_CSV    = "data/annotations/labels.csv"
DEFAULT_OUTPUT = "models/exports/metrics.json"
DEFAULT_MODES  = ["python", "app"]

RESAMPLING = {
    "python": Image.Resampling.BILINEAR,
    "app":    Image.Resampling.BILINEAR,
}


# ── Preprocessing / postprocessing ────────────────────────────────────────────

def preprocess(image_path: str, size: Tuple[int, int], mode: str) -> np.ndarray:
    """Load an image as a (1, H, W, 3) uint8 batch resized the way `mode` does."""
    if mode not in RESAMPLING:
        raise ValueError(f"Unknown preprocessing mode '{mode}' (expected one of {sorted(RESAMPLING)})")
    img = Image.open(image_path).convert("RGB").resize(size, RESAMPLING[mode])
    return np.asarray(img, dtype=np.uint8)[np.newaxis]


def dequantize_and_normalize(raw: np.ndarray, quantization: Tuple[float, int]) -> np.ndarray:
    """Dequantize integer model output, then renormalize so scores sum to 1.

    Kept as a name the rest of this module already uses; the rule itself lives
    in src/common/postprocess.py, shared with inference and the app (T33).
    """
    return postprocess(raw, quantization)


def _to_input_tensor(batch: np.ndarray, input_detail: dict) -> np.ndarray:
    dtype = input_detail["dtype"]
    if not np.issubdtype(dtype, np.integer):
        return batch.astype(dtype)
    scale, zero_point = input_detail["quantization"]
    if scale > 0 and (scale, zero_point) != (1.0, 0):
        info = np.iinfo(dtype)
        batch = np.clip(np.round(batch / scale + zero_point), info.min, info.max)
    return batch.astype(dtype)


# ── Evaluation ─────────────────────────────────────────────────────────────────

def evaluate_model(model_path: str, df: pd.DataFrame, mode: str, num_threads: int = 4) -> Dict:
    """Run every image in df through the model and return accuracy + per-class metrics."""
    import tensorflow as tf

    interpreter = tf.lite.Interpreter(model_path=model_path, num_threads=num_threads)
    interpreter.allocate_tensors()
    input_detail  = interpreter.get_input_details()[0]
    output_detail = interpreter.get_output_details()[0]
    size = (int(input_detail["shape"][2]), int(input_detail["shape"][1]))

    y_true: List[int] = []
    y_pred: List[int] = []
    for image_path, label in zip(df["image_path"], df["label"]):
        batch = preprocess(image_path, size, mode)
        interpreter.set_tensor(input_detail["index"], _to_input_tensor(batch, input_detail))
        interpreter.invoke()
        raw = interpreter.get_tensor(output_detail["index"])[0]
        probs = dequantize_and_normalize(raw, output_detail["quantization"])
        y_true.append(int(label))
        y_pred.append(int(np.argmax(probs)))

    labels = list(range(len(CLASS_NAMES)))
    precision, recall, f1, support = precision_recall_fscore_support(
        y_true, y_pred, labels=labels, zero_division=0
    )
    return {
        "n": len(y_true),
        "accuracy": round(float(np.mean(np.array(y_true) == np.array(y_pred))), 4),
        "per_class": {
            name: {
                "precision": round(float(precision[i]), 4),
                "recall":    round(float(recall[i]), 4),
                "f1":        round(float(f1[i]), 4),
                "support":   int(support[i]),
            }
            for i, name in enumerate(CLASS_NAMES)
        },
        "confusion_matrix": confusion_matrix(y_true, y_pred, labels=labels).tolist(),
    }


# ── Dataset checks ─────────────────────────────────────────────────────────────

def _file_md5(path: str) -> str:
    with open(path, "rb") as f:
        return hashlib.md5(f.read()).hexdigest()


def duplicate_report(df: pd.DataFrame, split_of: Optional[Dict[str, str]] = None) -> Dict:
    """Byte-identical duplicate images, including groups whose copies carry different labels."""
    hashed = df.assign(md5=df["image_path"].map(_file_md5))
    dup = hashed[hashed["md5"].duplicated(keep=False)]
    labels_per_group = dup.groupby("md5")["label"].nunique()
    conflicting = labels_per_group[labels_per_group > 1].index

    spanning = 0
    if split_of is not None:
        for _, group in dup.groupby("md5"):
            splits = {split_of.get(p) for p in group["image_path"]}
            spanning += int({"train", "test"} <= splits)

    return {
        "duplicate_files": int(len(dup)),
        "duplicate_groups": int(dup["md5"].nunique()),
        "conflicting_label_groups": int(len(conflicting)),
        "groups_spanning_train_and_test": spanning,
        "conflicting_groups": [
            sorted(dup.loc[dup["md5"] == h, "image_path"].tolist()) for h in conflicting
        ],
    }


# ── metrics.json ───────────────────────────────────────────────────────────────

def merge_metrics(
    output_path: str,
    model_name: str,
    mode: str,
    result: Dict,
    extra: Optional[Dict] = None,
    dataset: Optional[Dict] = None,
) -> None:
    """Write one model × mode result into metrics.json without touching other entries."""
    data: Dict = {}
    if os.path.exists(output_path):
        with open(output_path) as f:
            data = json.load(f)

    entry = data.setdefault("models", {}).setdefault(model_name, {})
    entry.update(extra or {})
    entry[mode] = result
    if dataset is not None:
        data["dataset"] = dataset

    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def _sha256(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _git_state() -> Tuple[Optional[str], Optional[bool]]:
    try:
        sha = subprocess.run(["git", "rev-parse", "HEAD"],
                             capture_output=True, text=True, check=True).stdout.strip()
        dirty = subprocess.run(["git", "status", "--porcelain"],
                               capture_output=True, text=True, check=True).stdout.strip()
        return sha, bool(dirty)
    except (OSError, subprocess.CalledProcessError):
        return None, None


def _tensor_info(detail: dict) -> Dict:
    scale, zero_point = detail["quantization"]
    return {"dtype": np.dtype(detail["dtype"]).name, "quantization": [float(scale), int(zero_point)]}


# ── CLI ───────────────────────────────────────────────────────────────────────

def _fail(message: str) -> None:
    print(message, file=sys.stderr)
    sys.exit(1)


def parse_args(argv: Optional[Sequence[str]] = None):
    p = argparse.ArgumentParser(description="Evaluate TFLite models and write metrics.json")
    p.add_argument("--model", action="append", required=True,
                   help="Path to a .tflite model (repeat for several models)")
    p.add_argument("--csv",    default=DEFAULT_CSV, help="labels.csv used for the stratified split")
    p.add_argument("--output", default=DEFAULT_OUTPUT, help="metrics.json to create or update")
    p.add_argument("--mode",   nargs="+", choices=sorted(RESAMPLING), default=DEFAULT_MODES)
    p.add_argument("--threads", type=int, default=4)
    return p.parse_args(argv)


def main(argv: Optional[Sequence[str]] = None) -> None:
    args = parse_args(argv)

    for model_path in args.model:
        if not os.path.exists(model_path):
            _fail(f"Model not found: {model_path}")
    if not os.path.exists(args.csv):
        _fail(f"Labels CSV not found: {args.csv}")

    import tensorflow as tf

    df = load_labels_csv(args.csv)
    train_df, val_df, test_df = split_dataframe(df)
    split_of = {p: "train" for p in train_df["image_path"]}
    split_of.update({p: "val" for p in val_df["image_path"]})
    split_of.update({p: "test" for p in test_df["image_path"]})
    dataset = {
        "csv": args.csv,
        "split_sizes": {"train": len(train_df), "val": len(val_df), "test": len(test_df)},
        "duplicates": duplicate_report(df, split_of),
    }
    git_sha, git_dirty = _git_state()

    for model_path in args.model:
        interpreter = tf.lite.Interpreter(model_path=model_path)
        extra = {
            "path": model_path,
            "sha256": _sha256(model_path),
            "input": _tensor_info(interpreter.get_input_details()[0]),
            "output": _tensor_info(interpreter.get_output_details()[0]),
        }
        for mode in args.mode:
            result = evaluate_model(model_path, test_df, mode, num_threads=args.threads)
            result.update({
                "csv": args.csv,
                "split": "test",
                "git_sha": git_sha,
                "git_dirty": git_dirty,
                "evaluated_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
            })
            merge_metrics(args.output, os.path.basename(model_path), mode, result,
                          extra=extra, dataset=dataset)
            f1 = ", ".join(f"{c} {v['f1']:.3f}" for c, v in result["per_class"].items())
            print(f"{os.path.basename(model_path)} [{mode}] acc={result['accuracy'] * 100:.2f}% "
                  f"n={result['n']} | F1: {f1}")

    print(f"Metrics written → {args.output}")


if __name__ == "__main__":
    main()
