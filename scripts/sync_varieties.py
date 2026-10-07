#!/usr/bin/env python3
"""Regenerates the Dart variety list from the reference CSV (ADR-006, T53).

    python scripts/sync_varieties.py            # rewrite the Dart file
    python scripts/sync_varieties.py --check    # fail if it is out of date

Dart cannot read the CSV at runtime, so the list is generated into
`mobile/lib/constants/varieties.dart`. The test suites in both languages check
the generated file against the CSV, so a drift fails a test rather than
producing a mismatch in the field.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from src.common.varieties import load_varieties  # noqa: E402

DART_FILE = Path(__file__).resolve().parents[1] / "mobile" / "lib" / "constants" / "varieties.dart"

HEADER = """// GENERATED FILE — do not edit by hand.
//
// Source: data/reference/maize_varieties.csv (ADR-006)
// Regenerate: python scripts/sync_varieties.py
//
// None of these names has been verified against a citable source yet; see the
// `verified` column in the CSV before describing them as registered Nigerian
// varieties or attaching a susceptibility claim to one (T53).

const List<String> kNigerianVarieties = [
"""


def render(varieties) -> str:
    body = "".join(f"  '{name}',\n" for name in varieties)
    return HEADER + body + "];\n"


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="Exit non-zero if the Dart file is out of date")
    args = parser.parse_args(argv)

    expected = render(load_varieties())
    current = DART_FILE.read_text() if DART_FILE.exists() else ""

    if args.check:
        if current != expected:
            print(f"{DART_FILE} is out of date — run: python scripts/sync_varieties.py",
                  file=sys.stderr)
            return 1
        print(f"{DART_FILE} matches the reference CSV")
        return 0

    DART_FILE.parent.mkdir(parents=True, exist_ok=True)
    DART_FILE.write_text(expected)
    print(f"Wrote {DART_FILE} ({len(load_varieties())} varieties)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
