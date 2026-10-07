"""T53: one variety list, and honesty about what backs it.

The thirteen names were hand-copied into `extractor.py` and `diseases.dart`,
where they could drift apart silently, and no source was ever recorded for
them. Neither the app nor the papers may call them registered varieties until
that is checked.
"""
import subprocess
import sys
from pathlib import Path

from src.common.varieties import (
    KNOWN_VARIETIES,
    load_variety_records,
    load_varieties,
    unverified_varieties,
)

ROOT = Path(__file__).resolve().parents[1]


def test_the_list_is_read_from_the_reference_file():
    assert len(KNOWN_VARIETIES) == 13
    assert KNOWN_VARIETIES[0] == "SAMMAZ 15"
    assert "EARLY THRIVING" in KNOWN_VARIETIES
    assert KNOWN_VARIETIES == load_varieties()


def test_every_row_records_whether_it_is_verified_and_against_what():
    for row in load_variety_records():
        assert row["name"].strip(), "a row with no name"
        assert row["verified"].strip().lower() in {"yes", "no"}
        assert row["source"].strip(), f"{row['name']} has no source column entry"


def test_unverified_names_are_not_quietly_presented_as_verified():
    # Everything is unverified today; the point is that the file says so
    # rather than the code implying otherwise.
    unverified = unverified_varieties()
    assert set(unverified) <= set(KNOWN_VARIETIES)
    assert unverified, "if this is empty, update the papers: the names are now citable"


def test_the_extractor_uses_the_shared_list():
    from src.phase2_ocr.extractor import KNOWN_VARIETIES as extractor_list

    assert extractor_list is KNOWN_VARIETIES


def test_no_module_defines_its_own_variety_list():
    offenders = []
    for path in (ROOT / "src").rglob("*.py"):
        if "common/varieties.py" in str(path):
            continue
        for line in path.read_text().splitlines():
            stripped = line.strip()
            if stripped.startswith(("KNOWN_VARIETIES", "VARIETIES")) and "=" in stripped \
                    and "import" not in stripped:
                offenders.append(f"{path.name}: {stripped}")
    assert not offenders, "varieties are defined outside src/common:\n" + "\n".join(offenders)


def test_the_generated_dart_file_is_in_step_with_the_csv():
    result = subprocess.run(
        [sys.executable, "scripts/sync_varieties.py", "--check"],
        cwd=ROOT, capture_output=True, text=True,
    )
    assert result.returncode == 0, result.stderr
