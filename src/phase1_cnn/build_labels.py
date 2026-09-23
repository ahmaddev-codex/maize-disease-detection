"""Builds data/annotations/labels.csv from the PlantVillage tree.

This used to be a Python heredoc inside run_all.sh, where it could not be
tested and quietly kept four images that are two byte-identical pairs, each
pair filed under both Blight and Gray Leaf Spot. One label in each pair is
wrong whichever way the split falls, so one member of each pair is listed in
data/annotations/exclusions.csv with its reason and dropped here (T34).

The metadata CSV it also writes carries invented variety, batch and planting
values for the fusion experiments; every row is flagged `synthetic=1` so no
result can be read as though the metadata were real (T31, ADR-002).

Usage:
    python -m src.phase1_cnn.build_labels \
        --root data/raw/plantvillage/data \
        --labels data/annotations/labels.csv \
        --metadata data/annotations/labels_with_metadata.csv
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import random
import sys
from collections import Counter
from pathlib import Path
from typing import Dict, Iterable, List, Set

from src.common.labels import SHORT_NAMES

# Dataset folder → (label id, short class name). The ids and names come from
# src/common/labels.py so the CSV, the metrics and the app agree (ADR-006).
CLASS_FOLDERS: Dict[str, int] = {
    "Blight": 0,
    "Common_Rust": 1,
    "Gray_Leaf_Spot": 2,
    "Healthy": 3,
}

IMAGE_SUFFIXES = (".jpg", ".jpeg", ".png")

DEFAULT_ROOT = Path("data/raw/plantvillage/data")
DEFAULT_LABELS = Path("data/annotations/labels.csv")
DEFAULT_METADATA = Path("data/annotations/labels_with_metadata.csv")
DEFAULT_EXCLUSIONS = Path("data/annotations/exclusions.csv")

# Values used to synthesise fusion metadata. Kept here so the flag and the
# values live together.
_VARIETIES = [
    "SAMMAZ 15", "SAMMAZ 17", "SAMMAZ 29", "SAMMAZ 34", "SAMMAZ 50",
    "OBA SUPER 2", "EVDT 99", "POOL 16 DT", "TZEE-W", "ABA WHITE",
    "ACROSS 97", "SUWAN 1", "EARLY THRIVING", None,
]
_BATCHES = ["BN-2024-042", "BN-2023-011", "LOT-2024-007", None]
_DATES = ["2024-03-15", "2023-11-01", "2024-05-20", None]


def md5_of(path: Path) -> str:
    """Content hash, used to find the duplicate pairs."""
    digest = hashlib.md5()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_exclusions(path: Path = DEFAULT_EXCLUSIONS) -> Set[str]:
    """Image paths to leave out, from a CSV of `image_path,reason`."""
    if not path.exists():
        return set()
    with path.open(newline="") as handle:
        return {
            row["image_path"].strip()
            for row in csv.DictReader(handle)
            if row.get("image_path", "").strip()
        }


def build_rows(root: Path, exclusions: Iterable[str] = ()) -> List[dict]:
    """One row per image under [root], in a stable order, minus [exclusions]."""
    excluded = {str(Path(p)) for p in exclusions}
    rows: List[dict] = []
    for folder, label in CLASS_FOLDERS.items():
        directory = Path(root) / folder
        if not directory.is_dir():
            continue
        for image in sorted(directory.iterdir()):
            if image.suffix.lower() not in IMAGE_SUFFIXES:
                continue
            if str(image) in excluded:
                continue
            rows.append({
                "image_path": str(image),
                "label": label,
                "class_name": SHORT_NAMES[label],
                "source": "plantvillage",
            })
    return rows


def conflicting_duplicates(rows: List[dict]) -> Dict[str, List[dict]]:
    """Groups of byte-identical images that carry more than one label."""
    by_hash: Dict[str, List[dict]] = {}
    for row in rows:
        by_hash.setdefault(md5_of(Path(row["image_path"])), []).append(row)
    return {
        digest: group
        for digest, group in by_hash.items()
        if len({row["label"] for row in group}) > 1
    }


def write_labels(
    rows: List[dict],
    labels_csv: Path = DEFAULT_LABELS,
    metadata_csv: Path = DEFAULT_METADATA,
    seed: int = 0,
) -> dict:
    """Writes both CSVs and returns a small summary for the console."""
    labels_csv = Path(labels_csv)
    metadata_csv = Path(metadata_csv)
    labels_csv.parent.mkdir(parents=True, exist_ok=True)
    metadata_csv.parent.mkdir(parents=True, exist_ok=True)

    with labels_csv.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle, fieldnames=["image_path", "label", "class_name", "source"]
        )
        writer.writeheader()
        writer.writerows(rows)

    rng = random.Random(seed)
    with metadata_csv.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=[
            "image_path", "label", "class_name", "source",
            "crop_variety", "batch_number", "planting_date", "synthetic",
        ])
        writer.writeheader()
        for row in rows:
            writer.writerow({
                **row,
                "crop_variety": rng.choice(_VARIETIES),
                "batch_number": rng.choice(_BATCHES),
                "planting_date": rng.choice(_DATES),
                # Invented, not observed: any fusion result must say so (ADR-002).
                "synthetic": 1,
            })

    counts = Counter(row["class_name"] for row in rows)
    return {"total": len(rows), "counts": dict(counts)}


def _print_summary(summary: dict, excluded: int) -> None:
    total = summary["total"]
    print(f"\n  labels.csv written: {total} images ({excluded} excluded)")
    print(f"  {'Class':<24} {'Count':>6}  {'Pct':>6}")
    print(f"  {'─' * 40}")
    for name in SHORT_NAMES:
        count = summary["counts"].get(name, 0)
        share = (count / total * 100) if total else 0.0
        print(f"  {name:<24} {count:>6}  {share:>5.1f}%")
    print(f"  {'─' * 40}")
    print(f"  {'TOTAL':<24} {total:>6}  100.0%")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--labels", type=Path, default=DEFAULT_LABELS)
    parser.add_argument("--metadata", type=Path, default=DEFAULT_METADATA)
    parser.add_argument("--exclusions", type=Path, default=DEFAULT_EXCLUSIONS)
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument(
        "--check-duplicates",
        action="store_true",
        help="Fail if a byte-identical image still carries two labels",
    )
    args = parser.parse_args(argv)

    if not Path(args.root).is_dir():
        print(f"ERROR: {args.root} not found.", file=sys.stderr)
        return 1

    exclusions = load_exclusions(args.exclusions)
    rows = build_rows(args.root, exclusions)
    if not rows:
        print(f"ERROR: no images found under {args.root}.", file=sys.stderr)
        return 1

    if args.check_duplicates:
        conflicts = conflicting_duplicates(rows)
        if conflicts:
            print("ERROR: duplicates with conflicting labels remain:", file=sys.stderr)
            for group in conflicts.values():
                for row in group:
                    print(f"  {row['class_name']}: {row['image_path']}", file=sys.stderr)
            return 1

    summary = write_labels(rows, args.labels, args.metadata, seed=args.seed)
    _print_summary(summary, excluded=len(exclusions))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
