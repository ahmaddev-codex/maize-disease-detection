"""
Prove-It tests for the Phase 3 fusion tf.data pipeline (T30).
build_fusion_dataset crashed because _load_image passed a nested size to
tf.image.resize.
"""

import numpy as np
import pandas as pd
import pytest
from PIL import Image

from src.phase2_ocr.encoder import METADATA_DIM
from src.phase3_fusion.train_fusion import build_fusion_dataset


def _tiny_dataset(tmp_path, n=2):
    paths = []
    for i in range(n):
        path = tmp_path / f"leaf_{i}.jpg"
        Image.fromarray(np.full((40, 60, 3), 30 * (i + 1), dtype=np.uint8)).save(path)
        paths.append(str(path))
    df = pd.DataFrame({"image_path": paths, "label": list(range(n))})
    meta = np.zeros((n, METADATA_DIM), dtype=np.float32)
    return df, meta


@pytest.mark.parametrize("augment", [False, True])
def test_fusion_dataset_yields_300px_images_with_metadata_and_labels(tmp_path, augment):
    df, meta = _tiny_dataset(tmp_path)

    ds = build_fusion_dataset(df, meta, augment=augment, shuffle=False, batch_size=2)
    (images, metadata), labels = next(iter(ds))

    assert tuple(images.shape) == (2, 300, 300, 3)
    assert tuple(metadata.shape) == (2, METADATA_DIM)
    assert labels.numpy().tolist() == [0, 1]


def test_fusion_dataset_keeps_pixels_in_0_255_range_without_augmentation(tmp_path):
    df, meta = _tiny_dataset(tmp_path)

    (images, _), _ = next(iter(build_fusion_dataset(df, meta, shuffle=False, batch_size=2)))

    assert float(images.numpy().max()) <= 255.0
    assert float(images.numpy().max()) > 1.0  # EfficientNetB3 rescales internally; no /255 here
