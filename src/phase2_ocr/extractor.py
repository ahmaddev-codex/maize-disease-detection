"""
Phase 2 — Field Extractor
Runs Tesseract 5 on a preprocessed image and parses three structured fields:
  - crop_variety   (e.g. "SAMMAZ 15", "OBA SUPER 2")
  - batch_number   (e.g. "BN-2024-001")
  - planting_date  (e.g. "15/03/2024", "March 2024")

Fuzzy matching is used to correct common OCR errors in variety names.
"""

import re
from datetime import datetime
from typing import Optional

import pytesseract
import numpy as np
from fuzzywuzzy import process as fw_process

# ── Known variety list (extend as needed) ─────────────────────────────────────
KNOWN_VARIETIES = [
    "SAMMAZ 15", "SAMMAZ 17", "SAMMAZ 29", "SAMMAZ 34", "SAMMAZ 50",
    "OBA SUPER 2", "EVDT 99",  "POOL 16 DT", "TZEE-W",
    "ABA WHITE",  "ACROSS 97", "SUWAN 1",    "EARLY THRIVING",
]

VARIETY_SCORE_THRESHOLD = 60   # minimum fuzzy-match score to accept

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

def _run_ocr(image: np.ndarray) -> str:
    return pytesseract.image_to_string(image, config=TESSERACT_CONFIG)


# ── Field parsers ──────────────────────────────────────────────────────────────

def _extract_variety(text: str) -> Optional[str]:
    """
    Look for a variety name via fuzzy matching against KNOWN_VARIETIES.
    Returns the best match if score ≥ threshold, else None.
    """
    lines = [l.strip() for l in text.splitlines() if l.strip()]
    for line in lines:
        match, score = fw_process.extractOne(line.upper(), KNOWN_VARIETIES)
        if score >= VARIETY_SCORE_THRESHOLD:
            return match
    return None


def _extract_batch(text: str) -> Optional[str]:
    """
    Match patterns like:
      BN-2024-001 / BATCH 2024-01 / LOT#003 / BATCH NO: 12345
    """
    patterns = [
        r"\bBN[-\s]?\d{4}[-\s]?\d{1,4}\b",
        r"\bBATCH\s*(?:NO|NUM|NUMBER)?[:\s#]*([A-Z0-9\-]+)\b",
        r"\bLOT\s*[#:\s]*([A-Z0-9\-]+)\b",
    ]
    for pat in patterns:
        m = re.search(pat, text, re.IGNORECASE)
        if m:
            return m.group(0).strip()
    return None


_DATE_PATTERNS = [
    (r"\b(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{4})\b",      "dmy"),
    (r"\b(\d{4})[/\-\.](\d{1,2})[/\-\.](\d{1,2})\b",      "ymd"),
    (r"\b(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+(\d{4})\b", "dmy_text"),
    (r"\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+(\d{4})\b",             "my_text"),
]

_MONTH_MAP = {
    "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
    "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
}


def _extract_date(text: str) -> Optional[str]:
    """Return planting date as ISO string (YYYY-MM-DD) or YYYY-MM if day unknown."""
    for pat, fmt in _DATE_PATTERNS:
        m = re.search(pat, text, re.IGNORECASE)
        if not m:
            continue
        try:
            if fmt == "dmy":
                d, mo, y = int(m.group(1)), int(m.group(2)), int(m.group(3))
                return datetime(y, mo, d).strftime("%Y-%m-%d")
            elif fmt == "ymd":
                y, mo, d = int(m.group(1)), int(m.group(2)), int(m.group(3))
                return datetime(y, mo, d).strftime("%Y-%m-%d")
            elif fmt == "dmy_text":
                d   = int(m.group(1))
                mo  = _MONTH_MAP[m.group(2).lower()[:3]]
                y   = int(m.group(3))
                return datetime(y, mo, d).strftime("%Y-%m-%d")
            elif fmt == "my_text":
                mo  = _MONTH_MAP[m.group(1).lower()[:3]]
                y   = int(m.group(2))
                return f"{y}-{mo:02d}"
        except (ValueError, KeyError):
            continue
    return None
