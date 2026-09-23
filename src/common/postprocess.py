"""One way to turn a model's output tensor into probabilities.

`inference.py` applied a softmax whenever the scores did not already sum to 1.
The model's last layer is a softmax, so its output *is* a probability vector:
running a second softmax over it flattens the winner (0.95 becomes about 0.4)
and the confidence a farmer sees no longer matches the evaluated metrics (T33).

The rule, shared with the Dart implementation through
tests/fixtures/postprocess_cases.json:

  1. dequantise integer output with the tensor's own (scale, zero_point);
  2. renormalise by the sum;
  3. never apply a softmax to probabilities.
"""
from typing import Sequence, Tuple

import numpy as np


def dequantize(raw: np.ndarray, quantization: Tuple[float, int]) -> np.ndarray:
    """Maps an integer output tensor back to real values.

    Float tensors are returned as they are; a missing or zero scale means the
    tensor was never quantised, so nothing is rescaled.
    """
    scores = np.asarray(raw, dtype=np.float32)
    scale, zero_point = quantization
    if np.issubdtype(np.asarray(raw).dtype, np.integer) and scale and scale > 0:
        scores = (scores - float(zero_point)) * float(scale)
    return scores


def normalize(scores: Sequence[float]) -> np.ndarray:
    """Renormalises scores so they sum to 1, without a softmax.

    A non-positive total means the model said nothing usable; an even split is
    reported rather than a confident first class.
    """
    values = np.asarray(scores, dtype=np.float32)
    total = float(values.sum())
    if total <= 0 or not np.isfinite(total):
        return np.full(values.shape, 1.0 / values.size, dtype=np.float32)
    if abs(total - 1.0) <= 1e-6:
        return values
    return values / total


def postprocess(raw: np.ndarray, quantization: Tuple[float, int] = (0.0, 0)) -> np.ndarray:
    """Dequantise then renormalise: the whole path, in one call."""
    return normalize(dequantize(raw, quantization))
