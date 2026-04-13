import 'dart:io';
import 'package:flutter/material.dart';

import '../services/database.dart';
import '../services/path_resolver.dart';
import '../theme/app_theme.dart';
import 'recommendation_screen.dart';

/// Shows a modal bottom sheet with full details for a past [ScanRecord].
void showScanDetail(BuildContext context, ScanRecord scan) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ScanDetailSheet(scan: scan),
  );
}

class _ScanDetailSheet extends StatelessWidget {
  final ScanRecord scan;
  const _ScanDetailSheet({required this.scan});

  Color get _color => switch (scan.classId) {
        0 => GhC.danger,
        1 => GhC.attention,
        2 => GhC.accentEmphasis,
        _ => GhC.success,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    final file = File(PathResolver.resolve(scan.imagePath));
    final hasImage = file.existsSync();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: c.canvas,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: Column(
          children: [
            // drag handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // image
            if (hasImage)
              SizedBox(
                height: 180,
                width: double.infinity,
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imagePlaceholder(c),
                ),
              )
            else
              _imagePlaceholder(c),
            // scrollable details
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(16),
                children: [
                  // disease + confidence row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scan.className,
                              style: TextStyle(
                                color: c.fg,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(scan.scannedAt),
                              style: TextStyle(color: c.fgSubtle, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _color.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '${(scan.confidence * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: _color,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFamily: GhC.mono,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const GhDivider(),
                  const SizedBox(height: 16),

                  // score breakdown
                  Text('Score breakdown', style: GhText.h3(c)),
                  const SizedBox(height: 10),
                  _ScoreBreakdown(scan: scan),
                  const SizedBox(height: 16),
                  const GhDivider(),
                  const SizedBox(height: 16),

                  // metadata grid
                  Text('Scan details', style: GhText.h3(c)),
                  const SizedBox(height: 10),
                  _MetaGrid(scan: scan),
                  const SizedBox(height: 20),

                  // AI advice button
                  SizedBox(
                    width: double.infinity,
                    child: GhButton(
                      'View AI recommendations',
                      icon: Icons.auto_awesome_rounded,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecommendationScreen(
                              classId: scan.classId,
                              confidence: scan.confidence,
                              cropVariety: scan.cropVariety,
                              plantingDate: scan.plantingDate,
                              batchNumber: scan.batchNumber,
                              latitude: scan.latitude,
                              longitude: scan.longitude,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder(AppColors c) => Container(
        height: 120,
        color: c.subtle,
        child: Center(
          child: Icon(Icons.image_not_supported_rounded,
              color: c.fgSubtle, size: 40),
        ),
      );

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  $h:$m';
  }
}

// ── Score bar breakdown ───────────────────────────────────────────────────────

class _ScoreBreakdown extends StatelessWidget {
  final ScanRecord scan;
  const _ScoreBreakdown({required this.scan});

  static const _labels = ['NCLB', 'Rust', 'GLS', 'Healthy'];
  static const _colors = [
    GhC.danger,
    GhC.attention,
    GhC.accentEmphasis,
    GhC.success,
  ];

  List<double> get _scores {
    try {
      final raw = scan.allScores
          .replaceAll('[', '')
          .replaceAll(']', '')
          .split(',');
      return raw.map((s) => double.parse(s.trim())).toList();
    } catch (_) {
      return [0, 0, 0, 0];
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    final scores = _scores;
    return Column(
      children: List.generate(_labels.length, (i) {
        final pct = i < scores.length ? scores[i].clamp(0.0, 1.0) : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  _labels[i],
                  style: TextStyle(
                    color: i == scan.classId ? _colors[i] : c.fgMuted,
                    fontSize: 11,
                    fontWeight: i == scan.classId
                        ? FontWeight.w700
                        : FontWeight.normal,
                    fontFamily: GhC.mono,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: c.subtle,
                    color: _colors[i],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  '${(pct * 100).toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: i == scan.classId ? _colors[i] : c.fgSubtle,
                    fontSize: 11,
                    fontFamily: GhC.mono,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ── Metadata grid ─────────────────────────────────────────────────────────────

class _MetaGrid extends StatelessWidget {
  final ScanRecord scan;
  const _MetaGrid({required this.scan});

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    final items = [
      ('Latency', '${scan.latencyMs.toStringAsFixed(0)} ms'),
      if (scan.cropVariety != null) ('Variety', scan.cropVariety!),
      if (scan.batchNumber != null) ('Batch', scan.batchNumber!),
      if (scan.plantingDate != null) ('Planted', scan.plantingDate!),
      if (scan.latitude != null)
        ('GPS',
            '${scan.latitude!.toStringAsFixed(4)}°N, ${scan.longitude!.toStringAsFixed(4)}°E'),
      if (scan.notes != null && scan.notes!.isNotEmpty)
        ('Notes', scan.notes!),
    ];

    if (items.isEmpty) {
      return Text('No additional details recorded.',
          style: GhText.muted(c));
    }

    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  item.$1,
                  style: TextStyle(color: c.fgSubtle, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.$2,
                  style: TextStyle(
                    color: c.fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
