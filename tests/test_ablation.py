"""T31: does the metadata branch actually help?

The metadata in `labels_with_metadata.csv` is invented (ADR-002), so any gain
the fusion model shows over the CNN alone may be nothing but noise. This
ablation makes that testable: the same split, three arms, and a shuffled-
metadata arm that destroys the row-to-image pairing while keeping the marginal
distribution. Fusion must beat shuffled by more than the noise band to mean
anything.

The arms themselves are trained by an injected function, so these tests run in
milliseconds; the real run is a manual step recorded in metrics.json.
"""
import json

import numpy as np
import pytest

from src.phase3_fusion.ablation import (
    ARMS,
    interpret,
    run_ablation,
    shuffle_metadata,
    write_ablation,
    zero_metadata,
)


def test_the_three_arms_are_named_and_ordered():
    assert ARMS == ("cnn_only", "fusion", "fusion_shuffled")


def test_shuffling_keeps_the_rows_but_breaks_the_pairing():
    vectors = np.arange(40, dtype=np.float32).reshape(10, 4)

    shuffled = shuffle_metadata(vectors, seed=0)

    assert shuffled.shape == vectors.shape
    # Same rows, different order: the marginal distribution is untouched.
    assert sorted(map(tuple, shuffled.tolist())) == sorted(map(tuple, vectors.tolist()))
    assert not np.array_equal(shuffled, vectors), "the pairing survived the shuffle"


def test_shuffling_is_reproducible():
    vectors = np.arange(40, dtype=np.float32).reshape(10, 4)
    assert np.array_equal(shuffle_metadata(vectors, seed=7), shuffle_metadata(vectors, seed=7))
    assert not np.array_equal(shuffle_metadata(vectors, seed=1), shuffle_metadata(vectors, seed=2))


def test_the_cnn_only_arm_carries_no_metadata():
    vectors = np.arange(40, dtype=np.float32).reshape(10, 4)
    zeroed = zero_metadata(vectors)
    assert zeroed.shape == vectors.shape
    assert not zeroed.any()


def test_a_difference_inside_the_noise_band_is_reported_as_noise():
    verdict = interpret({"cnn_only": 0.902, "fusion": 0.907, "fusion_shuffled": 0.905},
                        noise_band=0.01)
    assert verdict["fusion_beats_cnn_only"] is False
    assert verdict["fusion_beats_shuffled"] is False
    assert "noise" in verdict["summary"].lower()


def test_a_real_gain_over_shuffled_metadata_is_reported_as_one():
    verdict = interpret({"cnn_only": 0.880, "fusion": 0.940, "fusion_shuffled": 0.885},
                        noise_band=0.01)
    assert verdict["fusion_beats_cnn_only"] is True
    assert verdict["fusion_beats_shuffled"] is True


def test_beating_the_cnn_but_not_the_shuffle_is_not_evidence():
    # Both fusion arms gain the same amount, so the gain comes from the extra
    # parameters, not from what the metadata says.
    verdict = interpret({"cnn_only": 0.880, "fusion": 0.920, "fusion_shuffled": 0.919},
                        noise_band=0.01)
    assert verdict["fusion_beats_cnn_only"] is True
    assert verdict["fusion_beats_shuffled"] is False
    assert "metadata" in verdict["summary"].lower()


def test_every_arm_sees_the_same_split_and_the_results_are_recorded(tmp_path):
    seen = []

    def fake_train_and_evaluate(arm, train_meta, val_meta, test_meta, **kwargs):
        seen.append((arm, train_meta.shape, test_meta.shape))
        return {"accuracy": 0.9 + 0.001 * ARMS.index(arm), "n": len(test_meta)}

    results = run_ablation(
        train_metadata=np.ones((20, 4), dtype=np.float32),
        val_metadata=np.ones((5, 4), dtype=np.float32),
        test_metadata=np.ones((6, 4), dtype=np.float32),
        train_and_evaluate=fake_train_and_evaluate,
        metadata_is_synthetic=True,
        seed=0,
    )

    assert [arm for arm, _, _ in seen] == list(ARMS)
    assert {shape for _, shape, _ in seen} == {(20, 4)}, "arms trained on different splits"
    assert results["metadata_is_synthetic"] is True
    assert set(results["arms"]) == set(ARMS)
    assert results["verdict"]["summary"]


def test_the_record_says_the_metadata_was_invented(tmp_path):
    metrics = tmp_path / "metrics.json"
    metrics.write_text(json.dumps({"models": {}}))

    write_ablation(
        {
            "arms": {arm: {"accuracy": 0.9, "n": 100} for arm in ARMS},
            "metadata_is_synthetic": True,
            "verdict": {"summary": "within noise", "fusion_beats_cnn_only": False,
                        "fusion_beats_shuffled": False},
        },
        str(metrics),
    )

    written = json.loads(metrics.read_text())
    assert written["fusion_ablation"]["metadata_is_synthetic"] is True
    assert written["models"] == {}, "the ablation overwrote the model metrics"
    assert written["fusion_ablation"]["recorded_at"]


def test_a_missing_arm_is_refused_rather_than_half_reported():
    with pytest.raises(ValueError):
        interpret({"cnn_only": 0.9, "fusion": 0.91}, noise_band=0.01)
