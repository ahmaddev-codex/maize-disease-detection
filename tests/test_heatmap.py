"""T37/T38: the UAV survey summary, and the deprecated import path.

`_recommend` picked the most common class of all, so a field that is mostly
healthy was reported as "Dominant: Healthy" with an agronomist referral, and
importing the module switched matplotlib to Agg for whatever notebook happened
to import it.
"""
import importlib
import json
import warnings
from collections import Counter
from pathlib import Path

import pytest

from src.phase5_uav import heatmap


def predictions_from(counts, latency=None):
    rows = []
    for class_name, n in counts.items():
        for i in range(n):
            row = {
                "class_name": class_name,
                "confidence": 0.9,
                "lat": 7.3 + i * 1e-5,
                "lon": 3.9 + i * 1e-5,
            }
            if latency is not None:
                row["latency_ms"] = latency
            rows.append(row)
    return rows


def test_the_dominant_disease_is_a_disease():
    counts = Counter({"Healthy": 127, "Rust": 59, "NCLB": 38, "GLS": 26})

    recommendation = heatmap._recommend(disease_rate=123 / 250, counts=counts)

    assert "Dominant: Rust" in recommendation
    assert "triazole" in recommendation.lower()
    assert "Healthy" not in recommendation


def test_a_healthy_field_is_told_to_keep_scouting():
    counts = Counter({"Healthy": 240, "Rust": 10})
    recommendation = heatmap._recommend(disease_rate=0.04, counts=counts)
    assert "scouting" in recommendation.lower()
    assert "fungicide" not in recommendation.lower()


def test_a_field_with_disease_but_no_known_class_does_not_prescribe():
    counts = Counter({"Healthy": 10, "Unknown": 90})
    recommendation = heatmap._recommend(disease_rate=0.9, counts=counts)
    assert "fungicide" not in recommendation.lower()


def test_summary_counts_and_latency(tmp_path):
    output = tmp_path / "heatmap_summary.json"
    summary = heatmap.build_summary(
        predictions_from({"Healthy": 127, "Rust": 59, "NCLB": 38, "GLS": 26}, latency=42.0),
        str(output),
    )

    assert summary["total_patches"] == 250
    assert summary["disease_patches"] == 123
    assert summary["healthy_patches"] == 127
    assert "Dominant: Rust" in summary["recommendation"]
    assert json.loads(output.read_text())["total_patches"] == 250


def test_missing_latency_is_absent_rather_than_invented(tmp_path):
    summary = heatmap.build_summary(
        predictions_from({"Healthy": 2, "Rust": 2}),
        str(tmp_path / "s.json"),
    )
    assert summary["avg_latency_ms"] is None


def test_importing_the_module_leaves_the_plot_backend_alone():
    matplotlib = pytest.importorskip("matplotlib")
    before = matplotlib.get_backend()
    importlib.reload(heatmap)
    assert matplotlib.get_backend() == before, "importing heatmap changed the backend"


def test_the_summary_filename_follows_the_output_stem():
    assert heatmap.summary_path_for("data/uav/disease_heatmap.html") == \
        "data/uav/disease_heatmap_summary.json"
    assert heatmap.summary_path_for("out/map.html").endswith("_summary.json")


def test_the_deprecated_import_path_warns_but_still_works():
    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter("always")
        shim = importlib.import_module("deployment.uav.heatmap")
        importlib.reload(shim)

    assert any(issubclass(w.category, DeprecationWarning) for w in caught)
    assert hasattr(shim, "main")


def test_predictions_without_coordinates_still_produce_a_summary(tmp_path):
    """A non-georeferenced survey has no lat/lon (T39); the summary is still valid."""
    csv_path = tmp_path / "patches.csv"
    csv_path.write_text(
        "patch_row,patch_col,pixel_row,pixel_col,class_id,class_name,confidence,latency_ms\n"
        "0,0,0,0,1,Rust,0.91,120.0\n"
        "0,1,0,150,3,Healthy,0.88,118.0\n"
    )

    rows = heatmap.load_predictions(str(csv_path))
    assert len(rows) == 2
    assert rows[0].get("lat") is None

    summary = heatmap.build_summary(rows, str(tmp_path / "summary.json"))
    assert summary["total_patches"] == 2
    assert summary["disease_patches"] == 1


def test_maps_are_skipped_rather_than_crashing_without_coordinates(tmp_path):
    rows = [
        {"class_name": "Rust", "confidence": 0.9, "latency_ms": 100.0},
        {"class_name": "Healthy", "confidence": 0.9, "latency_ms": 100.0},
    ]

    assert heatmap.build_folium_map(rows, str(tmp_path / "map.html")) is None
    heatmap.build_static_map(rows, str(tmp_path / "map.png"))  # must not raise
    assert not (tmp_path / "map.html").exists()


def test_the_stale_root_package_is_gone():
    assert not (Path(__file__).parents[1] / "uav").exists(), \
        "the diverged root uav/ copy is back (ADR-004: src/phase5_uav is canonical)"
