"""T33: one label set and one post-processing path.

`inference.py` applied a softmax to values that were already probabilities, so
the confidence it printed did not match the app's, and three modules each had
their own class names. These cases are shared with the Dart test
(mobile/test/classifier_postprocess_test.dart) so both ends stay identical.
"""
import json
from pathlib import Path

import numpy as np
import pytest

from src.common.labels import (
    CLASS_NAMES,
    HEALTHY_CLASS_ID,
    NUM_CLASSES,
    SHORT_NAMES,
    display_name,
    short_name,
)
from src.common.postprocess import postprocess

CASES = json.loads((Path(__file__).parent / "fixtures" / "postprocess_cases.json").read_text())


@pytest.mark.parametrize("case", CASES["cases"], ids=lambda c: c["name"])
def test_shared_postprocess_cases(case):
    dtype = np.int32 if case["integer_output"] else np.float32
    raw = np.array(case["raw"], dtype=dtype)

    probs = postprocess(raw, (case["scale"], case["zero_point"]))

    assert probs.shape == (len(case["expected"]),)
    np.testing.assert_allclose(probs, case["expected"], atol=CASES["tolerance"])
    assert pytest.approx(float(probs.sum()), abs=1e-6) == 1.0
    assert int(np.argmax(probs)) == case["expected_class_id"]


def test_probabilities_are_never_softmaxed():
    # A softmax over [0.8, 0.1, 0.05, 0.05] would flatten the winner to ~0.36.
    probs = postprocess(np.array([0.8, 0.1, 0.05, 0.05], dtype=np.float32), (0.0, 0))
    assert probs[0] == pytest.approx(0.8, abs=1e-6)


def test_labels_are_defined_once_and_match_the_app():
    assert len(CLASS_NAMES) == NUM_CLASSES == len(SHORT_NAMES) == 4
    assert CLASS_NAMES == [
        "Northern Corn Leaf Blight",
        "Common Rust",
        "Gray Leaf Spot",
        "Healthy",
    ]
    assert SHORT_NAMES == ["NCLB", "Rust", "GLS", "Healthy"]
    assert HEALTHY_CLASS_ID == 3
    assert display_name(1) == "Common Rust"
    assert short_name(3) == "Healthy"


def test_the_app_and_python_agree_on_display_names():
    """diseases.dart is the single source for names shown to a farmer (ADR-006)."""
    dart = (Path(__file__).parents[1] / "mobile" / "lib" / "constants" / "diseases.dart").read_text()
    for name in CLASS_NAMES:
        assert f"'{name}'" in dart, f"{name} is not the name the app shows"


def test_only_common_defines_the_class_names():
    root = Path(__file__).parents[1] / "src"
    offenders = []
    for path in root.rglob("*.py"):
        if path.parts[-2] == "common" or "phase5_uav" in path.parts:
            continue  # the UAV modules migrate in T39/T40
        for line in path.read_text().splitlines():
            stripped = line.strip()
            if stripped.startswith("CLASS_NAMES") and "=" in stripped and "import" not in stripped:
                offenders.append(f"{path}: {stripped}")
    assert not offenders, "class names are still defined outside src/common:\n" + "\n".join(offenders)
