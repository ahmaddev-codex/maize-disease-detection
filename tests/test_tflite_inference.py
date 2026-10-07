"""
Unit tests for Phase 4 Edge TFLite inference engine.
"""

import os
import numpy as np
import pytest

from src.phase4_edge.inference import EdgeClassifier, CLASS_NAMES


def test_int8_model_inference():
    model_path = "models/exports/efficientnetb3_maize_int8.tflite"
    if not os.path.exists(model_path):
        pytest.skip(f"Model file not found: {model_path}")

    classifier = EdgeClassifier(model_path, num_threads=2)
    assert classifier.is_quantized is True
    assert classifier.input_dtype == np.uint8
    assert classifier.input_shape.tolist() == [1, 300, 300, 3]

    # Run single inference with random input tensor
    dummy = np.random.randint(0, 256, (1, 300, 300, 3), dtype=np.uint8)
    top_idx, confidence, probs, latency = classifier.predict(dummy)

    assert 0 <= top_idx < 4
    assert 0.0 <= confidence <= 1.0
    assert len(probs) == 4
    assert latency > 0.0
    assert abs(sum(probs) - 1.0) < 0.05
