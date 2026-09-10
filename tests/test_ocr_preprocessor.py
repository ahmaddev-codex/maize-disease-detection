"""
Prove-It tests for the Phase 2 OCR preprocessor deskew (T56).
_deskew measured skew from the white background, which OpenCV >= 4.5 reports as
a 90-degree rectangle, so every label was rotated sideways before OCR.
"""

import shutil

import cv2
import numpy as np
import pytest

from src.phase2_ocr import preprocessor as pp

SAMPLE_LABEL = "data/raw/seed_labels/sample_label.jpg"


def _text_block(angle_deg: float = 0.0) -> np.ndarray:
    """White page with dark horizontal text-like bars, optionally rotated."""
    page = np.full((600, 900), 255, dtype=np.uint8)
    for row in range(120, 480, 60):
        cv2.rectangle(page, (150, row), (750, row + 18), 0, thickness=-1)
    if angle_deg:
        centre = (page.shape[1] // 2, page.shape[0] // 2)
        m = cv2.getRotationMatrix2D(centre, angle_deg, 1.0)
        page = cv2.warpAffine(page, m, (page.shape[1], page.shape[0]),
                              flags=cv2.INTER_NEAREST, borderValue=255)
    return page


def _bar_angle(binary: np.ndarray) -> float:
    """Angle of the dark bars in degrees, normalised to [-45, 45]."""
    coords = np.column_stack(np.where(binary < 128))[:, ::-1].astype(np.float32)
    (_, _), (w, h), angle = cv2.minAreaRect(coords)
    if w < h:
        angle -= 90
    return (angle + 45) % 90 - 45


def _text_is_horizontal(binary: np.ndarray) -> bool:
    """The text block is wider than it is tall — i.e. not rotated sideways."""
    ys, xs = np.where(binary < 128)
    return (xs.max() - xs.min()) > (ys.max() - ys.min())


def test_deskew_leaves_an_upright_label_upright():
    page = _text_block(0.0)

    result = pp._deskew(page)

    assert result.shape == page.shape
    assert _text_is_horizontal(result)
    assert abs(_bar_angle(result)) < 1.0


@pytest.mark.parametrize("angle", [4.0, -6.0])
def test_deskew_corrects_a_slightly_rotated_label(angle):
    page = _text_block(angle)
    assert abs(_bar_angle(page)) > 3.0  # sanity: the input really is skewed

    result = pp._deskew(page)

    assert _text_is_horizontal(result)
    assert abs(_bar_angle(result)) < 1.0


def test_full_pipeline_reads_the_sample_label():
    if shutil.which("tesseract") is None:
        pytest.skip("tesseract binary not installed")
    from src.phase2_ocr.extractor import extract_fields_from_path

    fields = extract_fields_from_path(SAMPLE_LABEL)

    assert fields["crop_variety"] == "SAMMAZ 15"
    assert fields["batch_number"] == "BN-2024-042"
    assert fields["planting_date"] == "2024-03-15"
