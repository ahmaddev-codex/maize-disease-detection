"""
Unit tests for Phase 5 UAV Flight Path Planner.
"""

import pytest
from src.phase5_uav.flight_planner import Camera, Waypoint, generate_grid


def test_camera_footprint():
    cam = Camera(sensor_width_mm=6.17, sensor_height_mm=4.55, focal_length_mm=3.6)
    w, h = cam.footprint_m(altitude_m=30)
    gsd = cam.gsd_cm(altitude_m=30)

    assert w > 0
    assert h > 0
    assert gsd > 0


def test_flight_plan_grid_generation():
    cam = Camera()
    coords = [
        (3.9000, 7.4500),
        (3.9020, 7.4500),
        (3.9020, 7.4520),
        (3.9000, 7.4520),
    ]

    waypoints = generate_grid(
        coords=coords,
        altitude_m=30,
        overlap_pct=80,
        sidelap_pct=70,
        camera=cam,
    )
    assert len(waypoints) > 0

    for wp in waypoints:
        assert isinstance(wp, Waypoint)
        assert wp.alt == 30
        assert 7.44 <= wp.lat <= 7.46
        assert 3.89 <= wp.lon <= 3.91
