"""
Phase 5 — UAV Flight Mission Planner
Generates a grid survey mission (waypoints) over a farm polygon and writes a
MAVLink-compatible mission file readable by Mission Planner / QGroundControl.

Usage:
    python -m src.phase5_uav.flight_planner \
        --farm-geojson  data/uav/farm_boundary.geojson \
        --altitude      30 \
        --overlap       80 \
        --sidelap       70 \
        --output        data/uav/mission.waypoints

The planner computes:
  1. Bounding box of the farm polygon
  2. Camera footprint at the requested altitude given sensor specs
  3. Row spacing (from sidelap) and column spacing (from overlap)
  4. Grid waypoints in WGS-84 lat/lon
  5. MAVLink MISSION_ITEM records (QGC format)

Hardware assumptions (DJI Phantom 4 / Mavic equivalents — override via --fov):
    Sensor width : 6.17 mm  (1/2.3" CMOS)
    Focal length : 3.6 mm
    Image width  : 4000 px   (12 MP)
    Image height : 3000 px
    GSD at 30 m  : ≈ 1.3 cm/px
"""
from __future__ import annotations

import argparse
import json
import math
import os
from dataclasses import dataclass, field
from typing import List, Tuple

# ── Camera model ──────────────────────────────────────────────────────────────

@dataclass
class Camera:
    sensor_width_mm: float  = 6.17
    sensor_height_mm: float = 4.55
    focal_length_mm: float  = 3.6
    image_width_px: int     = 4000
    image_height_px: int    = 3000

    def footprint_m(self, altitude_m: float) -> Tuple[float, float]:
        """Returns (width_m, height_m) ground footprint at given altitude."""
        w = altitude_m * self.sensor_width_mm  / self.focal_length_mm
        h = altitude_m * self.sensor_height_mm / self.focal_length_mm
        return w, h

    def gsd_cm(self, altitude_m: float) -> float:
        """Ground sampling distance in cm/px."""
        return (altitude_m * self.sensor_width_mm / self.focal_length_mm
                / self.image_width_px * 100)


# ── Geometry helpers ──────────────────────────────────────────────────────────

def _bbox(coords: List[Tuple[float, float]]) -> Tuple[float, float, float, float]:
    """(min_lon, min_lat, max_lon, max_lat)"""
    lons = [c[0] for c in coords]
    lats = [c[1] for c in coords]
    return min(lons), min(lats), max(lons), max(lats)

def _deg_to_m(delta_deg: float, ref_lat: float, axis: str) -> float:
    """Approximate degrees → metres at reference latitude."""
    if axis == "lat":
        return delta_deg * 111_320
    else:
        return delta_deg * 111_320 * math.cos(math.radians(ref_lat))

def _m_to_deg(metres: float, ref_lat: float, axis: str) -> float:
    if axis == "lat":
        return metres / 111_320
    else:
        return metres / (111_320 * math.cos(math.radians(ref_lat)))


# ── Waypoint generation ───────────────────────────────────────────────────────

@dataclass
class Waypoint:
    lat: float
    lon: float
    alt: float
    index: int = 0


def generate_grid(
    coords: List[Tuple[float, float]],
    altitude_m: float,
    overlap_pct: float,
    sidelap_pct: float,
    camera: Camera,
) -> List[Waypoint]:
    """
    Generate a boustrophedon (snake) grid of waypoints over the farm boundary.

    Returns a list of Waypoints in flight order, starting from the SW corner.
    """
    min_lon, min_lat, max_lon, max_lat = _bbox(coords)
    ref_lat = (min_lat + max_lat) / 2

    fw, fh = camera.footprint_m(altitude_m)

    # Spacing between photo captures (along track) and between rows (cross track)
    along_spacing_m = fw * (1 - overlap_pct  / 100)
    cross_spacing_m = fh * (1 - sidelap_pct / 100)

    farm_width_m  = _deg_to_m(max_lon - min_lon, ref_lat, "lon")
    farm_height_m = _deg_to_m(max_lat - min_lat, ref_lat, "lat")

    n_rows = max(1, math.ceil(farm_height_m / cross_spacing_m) + 1)
    n_cols = max(1, math.ceil(farm_width_m  / along_spacing_m) + 1)

    waypoints: List[Waypoint] = []
    idx = 0

    for row in range(n_rows):
        lat = min_lat + _m_to_deg(row * cross_spacing_m, ref_lat, "lat")
        col_range = range(n_cols) if row % 2 == 0 else range(n_cols - 1, -1, -1)
        for col in col_range:
            lon = min_lon + _m_to_deg(col * along_spacing_m, ref_lat, "lon")
            waypoints.append(Waypoint(lat=lat, lon=lon, alt=altitude_m, index=idx))
            idx += 1

    return waypoints


# ── MAVLink mission writer ────────────────────────────────────────────────────

def write_mission(waypoints: List[Waypoint], home: Tuple[float, float],
                  altitude_m: float, output_path: str) -> None:
    """
    Write a QGroundControl-compatible .waypoints file.

    Format (tab-separated):
    INDEX CURRENT FRAME CMD P1 P2 P3 P4 LAT LON ALT AUTOCONTINUE
    """
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    lines = ["QGC WPL 110"]

    # Home / take-off waypoint (index 0)
    home_lat, home_lon = home
    lines.append(
        f"0\t1\t0\t16\t0\t0\t0\t0\t{home_lat:.7f}\t{home_lon:.7f}\t{altitude_m:.1f}\t1"
    )

    for wp in waypoints:
        # MAV_CMD_NAV_WAYPOINT = 16
        lines.append(
            f"{wp.index + 1}\t0\t3\t16\t0\t0\t0\t0\t"
            f"{wp.lat:.7f}\t{wp.lon:.7f}\t{wp.alt:.1f}\t1"
        )

    # Return to launch
    rtl_idx = len(waypoints) + 1
    lines.append(f"{rtl_idx}\t0\t3\t20\t0\t0\t0\t0\t0\t0\t0\t1")

    with open(output_path, "w") as f:
        f.write("\n".join(lines) + "\n")

    print(f"Mission saved: {output_path}  ({len(waypoints)} waypoints + RTL)")


# ── Summary ───────────────────────────────────────────────────────────────────

def print_summary(waypoints: List[Waypoint], camera: Camera,
                  altitude_m: float, overlap: float, sidelap: float) -> None:
    fw, fh = camera.footprint_m(altitude_m)
    gsd    = camera.gsd_cm(altitude_m)
    area_m2 = (
        (_deg_to_m(
            max(wp.lon for wp in waypoints) - min(wp.lon for wp in waypoints),
            (max(wp.lat for wp in waypoints) + min(wp.lat for wp in waypoints)) / 2,
            "lon") ) *
        _deg_to_m(
            max(wp.lat for wp in waypoints) - min(wp.lat for wp in waypoints),
            (max(wp.lat for wp in waypoints) + min(wp.lat for wp in waypoints)) / 2,
            "lat")
    )
    print("\n──── Flight plan summary ────────────────────────────")
    print(f"  Altitude         : {altitude_m} m AGL")
    print(f"  GSD              : {gsd:.2f} cm/px")
    print(f"  Footprint        : {fw:.1f} m × {fh:.1f} m")
    print(f"  Overlap / sidelap: {overlap}% / {sidelap}%")
    print(f"  Coverage area    : {area_m2 / 10_000:.2f} ha")
    print(f"  Total waypoints  : {len(waypoints)}")
    print("─────────────────────────────────────────────────────\n")


# ── CLI ───────────────────────────────────────────────────────────────────────

def _parse_args():
    p = argparse.ArgumentParser(description="Maize UAV Flight Planner")
    p.add_argument("--farm-geojson", default="data/uav/farm_boundary.geojson",
                   help="GeoJSON file with farm polygon (Polygon or Feature)")
    p.add_argument("--altitude",  type=float, default=30, help="Flight altitude AGL (m)")
    p.add_argument("--overlap",   type=float, default=80, help="Forward overlap %%")
    p.add_argument("--sidelap",   type=float, default=70, help="Side overlap %%")
    p.add_argument("--output",    default="data/uav/mission.waypoints")
    p.add_argument("--demo",      action="store_true",
                   help="Use a built-in demo farm polygon (no GeoJSON needed)")
    return p.parse_args()


def _demo_polygon() -> List[Tuple[float, float]]:
    """1-hectare demo farm near Ibadan, Nigeria."""
    base_lat, base_lon = 7.3775, 3.9470
    delta = 0.0045  # ≈ 500 m
    return [
        (base_lon,          base_lat         ),
        (base_lon + delta,  base_lat         ),
        (base_lon + delta,  base_lat + delta ),
        (base_lon,          base_lat + delta ),
        (base_lon,          base_lat         ),
    ]


def main():
    args = _parse_args()

    if args.demo:
        coords = _demo_polygon()
        home   = (coords[0][1], coords[0][0])   # (lat, lon)
        print("Using demo farm polygon near Ibadan, Nigeria.")
    else:
        with open(args.farm_geojson) as f:
            gj = json.load(f)
        # Accept FeatureCollection, Feature, or bare Polygon
        geom = gj
        if gj.get("type") == "FeatureCollection":
            geom = gj["features"][0]["geometry"]
        elif gj.get("type") == "Feature":
            geom = gj["geometry"]
        coords = geom["coordinates"][0]          # outer ring
        home   = (coords[0][1], coords[0][0])

    camera = Camera()
    waypoints = generate_grid(coords, args.altitude, args.overlap, args.sidelap, camera)
    print_summary(waypoints, camera, args.altitude, args.overlap, args.sidelap)
    write_mission(waypoints, home, args.altitude, args.output)


if __name__ == "__main__":
    main()
