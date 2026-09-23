import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../design_system/design_system.dart';
import '../models/farm_stats.dart';
import '../providers/app_provider.dart';
import '../providers/service_providers.dart';
import '../utils/time_format.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  FarmStats _stats = const FarmStats(days: 30, countsByClass: {});
  Map<String, int> _dailyCounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final db = ref.read(databaseServiceProvider);
    final stats = await db.farmStats(days: 30);
    final daily = await db.getDailyScans(days: 7);
    if (mounted) {
      setState(() {
        _stats = stats;
        _dailyCounts = daily;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trendAsync = ref.watch(healthTrendProvider);
    final labels = _dayLabels();

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
      appBar: AppBar(
        title: Row(
          children: [
            MaizeGuardLogo(size: 22, isDark: isDark),
            const SizedBox(width: AppSpacing.sm),
            const Text('Epidemiological Analytics'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Metrics',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.emeraldBase))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.emeraldBase,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
                children: [
                  // Row: Farm Health Index + 7-Day Trend
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _HealthScoreCard(rate: _stats.healthRate, total: _stats.total),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: 2,
                        child: trendAsync.when(
                          data: (delta) => _TrendCard(delta: delta),
                          loading: () => const AppCard(
                            child: SizedBox(
                              height: 120,
                              child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          error: (_, __) => const AppCard(
                            child: SizedBox(
                              height: 120,
                              child: Center(
                                child: Icon(Icons.error_outline_rounded, color: AppColors.danger),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Quick Metrics Row
                  Row(
                    children: [
                      Expanded(
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_stats.total}',
                                style: AppTypography.h2.copyWith(color: AppColors.emeraldBase),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Scans (Last 30 Days)',
                                style: AppTypography.caption.copyWith(color: AppColors.charcoal500),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_stats.diseased}',
                                style: AppTypography.h2.copyWith(color: AppColors.rust),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pathologies Detected',
                                style: AppTypography.caption.copyWith(color: AppColors.charcoal500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Disease Prevalence Breakdown
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PATHOLOGY INCIDENCE BREAKDOWN (30 DAYS)',
                          style: AppTypography.overline.copyWith(
                            color: AppColors.charcoal500,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ...[
                          ('Northern Leaf Blight (NCLB)', 0, AppColors.nclb),
                          ('Common Rust', 1, AppColors.rust),
                          ('Gray Leaf Spot (GLS)', 2, AppColors.gls),
                          ('Healthy Foliage', kHealthyClassId, AppColors.healthy),
                        ].map((item) {
                          final count = _stats.countFor(item.$2);
                          final pct = _stats.shareOf(item.$2);
                          final color = item.$3;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      item.$1,
                                      style: AppTypography.bodySmall.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.charcoal200 : AppColors.charcoal800,
                                      ),
                                    ),
                                    Text(
                                      '$count (${(pct * 100).toStringAsFixed(0)}%)',
                                      style: AppTypography.caption.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: AppRadii.full,
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 6,
                                    backgroundColor: color.withValues(alpha: 0.12),
                                    valueColor: AlwaysStoppedAnimation(color),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // 7-Day Field Activity Histogram
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '7-DAY FIELD SCANNING VELOCITY',
                          style: AppTypography.overline.copyWith(
                            color: AppColors.charcoal500,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          height: 160,
                          child: BarChart(
                            BarChartData(
                              barGroups: labels.asMap().entries.map((e) {
                                return BarChartGroupData(
                                  x: e.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: (_dailyCounts[e.value] ?? 0).toDouble(),
                                      color: AppColors.forestDark,
                                      width: 18,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                    ),
                                  ],
                                );
                              }).toList(),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (v, _) {
                                      final idx = v.toInt();
                                      if (idx < 0 || idx >= labels.length) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          labels[idx].substring(5), // MM-DD
                                          style: AppTypography.caption.copyWith(
                                            fontSize: 10,
                                            color: AppColors.charcoal500,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 24,
                                    getTitlesWidget: (v, _) => Text(
                                      '${v.toInt()}',
                                      style: AppTypography.caption.copyWith(
                                        fontSize: 10,
                                        color: AppColors.charcoal500,
                                      ),
                                    ),
                                  ),
                                ),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              gridData: FlGridData(
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (_) => FlLine(
                                  color: isDark ? Colors.white10 : AppColors.charcoal200,
                                  strokeWidth: 1,
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MaizeGuardWordmark(
                          height: 20,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Regional Epidemiological Surveillance Engine',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.charcoal400,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
    );
  }

  // Local days, matching how getDailyScans buckets scans (T16/T17).
  List<String> _dayLabels() {
    final today = DateTime.now();
    return List.generate(7, (i) => localDayKey(today.subtract(Duration(days: 6 - i))));
  }
}

class _HealthScoreCard extends StatelessWidget {
  /// Null when nothing has been scanned yet — showing 100% would be a lie.
  final double? rate;
  final int total;
  const _HealthScoreCard({required this.rate, required this.total});

  @override
  Widget build(BuildContext context) {
    if (rate == null) {
      return AppCard(
        child: SizedBox(
          height: 120,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.grass_outlined, size: 28, color: AppColors.charcoal400),
              const SizedBox(height: AppSpacing.xs),
              Text('No scans yet', style: AppTypography.h3.copyWith(fontSize: 13)),
              Text(
                'Scan a leaf to see farm health',
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(color: AppColors.charcoal500),
              ),
            ],
          ),
        ),
      );
    }

    final score = rate! * 100;
    final color = score >= 70
        ? AppColors.healthy
        : (score >= 40 ? AppColors.warning : AppColors.danger);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 74,
            height: 74,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 7,
                  backgroundColor: color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(color),
                  strokeCap: StrokeCap.round,
                ),
                Text(
                  score.toStringAsFixed(0),
                  style: AppTypography.h2.copyWith(color: color),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Crop Health Index', style: AppTypography.h3.copyWith(fontSize: 13)),
          Text(
            score >= 70 ? 'Crop Vigorous' : (score >= 40 ? 'Moderate Pathogen Load' : 'High Infestation'),
            style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final double delta;
  const _TrendCard({required this.delta});

  @override
  Widget build(BuildContext context) {
    final isImproving = delta > 0.05;
    final isWorsening = delta < -0.05;
    final color = isImproving
        ? AppColors.healthy
        : (isWorsening ? AppColors.danger : AppColors.charcoal500);
    final icon = isImproving
        ? Icons.trending_up_rounded
        : (isWorsening ? Icons.trending_down_rounded : Icons.trending_flat_rounded);
    final label = isImproving ? 'Improving' : (isWorsening ? 'Deteriorating' : 'Stable');

    return AppCard(
      child: SizedBox(
        height: 120,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: AppSpacing.xs),
            Text(label, style: AppTypography.h3.copyWith(fontSize: 14, color: color)),
            const SizedBox(height: 2),
            Text(
              'vs Previous Week',
              style: AppTypography.caption.copyWith(color: AppColors.charcoal500),
            ),
          ],
        ),
      ),
    );
  }
}
