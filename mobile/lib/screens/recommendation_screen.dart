import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_env.dart';
import '../constants/colors.dart';
import '../constants/diseases.dart';
import '../models/scan_record.dart';
import '../providers/app_provider.dart';
import '../services/ai_advisor.dart';
import '../services/recommendation_engine.dart';
import '../widgets/ds.dart';

class RecommendationScreen extends ConsumerStatefulWidget {
  const RecommendationScreen({super.key});
  @override
  ConsumerState<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends ConsumerState<RecommendationScreen> {
  String? _aiAdvice;
  bool    _loadingAi = false;
  String? _aiError;

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(lastResultProvider);
    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recommendation')),
        body: const EmptyState(
          icon: Icons.lightbulb_rounded,
          title: 'No scan result yet',
          subtitle: 'Scan a maize leaf first to get\npersonalised recommendations.',
        ),
      );
    }

    final isDark      = ref.watch(isDarkModeProvider);
    final disease     = diseaseForClass(result.classId);
    final recs        = RecommendationEngine.generate(result);
    final geminiKey   = ref.watch(geminiKeyProvider);
    final color       = AppColors.forClass(result.classId);
    // Use variety stored at scan time, not scans.first (which could be a different scan)
    final cropVariety = ref.watch(lastScanVarietyProvider);

    // In debug → Ollama (no key needed); in release → Gemini (needs key)
    final needsKey = !kDebugMode && (geminiKey == null || geminiKey.isEmpty)
        && AppEnv.geminiApiKey.isEmpty;

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
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: const FlexibleSpaceBar(
                  title: Text('Recommendation',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                  titlePadding: EdgeInsets.only(left: 16, bottom: 14),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: AppSpacing.pagePad,
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 12),

                // ── Disease header ────────────────────────────────────────
                GlassCard(
                  child: Row(children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        result.classId == 3
                            ? Icons.check_circle_rounded
                            : Icons.warning_rounded,
                        color: color, size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(disease.name,
                            style: TextStyle(fontWeight: FontWeight.w800,
                                fontSize: 15, color: color)),
                        const SizedBox(height: 3),
                        Text(recs.urgencyLabel,
                            style: const TextStyle(fontSize: 12,
                                color: AppColors.textSecondary)),
                      ],
                    )),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${(result.confidence * 100).toStringAsFixed(0)}%',
                        style: TextStyle(fontWeight: FontWeight.w800,
                            color: color, fontSize: 14),
                      ),
                    ),
                  ]),
                ),

                // ── Context ───────────────────────────────────────────────
                const SectionLabel('Context'),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    _InfoRow(Icons.calendar_month_rounded, AppColors.accent,
                        'Farming season', recs.season),
                    const Divider(height: 1, indent: 56),
                    _InfoRow(Icons.timer_rounded, AppColors.textSecondary,
                        'Inference time', '${result.latencyMs.toStringAsFixed(0)} ms'),
                    if (cropVariety != null) ...[
                      const Divider(height: 1, indent: 56),
                      _InfoRow(Icons.grass_rounded, AppColors.successFg,
                          'Crop variety', cropVariety),
                    ],
                  ]),
                ),

                // ── On-device recommendations ─────────────────────────────
                for (final section in recs.sections) ...[
                  SectionLabel(section.title),
                  BulletCard(
                    items: section.items,
                    bulletColor: section.color ?? AppColors.accentFg,
                  ),
                ],

                // ── AI Advice ─────────────────────────────────────────────
                const SectionLabel('AI Agronomic Advice'),

                if (needsKey)
                  _ApiKeyPrompt(
                    onSave: (key) => ref.read(geminiKeyProvider.notifier).save(key),
                  )
                else if (_loadingAi)
                  const GlassCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Analysing…',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                else if (_aiError != null)
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.error_rounded,
                              color: AppColors.dangerFg, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_aiError!,
                              style: const TextStyle(
                                  color: AppColors.dangerFg, fontSize: 12))),
                        ]),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () => _fetchAdvice(result, cropVariety, geminiKey),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                else if (_aiAdvice != null)
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const DuotoneIcon(Icons.auto_awesome_rounded,
                              size: 18,
                              primaryColor: AppColors.attentionFg,
                              secondaryColor: Color(0xFFFFD54F)),
                          const SizedBox(width: 8),
                          const Text('AI Advice',
                              style: TextStyle(fontWeight: FontWeight.w700,
                                  fontSize: 12, color: AppColors.attentionFg)),
                          if (kDebugMode) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.successFg.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(AppEnv.ollamaModel,
                                  style: const TextStyle(fontSize: 9,
                                      color: AppColors.successFg,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 10),
                        Text(_aiAdvice!,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.65)),
                      ],
                    ),
                  )
                else
                  GlassCard(
                    child: Column(
                      children: [
                        const DuotoneIcon(Icons.auto_awesome_rounded,
                            size: 32,
                            primaryColor: AppColors.attentionFg,
                            secondaryColor: Color(0xFFFFD54F)),
                        const SizedBox(height: 10),
                        const Text(
                          'Get personalised agronomic advice tailored to Nigerian\n'
                          'farming practices, seasons, and local fungicide options.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12,
                              color: AppColors.textSecondary, height: 1.5),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _fetchAdvice(result, cropVariety, geminiKey),
                          icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                          label: const Text('Get AI Advice'),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchAdvice(
      ClassificationResult result, String? variety, String? geminiKey) async {
    setState(() { _loadingAi = true; _aiError = null; _aiAdvice = null; });
    try {
      final advice = await AiAdvisor.instance.getAdvice(
        classId:     result.classId,
        confidence:  result.confidence,
        cropVariety: variety,
        apiKey:      geminiKey,
      );
      if (mounted) setState(() { _aiAdvice = advice; _loadingAi = false; });
    } catch (e) {
      if (mounted) setState(() { _aiError = 'Failed: $e'; _loadingAi = false; });
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.iconColor, this.label, this.value);
  final IconData icon;
  final Color iconColor;
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 16, color: iconColor),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
      Text(value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _ApiKeyPrompt extends StatefulWidget {
  const _ApiKeyPrompt({required this.onSave});
  final void Function(String) onSave;

  @override
  State<_ApiKeyPrompt> createState() => _ApiKeyPromptState();
}

class _ApiKeyPromptState extends State<_ApiKeyPrompt> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const DuotoneIcon(Icons.key_rounded,
              size: 20, primaryColor: AppColors.accent,
              secondaryColor: AppColors.accentFg),
          const SizedBox(width: 10),
          Text('Gemini API key required',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        const Text(
          'Add your Gemini key to get AI-powered agronomic advice. '
          'Stored securely on this device.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _ctrl,
          obscureText: _obscure,
          decoration: InputDecoration(
            hintText: 'AIza…',
            suffixIcon: IconButton(
              icon: Icon(_obscure
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded, size: 18),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () {
            if (_ctrl.text.isNotEmpty) widget.onSave(_ctrl.text.trim());
          },
          child: const Text('Save key'),
        ),
      ],
    ),
  );
}
