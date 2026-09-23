"""T34: dataset hygiene.

Four files in PlantVillage are two byte-identical pairs, each pair labelled
both Blight and Gray Leaf Spot. Whichever way the split falls, one of the two
labels is wrong, and the label CSV was built by a Python heredoc inside
run_all.sh where nothing could test it.
"""
import csv
import hashlib
from pathlib import Path

import pytest

from src.phase1_cnn.build_labels import (
    CLASS_FOLDERS,
    build_rows,
    load_exclusions,
    md5_of,
    write_labels,
)


@pytest.fixture()
def dataset(tmp_path):
    """A miniature PlantVillage tree with one conflicting duplicate pair."""
    root = tmp_path / "data"
    shared = b"the same leaf photographed once and filed twice"
    files = {
        "Blight": [("blight_1.jpg", b"blight one"), ("dup.jpg", shared)],
        "Common_Rust": [("rust_1.jpg", b"rust one")],
        "Gray_Leaf_Spot": [("gls_1.jpg", b"gls one"), ("dup_again.jpg", shared)],
        "Healthy": [("healthy_1.jpg", b"healthy one")],
    }
    for folder, entries in files.items():
        (root / folder).mkdir(parents=True)
        for name, content in entries:
            (root / folder / name).write_bytes(content)
    return root


def test_every_class_folder_is_read(dataset):
    rows = build_rows(dataset, exclusions=set())
    assert len(rows) == 6
    assert {r["class_name"] for r in rows} == {"NCLB", "Rust", "GLS", "Healthy"}
    assert all(Path(r["image_path"]).exists() for r in rows)
    # Labels follow the shared table, not the folder spelling.
    blight = next(r for r in rows if r["image_path"].endswith("blight_1.jpg"))
    assert (blight["label"], blight["class_name"]) == (0, "NCLB")


def test_folder_mapping_covers_the_four_classes():
    assert sorted(CLASS_FOLDERS) == ["Blight", "Common_Rust", "Gray_Leaf_Spot", "Healthy"]


def test_excluded_images_are_dropped(dataset):
    excluded = str(dataset / "Gray_Leaf_Spot" / "dup_again.jpg")
    rows = build_rows(dataset, exclusions={excluded})

    assert len(rows) == 5
    assert excluded not in {r["image_path"] for r in rows}


def test_no_conflicting_duplicate_survives_the_exclusions(dataset):
    excluded = {str(dataset / "Gray_Leaf_Spot" / "dup_again.jpg")}
    rows = build_rows(dataset, exclusions=excluded)

    by_hash = {}
    for row in rows:
        by_hash.setdefault(md5_of(Path(row["image_path"])), set()).add(row["label"])
    conflicting = {h: labels for h, labels in by_hash.items() if len(labels) > 1}
    assert not conflicting, "a duplicate with two different labels is still in the set"


def test_the_real_exclusions_file_lists_the_known_conflicts():
    path = Path(__file__).parents[1] / "data" / "annotations" / "exclusions.csv"
    assert path.exists(), "exclusions.csv is missing"

    with path.open() as handle:
        rows = list(csv.DictReader(handle))

    assert rows, "exclusions.csv has no entries"
    for row in rows:
        assert row["image_path"], "an exclusion without a path"
        assert row["reason"], f"{row['image_path']} is excluded without a reason"

    excluded = load_exclusions(path)
    assert len(excluded) == len(rows) == 2
    # One copy of each conflicting pair is dropped: the one whose folder does
    # not match what the image shows.
    assert any("Gray_Leaf_Spot" in p for p in excluded)
    assert any("Blight" in p for p in excluded)
    assert not any("Common_Rust" in p or "Healthy" in p for p in excluded)
    for row in rows:
        assert "decided_by" in row and row["decided_by"], "no one is named for the call"


def test_write_labels_writes_both_csvs_and_flags_synthetic_metadata(dataset, tmp_path):
    rows = build_rows(dataset, exclusions=set())
    labels_csv = tmp_path / "labels.csv"
    metadata_csv = tmp_path / "labels_with_metadata.csv"

    summary = write_labels(rows, labels_csv, metadata_csv, seed=0)

    assert summary["total"] == len(rows)
    with labels_csv.open() as handle:
        written = list(csv.DictReader(handle))
    assert len(written) == len(rows)
    assert set(written[0]) == {"image_path", "label", "class_name", "source"}

    with metadata_csv.open() as handle:
        meta = list(csv.DictReader(handle))
    # The variety, batch and planting date are invented; the column says so (T31).
    assert all(row["synthetic"] == "1" for row in meta)
    assert "crop_variety" in meta[0]


def test_metadata_generation_is_reproducible(dataset, tmp_path):
    rows = build_rows(dataset, exclusions=set())

    def varieties(seed):
        meta = tmp_path / f"meta_{seed}.csv"
        write_labels(rows, tmp_path / f"labels_{seed}.csv", meta, seed=seed)
        with meta.open() as handle:
            return [r["crop_variety"] for r in csv.DictReader(handle)]

    assert varieties(0) == varieties(0)


def test_md5_matches_hashlib(tmp_path):
    path = tmp_path / "x.bin"
    path.write_bytes(b"1234")
    assert md5_of(path) == hashlib.md5(b"1234").hexdigest()
