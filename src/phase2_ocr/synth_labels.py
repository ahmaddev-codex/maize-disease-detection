"""Renders synthetic NASC-style seed certification tags for OCR testing (T51).

No public dataset of Nigerian seed tags exists, and photographing real bags is
a field exercise that has not happened yet (T52). This generator produces tags
carrying the field set a NASC certification tag does, in the colours the seed
classes use, photographed badly on purpose — rotated, blurred, glared,
JPEG-crushed — together with ground truth for every field.

Two rules govern it:

  * **These tags are test data, never training data.** They are for measuring
    the OCR pipeline, not for fusion training: a model trained on rendered text
    would learn this renderer, not Nigerian seed tags (ADR-002).
  * **A synthetic measurement is not a field measurement.** Accuracy here
    bounds the parser, not what a farmer's camera will achieve. Real-bag
    measurement remains outstanding.

Usage:
    python -m src.phase2_ocr.synth_labels --n 200 --seed 42 --out data/synthetic/seed_tags
"""
from __future__ import annotations

import argparse
import json
import math
import random
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from src.common.varieties import KNOWN_VARIETIES

# NASC tag colours by seed class. (Breeder seed tags are yellow; the three
# below are the classes a farmer is most likely to be handed.)
SEED_CLASSES: Dict[str, Tuple[int, int, int]] = {
    "CERTIFIED": (206, 224, 245),   # blue
    "FOUNDATION": (245, 243, 235),  # white
    "REGISTERED": (226, 214, 240),  # purple
}

PRODUCERS = [
    "PREMIER SEED NIGERIA LTD",
    "MAINA SEEDS COMPANY",
    "VALUE SEEDS LTD",
    "DA-ALL GREEN SEEDS LTD",
    "TECHNISEM NIGERIA",
]

# The value only: the tag draws its own "LOT NUMBER :" label, so a format
# carrying a second label would render "LOT NUMBER : BATCH NO: …", which no
# real tag does.
LOT_FORMATS = ["BN-{year}-{n:03d}", "LOT-{year}-{n:03d}", "{year}{n:04d}"]
DATE_FORMATS = ["%d/%m/%Y", "%d-%m-%Y", "%Y-%m-%d", "%d %b %Y"]


def _font(size: int) -> ImageFont.FreeTypeFont:
    """A TrueType face at a size a phone camera can resolve.

    PIL's default bitmap font is about 11 px; after rotation and thresholding
    Tesseract misreads it, which measures the renderer rather than the parser.
    """
    import matplotlib.font_manager as fm

    return ImageFont.truetype(fm.findfont(fm.FontProperties(family="DejaVu Sans")), size)


def _date(rng: random.Random) -> Tuple[str, str]:
    """(rendered date, ISO ground truth)."""
    import datetime

    day = datetime.date(rng.randint(2022, 2026), rng.randint(1, 12), rng.randint(1, 28))
    fmt = rng.choice(DATE_FORMATS)
    return day.strftime(fmt), day.isoformat()


def _lot(rng: random.Random) -> str:
    fmt = rng.choice(LOT_FORMATS)
    return fmt.format(year=rng.randint(2022, 2026), n=rng.randint(1, 999))


def make_record(rng: random.Random) -> Dict:
    """The ground truth for one tag."""
    variety = rng.choice(KNOWN_VARIETIES)
    seed_class = rng.choice(list(SEED_CLASSES))
    rendered_date, iso_date = _date(rng)
    lot = _lot(rng)
    return {
        "crop_variety": variety,
        "seed_class": seed_class,
        "lot_number": lot,
        "producer": rng.choice(PRODUCERS),
        "net_weight_kg": rng.choice([1, 2, 5, 10, 25]),
        "purity_pct": round(rng.uniform(97.0, 99.9), 1),
        "inert_matter_pct": round(rng.uniform(0.1, 2.0), 1),
        "germination_pct": rng.randint(85, 99),
        "moisture_pct": round(rng.uniform(8.0, 13.0), 1),
        "test_date_rendered": rendered_date,
        "planting_date": iso_date,
    }


def render_tag(record: Dict, rng: random.Random) -> Image.Image:
    """Draws the tag, then photographs it badly."""
    width, height = 1100, 620
    image = Image.new("RGB", (width, height), color=SEED_CLASSES[record["seed_class"]])
    draw = ImageDraw.Draw(image)
    draw.rectangle([12, 12, width - 12, height - 12], outline=(60, 60, 60), width=3)

    title = _font(28)
    body = _font(30)
    small = _font(24)

    draw.text((40, 28), "NATIONAL AGRICULTURAL SEEDS COUNCIL", fill=(20, 20, 20), font=title)
    draw.text((40, 68), f"{record['seed_class']} SEED", fill=(20, 20, 90), font=small)

    lines = [
        f"CROP VARIETY : {record['crop_variety']}",
        f"LOT NUMBER   : {record['lot_number']}",
        f"SOWING DATE  : {record['test_date_rendered']}",
        f"PRODUCER     : {record['producer']}",
        f"NET WEIGHT   : {record['net_weight_kg']} KG",
        f"PURITY       : {record['purity_pct']}%   INERT: {record['inert_matter_pct']}%",
        f"GERMINATION  : {record['germination_pct']}%   MOISTURE: {record['moisture_pct']}%",
    ]
    y = 120
    for line in lines:
        draw.text((40, y), line, fill=(25, 25, 25), font=body)
        y += 62

    return _photograph(image, rng)


def _photograph(image: Image.Image, rng: random.Random) -> Image.Image:
    """Rotation, perspective, blur, glare and JPEG noise — a phone in a field."""
    # Rotation: a hand-held shot is never square to the tag.
    image = image.rotate(rng.uniform(-6, 6), expand=True, fillcolor=(250, 250, 250),
                         resample=Image.BILINEAR)

    # Perspective: the tag is rarely parallel to the sensor.
    width, height = image.size
    shift = rng.uniform(0.01, 0.05) * width
    coeffs = _perspective_coefficients(
        [(0, 0), (width, 0), (width, height), (0, height)],
        [(shift, 0), (width - shift * 0.5, rng.uniform(0, shift)),
         (width, height - shift * 0.5), (rng.uniform(0, shift), height)],
    )
    image = image.transform((width, height), Image.PERSPECTIVE, coeffs,
                            Image.BILINEAR, fillcolor=(250, 250, 250))

    if rng.random() < 0.6:
        image = image.filter(ImageFilter.GaussianBlur(radius=rng.uniform(0.3, 1.2)))

    # Glare: a bright patch, as from sun on a laminated tag.
    if rng.random() < 0.5:
        glare = Image.new("L", image.size, 0)
        gdraw = ImageDraw.Draw(glare)
        cx, cy = rng.randint(0, width), rng.randint(0, height)
        radius = rng.randint(120, 320)
        gdraw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
                      fill=rng.randint(60, 140))
        glare = glare.filter(ImageFilter.GaussianBlur(radius=80))
        image = Image.composite(Image.new("RGB", image.size, (255, 255, 255)), image, glare)

    # Sensor noise, then JPEG compression on save.
    array = np.array(image).astype(np.int16)
    array += rng.randint(2, 8) * np.random.default_rng(rng.randint(0, 2**31)).normal(
        0, 1, array.shape).astype(np.int16)
    return Image.fromarray(np.clip(array, 0, 255).astype(np.uint8))


def _perspective_coefficients(source, target):
    """Coefficients PIL needs to map `source` corners onto `target` corners."""
    matrix = []
    for (sx, sy), (tx, ty) in zip(source, target):
        matrix.append([tx, ty, 1, 0, 0, 0, -sx * tx, -sx * ty])
        matrix.append([0, 0, 0, tx, ty, 1, -sy * tx, -sy * ty])
    a = np.array(matrix, dtype=np.float64)
    b = np.array(source, dtype=np.float64).reshape(8)
    return np.linalg.solve(a, b).tolist()


def generate(n: int = 200, seed: int = 42, out_dir: Path = Path("data/synthetic/seed_tags")) -> Path:
    """Writes `n` tags plus `ground_truth.json`. The same seed gives the same set."""
    out_dir = Path(out_dir)
    images_dir = out_dir / "images"
    images_dir.mkdir(parents=True, exist_ok=True)

    rng = random.Random(seed)
    records: List[Dict] = []
    for i in range(n):
        record = make_record(rng)
        image = render_tag(record, rng)
        name = f"tag_{i:04d}.jpg"
        image.save(images_dir / name, quality=rng.randint(55, 92))
        records.append({"image": f"images/{name}", **record})

    truth = out_dir / "ground_truth.json"
    truth.write_text(json.dumps(
        {
            "_description": "Synthetic NASC-style seed tags for OCR evaluation (T51). "
                            "Test data only — never used for training.",
            "seed": seed,
            "count": n,
            "records": records,
        },
        indent=2,
    ) + "\n")
    print(f"Wrote {n} tags → {images_dir}")
    print(f"Ground truth → {truth}")
    return truth


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--n", type=int, default=200)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--out", type=Path, default=Path("data/synthetic/seed_tags"))
    args = parser.parse_args(argv)
    generate(args.n, args.seed, args.out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
