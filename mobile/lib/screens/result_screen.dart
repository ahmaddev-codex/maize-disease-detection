import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/colors.dart';
import '../constants/diseases.dart';
import '../models/scan_record.dart';
import '../providers/app_provider.dart';
import '../widgets/ai_advice_sheet.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result    = ref.watch(lastResultProvider);
    final imagePath = ref.watch(lastImagePathProvider);

    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Result')),
        body: const Center(child: Text('No result available')),
      );
    }

    final disease    = diseaseForClass(result.classId);
    final color      = AppColors.forClass(result.classId);
    final classNames = ['NCLB', 'Rust', 'GLS', 'Healthy'];
    final hasImage   = imagePath != null && imagePath.isNotEmpty &&
                       File(imagePath).existsSync();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: CustomScrollView(
        slivers: [
          // ── Hero image app bar ─────────────────────────────────────────
          SliverAppBar(
            expandedHeight: hasImage ? 280 : 160,
            pinned: true,
            backgroundColor: color.withOpacity(0.92),
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: hasImage
                  ? _HeroImage(imagePath: imagePath, color: color)
                  : _ColorBanner(color: color, disease: disease),
              collapseMode: CollapseMode.parallax,
            ),
            actions: [
              TextButton.icon(
                onPressed: () => showAiAdviceSheet(context),
                icon: const Icon(Icons.lightbulb_rounded, size: 18, color: Colors.white),
                label: const Text('AI Advice', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Glass diagnosis card ───────────────────────────────
                  _GlassCard(
                    margin: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            result.classId == 3
                                ? Icons.check_circle_rounded
                                : Icons.warning_rounded,
                            color: color,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(disease.name,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: color, fontWeight: FontWeight.w700,
                                  )),
                              const SizedBox(height: 4),
                              Text(
                                '${(result.confidence * 100).toStringAsFixed(1)}% confidence',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                '${result.latencyMs.toStringAsFixed(0)} ms inference',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Class scores ───────────────────────────────────────
                  _SectionLabel('Class Scores'),
                  const SizedBox(height: 10),
                  _GlassCard(
                    child: Column(
                      children: List.generate(classNames.length, (i) {
                        final score = result.allScores[i];
                        final c     = AppColors.forClass(i);
                        final isTop = i == result.classId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(classNames[i],
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isTop ? FontWeight.w700 : FontWeight.w400,
                                        color: isTop ? c : AppColors.textSecondary,
                                      )),
                                  Text('${(score * 100).toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isTop ? FontWeight.w700 : FontWeight.w400,
                                        color: c,
                                      )),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: score,
                                  minHeight: 8,
                                  backgroundColor: c.withOpacity(0.12),
                                  valueColor: AlwaysStoppedAnimation(c),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── About ──────────────────────────────────────────────
                  _SectionLabel('About'),
                  const SizedBox(height: 10),
                  _GlassCard(
                    child: Text(disease.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6)),
                  ),

                  if (!result.isHealthy) ...[
                    const SizedBox(height: 16),
                    _SectionLabel('Symptoms'),
                    const SizedBox(height: 10),
                    _BulletCard(items: disease.symptoms, color: AppColors.attentionFg),

                    const SizedBox(height: 16),
                    _SectionLabel('Treatments'),
                    const SizedBox(height: 10),
                    _BulletCard(items: disease.treatments, color: AppColors.successFg),
                  ],

                  const SizedBox(height: 16),
                  _SectionLabel('Prevention'),
                  const SizedBox(height: 10),
                  _BulletCard(items: disease.prevention, color: AppColors.accentFg),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => showAiAdviceSheet(context),
                      icon: const Icon(Icons.lightbulb_rounded),
                      label: const Text('Get AI Advice'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero image with colour overlay and blur vignette ─────────────────────────
class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.imagePath, required this.color});
  final String imagePath;
  final Color color;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.file(File(imagePath), fit: BoxFit.cover),
      // Bottom gradient so the AppBar title stays readable
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                color.withOpacity(0.6),
              ],
              stops: const [0.5, 1.0],
            ),
          ),
        ),
      ),
    ],
  );
}

class _ColorBanner extends StatelessWidget {
  const _ColorBanner({required this.color, required this.disease});
  final Color color;
  final DiseaseInfo disease;

  @override
  Widget build(BuildContext context) => Container(
    color: color.withOpacity(0.15),
    alignment: Alignment.center,
    child: Icon(Icons.grass_rounded, size: 80, color: color.withOpacity(0.3)),
  );
}

// ── Glassmorphic card ─────────────────────────────────────────────────────────
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.margin});
  final Widget child;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.surfaceDark : Colors.white).withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (isDark ? AppColors.borderDark : AppColors.border).withOpacity(0.6),
              ),
              boxShadow: AppColors.cardShadow,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      color: AppColors.textSecondary,
    ),
  );
}

// ── Bullet list card ──────────────────────────────────────────────────────────
class _BulletCard extends StatelessWidget {
  const _BulletCard({required this.items, required this.color});
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) => _GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 6, height: 6,
              margin: const EdgeInsets.only(top: 5, right: 10),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Expanded(child: Text(item,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5))),
          ],
        ),
      )).toList(),
    ),
  );
}

extension on ClassificationResult {
  bool get isHealthy => classId == 3;
}
