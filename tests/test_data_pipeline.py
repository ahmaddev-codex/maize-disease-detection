"""
Unit tests for Phase 1 Data Pipeline (Image preprocessing, label mappings).
"""

import os
import tempfile
import numpy as np
import pytest
from PIL import Image

from src.phase1_cnn.data_pipeline import CLASS_NAMES, NUM_CLASSES, IMG_SIZE


def test_class_definitions():
    assert NUM_CLASSES == 4
    assert len(CLASS_NAMES) == 4
    assert CLASS_NAMES == ["NCLB", "Rust", "GLS", "Healthy"]


def test_synthetic_image_resize():
    with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as f:
        path = f.name
        # Create a random RGB image
        arr = np.random.randint(0, 256, (100, 150, 3), dtype=np.uint8)
        img = Image.fromarray(arr)
        img.save(path)

    try:
        loaded = Image.open(path).convert("RGB")
        resized = loaded.resize(IMG_SIZE)
        assert resized.size == (300, 300)
        assert np.array(resized).shape == (300, 300, 3)
    finally:
        if os.path.exists(path):
            os.remove(path)
