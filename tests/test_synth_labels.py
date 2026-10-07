"""T51: the synthetic seed-tag set, and what may be concluded from it."""
import json
import hashlib
from pathlib import Path

import pytest

from src.common.varieties import KNOWN_VARIETIES
from src.phase2_ocr.synth_labels import (
    DATE_FORMATS,
    LOT_FORMATS,
    SEED_CLASSES,
    generate,
    make_record,
)

FIELDS = (
    "crop_variety", "seed_class", "lot_number", "producer", "net_weight_kg",
    "purity_pct", "inert_matter_pct", "germination_pct", "moisture_pct",
    "test_date_rendered", "planting_date",
)


def _hashes(directory: Path):
    return [hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(directory.glob("images/*.jpg"))]


@pytest.fixture(scope="module")
def generated(tmp_path_factory):
    out = tmp_path_factory.mktemp("tags")
    truth = generate(n=12, seed=42, out_dir=out)
    return out, json.loads(truth.read_text())


def test_the_same_seed_gives_the_same_tags(tmp_path):
    first, second = tmp_path / "a", tmp_path / "b"
    generate(n=5, seed=7, out_dir=first)
    generate(n=5, seed=7, out_dir=second)

    assert _hashes(first) == _hashes(second), "the generator is not reproducible"
    assert (first / "ground_truth.json").read_text() == (second / "ground_truth.json").read_text()


def test_a_different_seed_gives_different_tags(tmp_path):
    a, b = tmp_path / "a", tmp_path / "b"
    generate(n=5, seed=1, out_dir=a)
    generate(n=5, seed=2, out_dir=b)
    assert _hashes(a) != _hashes(b)


def test_every_record_carries_the_whole_field_set(generated):
    _, truth = generated
    assert truth["count"] == len(truth["records"]) == 12
    for record in truth["records"]:
        for field in FIELDS:
            assert field in record, f"{field} missing from the ground truth"
        assert record["image"].startswith("images/")
        assert record["crop_variety"] in KNOWN_VARIETIES
        assert record["seed_class"] in SEED_CLASSES


def test_the_images_exist_and_are_photographs_not_blank_canvases(generated):
    out, truth = generated
    for record in truth["records"]:
        path = out / record["image"]
        assert path.exists()
        assert path.stat().st_size > 5_000, "a tag came out suspiciously small"


def test_every_date_and_lot_format_can_appear():
    import random

    seen_dates, seen_lots = set(), set()
    rng = random.Random(0)
    for _ in range(400):
        record = make_record(rng)
        rendered = record["test_date_rendered"]
        seen_dates.add(sum(ch.isalpha() for ch in rendered) > 0)   # textual vs numeric
        seen_dates.add("/" in rendered)
        seen_dates.add(rendered.count("-") == 2 and rendered[:4].isdigit())
        lot = record["lot_number"]
        seen_lots.add(lot.split("-")[0] if "-" in lot else "bare")

    assert {"BN", "LOT", "bare"} <= seen_lots, f"lot formats seen: {seen_lots}"
    assert len(DATE_FORMATS) == 4 and len(LOT_FORMATS) == 3


def test_planting_date_ground_truth_is_iso(generated):
    _, truth = generated
    for record in truth["records"]:
        iso = record["planting_date"]
        assert len(iso) == 10 and iso[4] == "-" and iso[7] == "-"


def test_the_set_says_it_is_test_data(generated):
    _, truth = generated
    assert "never used for training" in truth["_description"].lower()
