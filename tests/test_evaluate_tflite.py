"""
Unit tests for the Phase 4 TFLite evaluation script (metrics.json producer).
"""

import json
import os

import numpy as np
import pandas as pd
import pytest
from PIL import Image

from src.phase4_edge.evaluate_tflite import (
    dequantize_and_normalize,
    duplicate_report,
    evaluate_model,
    main,
    merge_metrics,
    preprocess,
)

INT8_MODEL = "models/exports/efficientnetb3_maize_int8.tflite"
LABELS_CSV = "data/annotations/labels.csv"


def _write_checkerboard(path, size=(64, 48)):
    arr = np.indices(size[::-1]).sum(axis=0) % 2 * 255
    rgb = np.stack([arr, arr // 2, 255 - arr], axis=-1).astype(np.uint8)
    Image.fromarray(rgb).save(path)


def test_preprocess_returns_uint8_batch_in_both_modes(tmp_path):
    path = tmp_path / "leaf.png"
    _write_checkerboard(path)

    python_tensor = preprocess(str(path), (300, 300), mode="python")
    app_tensor = preprocess(str(path), (300, 300), mode="app")

    assert python_tensor.shape == (1, 300, 300, 3)
    assert python_tensor.dtype == np.uint8
    assert app_tensor.shape == (1, 300, 300, 3)
    # Since T09 the app resizes bilinearly too, so both modes must agree; this
    # guards the parity that closed a 1.75-point accuracy gap.
    assert np.array_equal(python_tensor, app_tensor)


def test_preprocess_rejects_unknown_mode(tmp_path):
    path = tmp_path / "leaf.png"
    _write_checkerboard(path)
    with pytest.raises(ValueError, match="mode"):
        preprocess(str(path), (300, 300), mode="bicubic")


def test_dequantize_uint8_output_sums_to_one_and_keeps_argmax():
    raw = np.array([200, 40, 10, 6], dtype=np.uint8)
    probs = dequantize_and_normalize(raw, quantization=(0.00390625, 0))

    assert probs.dtype == np.float32
    assert abs(float(probs.sum()) - 1.0) < 1e-6
    assert int(np.argmax(probs)) == 0


def test_float_output_is_renormalized_not_softmaxed():
    raw = np.array([0.5, 0.3, 0.1, 0.1], dtype=np.float32)
    probs = dequantize_and_normalize(raw, quantization=(0.0, 0))
    np.testing.assert_allclose(probs, raw, atol=1e-6)


def test_duplicate_report_flags_conflicting_labels(tmp_path):
    a = tmp_path / "a.jpg"
    b = tmp_path / "b.jpg"
    c = tmp_path / "c.jpg"
    a.write_bytes(b"same-bytes")
    b.write_bytes(b"same-bytes")
    c.write_bytes(b"different")
    df = pd.DataFrame({
        "image_path": [str(a), str(b), str(c)],
        "label": [0, 2, 1],
    })

    report = duplicate_report(df)

    assert report["duplicate_files"] == 2
    assert report["duplicate_groups"] == 1
    assert report["conflicting_label_groups"] == 1


def test_merge_metrics_preserves_other_entries(tmp_path):
    out = tmp_path / "metrics.json"
    out.write_text(json.dumps({
        "models": {"other.tflite": {"python": {"accuracy": 0.5}}},
        "ocr": {"synthetic": {"variety_accuracy": 0.9}},
    }))

    merge_metrics(str(out), "new.tflite", "python", {"accuracy": 0.9}, extra={"sha256": "abc"})

    data = json.loads(out.read_text())
    assert data["models"]["other.tflite"]["python"]["accuracy"] == 0.5
    assert data["models"]["new.tflite"]["python"]["accuracy"] == 0.9
    assert data["models"]["new.tflite"]["sha256"] == "abc"
    assert data["ocr"]["synthetic"]["variety_accuracy"] == 0.9


def test_main_exits_nonzero_when_model_missing(tmp_path, capsys):
    with pytest.raises(SystemExit) as exc:
        main(["--model", str(tmp_path / "missing.tflite"), "--output", str(tmp_path / "m.json")])
    assert exc.value.code != 0
    assert "Model not found" in capsys.readouterr().err


def test_main_exits_nonzero_when_labels_csv_missing(tmp_path, capsys):
    model = tmp_path / "model.tflite"
    model.write_bytes(b"not-a-real-model")
    with pytest.raises(SystemExit) as exc:
        main(["--model", str(model), "--csv", str(tmp_path / "nope.csv"),
              "--output", str(tmp_path / "m.json")])
    assert exc.value.code != 0
    assert "Labels CSV not found" in capsys.readouterr().err


def test_evaluate_int8_model_on_one_image_per_class():
    if not (os.path.exists(INT8_MODEL) and os.path.exists(LABELS_CSV)):
        pytest.skip("INT8 model or labels.csv not available")
    df = pd.read_csv(LABELS_CSV)
    sample = df.groupby("label", group_keys=False).head(1)
    if not all(os.path.exists(p) for p in sample["image_path"]):
        pytest.skip("PlantVillage images not downloaded")

    result = evaluate_model(INT8_MODEL, sample, mode="python")

    assert result["n"] == 4
    assert 0.0 <= result["accuracy"] <= 1.0
    assert set(result["per_class"]) == {"NCLB", "Rust", "GLS", "Healthy"}
    assert np.array(result["confusion_matrix"]).shape == (4, 4)
