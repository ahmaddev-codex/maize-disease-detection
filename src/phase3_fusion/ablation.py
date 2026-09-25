"""Does the metadata branch earn its place? (T31, ADR-002)

The variety, batch number and planting date in `labels_with_metadata.csv` are
invented — `build_labels.py` marks every row `synthetic=1`. A fusion model can
still score higher than the CNN alone simply because it has more parameters, so
"fusion is better" means nothing on its own.

Three arms, one split:

  cnn_only         the metadata vector is all zeros — the branch carries nothing
  fusion           the real metadata vector for each image
  fusion_shuffled  the same vectors, permuted across images: the marginal
                   distribution is identical, the pairing is destroyed

Fusion must beat *shuffled* by more than the noise band to be evidence that the
metadata says something. Beating only `cnn_only` shows the extra parameters
helped, not the data.

Run it (long, needs the dataset and a trained CNN):

    python -m src.phase3_fusion.ablation --epochs 10
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
from typing import Callable, Dict, Optional

import numpy as np

ARMS = ("cnn_only", "fusion", "fusion_shuffled")

# Run-to-run variation of this pipeline on this dataset. A difference smaller
# than this is not a result.
DEFAULT_NOISE_BAND = 0.01

DEFAULT_METRICS = "models/exports/metrics.json"


def zero_metadata(vectors: np.ndarray) -> np.ndarray:
    """The metadata branch, carrying nothing."""
    return np.zeros_like(np.asarray(vectors, dtype=np.float32))


def shuffle_metadata(vectors: np.ndarray, seed: int = 0) -> np.ndarray:
    """The same metadata rows, attached to the wrong images.

    Keeps every marginal distribution intact and destroys only the pairing, so
    any gain that survives this is a gain from the pairing.
    """
    values = np.asarray(vectors, dtype=np.float32)
    if len(values) < 2:
        return values.copy()
    rng = np.random.default_rng(seed)
    order = rng.permutation(len(values))
    # With a small number of rows a permutation can come back as the identity;
    # roll it so the pairing is genuinely broken.
    if np.array_equal(order, np.arange(len(values))):
        order = np.roll(order, 1)
    return values[order]


def interpret(accuracies: Dict[str, float], noise_band: float = DEFAULT_NOISE_BAND) -> Dict:
    """Turns three numbers into a statement that can be quoted."""
    missing = [arm for arm in ARMS if arm not in accuracies]
    if missing:
        raise ValueError(f"ablation is incomplete, missing: {', '.join(missing)}")

    over_cnn = accuracies["fusion"] - accuracies["cnn_only"]
    over_shuffled = accuracies["fusion"] - accuracies["fusion_shuffled"]
    beats_cnn = over_cnn > noise_band
    beats_shuffled = over_shuffled > noise_band

    if beats_shuffled:
        summary = (
            f"Fusion beats shuffled metadata by {over_shuffled:+.3f} "
            f"(> {noise_band:.3f}), so the pairing carries signal."
        )
    elif beats_cnn:
        summary = (
            f"Fusion beats the CNN by {over_cnn:+.3f} but only matches shuffled "
            f"metadata ({over_shuffled:+.3f}): the gain comes from the extra "
            "parameters, not from what the metadata says."
        )
    else:
        summary = (
            f"All three arms are within noise (fusion vs CNN {over_cnn:+.3f}, "
            f"vs shuffled {over_shuffled:+.3f}, band {noise_band:.3f})."
        )

    return {
        "fusion_minus_cnn_only": round(over_cnn, 4),
        "fusion_minus_shuffled": round(over_shuffled, 4),
        "noise_band": noise_band,
        "fusion_beats_cnn_only": bool(beats_cnn),
        "fusion_beats_shuffled": bool(beats_shuffled),
        "summary": summary,
    }


def run_ablation(
    train_metadata: np.ndarray,
    val_metadata: np.ndarray,
    test_metadata: np.ndarray,
    train_and_evaluate: Callable[..., Dict],
    metadata_is_synthetic: bool,
    seed: int = 0,
    noise_band: float = DEFAULT_NOISE_BAND,
    **kwargs,
) -> Dict:
    """Runs all three arms on one split and interprets the result.

    `train_and_evaluate(arm, train_meta, val_meta, test_meta, **kwargs)` returns
    at least {"accuracy": float}. It is injected so the comparison logic can be
    tested without training anything.
    """
    variants = {
        "cnn_only": (zero_metadata(train_metadata), zero_metadata(val_metadata), zero_metadata(test_metadata)),
        "fusion": (train_metadata, val_metadata, test_metadata),
        "fusion_shuffled": (
            shuffle_metadata(train_metadata, seed),
            shuffle_metadata(val_metadata, seed + 1),
            shuffle_metadata(test_metadata, seed + 2),
        ),
    }

    arms: Dict[str, Dict] = {}
    for arm in ARMS:
        train_meta, val_meta, test_meta = variants[arm]
        print(f"\n── arm: {arm} ───────────────────────────────")
        arms[arm] = train_and_evaluate(arm, train_meta, val_meta, test_meta, **kwargs)

    verdict = interpret({arm: arms[arm]["accuracy"] for arm in ARMS}, noise_band)
    return {
        "arms": arms,
        "metadata_is_synthetic": bool(metadata_is_synthetic),
        "seed": seed,
        "verdict": verdict,
    }


def write_ablation(results: Dict, metrics_path: str = DEFAULT_METRICS) -> None:
    """Records the ablation beside the model metrics, without touching them."""
    metrics = {}
    if os.path.exists(metrics_path):
        with open(metrics_path) as handle:
            metrics = json.load(handle)

    metrics["fusion_ablation"] = {
        **results,
        "recorded_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    }
    os.makedirs(os.path.dirname(metrics_path) or ".", exist_ok=True)
    with open(metrics_path, "w") as handle:
        json.dump(metrics, handle, indent=2)
        handle.write("\n")
    print(f"\nAblation written → {metrics_path}")
    print(results["verdict"]["summary"])


# ── Real run ──────────────────────────────────────────────────────────────────

def _train_and_evaluate(arm, train_meta, val_meta, test_meta, *, train_df, val_df,
                        test_df, epochs, cnn_weights, batch_size, lr):
    """Trains one arm and returns its test accuracy (imports TF lazily)."""
    import tensorflow as tf

    from src.phase3_fusion.fusion_model import build_fusion_model, compile_fusion_model
    from src.phase3_fusion.train_fusion import build_fusion_dataset

    tf.keras.utils.set_random_seed(42)

    train_ds = build_fusion_dataset(train_df, train_meta, augment=True, batch_size=batch_size)
    val_ds = build_fusion_dataset(val_df, val_meta, shuffle=False, batch_size=batch_size)
    test_ds = build_fusion_dataset(test_df, test_meta, shuffle=False, batch_size=batch_size)

    model = build_fusion_model(cnn_weights_path=cnn_weights, freeze_cnn=True)
    compile_fusion_model(model, learning_rate=lr)
    model.fit(train_ds, validation_data=val_ds, epochs=epochs, verbose=2)

    loss, accuracy = model.evaluate(test_ds, verbose=0)[:2]
    return {"accuracy": float(accuracy), "loss": float(loss), "n": int(len(test_df))}


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--metadata-csv", default="data/annotations/labels_with_metadata.csv")
    parser.add_argument("--cnn-weights", default="models/checkpoints/phase1_stage2_best.keras")
    parser.add_argument("--epochs", type=int, default=10)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--lr", type=float, default=5e-4)
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--noise-band", type=float, default=DEFAULT_NOISE_BAND)
    parser.add_argument("--limit", type=int, default=None,
                        help="Use only the first N rows (a quick smoke run)")
    parser.add_argument("--output", default=DEFAULT_METRICS)
    args = parser.parse_args(argv)

    import pandas as pd

    from src.phase1_cnn.data_pipeline import split_dataframe
    from src.phase3_fusion.train_fusion import compute_or_load_metadata

    frame = pd.read_csv(args.metadata_csv)
    if args.limit:
        frame = frame.head(args.limit)

    # Every row is flagged when the values were invented (build_labels.py).
    synthetic = bool(frame.get("synthetic", pd.Series([0] * len(frame))).astype(int).any())
    if synthetic:
        print("NOTE: this metadata is synthetic — see ADR-002. Read the result "
              "as a check on the architecture, not as evidence about real farm data.")

    metadata = compute_or_load_metadata(frame)
    train_df, val_df, test_df = split_dataframe(frame)
    index = {path: i for i, path in enumerate(frame["image_path"])}
    take = lambda df: metadata[[index[p] for p in df["image_path"]]]  # noqa: E731

    print(f"Split: train {len(train_df)} · val {len(val_df)} · test {len(test_df)}")
    results = run_ablation(
        train_metadata=take(train_df),
        val_metadata=take(val_df),
        test_metadata=take(test_df),
        train_and_evaluate=_train_and_evaluate,
        metadata_is_synthetic=synthetic,
        seed=args.seed,
        noise_band=args.noise_band,
        train_df=train_df,
        val_df=val_df,
        test_df=test_df,
        epochs=args.epochs,
        cnn_weights=args.cnn_weights,
        batch_size=args.batch_size,
        lr=args.lr,
    )
    results["config"] = {
        "csv": args.metadata_csv,
        "rows_used": int(len(frame)),
        "split_sizes": {"train": int(len(train_df)), "val": int(len(val_df)),
                        "test": int(len(test_df))},
        "epochs": args.epochs,
        "batch_size": args.batch_size,
        "learning_rate": args.lr,
        "cnn_weights": args.cnn_weights,
        "cnn_frozen": True,
    }
    write_ablation(results, args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
