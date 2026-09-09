"""
Unit tests for Phase 2/3 Metadata Encoding.
"""

import numpy as np
import pytest
from src.phase2_ocr.encoder import encode, METADATA_DIM, NUM_VARIETIES


def test_metadata_encoder():
    fields = {
        "crop_variety": "SAMMAZ 15",
        "batch_number": "BATCH-001",
        "planting_date": "2024-05-10",
    }
    vec = encode(fields)

    assert isinstance(vec, np.ndarray)
    assert vec.dtype == np.float32
    assert len(vec) == METADATA_DIM
    assert METADATA_DIM == NUM_VARIETIES + 4

    # Check unknown variety produces zero in one-hot segment
    unknown_fields = {
        "crop_variety": "NONEXISTENT",
        "batch_number": None,
        "planting_date": None,
    }
    vec_unknown = encode(unknown_fields)
    assert np.all(vec_unknown[:NUM_VARIETIES] == 0)
