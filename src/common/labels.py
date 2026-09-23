"""The four classes, named once.

Three modules used to carry their own list — `inference.py` even printed
"Northern Leaf Blight" where the app said "Northern Corn Leaf Blight" — so a
report and the phone in a farmer's hand disagreed about what was diagnosed
(T33). The display names here are the ones in `mobile/lib/constants/diseases.dart`.
"""
from typing import List

# Shown to a person. Must match diseases.dart exactly (ADR-006).
CLASS_NAMES: List[str] = [
    "Northern Corn Leaf Blight",
    "Common Rust",
    "Gray Leaf Spot",
    "Healthy",
]

# Compact form used in dataset folders, plots and CSV columns.
SHORT_NAMES: List[str] = ["NCLB", "Rust", "GLS", "Healthy"]

NUM_CLASSES: int = len(CLASS_NAMES)
HEALTHY_CLASS_ID: int = 3


def display_name(class_id: int) -> str:
    """Full name for a class id, or 'Unknown' when the id is out of range."""
    if 0 <= class_id < NUM_CLASSES:
        return CLASS_NAMES[class_id]
    return "Unknown"


def short_name(class_id: int) -> str:
    if 0 <= class_id < NUM_CLASSES:
        return SHORT_NAMES[class_id]
    return "Unknown"
