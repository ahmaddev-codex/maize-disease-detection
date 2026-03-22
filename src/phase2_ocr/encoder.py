"""
Phase 2 — Metadata Encoder
Converts the structured dict returned by extractor.py into a fixed-length
numpy vector that can be concatenated with CNN features in Phase 3.

Vector layout (length = METADATA_DIM = NUM_VARIETIES + 4):
  [0:NUM_VARIETIES]  crop_variety one-hot  (all zeros = unknown variety)
  [NUM_VARIETIES]    batch_number_present  (0 or 1)
  [NUM_VARIETIES+1]  batch_year_norm       (year / 2030, or 0.0 if absent)
  [NUM_VARIETIES+2]  planting_month_sin    (sin encoding of month, 0.0 if absent)
  [NUM_VARIETIES+3]  planting_month_cos    (cos encoding of month, 0.0 if absent)
"""

import re
import math
import numpy as np
from typing import Optional

from src.phase2_ocr.extractor import KNOWN_VARIETIES

# ── Constants ──────────────────────────────────────────────────────────────────

NUM_VARIETIES = len(KNOWN_VARIETIES)
METADATA_DIM  = NUM_VARIETIES + 4   # computed — no magic number


# ── Public API ─────────────────────────────────────────────────────────────────

def encode(fields: dict) -> np.ndarray:
    """
    Encode extracted OCR fields into a float32 vector of length METADATA_DIM.

    Args:
        fields: dict from extractor.extract_fields()

    Returns:
        np.ndarray shape (METADATA_DIM,) dtype float32
    """
    vec = np.zeros(METADATA_DIM, dtype=np.float32)

    # ── Variety one-hot ──────────────────────────────────────────────────
    variety_idx = _variety_index(fields.get("crop_variety"))
    # indices 0..NUM_VARIETIES-1; unknown → all zeros (no bit set)
    if variety_idx is not None:
        vec[variety_idx] = 1.0

    # ── Batch number ─────────────────────────────────────────────────────
    batch = fields.get("batch_number")
    vec[NUM_VARIETIES] = 1.0 if batch else 0.0

    year = _extract_year_from_batch(batch)
    vec[NUM_VARIETIES + 1] = (year / 2030.0) if year else 0.0

    # ── Planting date ────────────────────────────────────────────────────
    date_str = fields.get("planting_date")
    month    = _extract_month(date_str)
    if month is not None:
        vec[NUM_VARIETIES + 2] = math.sin(2 * math.pi * month / 12)
        vec[NUM_VARIETIES + 3] = math.cos(2 * math.pi * month / 12)

    return vec


def encode_batch(fields_list: list) -> np.ndarray:
    """Encode a list of field dicts → shape (N, METADATA_DIM)."""
    return np.stack([encode(f) for f in fields_list], axis=0)


# ── Helpers ────────────────────────────────────────────────────────────────────

def _variety_index(variety) -> Optional[int]:
    """Return index into KNOWN_VARIETIES, or None if unknown/absent/NaN."""
    if variety is None:
        return None
    try:
        # pandas may pass float NaN for empty CSV cells
        if not isinstance(variety, str):
            return None
        return KNOWN_VARIETIES.index(variety.upper())
    except ValueError:
        return None


def _extract_year_from_batch(batch) -> Optional[int]:
    if not batch or not isinstance(batch, str):
        return None
    m = re.search(r"\b(20\d{2})\b", batch)
    if m:
        return int(m.group(1))
    return None


def _extract_month(date_str) -> Optional[int]:
    """Return month as int (1-12) from ISO date string, or None."""
    if not date_str or not isinstance(date_str, str):
        return None
    parts = date_str.split("-")
    if len(parts) >= 2:
        try:
            return int(parts[1])
        except ValueError:
            return None
    return None
