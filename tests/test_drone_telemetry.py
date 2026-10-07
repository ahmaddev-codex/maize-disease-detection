"""T40: one capture, classified once, when the drone actually reaches a point.

The loop watched MISSION_CURRENT — which ArduPilot sets when it *starts*
flying to a waypoint — and then classified whatever file in the capture
directory happened to be newest. With a slow camera that is the previous
waypoint's photo, posted again under the new waypoint's number.
"""
import os
import time

import pytest

from src.phase5_uav.drone_telemetry import CaptureTracker, MISSION_REACHED_MESSAGE


class FakeMessage:
    def __init__(self, mtype, **fields):
        self._type = mtype
        self.__dict__.update(fields)

    def get_type(self):
        return self._type


@pytest.fixture()
def capture_dir(tmp_path):
    return tmp_path


def write_capture(directory, name, mtime=None):
    path = directory / name
    path.write_bytes(b"jpeg bytes")
    if mtime is not None:
        os.utime(path, (mtime, mtime))
    return str(path)


def test_the_trigger_is_the_waypoint_reached_event():
    assert MISSION_REACHED_MESSAGE == "MISSION_ITEM_REACHED"


def test_a_new_capture_is_returned_once(capture_dir):
    first = write_capture(capture_dir, "0001.jpg", mtime=time.time() - 60)
    tracker = CaptureTracker(str(capture_dir))

    assert tracker.next_capture() == first
    assert tracker.next_capture() is None, "the same capture was handed out twice"


def test_only_captures_newer_than_the_last_one_are_taken(capture_dir):
    now = time.time()
    write_capture(capture_dir, "0001.jpg", mtime=now - 60)
    tracker = CaptureTracker(str(capture_dir))
    tracker.next_capture()

    older = write_capture(capture_dir, "0000.jpg", mtime=now - 120)
    assert tracker.next_capture() is None, "an older capture was reprocessed"

    newer = write_capture(capture_dir, "0002.jpg", mtime=now)
    assert tracker.next_capture() == newer
    assert older not in (tracker.last_capture or "")


def test_no_capture_at_all_is_not_an_error(capture_dir):
    tracker = CaptureTracker(str(capture_dir))
    assert tracker.next_capture() is None


def test_a_missing_directory_is_reported_not_crashed(tmp_path):
    tracker = CaptureTracker(str(tmp_path / "never-created"))
    assert tracker.next_capture() is None


def test_two_captures_with_the_same_timestamp_are_both_seen(capture_dir):
    stamp = time.time() - 10
    a = write_capture(capture_dir, "a.jpg", mtime=stamp)
    b = write_capture(capture_dir, "b.jpg", mtime=stamp)
    tracker = CaptureTracker(str(capture_dir))

    taken = {tracker.next_capture(), tracker.next_capture()}
    assert taken == {a, b}
    assert tracker.next_capture() is None


def test_a_partially_written_capture_is_skipped_until_it_settles(capture_dir):
    path = capture_dir / "in_flight.jpg"
    path.write_bytes(b"")  # camera has created the file but not written it yet
    tracker = CaptureTracker(str(capture_dir))

    assert tracker.next_capture() is None, "an empty file was classified"

    path.write_bytes(b"jpeg bytes")
    assert tracker.next_capture() == str(path)


def test_the_waypoint_handler_posts_once_per_new_capture(capture_dir):
    from src.phase5_uav.drone_telemetry import handle_waypoint_reached

    posted = []
    write_capture(capture_dir, "0001.jpg", mtime=time.time() - 5)
    tracker = CaptureTracker(str(capture_dir))
    snapshot = {"lat": 7.38, "lon": 3.94}

    def classify(path):
        return {"class_id": 1, "class_name": "Rust", "confidence": 0.9,
                "scores": [0.03, 0.9, 0.04, 0.03], "latency_ms": 120.0}

    first = handle_waypoint_reached(
        seq=3, tracker=tracker, classify=classify, snapshot=snapshot,
        post=lambda payload: posted.append(payload) or True,
    )
    assert first is not None
    assert posted[0]["waypoint"] == 3
    assert posted[0]["class_name"] == "Rust"

    # Same waypoint event again, no new photo: nothing is posted.
    again = handle_waypoint_reached(
        seq=4, tracker=tracker, classify=classify, snapshot=snapshot,
        post=lambda payload: posted.append(payload) or True,
    )
    assert again is None
    assert len(posted) == 1, "a capture was posted twice"


def test_a_failed_classification_posts_nothing(capture_dir):
    from src.phase5_uav.drone_telemetry import handle_waypoint_reached

    posted = []
    write_capture(capture_dir, "0001.jpg", mtime=time.time() - 5)
    tracker = CaptureTracker(str(capture_dir))

    result = handle_waypoint_reached(
        seq=1, tracker=tracker, classify=lambda path: None, snapshot={"lat": 0, "lon": 0},
        post=lambda payload: posted.append(payload) or True,
    )

    assert result is None
    assert posted == []


def test_labels_come_from_the_shared_table():
    from src.phase5_uav import drone_telemetry
    from src.common.labels import SHORT_NAMES

    assert drone_telemetry.CLASS_NAMES == SHORT_NAMES
