"""
Phase 2 — OCR Preprocessor
Cleans an image of a seed bag label or handwritten farm record so that
Tesseract 5 can extract text reliably.

Pipeline:
  1. Resize to a consistent height
  2. Convert to grayscale
  3. Denoise (non-local means)
  4. Adaptive threshold (handles uneven lighting common in field photos)
  5. Deskew (rotate to align text horizontally)
  6. Optional morphological cleanup
"""

import cv2
import numpy as np


TARGET_HEIGHT = 1000   # resize to this height, keep aspect ratio


def preprocess(image: np.ndarray) -> np.ndarray:
    """
    Full preprocessing pipeline.

    Args:
        image: BGR image loaded via cv2.imread()

    Returns:
        Binary (thresholded) grayscale image ready for Tesseract.
    """
    img = _resize(image)
    img = _to_grayscale(img)
    img = _denoise(img)
    img = _adaptive_threshold(img)
    img = _deskew(img)
    img = _morphological_cleanup(img)
    return img


# ── Steps ──────────────────────────────────────────────────────────────────────

def _resize(image: np.ndarray) -> np.ndarray:
    h, w = image.shape[:2]
    if h == 0:
        return image
    scale = TARGET_HEIGHT / h
    new_w = int(w * scale)
    return cv2.resize(image, (new_w, TARGET_HEIGHT), interpolation=cv2.INTER_CUBIC)


def _to_grayscale(image: np.ndarray) -> np.ndarray:
    if len(image.shape) == 3:
        return cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    return image


def _denoise(gray: np.ndarray) -> np.ndarray:
    return cv2.fastNlMeansDenoising(gray, h=10, templateWindowSize=7, searchWindowSize=21)


def _adaptive_threshold(gray: np.ndarray) -> np.ndarray:
    return cv2.adaptiveThreshold(
        gray,
        maxValue=255,
        adaptiveMethod=cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        thresholdType=cv2.THRESH_BINARY,
        blockSize=31,
        C=10,
    )


MAX_DESKEW_DEG = 30.0   # larger estimates are unreliable; leave the image as captured


def _deskew(binary: np.ndarray) -> np.ndarray:
    """Estimate text skew from the dark text pixels and rotate it level."""
    # Text is dark on a white background after THRESH_BINARY. Measuring the
    # white pixels instead fits the whole page (a 90-degree rectangle on
    # OpenCV >= 4.5) and rotated every label sideways.
    coords = np.column_stack(np.where(binary < 128))[:, ::-1].astype(np.float32)  # (x, y)
    if len(coords) < 10:
        return binary

    (_, _), (width, height), angle = cv2.minAreaRect(coords)
    # OpenCV >= 4.5 reports the angle in (0, 90]; express the tilt in [-45, 45).
    if width < height:
        angle -= 90
    angle = (angle + 45) % 90 - 45

    if abs(angle) < 0.5 or abs(angle) > MAX_DESKEW_DEG:
        return binary

    h, w = binary.shape
    centre = (w // 2, h // 2)
    M = cv2.getRotationMatrix2D(centre, angle, 1.0)
    rotated = cv2.warpAffine(
        binary, M, (w, h),
        flags=cv2.INTER_CUBIC,
        borderMode=cv2.BORDER_REPLICATE,
    )
    return rotated


def _morphological_cleanup(binary: np.ndarray) -> np.ndarray:
    """Remove small noise specks with an opening operation."""
    kernel  = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
    opened  = cv2.morphologyEx(binary, cv2.MORPH_OPEN, kernel)
    return opened


# ── Utility ────────────────────────────────────────────────────────────────────

def load_image(path: str) -> np.ndarray:
    img = cv2.imread(path)
    if img is None:
        raise FileNotFoundError(f"Could not load image: {path}")
    return img


def preprocess_from_path(path: str) -> np.ndarray:
    return preprocess(load_image(path))
