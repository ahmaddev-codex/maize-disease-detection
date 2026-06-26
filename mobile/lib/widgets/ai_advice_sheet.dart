import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_env.dart';
import '../constants/colors.dart';
import '../constants/diseases.dart';
import '../models/scan_record.dart';
import '../providers/app_provider.dart';
import '../services/ai_advisor.dart';
import 'ds.dart';

/// Opens a Google-Maps-style draggable bottom sheet with AI advice.
void showAiAdviceSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    useSafeArea: false,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.5, 0.65, 0.92],
      builder: (ctx, scrollController) => _AiAdviceSheetContent(
        scrollController: scrollController,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _AiAdviceSheetContent extends ConsumerStatefulWidget {
  const _AiAdviceSheetContent({required this.scrollController});
  final ScrollController scrollController;

  @override
  ConsumerState<_AiAdviceSheetContent> createState() =>
      _AiAdviceSheetContentState();
}

class _AiAdviceSheetContentState
    extends ConsumerState<_AiAdviceSheetContent> {
  String? _aiAdvice;
  bool    _loadingAi = false;
  String? _aiError;

  @override
  Widget build(BuildContext context) {
    final result     = ref.watch(lastResultProvider);
    final isDark     = ref.watch(isDarkModeProvider);
    final geminiKey  = ref.watch(geminiKeyProvider);
    final scans      = ref.watch(scanListProvider);
    final cropVariety = scans.isNotEmpty ? scans.first.cropVariety : null;

    final bg = isDark ? AppColors.surfaceDark : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 32,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Drag handle ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 12, 10),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 20, color: AppColors.attentionFg),
                const SizedBox(width: 10),
                Text(
                  'AI Recommendation',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.textSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(36, 36),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Scrollable body ────────────────────────────────────────────────
          Expanded(
            child: result == null
                ? const _EmptyResult()
                : _SheetBody(
                    scrollController: widget.scrollController,
                    result: result,
                    geminiKey: geminiKey,
                    aiAdvice: _aiAdvice,
                    loadingAi: _loadingAi,
                    aiError: _aiError,
                    onFetch: () => _fetchAdvice(result, cropVariety, geminiKey),
                    onSaveKey: (k) =>
                        ref.read(geminiKeyProvider.notifier).save(k),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchAdvice(
      ClassificationResult result, String? variety, String? geminiKey) async {
    setState(() {
      _loadingAi = true;
      _aiError   = null;
      _aiAdvice  = null;
    });
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

// ─────────────────────────────────────────────────────────────────────────────

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.scrollController,
    required this.result,
    required this.geminiKey,
    required this.aiAdvice,
    required this.loadingAi,
    required this.aiError,
    required this.onFetch,
    required this.onSaveKey,
  });

  final ScrollController scrollController;
  final ClassificationResult result;
  final String? geminiKey;
  final String? aiAdvice;
  final bool    loadingAi;
  final String? aiError;
  final VoidCallback onFetch;
  final void Function(String) onSaveKey;

  @override
  Widget build(BuildContext context) {
    final disease  = diseaseForClass(result.classId);
    final color    = AppColors.forClass(result.classId);

    final needsKey = !kDebugMode && (geminiKey == null || geminiKey!.isEmpty)
        && AppEnv.geminiApiKey.isEmpty;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        // ── Disease header ──────────────────────────────────────────────────
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(disease.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: color)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${(result.confidence * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: color, fontSize: 14),
              ),
            ),
          ]),
        ),

        // ── AI Advice ────────────────────────────────────────────────────────
        const SectionLabel('AI Agronomic Advice'),

        if (needsKey)
          _ApiKeyCard(onSave: onSaveKey)
        else if (loadingAi)
          const GlassCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Analysing…',
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          )
        else if (aiError != null)
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.error_rounded,
                      color: AppColors.dangerFg, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(aiError!,
                        style: const TextStyle(
                            color: AppColors.dangerFg, fontSize: 12)),
                  ),
                ]),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onFetch,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ),
          )
        else if (aiAdvice != null)
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.auto_awesome_rounded,
                      size: 18, color: AppColors.attentionFg),
                  const SizedBox(width: 8),
                  const Text('AI Advice',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.attentionFg)),
                  if (kDebugMode) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.successFg.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        AppEnv.ollamaModel,
                        style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.successFg,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 10),
                Text(
                  aiAdvice!,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.65),
                ),
              ],
            ),
          )
        else
          GlassCard(
            child: Column(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 32, color: AppColors.attentionFg),
                const SizedBox(height: 10),
                const Text(
                  'Get personalised agronomic advice tailored to Nigerian\n'
                  'farming practices, seasons, and local fungicide options.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onFetch,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: const Text('Get AI Advice'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EmptyResult extends StatelessWidget {
  const _EmptyResult();

  @override
  Widget build(BuildContext context) => const EmptyState(
    icon: Icons.lightbulb_rounded,
    title: 'No scan result yet',
    subtitle: 'Scan a maize leaf first to get\npersonalised recommendations.',
  );
}

class _ApiKeyCard extends StatefulWidget {
  const _ApiKeyCard({required this.onSave});
  final void Function(String) onSave;

  @override
  State<_ApiKeyCard> createState() => _ApiKeyCardState();
}

class _ApiKeyCardState extends State<_ApiKeyCard> {
  final _ctrl    = TextEditingController();
  bool  _obscure = true;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.key_rounded, size: 20, color: AppColors.accent),
          const SizedBox(width: 10),
          Text('Gemini API key required',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        const Text(
          'Add your Gemini key to get AI-powered agronomic advice. '
          'Stored securely on this device.',
          style: TextStyle(
              fontSize: 12, color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _ctrl,
          obscureText: _obscure,
          decoration: InputDecoration(
            hintText: 'AIza…',
            suffixIcon: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 18,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              if (_ctrl.text.isNotEmpty) widget.onSave(_ctrl.text.trim());
            },
            child: const Text('Save key'),
          ),
        ),
      ],
    ),
  );
}
