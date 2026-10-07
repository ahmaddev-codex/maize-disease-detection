"""Measures the OCR pipeline against known ground truth (T51).

The project has never had a number for how often seed-label extraction works.
This runs the Python Tesseract pipeline over a generated tag set and reports
per-field accuracy, writing the result to `models/exports/metrics.json` under
`ocr.synthetic`.

What this number is, and is not:

  * It is measured on **rendered** tags (`synth_labels.py`) — clean typography,
    synthetic wear. It bounds the parser, not a farmer's camera.
  * It measures the **Python** pipeline. The app uses ML Kit, whose recognition
    differs; the generated set doubles as a manual test pack for the phone.
  * A field measurement on real bags is a separate, outstanding task (T52).

Usage:
    python -m src.phase2_ocr.ocr_eval --set data/synthetic/seed_tags
"""
from __future__ import annotations

import argparse
import datetime
import json
from pathlib import Path
from typing import Dict, List, Optional

FIELDS = ("crop_variety", "batch_number", "planting_date")

DEFAULT_METRICS = Path("models/exports/metrics.json")


def _normalise(value: Optional[str]) -> str:
    return (value or "").strip().upper()


def evaluate_set(set_dir: Path, limit: Optional[int] = None) -> Dict:
    """Runs extraction over every tag and counts exact per-field matches."""
    from src.phase2_ocr.extractor import extract_fields_from_path

    set_dir = Path(set_dir)
    truth = json.loads((set_dir / "ground_truth.json").read_text())
    records: List[Dict] = truth["records"][: limit or len(truth["records"])]

    counts = {field: {"correct": 0, "missing": 0, "wrong": 0} for field in FIELDS}
    failures: List[Dict] = []

    for record in records:
        image_path = set_dir / record["image"]
        extracted = extract_fields_from_path(str(image_path))

        # The generator names a field `lot_number`; the parser calls it
        # `batch_number`. Compare like with like.
        expected = {
            "crop_variety": record["crop_variety"],
            "batch_number": record["lot_number"],
            "planting_date": record["planting_date"],
        }

        for field in FIELDS:
            got = _normalise(extracted.get(field))
            want = _normalise(expected[field])
            if not got:
                counts[field]["missing"] += 1
                failures.append({"image": record["image"], "field": field,
                                 "expected": expected[field], "got": None})
            elif got == want:
                counts[field]["correct"] += 1
            else:
                counts[field]["wrong"] += 1
                failures.append({"image": record["image"], "field": field,
                                 "expected": expected[field], "got": extracted.get(field)})

    n = len(records)
    per_field = {
        field: {
            "accuracy": round(counts[field]["correct"] / n, 4) if n else 0.0,
            **counts[field],
        }
        for field in FIELDS
    }
    return {
        "n": n,
        "set": str(set_dir),
        "seed": truth.get("seed"),
        "per_field": per_field,
        "failures": failures[:40],
        "source": "synthetic",
        "engine": "tesseract (python pipeline)",
        "caveat": "Rendered tags, not photographs of real seed bags; bounds the "
                  "parser rather than field performance. The app uses ML Kit, "
                  "not Tesseract.",
        "evaluated_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    }


def write_metrics(result: Dict, metrics_path: Path = DEFAULT_METRICS) -> None:
    metrics_path = Path(metrics_path)
    metrics = {}
    if metrics_path.exists():
        metrics = json.loads(metrics_path.read_text())
    metrics.setdefault("ocr", {})["synthetic"] = result
    metrics_path.parent.mkdir(parents=True, exist_ok=True)
    metrics_path.write_text(json.dumps(metrics, indent=2) + "\n")
    print(f"OCR results written → {metrics_path}")


def print_result(result: Dict) -> None:
    print(f"\n──── OCR on {result['n']} synthetic tags ────")
    for field, stats in result["per_field"].items():
        print(f"  {field:<14} {stats['accuracy'] * 100:6.1f}%   "
              f"correct {stats['correct']:3d} · missing {stats['missing']:3d} · "
              f"wrong {stats['wrong']:3d}")
    print(f"  ({result['caveat']})\n")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--set", dest="set_dir", type=Path,
                        default=Path("data/synthetic/seed_tags"))
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--output", type=Path, default=DEFAULT_METRICS)
    parser.add_argument("--no-write", action="store_true",
                        help="Print the result without recording it")
    args = parser.parse_args(argv)

    result = evaluate_set(args.set_dir, args.limit)
    print_result(result)
    if not args.no_write:
        write_metrics(result, args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
