"""The maize varieties OCR matches against, read from one file.

The list used to be hand-copied into `extractor.py` and `diseases.dart`, where
the two could drift apart silently. `data/reference/maize_varieties.csv` is now
the source (ADR-006); the Dart copy is generated from it by
`scripts/sync_varieties.py` and checked by a test in both languages.

Every entry is currently `verified=no`: the names came with the original
project and no citation was recorded. Nothing in the app or the papers may
describe them as registered varieties, or attach a susceptibility claim to one,
until that is checked against the NASC catalogue (T53).
"""
from __future__ import annotations

import csv
from pathlib import Path
from typing import Dict, List

VARIETIES_CSV = Path(__file__).resolve().parents[2] / "data" / "reference" / "maize_varieties.csv"


def _rows(path: Path = VARIETIES_CSV) -> List[Dict[str, str]]:
    with path.open(newline="") as handle:
        # The file carries a comment header explaining its provenance.
        lines = [line for line in handle if not line.lstrip().startswith("#")]
    return list(csv.DictReader(lines))


def load_varieties(path: Path = VARIETIES_CSV) -> List[str]:
    """Variety names, in file order."""
    return [row["name"].strip() for row in _rows(path) if row.get("name", "").strip()]


def load_variety_records(path: Path = VARIETIES_CSV) -> List[Dict[str, str]]:
    """Full rows, including whether each name has been verified and against what."""
    return _rows(path)


def unverified_varieties(path: Path = VARIETIES_CSV) -> List[str]:
    """Names with no citable source yet — everything, for now."""
    return [r["name"].strip() for r in _rows(path) if r.get("verified", "").strip().lower() != "yes"]


KNOWN_VARIETIES: List[str] = load_varieties()
