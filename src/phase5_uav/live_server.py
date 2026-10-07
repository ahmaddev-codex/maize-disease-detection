"""
Phase 5 — MaizeGuard UAV Live Web Dashboard
Real-time Flask + Socket.IO server that renders a Leaflet.js map and updates it
as the drone flies the survey mission, showing disease detections the moment
each patch is classified.

Usage:
    # Terminal 1 — start this server
    python -m src.phase5_uav.live_server

    # Terminal 2 — connect the drone (streams to this server automatically)
    python -m src.phase5_uav.drone_telemetry \\
        --connect udp:0.0.0.0:14550 \\
        --mission data/uav/mission.waypoints \\
        --server  http://localhost:5000

    # Open http://localhost:5000 in any browser on the same machine (or LAN IP).

REST endpoints (called by drone_telemetry.py):
    POST /telemetry   — drone GPS position + status
    POST /patch       — disease classification result for a geo-tagged patch

Socket.IO events (broadcast to all browser clients):
    telemetry_update  — drone position moves on the map
    patch_result      — new disease marker appears + heatmap updates
    mission_status    — mission upload / arm / mode changes
"""
from __future__ import annotations

import json
import os
import time
from collections import deque
from typing import Any

try:
    from flask import Flask, jsonify, render_template_string, request
    from flask_socketio import SocketIO, emit
except ImportError:
    print("ERROR: flask and flask-socketio are not installed.")
    print("  Run: pip install flask flask-socketio gevent gevent-websocket")
    raise

# ── App setup ─────────────────────────────────────────────────────────────────
app = Flask(__name__)
app.config["SECRET_KEY"] = "maizeguard-uav-2026"

socketio = SocketIO(
    app,
    cors_allowed_origins="*",
    async_mode="gevent",
    logger=False,
    engineio_logger=False,
)

# ── In-memory state ───────────────────────────────────────────────────────────
_drone: dict[str, Any] = {
    "lat": 0.0, "lon": 0.0, "alt_m": 0.0,
    "heading_deg": 0.0, "battery_pct": -1,
    "mode": "UNKNOWN", "armed": False,
    "current_wp": 0, "fix_type": 0, "satellites": 0,
    "last_seen": None,
}
_patches: deque[dict] = deque(maxlen=2000)   # rolling window of patch results
_mission_log: list[str] = []

CLASS_COLORS = {
    "NCLB":    "#e74c3c",   # red
    "Rust":    "#e67e22",   # orange
    "GLS":     "#f1c40f",   # yellow
    "Healthy": "#2ecc71",   # green
}

# ── HTML template — self-contained, no CDN dependencies required ───────────────
# Uses Leaflet.js and Socket.IO from CDN (requires internet in browser, not server)
_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MaizeGuard — Live UAV Map</title>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<script src="https://unpkg.com/leaflet.heat@0.2.0/dist/leaflet-heat.js"></script>
<script src="https://cdn.socket.io/4.6.1/socket.io.min.js"></script>
<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  body { background:#0d1117; color:#e6edf3; font-family:'Courier New',monospace; display:flex; flex-direction:column; height:100vh; }
  #header { background:#161b22; border-bottom:1px solid #30363d; padding:10px 16px; display:flex; align-items:center; gap:16px; flex-shrink:0; }
  #header h1 { font-size:15px; color:#79c0ff; }
  #status { display:flex; gap:12px; font-size:12px; }
  .stat { background:#21262d; padding:3px 8px; border-radius:4px; }
  .stat.ok   { border-left:2px solid #3fb950; }
  .stat.warn { border-left:2px solid #e3b341; }
  .stat.err  { border-left:2px solid #f85149; }
  #map { flex:1; }
  #sidebar { position:fixed; right:0; top:48px; bottom:0; width:280px; background:#161b22;
             border-left:1px solid #30363d; overflow-y:auto; z-index:1000; padding:10px; }
  #sidebar h2 { font-size:12px; color:#7d8590; margin-bottom:8px; text-transform:uppercase; }
  .patch-card { background:#21262d; border-radius:6px; padding:8px; margin-bottom:6px;
                border-left:3px solid #444; font-size:11px; }
  .patch-card .cls  { font-size:13px; font-weight:bold; }
  .patch-card .meta { color:#7d8590; margin-top:3px; }
  #legend { position:fixed; bottom:16px; left:16px; background:rgba(22,27,34,0.92);
            border:1px solid #30363d; padding:10px; border-radius:8px; z-index:1000; font-size:11px; }
  #legend h3 { color:#7d8590; margin-bottom:6px; font-size:10px; text-transform:uppercase; }
  .leg-row { display:flex; align-items:center; gap:6px; margin-bottom:4px; }
  .leg-dot { width:10px; height:10px; border-radius:50%; }
</style>
</head>
<body>
<div id="header">
  <h1>MaizeGuard — Live UAV Disease Map</h1>
  <div id="status">
    <span class="stat" id="s-gps">GPS: --</span>
    <span class="stat" id="s-alt">Alt: --</span>
    <span class="stat" id="s-batt">Batt: --</span>
    <span class="stat" id="s-mode">Mode: --</span>
    <span class="stat" id="s-wp">WP: --</span>
    <span class="stat" id="s-patches">Patches: 0</span>
  </div>
</div>
<div id="map"></div>
<div id="sidebar">
  <h2>Recent Detections</h2>
  <div id="patch-list"></div>
</div>
<div id="legend">
  <h3>Disease Legend</h3>
  <div class="leg-row"><div class="leg-dot" style="background:#e74c3c"></div>NCLB (Blight)</div>
  <div class="leg-row"><div class="leg-dot" style="background:#e67e22"></div>Rust</div>
  <div class="leg-row"><div class="leg-dot" style="background:#f1c40f"></div>GLS (Gray Leaf Spot)</div>
  <div class="leg-row"><div class="leg-dot" style="background:#2ecc71"></div>Healthy</div>
</div>

<script>
const CLASS_COLORS = {{ class_colors_json }};

// ── Map init ──────────────────────────────────────────────────────────────────
const map = L.map('map', { center: [7.3775, 3.9470], zoom: 17, zoomControl: true });
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
  attribution: '© OpenStreetMap contributors',
  maxZoom: 20,
}).addTo(map);

// Satellite imagery layer (toggle)
const satLayer = L.tileLayer(
  'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  { attribution: 'Esri', maxZoom: 20 }
);
L.control.layers({ 'Street': L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
  {attribution:'© OpenStreetMap contributors'}), 'Satellite': satLayer }).addTo(map);

// ── Drone marker ──────────────────────────────────────────────────────────────
const droneIcon = L.divIcon({
  html: '<div style="width:18px;height:18px;background:#79c0ff;border:2px solid #fff;border-radius:50%;box-shadow:0 0 8px #79c0ff88"></div>',
  iconSize: [18, 18], iconAnchor: [9, 9],
});
const droneMarker = L.marker([7.3775, 3.9470], { icon: droneIcon })
  .bindTooltip('Drone', { permanent: true, direction: 'top', offset: [0, -12] })
  .addTo(map);
const dronePath = L.polyline([], { color: '#79c0ff', weight: 1.5, opacity: 0.5 }).addTo(map);

// ── Heat layer ────────────────────────────────────────────────────────────────
const heatLayer = L.heatLayer([], {
  radius: 20, blur: 18, maxZoom: 20,
  gradient: { 0.0: 'green', 0.4: 'yellow', 0.7: 'orange', 1.0: 'red' },
}).addTo(map);
const heatData = [];

// ── Patch markers ─────────────────────────────────────────────────────────────
let patchCount = 0;

function addPatchMarker(p) {
  const color   = CLASS_COLORS[p.class_name] || '#aaa';
  const radius  = p.confidence > 0.80 ? 7 : 5;
  const marker  = L.circleMarker([p.lat, p.lon], {
    radius, color, fillColor: color, fillOpacity: 0.75, weight: 1.5,
  });
  marker.bindPopup(`
    <div style="font-family:monospace;font-size:12px;min-width:160px">
      <b style="color:${color}">${p.class_name}</b><br>
      Confidence : ${(p.confidence * 100).toFixed(1)}%<br>
      Waypoint   : WP-${p.waypoint || '?'}<br>
      Lat / Lon  : ${p.lat.toFixed(5)}, ${p.lon.toFixed(5)}<br>
      Latency    : ${p.latency_ms || '?'} ms
    </div>`);
  marker.addTo(map);

  if (p.class_name !== 'Healthy') {
    heatData.push([p.lat, p.lon, p.confidence]);
    heatLayer.setLatLngs(heatData);
  }

  // Sidebar card
  patchCount++;
  document.getElementById('s-patches').textContent = `Patches: ${patchCount}`;
  const card = document.createElement('div');
  card.className = 'patch-card';
  card.style.borderColor = color;
  card.innerHTML = `<div class="cls" style="color:${color}">${p.class_name}</div>
    <div class="meta">${(p.confidence*100).toFixed(1)}% · WP-${p.waypoint||'?'} · ${p.lat.toFixed(5)}, ${p.lon.toFixed(5)}</div>`;
  const list = document.getElementById('patch-list');
  list.insertBefore(card, list.firstChild);
  if (list.children.length > 50) list.removeChild(list.lastChild);
}

// ── Socket.IO ─────────────────────────────────────────────────────────────────
const socket = io();

socket.on('telemetry_update', (d) => {
  if (!d.lat || !d.lon) return;
  const latlng = [d.lat, d.lon];
  droneMarker.setLatLng(latlng);
  dronePath.addLatLng(latlng);

  const fixStr = d.fix_type >= 3 ? `3D-fix (${d.satellites} sats)` : `No fix (${d.satellites} sats)`;
  const gpsEl  = document.getElementById('s-gps');
  gpsEl.textContent = `GPS: ${fixStr}`;
  gpsEl.className   = `stat ${d.fix_type >= 3 ? 'ok' : 'err'}`;

  document.getElementById('s-alt').textContent  = `Alt: ${d.alt_m.toFixed(1)}m`;
  document.getElementById('s-batt').textContent = `Batt: ${d.battery_pct >= 0 ? d.battery_pct + '%' : '?'}`;
  const battEl = document.getElementById('s-batt');
  battEl.className = `stat ${d.battery_pct > 20 ? 'ok' : d.battery_pct > 10 ? 'warn' : 'err'}`;
  document.getElementById('s-mode').textContent = `Mode: ${d.mode}`;
  document.getElementById('s-wp').textContent   = `WP: ${d.current_wp}`;
});

socket.on('patch_result', (p) => { addPatchMarker(p); });

socket.on('mission_status', (msg) => { console.log('[Mission]', msg); });

// ── Load existing patches on connect ──────────────────────────────────────────
fetch('/api/patches').then(r => r.json()).then(patches => {
  patches.forEach(addPatchMarker);
  if (patches.length > 0) {
    const lats = patches.map(p => p.lat);
    const lons = patches.map(p => p.lon);
    map.fitBounds([[Math.min(...lats), Math.min(...lons)],
                   [Math.max(...lats), Math.max(...lons)]], { padding: [40, 40] });
  }
});
</script>
</body>
</html>"""


# ── REST endpoints ────────────────────────────────────────────────────────────

@app.route("/")
def index():
    html = _HTML.replace(
        "{{ class_colors_json }}",
        json.dumps(CLASS_COLORS)
    )
    return render_template_string(html)


@app.route("/telemetry", methods=["POST"])
def receive_telemetry():
    """Called by drone_telemetry.py every ~0.5s with GPS + status."""
    data = request.get_json(silent=True) or {}
    _drone.update(data)
    _drone["last_seen"] = time.time()
    socketio.emit("telemetry_update", _drone)
    return jsonify({"ok": True})


@app.route("/patch", methods=["POST"])
def receive_patch():
    """Called by drone_telemetry.py when a new patch is classified at a waypoint."""
    data = request.get_json(silent=True) or {}
    if not data.get("lat") or not data.get("lon"):
        return jsonify({"error": "lat/lon required"}), 400
    _patches.append(data)
    socketio.emit("patch_result", data)
    return jsonify({"ok": True})


@app.route("/api/patches")
def api_patches():
    """Returns all buffered patch results (for browser on connect)."""
    return jsonify(list(_patches))


@app.route("/api/drone")
def api_drone():
    """Returns current drone state."""
    return jsonify(_drone)


@app.route("/api/summary")
def api_summary():
    """Returns aggregate disease stats across all patches received so far."""
    from collections import Counter
    total  = len(_patches)
    counts = Counter(p["class_name"] for p in _patches)
    return jsonify({
        "total_patches":   total,
        "disease_patches": total - counts.get("Healthy", 0),
        "classes": {
            cls: {
                "count": counts.get(cls, 0),
                "pct":   round(counts.get(cls, 0) / total * 100, 1) if total else 0,
            }
            for cls in ["NCLB", "Rust", "GLS", "Healthy"]
        },
    })


# ── Socket.IO events ──────────────────────────────────────────────────────────

@socketio.on("connect")
def on_connect():
    emit("mission_status", {"msg": "Connected to MaizeGuard live server"})


# ── CLI ───────────────────────────────────────────────────────────────────────

def _parse_args():
    import argparse
    p = argparse.ArgumentParser(description="MaizeGuard UAV Live Web Server")
    p.add_argument("--host", default="0.0.0.0",
                   help="Host to bind (default 0.0.0.0 — all interfaces)")
    p.add_argument("--port", type=int, default=5000,
                   help="TCP port (default 5000)")
    p.add_argument("--debug", action="store_true",
                   help="Enable Flask debug mode (auto-reload)")
    return p.parse_args()


def main():
    args = _parse_args()
    local_ip = _get_local_ip()

    print("\n============================================================")
    print("  MaizeGuard — UAV Live Web Server")
    print("============================================================")
    print(f"  Local  : http://localhost:{args.port}")
    if local_ip:
        print(f"  Network: http://{local_ip}:{args.port}  (share with tablet/laptop)")
    print()
    print("  Waiting for drone connection...")
    print("  Run in another terminal:")
    print(f"    python -m src.phase5_uav.drone_telemetry \\")
    print(f"        --connect udp:0.0.0.0:14550 \\")
    print(f"        --mission data/uav/mission.waypoints \\")
    print(f"        --server  http://localhost:{args.port}")
    print("============================================================\n")

    socketio.run(
        app,
        host=args.host,
        port=args.port,
        debug=args.debug,
        use_reloader=args.debug,
        log_output=False,
    )


def _get_local_ip() -> str:
    import socket
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return ""


if __name__ == "__main__":
    main()
