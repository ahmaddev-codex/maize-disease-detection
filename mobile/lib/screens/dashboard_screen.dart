import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../constants/colors.dart';
import '../providers/app_provider.dart';
import '../services/database_service.dart';
import '../widgets/ds.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Map<String, int> _classCounts = {};
  Map<String, int> _dailyCounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final results = await Future.wait([
      DatabaseService.instance.getClassCounts(days: 30),
      DatabaseService.instance.getDailyScans(days: 7),
    ]);
    if (mounted) {
      setState(() {
        _classCounts = results[0] as Map<String, int>;
        _dailyCounts = results[1] as Map<String, int>;
        _loading = false;
      });
    }
  }

  int get _total   => _classCounts.values.fold(0, (a, b) => a + b);
  int get _healthy => _classCounts['Healthy'] ?? 0;
  double get _healthScore => _total == 0 ? 100 : _healthy / _total * 100;

  @override
  Widget build(BuildContext context) {
    final isDark     = ref.watch(isDarkModeProvider);
    final trendAsync = ref.watch(healthTrendProvider);
    final labels     = _dayLabels();

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvas,
      body: CustomScrollView(
        slivers: [
          // ── Glass app bar ────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 90,
            backgroundColor:
                (isDark ? AppColors.surfaceDark : AppColors.surface).withOpacity(0.88),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh',
                onPressed: _load,
              ),
            ],
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: const FlexibleSpaceBar(
                  title: Text('Farm Analytics',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                  titlePadding: EdgeInsets.only(left: 16, bottom: 14),
                ),
              ),
            ),
          ),

          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverPadding(
              padding: AppSpacing.pagePad,
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 12),

                  // ── Health score + trend row ─────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _HealthScoreCard(score: _healthScore, total: _total)),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: trendAsync.when(
                          data: (delta) => _TrendCard(delta: delta),
                          loading: () => const GlassCard(child: Center(child: CircularProgressIndicator())),
                          error: (_, __) => const GlassCard(child: Icon(Icons.error_rounded)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── Quick stats row ──────────────────────────────────
                  Row(children: [
                    Expanded(child: StatChip(
                      value: '$_total',
                      label: 'Scans (30d)',
                      icon: Icons.qr_code_scanner_rounded,
                      color: AppColors.accent,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: StatChip(
                      value: '${_total - _healthy}',
                      label: 'Diseased',
                      icon: Icons.warning_rounded,
                      color: AppColors.dangerFg,
                    )),
                  ]),

                  // ── Disease breakdown ────────────────────────────────
                  const SectionLabel('Disease Breakdown (30 days)'),
                  GlassCard(
                    child: Column(
                      children: [
                        ('NCLB', 0), ('Rust', 1), ('GLS', 2), ('Healthy', 3),
                      ].map(((String, int) e) {
                        final count = _classCounts[e.$1] ?? 0;
                        final pct   = _total > 0 ? count / _total : 0.0;
                        final color = AppColors.forClass(e.$2);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                DiseaseDot(color),
                                const SizedBox(width: 8),
                                Expanded(child: Text(e.$1,
                                    style: const TextStyle(fontSize: 13,
                                        fontWeight: FontWeight.w500))),
                                Text('$count',
                                    style: TextStyle(fontSize: 13,
                                        color: color, fontWeight: FontWeight.w700)),
                                const SizedBox(width: 4),
                                SizedBox(width: 36, child: Text(
                                  '(${(pct * 100).toStringAsFixed(0)}%)',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.textSecondary),
                                )),
                              ]),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 8,
                                  backgroundColor: color.withOpacity(0.10),
                                  valueColor: AlwaysStoppedAnimation(color),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // ── 7-day bar chart ──────────────────────────────────
                  const SectionLabel('Scan Activity (7 days)'),
                  GlassCard(
                    padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                    child: SizedBox(
                      height: 150,
                      child: BarChart(BarChartData(
                        barGroups: labels.asMap().entries.map((e) =>
                          BarChartGroupData(
                            x: e.key,
                            barRods: [BarChartRodData(
                              toY: (_dailyCounts[e.value] ?? 0).toDouble(),
                              gradient: const LinearGradient(
                                colors: [AppColors.accent, AppColors.accentFg],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              width: 18,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            )],
                          ),
                        ).toList(),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                labels[v.toInt()].substring(5), // MM-DD
                                style: const TextStyle(
                                    fontSize: 9, color: AppColors.textSecondary),
                              ),
                            ),
                          )),
                          leftTitles: AxisTitles(sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            getTitlesWidget: (v, _) => Text('${v.toInt()}',
                                style: const TextStyle(
                                    fontSize: 9, color: AppColors.textSecondary)),
                          )),
                          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) =>
                              const FlLine(color: AppColors.border, strokeWidth: 0.5),
                        ),
                        borderData: FlBorderData(show: false),
                      )),
                    ),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  List<String> _dayLabels() {
    final today = DateTime.now();
    return List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return DateFormat('yyyy-MM-dd').format(d);
    });
  }
}

// ── Farm health score arc card ─────────────────────────────────────────────────
class _HealthScoreCard extends StatelessWidget {
  const _HealthScoreCard({required this.score, required this.total});
  final double score;
  final int total;

  @override
  Widget build(BuildContext context) {
    final color = score >= 70
        ? AppColors.successFg
        : score >= 40 ? AppColors.attentionFg : AppColors.dangerFg;

    return GlassCard(
      child: Column(
        children: [
          SizedBox(
            width: 80, height: 80,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 8,
                backgroundColor: color.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation(color),
                strokeCap: StrokeCap.round,
              ),
              Text('${score.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            ]),
          ),
          const SizedBox(height: 10),
          const Text('Farm Health',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 2),
          Text('$total scans',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            score >= 70 ? 'Looking good' :
            score >= 40 ? 'Moderate risk' : 'Take action',
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Trend card ────────────────────────────────────────────────────────────────
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.delta});
  final double delta;

  @override
  Widget build(BuildContext context) {
    final isImproving  = delta > 0.08;
    final isWorsening  = delta < -0.08;
    final color = isImproving ? AppColors.successFg
        : isWorsening ? AppColors.dangerFg
        : AppColors.attentionFg;
    final icon  = isImproving ? Icons.trending_up_rounded
        : isWorsening ? Icons.trending_down_rounded
        : Icons.trending_flat_rounded;
    final label = isImproving ? 'Improving'
        : isWorsening ? 'Worsening'
        : 'Stable';
    final sub   = isImproving ? 'vs last week'
        : isWorsening ? 'vs last week'
        : 'No change';

    return GlassCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 14, color: color)),
          const SizedBox(height: 2),
          Text('Trend · $sub',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
