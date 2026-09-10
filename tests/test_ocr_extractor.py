"""
Phase 2 OCR extractor parity with the mobile parser (T14, ADR-006).
Runs the shared cases in tests/fixtures/ocr_cases.json against the Python
field parsers, and checks the extractor CLI fails loudly.
"""

import json
from pathlib import Path

import pytest

from src.phase2_ocr import extractor

CASES = json.loads((Path(__file__).parent / "fixtures" / "ocr_cases.json").read_text())


def _ids(cases):
    return [c["text"].replace("\n", "\\n") for c in cases]


@pytest.mark.parametrize("case", CASES["dates"], ids=_ids(CASES["dates"]))
def test_extract_date_matches_shared_cases(case):
    assert extractor._extract_date(case["text"]) == case["expected"]


@pytest.mark.parametrize("case", CASES["varieties"], ids=_ids(CASES["varieties"]))
def test_extract_variety_matches_shared_cases(case):
    assert extractor._extract_variety(case["text"]) == case["expected"]


@pytest.mark.parametrize("case", CASES["batches"], ids=_ids(CASES["batches"]))
def test_extract_batch_matches_shared_cases(case):
    assert extractor._extract_batch(case["text"]) == case["expected"]


def test_cli_exits_nonzero_for_missing_image(tmp_path, capsys):
    with pytest.raises(SystemExit) as exc:
        extractor.main(["--image", str(tmp_path / "missing.jpg")])
    assert exc.value.code != 0
    assert "Image not found" in capsys.readouterr().err


def test_cli_exits_nonzero_when_tesseract_is_missing(tmp_path, capsys, monkeypatch):
    image = tmp_path / "label.png"
    image.write_bytes(b"placeholder")

    def _no_tesseract():
        raise extractor.pytesseract.TesseractNotFoundError()

    monkeypatch.setattr(extractor.pytesseract, "get_tesseract_version", _no_tesseract)

    with pytest.raises(SystemExit) as exc:
        extractor.main(["--image", str(image)])
    assert exc.value.code != 0
    assert "tesseract not found" in capsys.readouterr().err.lower()
