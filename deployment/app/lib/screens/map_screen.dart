import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';
import '../services/database.dart';
import 'settings_screen.dart';

/// Farm map screen — OpenStreetMap tiles + disease scan markers.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _dao = AppDatabase.instance.scanDao;
  final _mapController = MapController();
  List<ScanRecord> _scans = [];
  bool _loading = true;

  // Default centre: Ibadan, Nigeria (major maize-growing region)
  static const _defaultCenter = LatLng(7.3775, 3.9470);
  static const _defaultZoom = 13.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final scans = await _dao.allScans();
    if (mounted) {
      setState(() {
        _scans = scans.where((s) => s.latitude != null && s.longitude != null).toList();
        _loading = false;
      });
    }
  }

  LatLng? get _mapCenter {
    if (_scans.isEmpty) return null;
    final lats = _scans.map((s) => s.latitude!).toList();
    final lons = _scans.map((s) => s.longitude!).toList();
    return LatLng(
      lats.reduce((a, b) => a + b) / lats.length,
      lons.reduce((a, b) => a + b) / lons.length,
    );
  }

  Color _markerColor(int classId) => switch (classId) {
        0 => GhC.danger,
        1 => GhC.attention,
        2 => GhC.accentEmphasis,
        _ => GhC.success,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    final center = _mapCenter ?? _defaultCenter;

    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(
        title: const Text('Farm Map'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: c.fgMuted, size: 20),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
          IconButton(
            icon: Icon(Icons.settings_rounded, color: c.fgMuted, size: 22),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: GhC.accentEmphasis, strokeWidth: 2))
          : Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: center,
                            initialZoom: _defaultZoom,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.maizeguard.app',
                            ),
                            MarkerLayer(
                              markers: _scans.map((s) {
                                final color = _markerColor(s.classId);
                                return Marker(
                                  point: LatLng(s.latitude!, s.longitude!),
                                  width: 36,
                                  height: 44,
                                  child: GestureDetector(
                                    onTap: () => _showScanInfo(s),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white, width: 2),
                                          ),
                                          child: Center(
                                            child: Text(
                                              s.shortName[0],
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                        CustomPaint(
                                          size: const Size(8, 8),
                                          painter: _DropPainter(color),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        // Legend overlay
                        Positioned(
                          bottom: 16,
                          left: 16,
                          child: _MapLegend(c: c),
                        ),
                        // Scan count badge
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: c.surface.withValues(alpha: 0.92),
                              border: Border.all(color: c.border),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${_scans.length} GPS-tagged scans',
                              style: TextStyle(
                                color: c.fg,
                                fontSize: 11,
                                fontFamily: GhC.mono,
                              ),
                            ),
                          ),
                        ),
                        if (_scans.isEmpty)
                          Center(
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 32),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: c.surface.withValues(alpha: 0.95),
                                border: Border.all(color: c.border),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_off_rounded,
                                      color: c.fgSubtle, size: 32),
                                  const SizedBox(height: 8),
                                  Text('No GPS-tagged scans yet',
                                      style: GhText.h3(c)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Enable location when scanning to see disease hotspots here.',
                                    textAlign: TextAlign.center,
                                    style: GhText.muted(c),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
    );
  }

  void _showScanInfo(ScanRecord scan) {
    final c = context.gc;
    final color = _markerColor(scan.classId);
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        side: BorderSide(color: c.border),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    scan.className,
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(scan.confidence * 100).toStringAsFixed(1)}% confidence',
                  style: GhText.muted(c),
                ),
                const Spacer(),
                GhLabel(scan.shortName, color: color, fontSize: 10),
              ],
            ),
            const SizedBox(height: 14),
            _InfoRow2(
                c: c,
                icon: Icons.calendar_today_rounded,
                label: 'Date',
                value: _formatDate(scan.scannedAt)),
            if (scan.cropVariety != null)
              _InfoRow2(
                  c: c,
                  icon: Icons.grass_rounded,
                  label: 'Variety',
                  value: scan.cropVariety!),
            if (scan.latitude != null)
              _InfoRow2(
                  c: c,
                  icon: Icons.location_on_rounded,
                  label: 'GPS',
                  value:
                      '${scan.latitude!.toStringAsFixed(5)}, ${scan.longitude!.toStringAsFixed(5)}'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

}

class _InfoRow2 extends StatelessWidget {
  final AppColors c;
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow2(
      {required this.c, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: c.fgSubtle, size: 14),
          const SizedBox(width: 8),
          SizedBox(
              width: 60,
              child: Text(label,
                  style: TextStyle(color: c.fgMuted, fontSize: 12))),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      color: c.fg, fontSize: 12, fontFamily: GhC.mono))),
        ],
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  final AppColors c;
  const _MapLegend({required this.c});

  @override
  Widget build(BuildContext context) {
    const items = [
      ('NCLB', GhC.danger),
      ('Rust', GhC.attention),
      ('GLS', GhC.accentEmphasis),
      ('Healthy', GhC.success),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.92),
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) {
          final (label, color) = item;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: c.fg, fontSize: 10)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DropPainter extends CustomPainter {
  final Color color;
  _DropPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DropPainter old) => old.color != color;
}
