"""T32: what the INT8 converter is allowed to look at, and what it records.

Calibration sampled from the whole of labels.csv, test images included, so the
quantisation ranges were fitted on images the model is then scored against.
The exports also carried no link back to the checkpoint that produced them.
"""
import hashlib
from pathlib import Path

import pandas as pd
import pytest

from src.phase4_edge.convert_tflite import (
    calibration_sample,
    export_record,
    sha256_of,
)


@pytest.fixture()
def labels(tmp_path):
    rows = []
    for i in range(200):
        rows.append({
            "image_path": str(tmp_path / f"img_{i}.jpg"),
            "label": i % 4,
            "class_name": ["NCLB", "Rust", "GLS", "Healthy"][i % 4],
            "source": "plantvillage",
        })
    frame = pd.DataFrame(rows)
    csv_path = tmp_path / "labels.csv"
    frame.to_csv(csv_path, index=False)
    return csv_path


def test_calibration_images_come_only_from_the_training_split(labels):
    from src.phase1_cnn.data_pipeline import load_labels_csv, split_dataframe

    train_df, val_df, test_df = split_dataframe(load_labels_csv(labels))
    sample = calibration_sample(labels, n=50)

    train_paths = set(train_df["image_path"])
    assert len(sample) == 50
    assert set(sample).issubset(train_paths), "calibration saw val or test images"
    assert not set(sample) & set(test_df["image_path"])
    assert not set(sample) & set(val_df["image_path"])


def test_the_sample_is_reproducible(labels):
    assert calibration_sample(labels, n=30) == calibration_sample(labels, n=30)


def test_a_small_training_split_is_not_oversampled(labels):
    sample = calibration_sample(labels, n=10_000)
    from src.phase1_cnn.data_pipeline import load_labels_csv, split_dataframe

    train_df, _, _ = split_dataframe(load_labels_csv(labels))
    assert len(sample) == len(train_df)
    assert len(set(sample)) == len(sample), "the same image was used twice"


def test_sha256_matches_hashlib(tmp_path):
    path = tmp_path / "model.bin"
    path.write_bytes(b"weights")
    assert sha256_of(path) == hashlib.sha256(b"weights").hexdigest()


def test_an_export_records_where_it_came_from(tmp_path, labels):
    source = tmp_path / "efficientnetb3_maize.keras"
    source.write_bytes(b"the checkpoint")
    exported = tmp_path / "efficientnetb3_maize_int8.tflite"
    exported.write_bytes(b"the export")

    record = export_record(
        exported,
        source_keras=source,
        precision="int8",
        calibration_csv=labels,
        calibration_images=50,
    )

    assert record["sha256"] == sha256_of(exported)
    assert record["source_keras"]["path"] == str(source)
    assert record["source_keras"]["sha256"] == sha256_of(source)
    assert record["precision"] == "int8"
    assert record["calibration"]["split"] == "train"
    assert record["calibration"]["images"] == 50
    assert record["calibration"]["csv"] == str(labels)
    assert record["exported_at"]


def test_a_missing_source_checkpoint_is_recorded_as_unknown_not_invented(tmp_path, labels):
    exported = tmp_path / "model_fp16.tflite"
    exported.write_bytes(b"export")

    record = export_record(
        exported,
        source_keras=tmp_path / "gone.keras",
        precision="fp16",
        calibration_csv=None,
        calibration_images=0,
    )

    assert record["source_keras"]["sha256"] is None
    assert record["source_keras"]["missing"] is True
    assert "calibration" not in record or record["calibration"] is None
