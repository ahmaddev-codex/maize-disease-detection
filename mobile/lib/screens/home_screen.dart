import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../design_system/design_system.dart';
import '../navigation/open_scan.dart';
import '../providers/app_provider.dart';
import '../providers/classifier_state.dart';
import '../services/path_resolver.dart';
import '../utils/time_format.dart';

class _ModelStatusPill extends StatelessWidget {
  const _ModelStatusPill({
    required this.state,
    required this.isDark,
    required this.onRetry,
  });

  final ClassifierState state;
  final bool isDark;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (dotColor, label) = switch (state.phase) {
      ClassifierPhase.loading => (AppColors.charcoal400, 'Loading disease model…'),
      ClassifierPhase.ready   => (AppColors.emeraldLight, state.status ?? 'Disease model ready'),
      ClassifierPhase.failed  => (AppColors.danger, 'Disease model failed to load'),
    };

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: state.isFailed
                  ? AppColors.danger
                  : (isDark ? AppColors.charcoal400 : AppColors.charcoal600),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (state.isFailed)
          TextButton(
            key: const Key('model-retry-button'),
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
      ],
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  // The model is loaded once by the splash screen (classifierStateProvider).
  Future<void> _init() async {
    await ref.read(scanListProvider.notifier).load();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final scans   = ref.watch(scanListProvider);
    final modelState = ref.watch(classifierStateProvider);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final recent  = scans.take(5).toList();

    // Same source and window as the dashboard, so the two always agree (T16).
    final stats      = ref.watch(farmStatsProvider(30)).valueOrNull;
    final total      = stats?.total ?? 0;
    final diseased   = stats?.diseased ?? 0;
    final healthRate = stats?.healthRate;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // ── Atmospheric Header ───────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: AppColors.forestDark,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.map_outlined, color: Colors.white),
                tooltip: 'Geospatial Farm Map',
                onPressed: () => context.push('/map'),
              ),
              IconButton(
                icon: const Icon(Icons.document_scanner_outlined, color: Colors.white),
                tooltip: 'Seed Label OCR',
                onPressed: () => context.push('/ocr'),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: AppSpacing.md, bottom: AppSpacing.md),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.charcoal400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const MaizeGuardWordmark(
                    height: 20,
                    isDark: true,
                  ),
                ],
              ),
            ),
          ),

          // ── Main Body ────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 1. Model status (real variant, or a retry when loading failed)
                _ModelStatusPill(
                  state: modelState,
                  isDark: isDark,
                  onRetry: () => ref.read(classifierStateProvider.notifier).load(),
                ),

                const SizedBox(height: AppSpacing.md),

                // 2. Primary Scan Hero Card
                AppCard(
                  surfaceColor: AppColors.forestDark,
                  borderColor: AppColors.primaryLight.withValues(alpha: 0.3),
                  onTap: modelState.isFailed ? null : () => context.push('/camera'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: AppRadii.sm,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                'REAL-TIME DIAGNOSIS',
                                style: AppTypography.overline.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Diagnose Maize Foliage',
                              style: AppTypography.h2.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Instant edge inference for NCLB, Rust, and GLS. Works fully offline.',
                              style: AppTypography.bodySmall.copyWith(color: AppColors.charcoal300),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.emeraldBase,
                                    borderRadius: AppRadii.md,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Open Camera',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: const Center(
                          child: MaizeGuardLogo(
                            size: 42,
                            isDark: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // 3. Quick Utility Actions Grid (Seed OCR & Farm Map)
                Row(
                  children: [
                    Expanded(
                      child: AppCard(
                        onTap: () => context.push('/ocr'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.qr_code_scanner_rounded, color: AppColors.emeraldBase, size: 28),
                            const SizedBox(height: AppSpacing.sm),
                            Text('Seed Label OCR', style: AppTypography.h3),
                            const SizedBox(height: 2),
                            Text(
                              'Extract lot number & crop variety',
                              style: AppTypography.caption.copyWith(color: AppColors.charcoal500),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppCard(
                        onTap: () => context.push('/map'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.pin_drop_outlined, color: AppColors.emeraldBase, size: 28),
                            const SizedBox(height: AppSpacing.sm),
                            Text('Field Disease Map', style: AppTypography.h3),
                            const SizedBox(height: 2),
                            Text(
                              'Geospatial farm tracking',
                              style: AppTypography.caption.copyWith(color: AppColors.charcoal500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // 4. Farm Health Overview Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('FARM HEALTH STATUS', style: AppTypography.overline.copyWith(color: AppColors.charcoal500)),
                    GestureDetector(
                      onTap: () => context.go('/dashboard'),
                      child: Text(
                        'Detailed Analytics →',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.emeraldBase,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$total', style: AppTypography.h2),
                            Text('Scans (30 days)', style: AppTypography.caption.copyWith(color: AppColors.charcoal500)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              healthRate == null ? '—' : '${(healthRate * 100).round()}%',
                              style: AppTypography.h2.copyWith(color: AppColors.healthy),
                            ),
                            Text('Healthy Rate', style: AppTypography.caption.copyWith(color: AppColors.charcoal500)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$diseased',
                              style: AppTypography.h2.copyWith(color: AppColors.rust),
                            ),
                            Text('Infections', style: AppTypography.caption.copyWith(color: AppColors.charcoal500)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // 5. Recent Diagnoses Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('RECENT FIELD DIAGNOSES', style: AppTypography.overline.copyWith(color: AppColors.charcoal500)),
                    if (recent.isNotEmpty)
                      GestureDetector(
                        onTap: () => context.go('/history'),
                        child: Text(
                          'View All (${scans.length})',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.emeraldBase,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                if (recent.isEmpty)
                  AppCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.grass_rounded, size: 40, color: AppColors.charcoal300),
                            const SizedBox(height: AppSpacing.xs),
                            Text('No Diagnoses Recorded Yet', style: AppTypography.h3),
                            const SizedBox(height: 2),
                            Text(
                              'Tap "Diagnose Maize Foliage" above to scan your first leaf.',
                              style: AppTypography.caption.copyWith(color: AppColors.charcoal500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: recent.asMap().entries.map((e) {
                        final scan = e.value;
                        final isLast = e.key == recent.length - 1;
                        final absPath = PathResolver.resolve(scan.imagePath);
                        final hasImage = scan.imagePath.isNotEmpty && File(absPath).existsSync();

                        final badgeColor = switch (scan.classId) {
                          0 => AppColors.nclb,
                          1 => AppColors.rust,
                          2 => AppColors.gls,
                          3 => AppColors.healthy,
                          _ => AppColors.charcoal500,
                        };

                        return Column(
                          children: [
                            ListTile(
                              onTap: () => openScan(context, ref, scan.id!),
                              leading: ClipRRect(
                                borderRadius: AppRadii.sm,
                                child: hasImage
                                    ? Image.file(File(absPath), width: 44, height: 44, fit: BoxFit.cover)
                                    : Container(
                                        width: 44,
                                        height: 44,
                                        color: badgeColor.withValues(alpha: 0.12),
                                        child: Icon(Icons.eco_outlined, color: badgeColor, size: 20),
                                      ),
                              ),
                              title: Text(
                                scan.className,
                                style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                formatScanTime(scan.scannedAt),
                                style: AppTypography.caption.copyWith(color: AppColors.charcoal400),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.15),
                                  borderRadius: AppRadii.sm,
                                ),
                                child: Text(
                                  '${(scan.confidence * 100).toStringAsFixed(0)}%',
                                  style: AppTypography.caption.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: badgeColor,
                                  ),
                                ),
                              ),
                            ),
                            if (!isLast) const Divider(height: 1, indent: 70),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                const SizedBox(height: AppSpacing.xxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
