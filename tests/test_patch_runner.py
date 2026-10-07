"""T39: which patches are worth classifying, and where they actually are.

The vegetation filter skipped any patch whose mean red exceeded 1.5× mean
green, which is exactly what a rust-covered canopy looks like — the disease the
survey exists to find. And an image without georeferencing was given invented
coordinates near Ibadan, so a demo run produced a map of a field that was never
flown.
"""
import numpy as np
import pytest

from src.phase5_uav.patch_runner import (
    GeoTransform,
    excess_green,
    is_vegetation,
    patch_coordinates,
)


def patch_of(rgb, size=300):
    return np.full((size, size, 3), rgb, dtype=np.uint8)


def test_healthy_canopy_is_vegetation():
    assert is_vegetation(patch_of((60, 140, 50)))


def test_rust_flecked_canopy_is_still_vegetation():
    # Brick-red pustules scattered over green leaf — what rust looks like from
    # the air until the canopy is completely gone.
    patch = patch_of((60, 140, 50))
    patch[::3, ::2] = (165, 85, 45)
    assert is_vegetation(patch), "a rust-flecked patch was skipped"


def test_shaded_canopy_is_not_mistaken_for_background():
    # The rule this replaces skipped any patch whose mean green fell below
    # 5% of full scale, which threw away canopy in cloud shadow or a dark
    # exposure. Excess Green works on chromatic coordinates, so brightness
    # does not decide it.
    dark_canopy = patch_of((5, 12, 4))
    assert dark_canopy[:, :, 1].mean() < 0.05 * 255
    assert is_vegetation(dark_canopy)


def test_a_canopy_that_is_brown_overall_is_skipped_known_limitation():
    """Excess Green cannot separate a wholly brick-red canopy from bare soil.

    Recorded so the behaviour is deliberate rather than a surprise: patches
    this far gone are skipped, and a follow-up would need a texture or
    context cue to keep them (T39).
    """
    assert not is_vegetation(patch_of((165, 85, 45)))


def test_a_severely_blighted_patch_is_still_classified():
    # Tan, dried-out lesions covering most of the patch.
    patch = patch_of((70, 150, 60))
    patch[:, :220] = (190, 170, 120)
    assert is_vegetation(patch)


def test_road_and_sky_are_skipped():
    assert not is_vegetation(patch_of((128, 128, 128))), "grey road classified"
    assert not is_vegetation(patch_of((140, 170, 220))), "sky classified"
    assert not is_vegetation(patch_of((150, 120, 90))), "bare soil classified"


def test_excess_green_is_signed_and_scaled():
    green = excess_green(patch_of((0, 255, 0)))
    grey = excess_green(patch_of((128, 128, 128)))
    assert green.mean() > 0
    assert grey.mean() == pytest.approx(0, abs=1e-6)


class _Geo(GeoTransform):
    pass


def test_a_georeferenced_image_gives_coordinates():
    geo = GeoTransform(origin_lon=3.9, origin_lat=7.4, pixel_width=1e-5, pixel_height=-1e-5)
    lat, lon = patch_coordinates(geo, row=100, col=200)
    assert lat == pytest.approx(7.4 - 100e-5)
    assert lon == pytest.approx(3.9 + 200e-5)


def test_without_a_georeference_there_are_no_coordinates():
    lat, lon = patch_coordinates(None, row=100, col=200)
    assert lat is None and lon is None


def test_no_default_coordinates_are_invented():
    """GeoTransform.dummy used to default to a spot near Ibadan."""
    assert not hasattr(GeoTransform, "dummy"), "the invented-coordinates helper is back"


def test_an_origin_and_gsd_can_be_supplied_explicitly():
    geo = GeoTransform.from_origin_and_gsd(
        origin_lat=7.4, origin_lon=3.9, gsd_m=0.05, width_px=1000, height_px=800
    )
    centre_lat, centre_lon = patch_coordinates(geo, row=400, col=500)
    # The origin is the top-left corner, so the centre sits south and east of it.
    assert centre_lat < 7.4
    assert centre_lon > 3.9
    # 400 rows × 0.05 m ≈ 20 m ≈ 0.00018°
    assert 7.4 - centre_lat == pytest.approx(0.00018, abs=2e-5)


def test_rows_without_coordinates_omit_the_columns():
    from src.phase5_uav.patch_runner import result_row

    row = result_row(patch_row=1, patch_col=2, lat=None, lon=None,
                     class_id=1, confidence=0.9, latency_ms=12.0)
    assert "lat" not in row and "lon" not in row
    assert row["class_name"] == "Rust"


def test_utm_patch_centres_are_reprojected_to_wgs84():
    rasterio = pytest.importorskip("rasterio", reason="GeoTIFF support is optional (needs GDAL)")
    from src.phase5_uav.patch_runner import to_wgs84

    # UTM zone 31N, a point in south-western Nigeria.
    lat, lon = to_wgs84("EPSG:32631", 600000.0, 815000.0)
    assert 7.0 < lat < 7.6
    assert 3.0 < lon < 4.0
