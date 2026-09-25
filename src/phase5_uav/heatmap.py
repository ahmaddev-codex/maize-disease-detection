"""
Phase 5 — UAV Disease Heatmap Generator
Reads the patch prediction CSV from patch_runner.py and produces an interactive
Folium map (HTML) and a static matplotlib figure with disease overlays.

Usage:
    python -m deployment.uav.heatmap \
        --csv    data/uav/patch_predictions.csv \
        --output data/uav/disease_heatmap.html

    # Quick demo — generates synthetic predictions first:
    python -m deployment.uav.heatmap --demo

Outputs:
    data/uav/disease_heatmap.html   — interactive Folium map (open in browser)
    data/uav/disease_heatmap.png    — static overview figure (for reports)
    data/uav/<output stem>_summary.json — aggregate disease stats per class
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import random
from collections import Counter, defaultdict
from typing import Any, Dict, List, Optional

# ── Optional deps — graceful degradation ─────────────────────────────────────
try:
    import folium
    from folium.plugins import HeatMap, MarkerCluster
    HAS_FOLIUM = True
except ImportError:
    HAS_FOLIUM = False
    folium: Any = None
    HeatMap: Any = None
    MarkerCluster: Any = None
    print("Warning: folium not installed. Interactive HTML map will be skipped.")
    print("  Install: pip install folium")

try:
    import matplotlib
    # Deliberately not calling matplotlib.use() here: importing this module in
    # a notebook used to switch that notebook to Agg (T38). main() sets it.
    import matplotlib.pyplot as plt
    import matplotlib.patches as mpatches
    from matplotlib.colors import to_rgba
    HAS_MPL = True
except ImportError:
    HAS_MPL = False
    matplotlib: Any = None
    plt: Any = None
    mpatches: Any = None
    to_rgba: Any = None
    print("Warning: matplotlib not installed. Static PNG will be skipped.")

# ── Class styling ─────────────────────────────────────────────────────────────

CLASS_INFO = {
    "NCLB":    {"color": "#e74c3c", "label": "NCLB (N. Corn Leaf Blight)", "severity": "high"},
    "Rust":    {"color": "#e67e22", "label": "Rust (Common Rust)",          "severity": "medium"},
    "GLS":     {"color": "#f1c40f", "label": "GLS (Gray Leaf Spot)",        "severity": "medium"},
    "Healthy": {"color": "#2ecc71", "label": "Healthy",                     "severity": "low"},
}

CONFIDENCE_THRESHOLDS = {"high": 0.80, "medium": 0.55}


# ── CSV loading ───────────────────────────────────────────────────────────────

def _optional_float(value) -> Optional[float]:
    if value in (None, ""):
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def load_predictions(csv_path: str) -> List[Dict[str, Any]]:
    """Reads a patch prediction CSV.

    Coordinates are optional: a survey of a non-georeferenced image reports
    pixel positions only (T39), and the class summary is still worth having.
    """
    with open(csv_path, newline="") as f:
        reader = csv.DictReader(f)
        rows = []
        for r in reader:
            rows.append({
                "patch_row":  int(r["patch_row"]),
                "patch_col":  int(r["patch_col"]),
                "lat":        _optional_float(r.get("lat")),
                "lon":        _optional_float(r.get("lon")),
                "class_id":   int(r["class_id"]),
                "class_name": r["class_name"],
                "confidence": float(r["confidence"]),
                "latency_ms": _optional_float(r.get("latency_ms")),
            })
    return rows


def _located(predictions: List[Dict]) -> List[Dict]:
    """Only the patches that have coordinates to put on a map."""
    return [p for p in predictions
            if p.get("lat") is not None and p.get("lon") is not None]


def make_demo_predictions(n: int = 200) -> List[Dict[str, Any]]:
    """Invented predictions for a demo map.

    Every row carries synthetic=True and no latency: these numbers have never
    been measured and must never appear in a report as if they had (T38).
    """
    rng = random.Random(42)
    base_lat, base_lon = 7.3775, 3.9470
    classes = ["NCLB", "Rust", "GLS", "Healthy"]
    weights = [0.20, 0.25, 0.15, 0.40]
    rows = []
    for i in range(n):
        cls = rng.choices(classes, weights)[0]
        rows.append({
            "patch_row":  i // 20,
            "patch_col":  i % 20,
            "lat":        base_lat + rng.uniform(-0.002, 0.002),
            "lon":        base_lon + rng.uniform(-0.003, 0.003),
            "class_id":   classes.index(cls),
            "class_name": cls,
            "confidence": rng.uniform(0.55, 0.99),
            "synthetic":  True,
        })
    return rows


# ── Folium interactive map ────────────────────────────────────────────────────

def build_folium_map(predictions: List[Dict], output_html: str = "") -> Any:
    if not HAS_FOLIUM:
        return None

    predictions = _located(predictions)
    if not predictions:
        print("No patch has coordinates, so no map was drawn. "
              "Re-run the patch runner on a georeferenced image, or pass "
              "--origin-lat/--origin-lon/--gsd.")
        return None

    lats = [p["lat"] for p in predictions]
    lons = [p["lon"] for p in predictions]
    centre = (sum(lats) / len(lats), sum(lons) / len(lons))

    m = folium.Map(
        location=centre,
        zoom_start=17,
        tiles="https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
        attr="Esri",
    )

    # ── Disease heatmap layer (non-healthy patches weighted by confidence) ──
    heat_data = [
        [p["lat"], p["lon"], p["confidence"]]
        for p in predictions
        if p["class_name"] != "Healthy"
    ]
    if heat_data:
        HeatMap(
            heat_data,
            name="Disease intensity",
            min_opacity=0.3,
            max_zoom=18,
            radius=18,
            blur=15,
            gradient={"0.0": "green", "0.5": "yellow", "0.8": "orange", "1.0": "red"},
        ).add_to(m)

    # ── Per-class marker clusters ──────────────────────────────────────────
    cluster_groups: Dict[str, Any] = {}
    for cls in CLASS_INFO:
        fg = folium.FeatureGroup(name=cls, show=(cls != "Healthy"))
        cluster_groups[cls] = MarkerCluster().add_to(fg)
        fg.add_to(m)

    for p in predictions:
        cls   = p["class_name"]
        info  = CLASS_INFO.get(cls, CLASS_INFO["Healthy"])
        conf  = p["confidence"]
        if conf < CONFIDENCE_THRESHOLDS.get("medium", 0.55):
            continue   # skip low-confidence detections from the marker layer

        popup_html = f"""
        <div style="font-family:monospace;font-size:12px;min-width:180px">
          <b style="color:{info['color']}">{info['label']}</b><br>
          Confidence : {conf:.1%}<br>
          Severity   : {info['severity'].upper()}<br>
          Lat / Lon  : {p['lat']:.5f}, {p['lon']:.5f}<br>
          Patch      : row {p['patch_row']}, col {p['patch_col']}<br>
          Latency    : {p['latency_ms']:.0f} ms
        </div>"""
        folium.CircleMarker(
            location=(p["lat"], p["lon"]),
            radius=6 if conf > CONFIDENCE_THRESHOLDS["high"] else 4,
            color=info["color"],
            fill=True,
            fill_color=info["color"],
            fill_opacity=0.7,
            popup=folium.Popup(popup_html, max_width=240),
            tooltip=f"{cls} ({conf:.0%})",
        ).add_to(cluster_groups[cls])

    # ── Legend ─────────────────────────────────────────────────────────────
    legend_html = """
    <div style="position:fixed;bottom:30px;left:30px;z-index:9999;
                background:rgba(255,255,255,0.92);padding:12px 16px;
                border-radius:8px;border:1px solid #ccc;
                font-family:monospace;font-size:12px;box-shadow:2px 2px 6px rgba(0,0,0,.3)">
      <b>MaizeGuard — Disease Map</b><br><br>"""
    for cls, info in CLASS_INFO.items():
        legend_html += (
            f'<span style="background:{info["color"]};display:inline-block;'
            f'width:12px;height:12px;border-radius:50%;margin-right:6px"></span>'
            f'{info["label"]}<br>'
        )
    legend_html += "</div>"
    getattr(m.get_root(), "html").add_child(folium.Element(legend_html))

    folium.LayerControl(collapsed=False).add_to(m)

    if output_html:
        os.makedirs(os.path.dirname(output_html) or ".", exist_ok=True)
        m.save(output_html)
        print(f"Interactive map saved: {output_html}")
    return m


# ── Static matplotlib figure ──────────────────────────────────────────────────

def build_static_map(predictions: List[Dict], output_png: str) -> None:
    if not HAS_MPL:
        return

    predictions = _located(predictions)
    if not predictions:
        print(f"No patch has coordinates, so {output_png} was not drawn.")
        return

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 7),
                                   facecolor="#1a1a2e")
    fig.patch.set_facecolor("#1a1a2e")

    lats = [p["lat"] for p in predictions]
    lons = [p["lon"] for p in predictions]

    # Subplot 1: Categorical scatter
    ax1.set_facecolor("#16213e")
    ax1.set_title("Disease Class Distribution", color="white", fontsize=13, pad=10)
    for cls, info in CLASS_INFO.items():
        sub = [p for p in predictions if p["class_name"] == cls]
        if not sub:
            continue
        ax1.scatter(
            [p["lon"] for p in sub],
            [p["lat"] for p in sub],
            c=info["color"],
            label=f"{info['label']} (n={len(sub)})",
            s=35,
            alpha=0.85,
            edgecolors="none",
        )
    ax1.set_xlabel("Longitude", color="#aaa")
    ax1.set_ylabel("Latitude",  color="#aaa")
    ax1.tick_params(colors="#aaa")
    for spine in ax1.spines.values():
        spine.set_edgecolor("#444")
    ax1.legend(loc="upper right", facecolor="#1a1a2e", edgecolor="#444",
               labelcolor="white", fontsize=9)

    # Subplot 2: Density / confidence scatter (disease only)
    ax2.set_facecolor("#16213e")
    ax2.set_title("Disease Severity & Confidence", color="white", fontsize=13, pad=10)
    disease = [p for p in predictions if p["class_name"] != "Healthy"]
    if disease:
        dlats = [p["lat"] for p in disease]
        dlons = [p["lon"] for p in disease]
        confs = [p["confidence"] for p in disease]
        sc = ax2.scatter(dlons, dlats, c=confs, cmap="YlOrRd",
                         s=30, alpha=0.8, vmin=0.5, vmax=1.0, zorder=3)
        cbar = plt.colorbar(sc, ax=ax2)
        cbar.set_label("Confidence", color="white")
        cbar.ax.yaxis.set_tick_params(color="white")
        plt.setp(cbar.ax.yaxis.get_ticklabels(), color="white")
    ax2.set_xlabel("Longitude", color="#aaa")
    ax2.set_ylabel("Latitude",  color="#aaa")
    ax2.tick_params(colors="#aaa")
    for spine in ax2.spines.values():
        spine.set_edgecolor("#444")

    plt.tight_layout(rect=[0, 0.03, 1, 0.95])
    fig.suptitle("MaizeGuard UAV — Orthomosaic Disease Analysis",
                 color="white", fontsize=15, y=0.98)

    os.makedirs(os.path.dirname(output_png) or ".", exist_ok=True)
    plt.savefig(output_png, dpi=150, bbox_inches="tight", facecolor=fig.get_facecolor())
    plt.close()
    print(f"Static map saved: {output_png}")


# ── Summary JSON ──────────────────────────────────────────────────────────────

def _mean_latency(predictions: List[Dict]) -> Optional[float]:
    """Mean inference latency, or None when the predictions carry no timings."""
    timings = [p["latency_ms"] for p in predictions if p.get("latency_ms") is not None]
    if not timings:
        return None
    return round(sum(timings) / len(timings), 1)

def build_summary(predictions: List[Dict], output_json: str) -> Dict:
    total = len(predictions)
    counts = Counter(p["class_name"] for p in predictions)
    disease_counts = {k: v for k, v in counts.items() if k != "Healthy"}
    disease_total  = sum(disease_counts.values())

    by_class: Dict[str, list] = defaultdict(list)
    for p in predictions:
        by_class[p["class_name"]].append(p["confidence"])

    summary = {
        "total_patches": total,
        "disease_patches": disease_total,
        "healthy_patches": counts.get("Healthy", 0),
        "disease_rate_pct": round(disease_total / total * 100, 1) if total else 0,
        "classes": {
            cls: {
                "count": counts.get(cls, 0),
                "pct":   round(counts.get(cls, 0) / total * 100, 1) if total else 0,
                "mean_confidence": round(
                    sum(by_class[cls]) / len(by_class[cls]), 3
                ) if by_class[cls] else 0,
                "severity": CLASS_INFO.get(cls, {}).get("severity", "unknown"),
            }
            for cls in ["NCLB", "Rust", "GLS", "Healthy"]
        },
        # None, not 0: a run without timings should not report a latency (T38).
        "avg_latency_ms": _mean_latency(predictions),
        "recommendation": _recommend(disease_rate=disease_total / total if total else 0,
                                     counts=counts),
    }

    os.makedirs(os.path.dirname(output_json) or ".", exist_ok=True)
    with open(output_json, "w") as f:
        json.dump(summary, f, indent=2)
    print(f"Summary JSON saved: {output_json}")
    return summary


def summary_path_for(output_html: str) -> str:
    """The summary that belongs to a given map file.

    One place decides the name, so the docstring, the notebook and the CLI
    cannot drift apart (T38).
    """
    return os.path.splitext(output_html)[0] + "_summary.json"


def _recommend(disease_rate: float, counts: Counter) -> str:
    if disease_rate < 0.05:
        return "Field appears healthy. Continue routine scouting every 7-10 days."
    # Healthy is not a disease: counting it made a mostly healthy field report
    # "Dominant: Healthy" and refer the farmer to an agronomist (T38).
    diseased = Counter({k: v for k, v in counts.items() if k != "Healthy" and v})
    dominant = diseased.most_common(1)[0][0] if diseased else "unknown"
    recs = {
        "NCLB": "Apply foliar fungicide (mancozeb / azoxystrobin). Remove severely blighted leaves.",
        "Rust":  "Apply triazole fungicide (propiconazole) early. Rust spreads rapidly in cool humid conditions.",
        "GLS":   "Apply strobilurin fungicide. Increase plant spacing; remove crop debris after harvest.",
    }
    base = recs.get(dominant, "Consult agronomist for targeted treatment.")
    return f"{disease_rate:.0%} of field affected. Dominant: {dominant}. {base}"


def print_summary(summary: Dict) -> None:
    print("\n──── UAV survey summary ─────────────────────────────")
    print(f"  Total patches analysed : {summary['total_patches']}")
    print(f"  Disease patches        : {summary['disease_patches']}  ({summary['disease_rate_pct']}%)")
    print(f"  Avg inference latency  : {summary['avg_latency_ms']} ms/patch")
    print()
    for cls, info in summary["classes"].items():
        bar = "█" * max(0, int(info["pct"] / 2))
        print(f"  {cls:<8} {info['count']:4d} ({info['pct']:5.1f}%)  {bar}")
    print()
    print(f"  Recommendation: {summary['recommendation']}")
    print("─────────────────────────────────────────────────────\n")


# ── CLI ───────────────────────────────────────────────────────────────────────

def _parse_args():
    p = argparse.ArgumentParser(description="MaizeGuard UAV Heatmap Generator")
    p.add_argument("--csv",    default="data/uav/patch_predictions.csv")
    p.add_argument("--output", default="data/uav/disease_heatmap.html")
    p.add_argument("--demo",   action="store_true",
                   help="Use synthetic demo predictions (no CSV needed)")
    return p.parse_args()


def main():
    args  = _parse_args()
    # Plotting to files, so force a headless backend here rather than at import.
    try:
        import matplotlib as _mpl

        _mpl.use("Agg")
    except ImportError:
        pass

    stem  = os.path.splitext(args.output)[0]
    out_html = args.output
    out_png  = stem + ".png"
    out_json = summary_path_for(args.output)

    if args.demo:
        print("Generating synthetic demo predictions (200 patches)...")
        predictions = make_demo_predictions(200)
    else:
        print(f"Loading predictions: {args.csv}")
        predictions = load_predictions(args.csv)

    if not predictions:
        print("No predictions found.")
        return

    build_folium_map(predictions, out_html)
    build_static_map(predictions, out_png)
    summary = build_summary(predictions, out_json)
    print_summary(summary)


if __name__ == "__main__":
    main()
