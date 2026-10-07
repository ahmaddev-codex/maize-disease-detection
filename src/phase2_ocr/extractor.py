"""
Phase 2 — Field Extractor
Runs Tesseract 5 on a preprocessed image and parses three structured fields:
  - crop_variety   (e.g. "SAMMAZ 15", "OBA SUPER 2")
  - batch_number   (e.g. "BN-2024-042", "12345" from "Batch No: 12345")
  - planting_date  (ISO YYYY-MM-DD, from "15/03/2024" or "15 March 2024")

Parsing rules are shared with mobile/lib/services/ocr_parser.dart through the
cases in tests/fixtures/ocr_cases.json (ADR-006) — change both together.

Run:
    python -m src.phase2_ocr.extractor --image data/raw/seed_labels/sample_label.jpg
"""

import argparse
import json
import os
import re
import sys
from datetime import date
from typing import List, Optional, Sequence, cast

import numpy as np
import pytesseract
from Levenshtein import distance as _levenshtein

# ── Known variety list ────────────────────────────────────────────────────────
# One source for both languages: data/reference/maize_varieties.csv (ADR-006).
from src.common.varieties import KNOWN_VARIETIES  # noqa: E402,F401

VARIETY_SCORE_THRESHOLD = 60   # FR-14: minimum per-word similarity score (0–100)

# Tesseract config: PSM 6 = assume a single uniform block of text
TESSERACT_CONFIG = "--oem 3 --psm 6"


# ── Public API ─────────────────────────────────────────────────────────────────

def extract_fields(preprocessed_image: np.ndarray) -> dict:
    """
    Run OCR on a preprocessed (thresholded) image and return a dict:

    {
        "raw_text":     str,
        "crop_variety": str | None,
        "batch_number": str | None,
        "planting_date": str | None,   # ISO format YYYY-MM-DD if parsed
    }
    """
    raw_text = _run_ocr(preprocessed_image)
    return {
        "raw_text":      raw_text,
        "crop_variety":  _extract_variety(raw_text),
        "batch_number":  _extract_batch(raw_text),
        "planting_date": _extract_date(raw_text),
    }


def extract_fields_from_path(image_path: str) -> dict:
    from src.phase2_ocr.preprocessor import preprocess_from_path
    preprocessed = preprocess_from_path(image_path)
    return extract_fields(preprocessed)


# ── OCR ────────────────────────────────────────────────────────────────────────

def _require_tesseract() -> None:
    """Fail loudly instead of silently returning empty text without Tesseract."""
    try:
        pytesseract.get_tesseract_version()
    except pytesseract.TesseractNotFoundError as exc:
        raise RuntimeError(
            "tesseract not found — install Tesseract 5 "
            "(macOS: brew install tesseract; Ubuntu: sudo apt install tesseract-ocr)"
        ) from exc


def _run_ocr(image: np.ndarray) -> str:
    _require_tesseract()
    return cast(str, pytesseract.image_to_string(image, config=TESSERACT_CONFIG))


# ── Field parsers ──────────────────────────────────────────────────────────────

def _words(text: str) -> List[str]:
    return [w for w in re.split(r"[^A-Z0-9]+", text.upper()) if w]


def _word_score(word: str, target: str) -> Optional[float]:
    """Numbers must match exactly; other words need VARIETY_SCORE_THRESHOLD similarity."""
    if word.isdigit() or target.isdigit():
        return 100.0 if word == target else None
    longest = max(len(word), len(target))
    score = 100 * (1 - _levenshtein(word, target) / longest)
    return score if score >= VARIETY_SCORE_THRESHOLD else None


def _best_window_score(words: List[str], target: List[str]) -> Optional[float]:
    best = None
    for start in range(len(words) - len(target) + 1):
        scores: List[float] = []
        for i, t in enumerate(target):
            score = _word_score(words[start + i], t)
            if score is None:
                break
            scores.append(score)
        if len(scores) < len(target):
            continue
        mean = sum(scores) / len(target)
        if best is None or mean > best:
            best = mean
    return best


def _extract_variety(text: str) -> Optional[str]:
    """
    Return the known variety named in text, matching word by word within a line
    so "SAMMAZ-17 ... 15/03/2024" is not read as SAMMAZ 15, or None.
    """
    best, best_score, best_len = None, 0.0, 0
    for line in text.splitlines():
        words = _words(line)
        for variety in KNOWN_VARIETIES:
            target = _words(variety)
            score = _best_window_score(words, target)
            if score is None:
                continue
            if score > best_score or (score == best_score and len(target) > best_len):
                best, best_score, best_len = variety, score, len(target)
    return best


# A lot code that carries its own prefix. The separator may be read as a
# period or a space: "LOT.2023-686" is the same code as "LOT-2023-686" (T51).
# Punctuation separator only: "LOT 2024" with a space is ambiguous with the
# label "LOT NUMBER", which the labelled branch below handles.
_PREFIXED_CODE = re.compile(
    r"\b(BN|LOT|BATCH)[-.]([A-Z0-9]*\d[A-Z0-9]*(?:[-.][A-Z0-9]+)*)\b", re.IGNORECASE
)

# A labelled value: "LOT NUMBER : 20220291". The separator run tolerates the
# stray underscores and periods OCR leaves between the label and the colon.
_LABELLED_CODE = re.compile(
    r"\b(?:BATCH|LOT)\s*(?:NUMBER|NUM|NO)?[\s._\-]*[:#]?[\s._]*([A-Z0-9][A-Z0-9\-./]*)",
    re.IGNORECASE,
)

# Tesseract confuses letters in the label itself — "LOT" becomes "Lor", "BATCH"
# becomes "BATGH". Anything before a colon that is nearly one of these labels
# counts as one.
_LABEL_WORDS = ("LOT", "BATCH", "LOTNUMBER", "BATCHNO", "LOTNO", "BATCHNUMBER")
_VALUE_AFTER_COLON = re.compile(r"^([A-Z0-9][A-Z0-9\-./]*)", re.IGNORECASE)


def _looks_like_label(fragment: str) -> bool:
    """True when `fragment` is a lot/batch label, allowing for OCR slips."""
    from Levenshtein import distance as _distance

    cleaned = re.sub(r"[^A-Z]", "", fragment.upper())
    if not cleaned or len(cleaned) > 14:
        return False
    for word in _LABEL_WORDS:
        # One slip in a short word, two in a longer one.
        budget = 1 if len(word) <= 5 else 2
        if _distance(cleaned, word) <= budget:
            return True
    return False


def _normalise_code(code: str) -> str:
    """Puts a prefixed code back into its canonical form."""
    code = code.upper().strip(" .:-_")
    return re.sub(r"(?<=[A-Z0-9])\.(?=[A-Z0-9])", "-", code)


def _extract_batch(text: str) -> Optional[str]:
    """Return the batch/lot code without its 'Batch No:' style label, or None."""
    for line in text.splitlines():
        prefixed = _PREFIXED_CODE.search(line)
        if prefixed:
            return _normalise_code(f"{prefixed.group(1).upper()}-{prefixed.group(2)}")

    for line in text.splitlines():
        for m in _LABELLED_CODE.finditer(line):
            value = m.group(1)
            if re.search(r"\d", value):
                return _normalise_code(value)

    # Last resort: a label the OCR mangled, followed by a colon and a value.
    for line in text.splitlines():
        if ":" not in line:
            continue
        label, _, rest = line.partition(":")
        if not _looks_like_label(label):
            continue
        value = _VALUE_AFTER_COLON.match(rest.strip())
        if value and re.search(r"\d", value.group(1)):
            return _normalise_code(value.group(1))
    return None


_MONTHS = {
    "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
    "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
}

_DAY_FIRST_DATE = re.compile(r"\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})\b")
_ISO_DATE       = re.compile(r"\b(\d{4})-(\d{1,2})-(\d{1,2})\b")
_TEXTUAL_DATE   = re.compile(
    r"\b(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+(\d{4})\b",
    re.IGNORECASE,
)


def _iso_date(year: int, month: int, day: int) -> Optional[str]:
    try:
        return date(year, month, day).isoformat()
    except ValueError:
        return None


def _extract_date(text: str) -> Optional[str]:
    """Return the first real calendar date as YYYY-MM-DD (numeric dates read day-first), or None."""
    for m in _DAY_FIRST_DATE.finditer(text):
        iso = _iso_date(int(m.group(3)), int(m.group(2)), int(m.group(1)))
        if iso:
            return iso
    for m in _ISO_DATE.finditer(text):
        iso = _iso_date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
        if iso:
            return iso
    for m in _TEXTUAL_DATE.finditer(text):
        iso = _iso_date(int(m.group(3)), _MONTHS[m.group(2).lower()], int(m.group(1)))
        if iso:
            return iso
    return None


# ── CLI ───────────────────────────────────────────────────────────────────────

def _fail(message: str) -> None:
    print(message, file=sys.stderr)
    sys.exit(1)


def main(argv: Optional[Sequence[str]] = None) -> None:
    p = argparse.ArgumentParser(description="Extract seed-label fields from an image with Tesseract")
    p.add_argument("--image", required=True, help="Path to a seed bag or tag photo")
    args = p.parse_args(argv)

    if not os.path.exists(args.image):
        _fail(f"Image not found: {args.image}")
    try:
        _require_tesseract()
        fields = extract_fields_from_path(args.image)
    except RuntimeError as exc:
        _fail(str(exc))
        return
    print(json.dumps(fields, indent=2))


if __name__ == "__main__":
    main()
