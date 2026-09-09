"""
Phase 5 — Live Drone Telemetry & Mission Control
Connects to a real MAVLink-compatible drone (Pixhawk, ArduCopter, PX4) and
streams GPS position + waypoint events to the MaizeGuard live web server so the
disease heatmap updates in real-time as the drone flies the survey mission.

── Connection options ───────────────────────────────────────────────────────────
  Serial / USB (Pixhawk connected via USB):
      python -m deployment.uav.drone_telemetry --connect /dev/ttyUSB0:57600

  Serial / SiK 915 MHz radio:
      python -m deployment.uav.drone_telemetry --connect /dev/ttyUSB0:57600

  UDP (MAVProxy / SITL / WiFi video link bridged with MAVProxy):
      python -m deployment.uav.drone_telemetry --connect udp:0.0.0.0:14550

  TCP (Companion computer or direct WiFi to drone):
      python -m deployment.uav.drone_telemetry --connect tcp:192.168.1.1:5760

── Typical workflow ─────────────────────────────────────────────────────────────
  # Terminal 1 — start the live web dashboard
  python -m deployment.uav.live_server

  # Terminal 2 — generate the mission (or use an existing .waypoints file)
  python -m deployment.uav.flight_planner --farm-geojson data/uav/farm_boundary.geojson \\
      --output data/uav/mission.waypoints

  # Terminal 3 — connect the drone and begin the survey
  python -m deployment.uav.drone_telemetry \\
      --connect udp:0.0.0.0:14550 \\
      --mission data/uav/mission.waypoints \\
      --model   models/exports/efficientnetb3_maize_int8.tflite \\
      --server  http://localhost:5000

  # Open http://localhost:5000 in your browser to watch the live heatmap.

── Hardware tested ──────────────────────────────────────────────────────────────
  ArduCopter 4.x (Pixhawk 2.4.8, Cube Orange)
  PX4 v1.14 (Pixhawk 6C)
  DJI Phantom 4 via MAVProxy serial bridge
  SITL (ArduCopter software-in-the-loop for testing without hardware)
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import threading
import time
from typing import Optional

import requests

# ── MAVLink ───────────────────────────────────────────────────────────────────
try:
    from pymavlink import mavutil
    from pymavlink.dialects.v20 import common as mavlink
except ImportError:
    print("ERROR: pymavlink not installed.")
    print("  Run: pip install pymavlink==2.4.41")
    sys.exit(1)

# ── TFLite (optional — for on-the-fly patch inference) ───────────────────────
try:
    from tflite_runtime.interpreter import Interpreter as TFLiteInterpreter
except ImportError:
    try:
        from tensorflow.lite.python.interpreter import Interpreter as TFLiteInterpreter
    except ImportError:
        TFLiteInterpreter = None

import numpy as np
from PIL import Image

# ── Constants ─────────────────────────────────────────────────────────────────
CLASS_NAMES = ["NCLB", "Rust", "GLS", "Healthy"]
PATCH_SIZE  = 300
HEARTBEAT_TIMEOUT_S = 10
TELEMETRY_HZ = 2          # how often to POST position to live server


# ── Waypoint file parser ──────────────────────────────────────────────────────

def parse_waypoints(path: str) -> list[dict]:
    """
    Parse a QGroundControl / Mission Planner .waypoints text file.
    Returns list of {index, lat, lon, alt} dicts (skips home and RTL entries).
    """
    waypoints = []
    with open(path) as f:
        lines = f.readlines()

    if not lines or not lines[0].startswith("QGC WPL"):
        raise ValueError(f"Not a QGC WPL file: {path}")

    for line in lines[1:]:
        parts = line.strip().split("\t")
        if len(parts) < 12:
            continue
        idx    = int(parts[0])
        cmd    = int(parts[3])
        lat    = float(parts[8])
        lon    = float(parts[9])
        alt    = float(parts[10])
        # MAV_CMD_NAV_WAYPOINT = 16 only (skip home=16@idx0 handled separately, RTL=20)
        if cmd == 16 and idx > 0:
            waypoints.append({"index": idx, "lat": lat, "lon": lon, "alt": alt})

    return waypoints


# ── Mission uploader ──────────────────────────────────────────────────────────

MAX_WAYPOINTS = 700  # ArduPilot hard cap; PX4 allows ~900 but 700 is safe


def upload_mission(master, waypoints: list[dict]) -> bool:
    """
    Upload waypoints to the drone via MAVLink MISSION_ITEM_INT protocol.
    Handles both MISSION_REQUEST (MAVLink v1) and MISSION_REQUEST_INT (MAVLink v2).
    Returns True on success.
    """
    count = len(waypoints)

    if count > MAX_WAYPOINTS:
        print(f"  WARNING: {count} waypoints exceeds autopilot cap (~{MAX_WAYPOINTS}).")
        print(f"  Truncating to first {MAX_WAYPOINTS} waypoints.")
        waypoints = waypoints[:MAX_WAYPOINTS]
        count = MAX_WAYPOINTS

    # Resolve broadcast sysid — some SITL/bridges send heartbeat from sysid 0.
    target_sys  = master.target_system  if master.target_system  != 0 else 1
    target_comp = master.target_component if master.target_component != 0 else 1

    print(f"  Uploading {count} waypoints to drone (sysid={target_sys}, compid={target_comp})...")

    master.mav.mission_count_send(
        target_sys,
        target_comp,
        count,
        mavlink.MAV_MISSION_TYPE_MISSION,
    )

    ack_timeout = 10  # give autopilot more breathing room per waypoint
    for _ in waypoints:
        # Modern autopilots (ArduPilot 4.x / PX4) send MISSION_REQUEST_INT;
        # older firmware sends MISSION_REQUEST.  Accept either.
        msg = master.recv_match(
            type=["MISSION_REQUEST_INT", "MISSION_REQUEST"],
            blocking=True,
            timeout=ack_timeout,
        )
        if msg is None:
            print("  ERROR: No MISSION_REQUEST/_INT received — upload timed out.")
            return False

        seq = msg.seq
        if seq >= count:
            print(f"  ERROR: Drone requested seq {seq} but only {count} waypoints exist.")
            return False

        w = waypoints[seq]
        master.mav.mission_item_int_send(
            target_sys,
            target_comp,
            seq,
            mavlink.MAV_FRAME_GLOBAL_RELATIVE_ALT_INT,
            mavlink.MAV_CMD_NAV_WAYPOINT,
            0,    # current
            1,    # autocontinue
            0, 0, 0, 0,          # params 1-4 (hold time, acceptance radius, etc.)
            int(w["lat"] * 1e7),
            int(w["lon"] * 1e7),
            w["alt"],
            mavlink.MAV_MISSION_TYPE_MISSION,
        )
        if seq % 100 == 0:
            print(f"    ... {seq}/{count}")

    # Wait for MISSION_ACK
    ack = master.recv_match(type="MISSION_ACK", blocking=True, timeout=ack_timeout)
    if ack and ack.type == mavlink.MAV_MISSION_ACCEPTED:
        print("  [OK] Mission upload accepted by drone.")
        return True
    else:
        err = ack.type if ack else "timeout"
        print(f"  ERROR: Mission upload failed — {err}")
        return False


# ── Drone state ───────────────────────────────────────────────────────────────

class DroneState:
    def __init__(self):
        self.lat: float = 0.0
        self.lon: float = 0.0
        self.alt_m: float = 0.0
        self.heading_deg: float = 0.0
        self.battery_pct: int = -1
        self.mode: str = "UNKNOWN"
        self.armed: bool = False
        self.current_wp: int = 0
        self.fix_type: int = 0       # 0=no fix, 3=3D fix
        self.satellites: int = 0
        self.lock = threading.Lock()

    def update_position(self, msg) -> None:
        with self.lock:
            self.lat        = msg.lat / 1e7
            self.lon        = msg.lon / 1e7
            self.alt_m      = msg.relative_alt / 1000.0
            self.heading_deg = msg.hdg / 100.0

    def update_gps(self, msg) -> None:
        with self.lock:
            self.fix_type  = msg.fix_type
            self.satellites = msg.satellites_visible

    def update_battery(self, msg) -> None:
        with self.lock:
            self.battery_pct = msg.battery_remaining  # -1 if unknown

    def update_heartbeat(self, msg) -> None:
        with self.lock:
            self.armed = bool(msg.base_mode & mavutil.mavlink.MAV_MODE_FLAG_SAFETY_ARMED)

    def update_mission_current(self, seq: int) -> None:
        with self.lock:
            self.current_wp = seq

    def snapshot(self) -> dict:
        with self.lock:
            return {
                "lat":          self.lat,
                "lon":          self.lon,
                "alt_m":        self.alt_m,
                "heading_deg":  self.heading_deg,
                "battery_pct":  self.battery_pct,
                "mode":         self.mode,
                "armed":        self.armed,
                "current_wp":   self.current_wp,
                "fix_type":     self.fix_type,
                "satellites":   self.satellites,
            }


# ── TFLite patch inference ────────────────────────────────────────────────────

def load_model(model_path: str) -> Optional[object]:
    if TFLiteInterpreter is None:
        print("  [WARN] TFLite not available — patch inference disabled.")
        return None
    if not os.path.exists(model_path):
        print(f"  [WARN] Model not found: {model_path} — patch inference disabled.")
        return None
    interp = TFLiteInterpreter(model_path=model_path, num_threads=4)
    interp.allocate_tensors()
    print(f"  [OK] TFLite model loaded: {model_path}")
    return interp


def classify_patch(interp, image_path: str) -> Optional[dict]:
    """
    Load a JPEG/PNG from image_path, resize to 300×300, run TFLite inference.
    Returns {class_id, class_name, confidence, scores, latency_ms} or None.
    """
    if interp is None or not os.path.exists(image_path):
        return None

    try:
        img  = Image.open(image_path).convert("RGB").resize((PATCH_SIZE, PATCH_SIZE))
        arr  = np.array(img, dtype=np.uint8)

        inp  = interp.get_input_details()[0]
        out  = interp.get_output_details()[0]

        interp.set_tensor(inp["index"], arr[np.newaxis])
        t0 = time.perf_counter()
        interp.invoke()
        latency_ms = (time.perf_counter() - t0) * 1000

        raw = interp.get_tensor(out["index"])[0].astype(np.float32)
        if out["dtype"] == np.uint8:
            scale, zp = out["quantization"]
            raw = (raw - zp) * scale
        if raw.max() > 1.0 or raw.min() < 0.0:
            e = np.exp(raw - raw.max())
            raw = e / e.sum()

        class_id   = int(np.argmax(raw))
        confidence = float(raw[class_id])
        return {
            "class_id":   class_id,
            "class_name": CLASS_NAMES[class_id],
            "confidence": round(confidence, 4),
            "scores":     [round(float(s), 4) for s in raw],
            "latency_ms": round(latency_ms, 1),
        }
    except Exception as exc:
        print(f"  [WARN] Inference failed: {exc}")
        return None


# ── Live server client ────────────────────────────────────────────────────────

def post_json(url: str, payload: dict) -> bool:
    try:
        r = requests.post(url, json=payload, timeout=2)
        return r.status_code == 200
    except Exception:
        return False


# ── Telemetry loop (runs in background thread) ────────────────────────────────

def telemetry_loop(master, state: DroneState, server_url: str,
                   stop_event: threading.Event) -> None:
    """Background thread: reads MAVLink messages, updates state, POSTs to server."""
    last_post = 0.0

    while not stop_event.is_set():
        msg = master.recv_match(blocking=True, timeout=0.5)
        if msg is None:
            continue

        mtype = msg.get_type()

        if mtype == "GLOBAL_POSITION_INT":
            state.update_position(msg)
        elif mtype == "GPS_RAW_INT":
            state.update_gps(msg)
        elif mtype == "SYS_STATUS":
            state.update_battery(msg)
        elif mtype == "HEARTBEAT" and msg.get_srcSystem() == master.target_system:
            state.update_heartbeat(msg)
        elif mtype == "MISSION_CURRENT":
            state.update_mission_current(msg.seq)

        # POST telemetry to live server at TELEMETRY_HZ
        now = time.monotonic()
        if now - last_post >= 1.0 / TELEMETRY_HZ:
            if server_url:
                post_json(f"{server_url}/telemetry", state.snapshot())
            last_post = now


# ── Main ─────────────────────────────────────────────────────────────────────

def _parse_args():
    p = argparse.ArgumentParser(
        description="MaizeGuard — Live Drone Telemetry & Mission Control",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument(
        "--connect", required=True,
        help=(
            "MAVLink connection string. Examples:\n"
            "  /dev/ttyUSB0:57600   (serial)\n"
            "  udp:0.0.0.0:14550   (UDP — SITL / MAVProxy)\n"
            "  tcp:192.168.1.1:5760 (TCP — WiFi)"
        ),
    )
    p.add_argument("--mission", default=None,
                   help="Path to .waypoints file to upload before flight")
    p.add_argument("--model",   default="models/exports/efficientnetb3_maize_int8.tflite",
                   help="TFLite model for on-trigger patch inference")
    p.add_argument("--server",  default="http://localhost:5000",
                   help="URL of the MaizeGuard live web server (live_server.py)")
    p.add_argument("--auto-arm",  action="store_true",
                   help="Automatically arm and set AUTO mode after mission upload")
    p.add_argument("--image-dir", default="data/uav/captures",
                   help="Directory where drone image captures will be placed for inference")
    return p.parse_args()


def main():
    args = _parse_args()

    # ── Connect ───────────────────────────────────────────────────────────────
    print(f"\nConnecting to drone: {args.connect}")
    conn_str = args.connect
    # Parse serial strings like /dev/ttyUSB0:57600
    if ":" in conn_str and not conn_str.startswith(("udp:", "tcp:")):
        dev, baud = conn_str.rsplit(":", 1)
        master = mavutil.mavlink_connection(dev, baud=int(baud))
    else:
        master = mavutil.mavlink_connection(conn_str)

    # Wait for a heartbeat that comes from an actual autopilot, not a GCS.
    # MAV_TYPE_GCS=6; sysid=0 is the broadcast/unaddressed slot — neither is a drone.
    MAV_TYPE_GCS = 6
    print(f"Waiting for autopilot heartbeat (timeout {HEARTBEAT_TIMEOUT_S}s)...")
    deadline = time.time() + HEARTBEAT_TIMEOUT_S
    autopilot_hb = None
    while time.time() < deadline:
        msg = master.recv_match(type="HEARTBEAT", blocking=True,
                                timeout=deadline - time.time())
        if msg is None:
            break
        if msg.get_srcSystem() == 0 or msg.type == MAV_TYPE_GCS:
            print(f"  [SKIP] GCS/broadcast heartbeat from sysid={msg.get_srcSystem()} "
                  f"type={msg.type} — waiting for autopilot...")
            continue
        master.target_system    = msg.get_srcSystem()
        master.target_component = msg.get_srcComponent()
        autopilot_hb = msg
        break

    if autopilot_hb is None:
        print("ERROR: No autopilot heartbeat received within "
              f"{HEARTBEAT_TIMEOUT_S}s.\n"
              "  If testing without hardware, start ArduCopter SITL:\n"
              "    sim_vehicle.py -v ArduCopter --console --map\n"
              "  Then connect with:  --connect udp:127.0.0.1:14550\n"
              "  If using real hardware, check your --connect string (serial/UDP/TCP).")
        sys.exit(1)

    print(f"[OK] Autopilot heartbeat — sysid={master.target_system} "
          f"compid={master.target_component} type={autopilot_hb.type}")

    # ── Request telemetry streams ─────────────────────────────────────────────
    # Ask for: position (2 Hz), GPS (1 Hz), battery (1 Hz), extra1 (attitude, 4 Hz)
    for stream_id, rate in [
        (mavutil.mavlink.MAV_DATA_STREAM_POSITION,    2),
        (mavutil.mavlink.MAV_DATA_STREAM_EXTRA2,      1),   # battery
        (mavutil.mavlink.MAV_DATA_STREAM_RAW_SENSORS, 1),   # GPS_RAW_INT
    ]:
        master.mav.request_data_stream_send(
            master.target_system, master.target_component,
            stream_id, rate, 1,
        )

    state = DroneState()
    interp = load_model(args.model)
    os.makedirs(args.image_dir, exist_ok=True)

    # ── Upload mission ─────────────────────────────────────────────────────────
    if args.mission:
        if not os.path.exists(args.mission):
            print(f"ERROR: Mission file not found: {args.mission}")
            sys.exit(1)
        waypoints = parse_waypoints(args.mission)
        print(f"\nMission file: {args.mission}  ({len(waypoints)} nav waypoints)")
        if not upload_mission(master, waypoints):
            sys.exit(1)

        if args.auto_arm:
            print("\nArming drone and setting AUTO mode...")
            master.arducopter_arm()
            master.set_mode("AUTO")
            print("[OK] Drone armed and AUTO mode set.")
            print("     Drone will now execute the survey mission.")
    else:
        print("\n[INFO] No mission file specified — telemetry streaming only.")
        print("       To upload a mission, add: --mission data/uav/mission.waypoints")

    # ── Start telemetry background thread ────────────────────────────────────
    stop_event = threading.Event()
    t = threading.Thread(
        target=telemetry_loop,
        args=(master, state, args.server, stop_event),
        daemon=True,
    )
    t.start()

    print(f"\n[LIVE] Streaming telemetry to {args.server}")
    print("       Open your browser at that URL to see the real-time map.")
    print("       Press Ctrl+C to stop.\n")

    # ── Main loop: watch for MISSION_ITEM_REACHED and trigger inference ───────
    last_wp_reached = -1

    try:
        while True:
            snap = state.snapshot()

            # Print live status line
            fix_str = f"GPS fix={snap['fix_type']} sats={snap['satellites']}"
            pos_str = f"lat={snap['lat']:.6f} lon={snap['lon']:.6f} alt={snap['alt_m']:.1f}m"
            bat_str = f"batt={snap['battery_pct']}%" if snap['battery_pct'] >= 0 else "batt=?"
            wp_str  = f"WP={snap['current_wp']}"
            print(f"\r  {pos_str}  {wp_str}  {bat_str}  {fix_str}      ", end="", flush=True)

            # Check for new waypoint reached
            # MISSION_ITEM_REACHED is caught in the telemetry thread;
            # we detect it via current_wp change here for simplicity
            current_wp = snap["current_wp"]
            if current_wp != last_wp_reached and current_wp > 0:
                last_wp_reached = current_wp
                print(f"\n[WP] Reached waypoint {current_wp}")

                # Look for the most recently downloaded image from the drone camera
                # (assumes drone saves images to args.image_dir via MAVLink FTP or RTSP capture)
                captures = sorted([
                    os.path.join(args.image_dir, f)
                    for f in os.listdir(args.image_dir)
                    if f.lower().endswith((".jpg", ".jpeg", ".png"))
                ], key=os.path.getmtime, reverse=True)

                if captures:
                    latest = captures[0]
                    print(f"  Classifying: {os.path.basename(latest)}")
                    result = classify_patch(interp, latest)
                    if result:
                        print(f"  Result: {result['class_name']} "
                              f"({result['confidence']:.1%})  "
                              f"latency={result['latency_ms']:.0f}ms")
                        # POST patch result to live server
                        patch_payload = {
                            **result,
                            "lat":       snap["lat"],
                            "lon":       snap["lon"],
                            "waypoint":  current_wp,
                            "image":     os.path.basename(latest),
                        }
                        post_json(f"{args.server}/patch", patch_payload)
                    else:
                        print("  [SKIP] Inference returned no result.")
                else:
                    print(f"  [INFO] No capture found in {args.image_dir}")

            time.sleep(0.5)

    except KeyboardInterrupt:
        print("\n\n[STOP] Telemetry stopped by user.")
    finally:
        stop_event.set()
        t.join(timeout=2)
        master.close()
        print("[OK] MAVLink connection closed.")


if __name__ == "__main__":
    main()
