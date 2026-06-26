import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../constants/colors.dart';
import '../models/scan_record.dart';
import '../providers/app_provider.dart';
import '../services/classifier_service.dart';
import '../services/path_resolver.dart';
import '../widgets/ds.dart';

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

  Future<void> _init() async {
    await ClassifierService.instance.loadModel();
    if (!mounted) return;
    ref.read(classifierReadyProvider.notifier).state = true;
    await ref.read(scanListProvider.notifier).load();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final scans   = ref.watch(scanListProvider);
    final isReady = ref.watch(classifierReadyProvider);
    final isDark  = ref.watch(isDarkModeProvider);
    final recent  = scans.take(5).toList();

    // Stats derived from all scans
    final total      = scans.length;
    final healthy    = scans.where((s) => s.classId == 3).length;
    final healthPct  = total == 0 ? 100 : (healthy / total * 100).round();
    final diseased   = total - healthy;

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvas,
      body: CustomScrollView(
        slivers: [
          // ── Glass app bar ────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 110,
            backgroundColor:
                (isDark ? AppColors.surfaceDark : AppColors.surface).withOpacity(0.88),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const DuotoneIcon(Icons.map_rounded,
                    size: 20,
                    primaryColor: AppColors.successFg,
                    secondaryColor: Color(0xFF69F0AE)),
                tooltip: 'Farm Map',
                onPressed: () => context.push('/map'),
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
                  title: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_greeting(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                          )),
                      const Text('MaizeGuard',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: AppSpacing.pagePad,
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 12),

                // ── Model status ─────────────────────────────────────────
                _ModelStatusChip(isReady: isReady),
                const SizedBox(height: 16),

                // ── Hero scan card ───────────────────────────────────────
                _ScanHeroCard(),
                const SizedBox(height: 12),

                // ── Seed label shortcut ─────────────────────────────────
                _OcrCard(),
                const SizedBox(height: 20),

                // ── Quick stats ─────────────────────────────────────────
                const SectionLabel('Farm Overview', topMargin: 0),
                Row(children: [
                  Expanded(child: StatChip(
                    value: '$total',
                    label: 'Total scans',
                    icon: Icons.qr_code_scanner_rounded,
                    color: AppColors.accent,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: StatChip(
                    value: '$healthPct%',
                    label: 'Healthy',
                    icon: Icons.favorite_rounded,
                    color: AppColors.successFg,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: StatChip(
                    value: '$diseased',
                    label: 'Diseased',
                    icon: Icons.warning_rounded,
                    color: AppColors.dangerFg,
                  )),
                ]),

                // ── Recent scans ─────────────────────────────────────────
                if (recent.isNotEmpty) ...[
                  const SectionLabel('Recent Scans'),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: recent.asMap().entries.map((e) {
                        final scan = e.value;
                        final isLast = e.key == recent.length - 1;
                        return Column(
                          children: [
                            _ScanRow(scan: scan),
                            if (!isLast)
                              const Divider(height: 1, indent: 72, endIndent: 16),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Model status chip ─────────────────────────────────────────────────────────
class _ModelStatusChip extends StatelessWidget {
  const _ModelStatusChip({required this.isReady});
  final bool isReady;

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 7, height: 7,
      decoration: BoxDecoration(
        color: isReady ? AppColors.successFg : AppColors.attentionFg,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(
          color: (isReady ? AppColors.successFg : AppColors.attentionFg)
              .withOpacity(0.5),
          blurRadius: 6,
        )],
      ),
    ),
    const SizedBox(width: 6),
    Text(
      isReady
          ? ClassifierService.instance.modelStatus
          : 'Loading model…',
      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
    ),
  ]);
}

// ── Hero scan card ─────────────────────────────────────────────────────────────
class _ScanHeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push('/camera'),
    child: GlassCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('AI DETECTION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                      letterSpacing: 0.8,
                    )),
              ),
              const SizedBox(height: 8),
              Text('Scan a Leaf',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 4),
              const Text('Camera or gallery · <2s on-device',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, AppColors.accentFg],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.30),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Scan Now',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w700, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Decorative icon graphic
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.grass_rounded,
              size: 46, color: AppColors.accent),
        ),
      ]),
    ),
  );
}

// ── OCR shortcut card ─────────────────────────────────────────────────────────
class _OcrCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push('/ocr'),
    child: GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppColors.doneFg.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const DuotoneIcon(Icons.document_scanner_rounded,
              size: 22,
              primaryColor: AppColors.doneFg,
              secondaryColor: Color(0xFFB39DDB)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Scan Seed Label',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              const Text('Extract variety, batch & planting date via OCR',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
      ]),
    ),
  );
}

// ── Scan row in recent list ───────────────────────────────────────────────────
class _ScanRow extends ConsumerWidget {
  const _ScanRow({super.key, required this.scan});
  final ScanRecord scan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color      = AppColors.forClass(scan.classId);
    final absPath    = PathResolver.resolve(scan.imagePath);
    final hasImage   = scan.imagePath.isNotEmpty && File(absPath).existsSync();

    return InkWell(
      onTap: () {
        final result = ClassificationResult(
          classId:    scan.classId,
          className:  scan.className,
          shortName:  scan.shortName,
          confidence: scan.confidence,
          allScores:  scan.allScores,
          latencyMs:  scan.latencyMs,
        );
        ref.read(lastResultProvider.notifier).state       = result;
        ref.read(lastImagePathProvider.notifier).state    = absPath;
        ref.read(lastScanVarietyProvider.notifier).state  = scan.cropVariety;
        context.push('/recommendation');
      },
      borderRadius: BorderRadius.circular(0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: hasImage
                ? Image.file(File(absPath),
                    width: 48, height: 48, fit: BoxFit.cover)
                : Container(
                    width: 48, height: 48,
                    color: color.withOpacity(0.12),
                    child: Icon(Icons.grass_rounded,
                        color: color.withOpacity(0.5), size: 24),
                  ),
          ),
          const SizedBox(width: 12),
          // Disease + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  DiseaseDot(color),
                  const SizedBox(width: 6),
                  Text(scan.shortName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
                const SizedBox(height: 2),
                Text(DateFormat('d MMM, HH:mm').format(scan.scannedAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          // Confidence badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${(scan.confidence * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}
