import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../design_system/design_system.dart';
import '../models/scan_record.dart';
import '../providers/app_provider.dart';
import '../services/path_resolver.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  ScanRecord? _selected;

  @override
  Widget build(BuildContext context) {
    final scans = ref.watch(scanListProvider);
    final geoScans = scans.where((s) => s.latitude != null && s.longitude != null).toList();

    final centre = geoScans.isNotEmpty
        ? LatLng(
            geoScans.map((s) => s.latitude!).reduce((a, b) => a + b) / geoScans.length,
            geoScans.map((s) => s.longitude!).reduce((a, b) => a + b) / geoScans.length,
          )
        : const LatLng(9.0820, 8.6753); // Center of Nigeria

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            MaizeGuardLogo(size: 22, isDark: Theme.of(context).brightness == Brightness.dark),
            const SizedBox(width: AppSpacing.sm),
            const Text('Geospatial Farm Map'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: AppRadii.full,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Text(
                  '${geoScans.length} GPS Pinned',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: geoScans.isEmpty
          ? EmptyStateView(
              illustration: const MaizeGuardLogo(size: 56),
              title: 'No Geospatial Data Yet',
              message: 'Leaf scans taken with device GPS enabled will be georeferenced and mapped across your farmland.',
              actionLabel: 'Scan Field',
              onAction: () => context.push('/camera'),
            )
          : Stack(
              children: [
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
                      markers: geoScans.map((scan) {
                        final isSelected = _selected?.id == scan.id;
                        final pinColor = switch (scan.classId) {
                          0 => AppColors.nclb,
                          1 => AppColors.rust,
                          2 => AppColors.gls,
                          3 => AppColors.healthy,
                          _ => AppColors.charcoal500,
                        };

                        return Marker(
                          width: 44,
                          height: 44,
                          point: LatLng(scan.latitude!, scan.longitude!),
                          child: GestureDetector(
                            onTap: () => setState(() => _selected = isSelected ? null : scan),
                            child: AnimatedScale(
                              scale: isSelected ? 1.3 : 1.0,
                              duration: const Duration(milliseconds: 150),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: pinColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: isSelected ? 3 : 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: pinColor.withValues(alpha: 0.5),
                                      blurRadius: isSelected ? 12 : 6,
                                      spreadRadius: isSelected ? 2 : 1,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  scan.classId == 3
                                      ? Icons.check_rounded
                                      : Icons.warning_amber_rounded,
                                  color: Colors.white,
                                  size: isSelected ? 24 : 20,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                // Interactive Bottom Detail Sheet
                if (_selected != null)
                  Positioned(
                    bottom: AppSpacing.lg,
                    left: AppSpacing.md,
                    right: AppSpacing.md,
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

class _ScanDetailCard extends ConsumerWidget {
  final ScanRecord scan;
  final VoidCallback onClose;

  const _ScanDetailCard({required this.scan, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final absPath = PathResolver.resolve(scan.imagePath);
    final hasImage = scan.imagePath.isNotEmpty && File(absPath).existsSync();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final badgeColor = switch (scan.classId) {
      0 => AppColors.nclb,
      1 => AppColors.rust,
      2 => AppColors.gls,
      3 => AppColors.healthy,
      _ => AppColors.charcoal500,
    };

    return AppCard(
      surfaceColor: isDark ? AppColors.surfaceDark : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage)
                ClipRRect(
                  borderRadius: AppRadii.md,
                  child: Image.file(
                    File(absPath),
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: AppRadii.md,
                  ),
                  child: Icon(Icons.eco_outlined, color: badgeColor, size: 24),
                ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scan.className,
                      style: AppTypography.h3.copyWith(
                        color: isDark ? Colors.white : AppColors.charcoal900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DateFormat('d MMM yyyy · HH:mm').format(scan.scannedAt)} · ${(scan.confidence * 100).toStringAsFixed(0)}% Confidence',
                      style: AppTypography.caption.copyWith(color: AppColors.charcoal400),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: onClose,
                color: AppColors.charcoal400,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.emeraldBase),
              const SizedBox(width: 4),
              Text(
                'Lat: ${scan.latitude!.toStringAsFixed(5)}, Lon: ${scan.longitude!.toStringAsFixed(5)}',
                style: AppTypography.caption.copyWith(color: AppColors.charcoal500),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'View Detailed Diagnosis & Treatment',
            icon: Icons.assignment_outlined,
            backgroundColor: AppColors.forestDark,
            onPressed: () {
              ref.read(activeScanIdProvider.notifier).state = scan.id;
              context.push('/result');
            },
          ),
        ],
      ),
    );
  }
}
