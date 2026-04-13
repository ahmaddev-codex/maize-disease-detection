import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../theme/app_theme.dart';
import '../services/database.dart';
import '../services/path_resolver.dart';
import 'scan_detail_sheet.dart';
import 'settings_screen.dart';

/// Dashboard — farm health summary, disease trends, recent scans strip.
class DashboardScreen extends StatefulWidget {
  final VoidCallback onScanTap;
  const DashboardScreen({super.key, required this.onScanTap});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _dao = AppDatabase.instance.scanDao;
  List<ScanRecord> _recent = [];
  List<ScanRecord> _last30 = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final recent = await _dao.recentScans(limit: 10);
    final last30 = await _dao.scansInLastDays(30);
    if (mounted) {
      setState(() {
        _recent = recent;
        _last30 = last30;
        _loading = false;
      });
    }
  }

  double get _healthScore {
    if (_last30.isEmpty) return 0;
    final healthy = _last30.where((s) => s.classId == 3).length;
    return (healthy / _last30.length) * 100;
  }

  Color get _healthColor {
    final s = _healthScore;
    if (s >= 75) return GhC.success;
    if (s >= 50) return GhC.attention;
    return GhC.danger;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            decoration: BoxDecoration(
              color: GhC.successEmphasis,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 17),
          ),
        ),
        title: const Text('Overview'),
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
          : RefreshIndicator(
              onRefresh: _load,
              color: GhC.accentEmphasis,
              backgroundColor: c.surface,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                children: [
                  AnimatedEntry(
                    delayMs: 0,
                    child: _CircularHealthScore(
                      score: _healthScore,
                      color: _healthColor,
                      totalScans: _last30.length,
                      onScanTap: widget.onScanTap,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AnimatedEntry(
                    delayMs: 80,
                    child: _TrendChart(scans: _last30),
                  ),
                  const SizedBox(height: 16),
                  AnimatedEntry(
                    delayMs: 160,
                    child: _DiseaseBreakdown(scans: _last30),
                  ),
                  const SizedBox(height: 16),
                  AnimatedEntry(
                    delayMs: 240,
                    child: _RecentScansStrip(
                      scans: _recent,
                      onScanTap: widget.onScanTap,
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onScanTap,
        backgroundColor: GhC.successEmphasis,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.camera_alt_rounded),
        label: const Text('Scan Leaf',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

}

// ── Circular Health Score ─────────────────────────────────────────────────────

class _CircularHealthScore extends StatelessWidget {
  final double score;
  final Color color;
  final int totalScans;
  final VoidCallback onScanTap;

  const _CircularHealthScore({
    required this.score,
    required this.color,
    required this.totalScans,
    required this.onScanTap,
  });

  String get _label {
    if (totalScans == 0) return 'No data yet';
    if (score >= 75) return 'Farm looks healthy';
    if (score >= 50) return 'Moderate pressure';
    return 'High pressure — act now';
  }

  String get _sublabel {
    if (totalScans == 0) return 'Tap "Scan Leaf" to begin';
    return '$totalScans scan${totalScans == 1 ? '' : 's'} in last 30 days';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    return Container(
      decoration: GhBox.card(c),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.eco_rounded, color: GhC.success, size: 14),
              const SizedBox(width: 6),
              Text('Farm Health Score', style: GhText.h3(c)),
              const Spacer(),
              GhLabel('Last 30 days', color: c.fgSubtle, fontSize: 10),
            ],
          ),
          const SizedBox(height: 24),

          // Circular arc
          AnimatedArcScore(
            score: score,
            color: color,
            size: 200,
            strokeWidth: 16,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated counting number
                AnimatedNumber(
                  value: totalScans == 0 ? 0 : score,
                  duration: const Duration(milliseconds: 1400),
                  builder: (_, v, __) => Text(
                    totalScans == 0 ? '--' : '${v.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: color,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      fontFamily: GhC.mono,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('health',
                    style: TextStyle(color: c.fgMuted, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Status label
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              _label,
              key: ValueKey(_label),
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(_sublabel, style: GhText.muted(c)),

          // Stats row
          if (totalScans > 0) ...[
            const SizedBox(height: 20),
            GhDivider(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatPill(
                  icon: Icons.check_circle_rounded,
                  color: GhC.success,
                  label: 'Healthy',
                  value: '${_last30HealthyCount(context)}',
                ),
                _StatDivider(),
                _StatPill(
                  icon: Icons.bug_report_rounded,
                  color: GhC.danger,
                  label: 'Diseased',
                  value: '${_last30DiseasedCount(context)}',
                ),
                _StatDivider(),
                _StatPill(
                  icon: Icons.speed_rounded,
                  color: GhC.accent,
                  label: 'Avg conf.',
                  value: '${_avgConf(context)}%',
                ),
              ],
            ),
          ],

          if (totalScans == 0) ...[
            const SizedBox(height: 20),
            GhButton('Scan first leaf',
                icon: Icons.camera_alt_rounded, onTap: onScanTap),
          ],
        ],
      ),
    );
  }

  int _last30HealthyCount(BuildContext ctx) =>
      (ctx.findAncestorStateOfType<_DashboardScreenState>()?._last30 ?? [])
          .where((s) => s.classId == 3)
          .length;

  int _last30DiseasedCount(BuildContext ctx) =>
      (ctx.findAncestorStateOfType<_DashboardScreenState>()?._last30 ?? [])
          .where((s) => s.classId != 3)
          .length;

  String _avgConf(BuildContext ctx) {
    final scans =
        ctx.findAncestorStateOfType<_DashboardScreenState>()?._last30 ?? [];
    if (scans.isEmpty) return '--';
    final avg =
        scans.map((s) => s.confidence).reduce((a, b) => a + b) / scans.length;
    return (avg * 100).toStringAsFixed(0);
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StatPill(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFamily: GhC.mono)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: c.fgSubtle, fontSize: 10)),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 28, width: 1, color: context.gc.border);
  }
}

// ── Trend Chart ───────────────────────────────────────────────────────────────

class _TrendChart extends StatelessWidget {
  final List<ScanRecord> scans;
  const _TrendChart({required this.scans});

  List<_DayBucket> _bucket() {
    final now = DateTime.now();
    final buckets = List.generate(7, (i) => _DayBucket(i));
    for (final s in scans) {
      final diff = now.difference(s.scannedAt).inDays;
      if (diff < 7) buckets[diff].add(s.classId);
    }
    return buckets.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    final buckets = _bucket();
    if (scans.isEmpty) return _EmptyCard(label: 'Disease trend (7 days)', c: c);

    return Container(
      decoration: GhBox.card(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(Icons.trending_up_rounded, color: c.fgSubtle, size: 14),
                const SizedBox(width: 6),
                Text('Disease trend (7 days)', style: GhText.h3(c)),
              ],
            ),
          ),
          GhDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: buckets
                          .map((b) => b.total.toDouble())
                          .fold(0.0, (a, b) => a > b ? a : b) +
                      1,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (v, _) => Text(
                          v.toInt().toString(),
                          style: TextStyle(color: c.fgSubtle, fontSize: 9),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= buckets.length) {
                            return const SizedBox.shrink();
                          }
                          final d =
                              DateTime.now().subtract(Duration(days: 6 - idx));
                          return Text('${d.day}/${d.month}',
                              style: TextStyle(color: c.fgSubtle, fontSize: 9));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: c.border, strokeWidth: 0.5),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(buckets.length, (i) {
                    final b = buckets[i];
                    return BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: b.diseased.toDouble(),
                        color: GhC.danger,
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3)),
                      ),
                      BarChartRodData(
                        toY: b.healthy.toDouble(),
                        color: GhC.success,
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3)),
                      ),
                    ]);
                  }),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                _Legend(color: GhC.danger, label: 'Diseased', c: c),
                const SizedBox(width: 16),
                _Legend(color: GhC.success, label: 'Healthy', c: c),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayBucket {
  final int offset;
  int healthy = 0;
  int diseased = 0;
  _DayBucket(this.offset);
  int get total => healthy + diseased;
  void add(int classId) {
    if (classId == 3) {
      healthy++;
    } else {
      diseased++;
    }
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final AppColors c;
  const _Legend({required this.color, required this.label, required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: c.fgMuted, fontSize: 10)),
      ],
    );
  }
}

// ── Disease Breakdown ─────────────────────────────────────────────────────────

class _DiseaseBreakdown extends StatelessWidget {
  final List<ScanRecord> scans;
  const _DiseaseBreakdown({required this.scans});

  static const _classes = ['NCLB', 'Rust', 'GLS', 'Healthy'];
  static const _colors = [
    GhC.danger,
    GhC.attention,
    GhC.accentEmphasis,
    GhC.success,
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    if (scans.isEmpty) {
      return _EmptyCard(label: 'Disease breakdown', c: c);
    }

    final counts = List.filled(4, 0);
    for (final s in scans) {
      counts[s.classId.clamp(0, 3)]++;
    }
    final total = scans.length;

    return Container(
      decoration: GhBox.card(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(Icons.pie_chart_rounded, color: c.fgSubtle, size: 14),
                const SizedBox(width: 6),
                Text('Disease breakdown', style: GhText.h3(c)),
              ],
            ),
          ),
          GhDivider(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: List.generate(4, (i) {
                final pct = total == 0 ? 0.0 : counts[i] / total;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child: Text(_classes[i],
                            style: TextStyle(
                                color: c.fgMuted,
                                fontSize: 11,
                                fontFamily: GhC.mono)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: pct),
                          duration: Duration(milliseconds: 800 + i * 100),
                          curve: Curves.easeOut,
                          builder: (_, v, __) => ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: v,
                              minHeight: 6,
                              backgroundColor: c.subtle,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(_colors[i]),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${(pct * 100).toStringAsFixed(0)}%',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              color: c.fg, fontSize: 11, fontFamily: GhC.mono),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 20,
                        child: Text('(${counts[i]})',
                            style: TextStyle(color: c.fgSubtle, fontSize: 10)),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recent Scans Strip ────────────────────────────────────────────────────────

class _RecentScansStrip extends StatelessWidget {
  final List<ScanRecord> scans;
  final VoidCallback onScanTap;
  const _RecentScansStrip({required this.scans, required this.onScanTap});

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    return Container(
      decoration: GhBox.card(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(Icons.history_rounded, color: c.fgSubtle, size: 14),
                const SizedBox(width: 6),
                Text('Recent scans', style: GhText.h3(c)),
              ],
            ),
          ),
          GhDivider(),
          if (scans.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.camera_alt_rounded, color: c.fgSubtle, size: 32),
                    const SizedBox(height: 8),
                    Text('No scans yet', style: GhText.muted(c)),
                    const SizedBox(height: 12),
                    GhButton('Scan first leaf',
                        icon: Icons.camera_alt_rounded, onTap: onScanTap),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                itemCount: scans.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _ScanThumb(scan: scans[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScanThumb extends StatelessWidget {
  final ScanRecord scan;
  const _ScanThumb({required this.scan});

  Color get _color => switch (scan.classId) {
        0 => GhC.danger,
        1 => GhC.attention,
        2 => GhC.accentEmphasis,
        _ => GhC.success,
      };

  @override
  Widget build(BuildContext context) {
    final file = File(PathResolver.resolve(scan.imagePath));
    return GestureDetector(
        onTap: () => showScanDetail(context, scan),
        child: Container(
          width: 76,
          decoration: BoxDecoration(
            border: Border.all(color: _color.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(5)),
                  child: file.existsSync()
                      ? Image.file(
                          file,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                            color: context.gc.subtle,
                            child: Icon(Icons.image_not_supported_rounded,
                                color: context.gc.fgSubtle, size: 20),
                          ),
                        )
                      : Container(
                          color: context.gc.subtle,
                          child: Icon(Icons.image_not_supported_rounded,
                              color: context.gc.fgSubtle, size: 20),
                        ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.12),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(5)),
                ),
                child: Text(
                  scan.shortName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _color,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    fontFamily: GhC.mono,
                  ),
                ),
              ),
            ],
          ),
        ));
  }
}

// ── Empty card placeholder ─────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final String label;
  final AppColors c;
  const _EmptyCard({required this.label, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: GhBox.card(c),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(Icons.bar_chart_rounded, color: c.fgSubtle, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GhText.h3(c)),
              const SizedBox(height: 2),
              Text('Scan leaves to populate this chart',
                  style: GhText.muted(c)),
            ],
          ),
        ],
      ),
    );
  }
}
