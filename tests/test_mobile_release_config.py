"""
Release-configuration checks for the Flutter app (T04 / ADR-005).
Guards against shipping an Android release build without network/GPS
permissions, silently debug-signed, or with mismatched app identifiers.
"""

import re
from pathlib import Path

MOBILE     = Path(__file__).resolve().parents[1] / "mobile"
MANIFEST   = MOBILE / "android/app/src/main/AndroidManifest.xml"
GRADLE     = MOBILE / "android/app/build.gradle.kts"
PBXPROJ    = MOBILE / "ios/Runner.xcodeproj/project.pbxproj"
MAP_SCREEN = MOBILE / "lib/screens/map_screen.dart"
APP_ID     = "com.ahmaddev.maizeguard"


def test_main_manifest_declares_permissions_release_builds_need():
    declared = set(re.findall(r'uses-permission\s+android:name="([^"]+)"', MANIFEST.read_text()))
    required = {
        "android.permission.INTERNET",
        "android.permission.ACCESS_FINE_LOCATION",
        "android.permission.ACCESS_COARSE_LOCATION",
        "android.permission.CAMERA",
    }
    assert not required - declared, f"missing from main manifest: {sorted(required - declared)}"


def test_android_and_ios_use_one_app_id():
    gradle = GRADLE.read_text()
    assert f'applicationId = "{APP_ID}"' in gradle
    assert f'namespace = "{APP_ID}"' in gradle

    bundle_ids = set(re.findall(r"PRODUCT_BUNDLE_IDENTIFIER = ([\w.]+);", PBXPROJ.read_text()))
    assert bundle_ids == {APP_ID, f"{APP_ID}.RunnerTests"}


def test_main_activity_package_matches_namespace():
    activity = MOBILE / "android/app/src/main/kotlin" / Path(*APP_ID.split(".")) / "MainActivity.kt"
    assert activity.exists(), f"expected {activity.relative_to(MOBILE)}"
    assert activity.read_text().startswith(f"package {APP_ID}\n")


def test_release_build_requires_a_keystore_or_explicit_debug_opt_in():
    gradle = GRADLE.read_text()
    assert 'rootProject.file("key.properties")' in gradle
    assert "MAIZEGUARD_ALLOW_DEBUG_SIGNING" in gradle
    assert "GradleException" in gradle


def test_release_shrinking_has_rules_for_optional_mlkit_and_tflite_classes():
    rules = (MOBILE / "android/app/proguard-rules.pro").read_text()
    assert '"proguard-rules.pro"' in GRADLE.read_text()
    assert "-dontwarn com.google.mlkit.vision.text.chinese.**" in rules
    assert "-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options" in rules


def test_map_tiles_identify_the_app_and_show_osm_attribution():
    source = MAP_SCREEN.read_text()
    assert f"userAgentPackageName: '{APP_ID}'" in source
    assert "SimpleAttributionWidget" in source
    assert "OpenStreetMap contributors" in source
