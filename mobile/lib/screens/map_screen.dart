import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../constants/colors.dart';
import '../models/scan_record.dart';
import '../providers/app_provider.dart';
import '../widgets/ds.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  ScanRecord? _selected;

  @override
  Widget build(BuildContext context) {
    final scans    = ref.watch(scanListProvider);
    final geoScans = scans.where(
        (s) => s.latitude != null && s.longitude != null).toList();

    final centre = geoScans.isNotEmpty
        ? LatLng(
            geoScans.map((s) => s.latitude!).reduce((a, b) => a + b) / geoScans.length,
            geoScans.map((s) => s.longitude!).reduce((a, b) => a + b) / geoScans.length,
          )
        : const LatLng(9.0820, 8.6753); // Nigeria centre

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              title: const Text('Farm Map'),
              backgroundColor: AppColors.surface.withOpacity(0.80),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Center(
                    child: Text('${geoScans.length} pinned',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: geoScans.isEmpty
          ? EmptyState(
              icon: Icons.map_rounded,
              title: 'No GPS data yet',
              subtitle: 'Scan leaves while GPS is enabled\nto pin disease locations on your farm.',
              action: ElevatedButton.icon(
                onPressed: () => context.push('/camera'),
                icon: const Icon(Icons.camera_alt_rounded, size: 16),
                label: const Text('Start scanning'),
              ),
            )
          : Stack(
              children: [
                // ── Map ─────────────────────────────────────────────────
                FlutterMap(
                  options: MapOptions(
                    initialCenter: centre,
                    initialZoom: 14,
                    onTap: (_, __) => setState(() => _selected = null),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.maizeguard.app',
                    ),
                    MarkerLayer(
                      markers: geoScans.map((scan) => Marker(
                        width: 40, height: 40,
                        point: LatLng(scan.latitude!, scan.longitude!),
                        child: GestureDetector(
                          onTap: () => setState(() =>
                              _selected = _selected?.id == scan.id ? null : scan),
                          child: _DiseasePin(scan: scan,
                              selected: _selected?.id == scan.id),
                        ),
                      )).toList(),
                    ),
                  ],
                ),

                // ── Detail popup on marker tap ───────────────────────────
                if (_selected != null)
                  Positioned(
                    bottom: 24, left: 16, right: 16,
                    child: _ScanDetailCard(
                      scan: _selected!,
                      onClose: () => setState(() => _selected = null),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _DiseasePin extends StatelessWidget {
  const _DiseasePin({required this.scan, required this.selected});
  final ScanRecord scan;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forClass(scan.classId);
    return AnimatedScale(
      scale: selected ? 1.25 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.85),
          shape: BoxShape.circle,
          border: Border.all(
              color: Colors.white, width: selected ? 3 : 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(selected ? 0.5 : 0.3),
              blurRadius: selected ? 12 : 6,
              spreadRadius: selected ? 2 : 1,
            ),
          ],
        ),
        child: Icon(
          scan.classId == 3
              ? Icons.check_rounded
              : Icons.warning_amber_rounded,
          color: Colors.white,
          size: selected ? 22 : 18,
        ),
      ),
    );
  }
}

class _ScanDetailCard extends StatelessWidget {
  const _ScanDetailCard({required this.scan, required this.onClose});
  final ScanRecord scan;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forClass(scan.classId);
    return GlassCard(
      radius: AppRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                scan.classId == 3 ? Icons.check_circle_rounded : Icons.warning_rounded,
                color: color, size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(scan.shortName,
                    style: TextStyle(fontWeight: FontWeight.w800,
                        fontSize: 15, color: color)),
                Text(DateFormat('d MMM yyyy · HH:mm').format(scan.scannedAt),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            )),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  size: 18, color: AppColors.textSecondary),
              onPressed: onClose,
            ),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(children: [
            _DetailChip('Confidence',
                '${(scan.confidence * 100).toStringAsFixed(0)}%', color),
            const SizedBox(width: 10),
            if (scan.cropVariety != null)
              _DetailChip('Variety', scan.cropVariety!, AppColors.successFg),
          ]),
          if (scan.latitude != null) ...[
            const SizedBox(height: 8),
            Text(
              '${scan.latitude!.toStringAsFixed(5)}, ${scan.longitude!.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip(this.label, this.value, this.color);
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        Text(value,
            style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w700, color: color)),
      ],
    ),
  );
}
