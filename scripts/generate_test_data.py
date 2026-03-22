"""
scripts/generate_test_data.py

Generates synthetic maize leaf images and a seed-bag label image so the
full pipeline (Phase 1 → Phase 2 → Phase 3) can be verified without
needing the real PlantVillage dataset.

Creates:
    data/raw/synthetic/NCLB/*.jpg        (and Rust, GLS, MSV, Healthy)
    data/raw/seed_labels/sample_label.jpg
    data/annotations/labels.csv          (populated)
    data/annotations/labels_with_metadata.csv

Run:
    python scripts/generate_test_data.py [--images-per-class N]
"""

import os
import csv
import argparse
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFont

CLASS_NAMES = ["NCLB", "Rust", "GLS", "Healthy"]
IMG_SIZE    = (300, 300)

# Distinct base colours per class to make images visually different
CLASS_COLOURS = {
    "NCLB":    (34, 80, 20),    # dark green + tan lesions
    "Rust":    (50, 70, 30),    # olive green
    "GLS":     (60, 90, 25),    # green
    "Healthy": (20, 120, 15),   # bright green
}
LESION_COLOURS = {
    "NCLB":    (160, 120, 60),
    "Rust":    (180, 80,  20),
    "GLS":     (140, 130, 90),
    "Healthy": None,
}


def make_leaf_image(class_name: str, seed: int) -> Image.Image:
    rng = random.Random(seed)
    np_rng = np.random.default_rng(seed)

    base_r, base_g, base_b = CLASS_COLOURS[class_name]
    noise = np_rng.integers(-20, 20, size=(*IMG_SIZE, 3))
    r = np.clip(base_r + noise[:, :, 0], 0, 255)
    g = np.clip(base_g + noise[:, :, 1], 0, 255)
    b = np.clip(base_b + noise[:, :, 2], 0, 255)
    arr = np.stack([r, g, b], axis=2).astype(np.uint8)

    img  = Image.fromarray(arr)
    draw = ImageDraw.Draw(img)

    # Draw a leaf-like oval
    margin = 20
    draw.ellipse([margin, margin, IMG_SIZE[0] - margin, IMG_SIZE[1] - margin],
                 fill=tuple(int(x) for x in [base_r + 10, base_g + 10, base_b + 10]))

    # Draw lesions / streaks for diseased classes
    lesion_col = LESION_COLOURS[class_name]
    if lesion_col:
        for _ in range(rng.randint(5, 20)):
            x = rng.randint(30, IMG_SIZE[0] - 30)
            y = rng.randint(30, IMG_SIZE[1] - 30)
            r_w = rng.randint(5, 25)
            r_h = rng.randint(3, 15)
            draw.ellipse([x - r_w, y - r_h, x + r_w, y + r_h], fill=lesion_col)

    return img


def make_seed_label_image() -> Image.Image:
    """Generate a fake seed-bag label with parseable text fields."""
    img  = Image.new("RGB", (600, 300), color=(240, 235, 220))
    draw = ImageDraw.Draw(img)

    lines = [
        "SAMMAZ 15",
        "Batch No: BN-2024-042",
        "Planting Date: 15/03/2024",
        "Net Weight: 2 kg",
        "Produced by: IITA Seeds Ltd",
    ]
    y = 20
    for line in lines:
        draw.text((30, y), line, fill=(10, 10, 10))
        y += 45

    return img


def generate(images_per_class: int):
    # ── Leaf images ──────────────────────────────────────────────────────
    rows = []
    for label_idx, class_name in enumerate(CLASS_NAMES):
        class_dir = os.path.join("data", "raw", "synthetic", class_name)
        os.makedirs(class_dir, exist_ok=True)
        for i in range(images_per_class):
            img  = make_leaf_image(class_name, seed=label_idx * 10000 + i)
            path = os.path.join(class_dir, f"{class_name}_{i:04d}.jpg")
            img.save(path, "JPEG", quality=90)
            rows.append({
                "image_path": path,
                "label":      label_idx,
                "class_name": class_name,
                "source":     "synthetic",
            })

    # ── labels.csv ───────────────────────────────────────────────────────
    os.makedirs("data/annotations", exist_ok=True)
    csv_path = "data/annotations/labels.csv"
    with open(csv_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["image_path", "label", "class_name", "source"])
        writer.writeheader()
        writer.writerows(rows)
    print(f"Written {len(rows)} rows → {csv_path}")

    # ── labels_with_metadata.csv (adds OCR fields for Phase 3) ──────────
    meta_path = "data/annotations/labels_with_metadata.csv"
    varieties = ["SAMMAZ 15", "SAMMAZ 17", "OBA SUPER 2", None]
    batches   = ["BN-2024-042", "BN-2023-011", None]
    dates     = ["2024-03-15", "2023-11-01", None]
    with open(meta_path, "w", newline="") as f:
        fieldnames = ["image_path", "label", "class_name", "source",
                      "crop_variety", "batch_number", "planting_date"]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        rng = random.Random(0)
        for row in rows:
            writer.writerow({
                **row,
                "crop_variety":  rng.choice(varieties),
                "batch_number":  rng.choice(batches),
                "planting_date": rng.choice(dates),
            })
    print(f"Written {len(rows)} rows → {meta_path}")

    # ── Seed label image ─────────────────────────────────────────────────
    label_dir = os.path.join("data", "raw", "seed_labels")
    os.makedirs(label_dir, exist_ok=True)
    seed_img_path = os.path.join(label_dir, "sample_label.jpg")
    make_seed_label_image().save(seed_img_path, "JPEG")
    print(f"Written seed label image → {seed_img_path}")

    total = len(CLASS_NAMES) * images_per_class
    print(f"\nDone — {total} synthetic images across {len(CLASS_NAMES)} classes.")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--images-per-class", type=int, default=50,
                   help="Number of images per class (default: 50 = 250 total)")
    args = p.parse_args()
    generate(args.images_per_class)
