import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/ai_advisor.dart';
import '../services/database.dart';
import '../services/recommendation_engine.dart';

/// Full-page AI recommendations screen.
/// Shown from ResultScreen — loads on-device recs immediately, then optionally
/// upgrades to Gemini API if a key is configured.
class RecommendationScreen extends StatefulWidget {
  final int classId;
  final double confidence;
  final String? cropVariety;
  final String? plantingDate;
  final String? batchNumber;
  final double? latitude;
  final double? longitude;

  const RecommendationScreen({
    super.key,
    required this.classId,
    required this.confidence,
    this.cropVariety,
    this.plantingDate,
    this.batchNumber,
    this.latitude,
    this.longitude,
  });

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  RecommendationResult? _result;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Fetch recent history for trend analysis
      final history = await AppDatabase.instance.scanDao.recentScans(limit: 10);
      final result = await AiAdvisor.advise(
        classId: widget.classId,
        confidence: widget.confidence,
        cropVariety: widget.cropVariety,
        plantingDate: widget.plantingDate,
        batchNumber: widget.batchNumber,
        latitude: widget.latitude,
        longitude: widget.longitude,
        recentHistory: history,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.fg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.psychology_rounded, color: GhC.accent, size: 16),
            SizedBox(width: 8),
            Text('AI Recommendations',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.border),
        ),
        actions: [
          _AppBarIconBtn(
            icon: Icons.settings_rounded,
            tooltip: 'Configure Gemini API key',
            onTap: _showApiKeyDialog,
          ),
          if (!_loading)
            _AppBarIconBtn(
              icon: Icons.refresh_rounded,
              tooltip: 'Refresh',
              onTap: _load,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : _buildContent(_result!),
    );
  }

  Widget _buildLoading() {
    final c = context.gc;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
              color: GhC.accentEmphasis, strokeWidth: 2),
          const SizedBox(height: 16),
          Text('Generating recommendations…', style: GhText.body(c)),
          const SizedBox(height: 4),
          Text('Analysing disease context + scan history',
              style: GhText.muted(c)),
        ],
      ),
    );
  }

  Widget _buildError() {
    final c = context.gc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_rounded, color: GhC.danger, size: 32),
            const SizedBox(height: 12),
            Text('Failed to load recommendations', style: GhText.h3(c)),
            const SizedBox(height: 8),
            Text(_error!, style: GhText.muted(c), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            GhButton('Retry', icon: Icons.refresh_rounded, onTap: _load),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(RecommendationResult rec) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SourceBadge(source: rec.source),
        if (rec.apiError != null) ...[
          const SizedBox(height: 8),
          _ApiErrorBanner(error: rec.apiError!),
        ],
        const SizedBox(height: 12),
        _UrgencyBanner(urgency: rec.urgency, headline: rec.headline),
        const SizedBox(height: 16),
        _SummaryCard(summary: rec.summary, trend: rec.trend, season: rec.season),
        const SizedBox(height: 16),
        _ActionList(actions: rec.immediateActions),
        if (rec.fungicideOptions.isNotEmpty) ...[
          const SizedBox(height: 16),
          _FungicideCard(options: rec.fungicideOptions),
        ],
        const SizedBox(height: 16),
        _TimingCard(advice: rec.timingAdvice),
        if (rec.resistanceNote != null) ...[
          const SizedBox(height: 16),
          _ResistanceCard(note: rec.resistanceNote!),
        ],
        if (rec.preventionTips.isNotEmpty) ...[
          const SizedBox(height: 16),
          _PreventionCard(tips: rec.preventionTips),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _showApiKeyDialog() async {
    final existing = await AiAdvisor.getApiKey();
    if (!mounted) return;

    final controller = TextEditingController(text: existing ?? '');
    // Capture c before the async gap so the bottom sheet never calls
    // context.gc (which would register InheritedWidget dependencies on the
    // sheet's element, causing _dependents.isEmpty assertions on dismiss).
    final c = context.gc;

    // showModalBottomSheet uses a different route/overlay teardown path than
    // showDialog — it does not trigger the _dependents.isEmpty /
    // "wrong build scope" assertions that Dialog routes cause when a
    // StatefulWidget containing a TextField is dismissed without interaction.
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: c.border),
      ),
      // Keyboard avoidance is handled here in the builder closure, NOT inside
      // _ApiKeySheet.  The builder runs in Flutter's internal widget context so
      // MediaQuery.of(ctx) doesn't register _ApiKeySheetState as a dependent
      // of the route-local MediaQuery.  We then provide a fresh MediaQuery with
      // viewInsets zeroed-out to the sheet body — all of _ApiKeySheet's
      // InheritedWidget dependencies are scoped to this locally-owned element,
      // so when the route deactivates they unwind in the correct order and the
      // _dependents.isEmpty assertion never fires on iOS.
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return MediaQuery(
          data: MediaQuery.of(ctx).copyWith(viewInsets: EdgeInsets.zero),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottom),
            child: _ApiKeySheet(
              c: c,
              controller: controller,
              existing: existing,
            ),
          ),
        );
      },
    );

    final key = controller.text;
    // Do NOT dispose immediately — the bottom sheet's exit animation keeps
    // the TextField in the tree for ~250 ms after Navigator.pop() returns.
    // Disposing here crashes the TextField. The controller is a local variable
    // so GC will reclaim it once the animation finishes and the widget is gone.

    if (!mounted) return;

    bool needsReload = false;
    if (action == 'save' && key.isNotEmpty) {
      await AiAdvisor.saveApiKey(key);
      needsReload = true;
    } else if (action == 'clear') {
      await AiAdvisor.clearApiKey();
      needsReload = true;
    }

    // Defer the reload to the next frame so the sheet's exit animation has
    // fully cleared the overlay before we rebuild the parent.
    if (needsReload && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

/// Ink-free AppBar action icon. `IconButton` uses InkWell which can keep
/// animating after the surrounding Material detaches, causing
/// 'referenceBox.attached' assertion spam. GestureDetector has no ink layer.
class _AppBarIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _AppBarIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}

/// Shown when the Gemini API key is set but the call failed.
class _ApiErrorBanner extends StatelessWidget {
  final String error;
  const _ApiErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: GhC.attention.withValues(alpha: 0.08),
        border: Border.all(color: GhC.attention.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: GhC.attention, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gemini API failed — showing on-device results',
                    style: TextStyle(
                        color: GhC.attention,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(error,
                    style: TextStyle(
                        color: c.fgMuted, fontSize: 10, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final RecommendationSource source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    final isCloud = source == RecommendationSource.geminiApi;
    return Row(
      children: [
        Icon(
          isCloud ? Icons.cloud_done_rounded : Icons.memory_rounded,
          color: isCloud ? GhC.accent : c.fgSubtle,
          size: 14,
        ),
        const SizedBox(width: 6),
        Text(
          isCloud ? 'Powered by Gemini AI' : 'On-device rule engine',
          style: TextStyle(
            color: isCloud ? GhC.accent : c.fgSubtle,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        if (!isCloud)
          GhLabel('Offline', color: c.fgSubtle, fontSize: 9),
        if (isCloud)
          GhLabel('gemini-2.0-flash', color: GhC.accentEmphasis, fontSize: 9),
      ],
    );
  }
}

class _UrgencyBanner extends StatelessWidget {
  final Urgency urgency;
  final String headline;
  const _UrgencyBanner({required this.urgency, required this.headline});

  Color get _color => switch (urgency) {
        Urgency.high   => GhC.danger,
        Urgency.medium => GhC.attention,
        Urgency.low    => GhC.accent,
        Urgency.none   => GhC.success,
      };

  String get _urgencyLabel => switch (urgency) {
        Urgency.high   => 'HIGH URGENCY',
        Urgency.medium => 'MEDIUM URGENCY',
        Urgency.low    => 'LOW URGENCY',
        Urgency.none   => 'HEALTHY',
      };

  IconData get _icon => switch (urgency) {
        Urgency.high   => Icons.warning_rounded,
        Urgency.medium => Icons.info_rounded,
        Urgency.low    => Icons.notifications_rounded,
        Urgency.none   => Icons.check_circle_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.08),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: _color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GhLabel(_urgencyLabel, color: _color, fontSize: 10),
                const SizedBox(height: 6),
                Text(headline,
                    style: TextStyle(
                      color: _color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String summary;
  final DiseaseTrend trend;
  final NigerianSeason season;
  const _SummaryCard(
      {required this.summary, required this.trend, required this.season});

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
                Icon(Icons.summarize_rounded, color: c.fgSubtle, size: 14),
                const SizedBox(width: 6),
                Text('Assessment', style: GhText.h3(c)),
              ],
            ),
          ),
          const GhDivider(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary, style: GhText.body(c)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Chip(
                      icon: Icons.trending_up_rounded,
                      label: switch (trend) {
                        DiseaseTrend.worsening => 'Worsening',
                        DiseaseTrend.improving => 'Improving',
                        DiseaseTrend.stable    => 'Stable',
                        DiseaseTrend.unknown   => 'First scan',
                      },
                      color: switch (trend) {
                        DiseaseTrend.worsening => GhC.danger,
                        DiseaseTrend.improving => GhC.success,
                        _                     => c.fgMuted,
                      },
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      icon: Icons.wb_sunny_rounded,
                      label: switch (season) {
                        NigerianSeason.mainSeason => 'Main season',
                        NigerianSeason.offSeason  => 'Off season',
                        NigerianSeason.drySeason  => 'Dry season',
                      },
                      color: GhC.attention,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ActionList extends StatelessWidget {
  final List<String> actions;
  const _ActionList({required this.actions});

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    if (actions.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: GhBox.card(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(Icons.checklist_rounded, color: c.fgSubtle, size: 14),
                const SizedBox(width: 6),
                Text('Immediate steps', style: GhText.h3(c)),
              ],
            ),
          ),
          const GhDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              children: List.generate(actions.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: GhC.successEmphasis.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color:
                                  GhC.successEmphasis.withValues(alpha: 0.4)),
                        ),
                        child: Center(
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                color: GhC.success,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                fontFamily: GhC.mono,
                              )),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(actions[i], style: GhText.body(c))),
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

class _FungicideCard extends StatelessWidget {
  final List<FungicideOption> options;
  const _FungicideCard({required this.options});

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
                Icon(Icons.science_rounded, color: c.fgSubtle, size: 14),
                const SizedBox(width: 6),
                Text('Fungicide options', style: GhText.h3(c)),
              ],
            ),
          ),
          const GhDivider(),
          ...options.asMap().entries.map((e) {
            final opt = e.value;
            final isLast = e.key == options.length - 1;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GhLabel('Option ${e.key + 1}',
                              color: GhC.accentEmphasis, fontSize: 9),
                          const SizedBox(width: 8),
                          Text(opt.activeIngredient,
                              style: TextStyle(
                                color: c.fg,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                fontFamily: GhC.mono,
                              )),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Brands: ${opt.brandNames.join(', ')}',
                        style: TextStyle(color: c.fgMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _InfoChip(
                              icon: Icons.straighten_rounded,
                              label: opt.ratePerHectare),
                          const SizedBox(width: 8),
                          _InfoChip(
                              icon: Icons.schedule_rounded,
                              label: opt.applicationInterval),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(opt.notes,
                          style: TextStyle(
                              color: c.fgMuted,
                              fontSize: 11,
                              height: 1.4)),
                    ],
                  ),
                ),
                if (!isLast) const GhDivider(),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: GhBox.subtle(c),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: c.fgSubtle, size: 10),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: c.fgMuted, fontSize: 10, fontFamily: GhC.mono)),
        ],
      ),
    );
  }
}

class _TimingCard extends StatelessWidget {
  final String advice;
  const _TimingCard({required this.advice});

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    return Container(
      decoration: GhBox.card(c),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, color: c.fgSubtle, size: 14),
              const SizedBox(width: 6),
              Text('Application timing', style: GhText.h3(c)),
            ],
          ),
          const SizedBox(height: 10),
          Text(advice, style: GhText.body(c)),
        ],
      ),
    );
  }
}

class _ResistanceCard extends StatelessWidget {
  final String note;
  const _ResistanceCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    return Container(
      decoration: GhBox.card(c),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: GhC.attention, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resistance management', style: GhText.h3(c)),
                const SizedBox(height: 6),
                Text(note,
                    style: TextStyle(
                        color: c.fgMuted, fontSize: 12, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreventionCard extends StatelessWidget {
  final List<String> tips;
  const _PreventionCard({required this.tips});

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
                Icon(Icons.shield_rounded, color: c.fgSubtle, size: 14),
                const SizedBox(width: 6),
                Text('Prevention — next season', style: GhText.h3(c)),
              ],
            ),
          ),
          const GhDivider(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: tips.map((tip) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.arrow_right_rounded,
                          color: c.fgSubtle, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(tip,
                              style: TextStyle(
                                  color: c.fgMuted,
                                  fontSize: 12,
                                  height: 1.4))),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── API key bottom sheet ──────────────────────────────────────────────────────

/// Bottom sheet for entering / clearing the Gemini API key.
/// Using showModalBottomSheet (instead of showDialog) avoids the
/// '_dependents.isEmpty' / 'wrong build scope' assertions that fire when
/// an AlertDialog with Theme-dependent widgets is dismissed.
class _ApiKeySheet extends StatefulWidget {
  final AppColors c;
  final TextEditingController controller;
  final String? existing;

  const _ApiKeySheet({
    required this.c,
    required this.controller,
    required this.existing,
  });

  @override
  State<_ApiKeySheet> createState() => _ApiKeySheetState();
}

class _ApiKeySheetState extends State<_ApiKeySheet> {
  bool _hideKey = true;

  @override
  Widget build(BuildContext context) {
    final c = widget.c; // use pre-captured colors — never call context.gc here
    // Keyboard avoidance padding is applied by the showModalBottomSheet builder,
    // NOT here. This widget must not call MediaQuery.of(context) for viewInsets
    // because that would register it as a dependent of the route-local
    // MediaQuery — causing _dependents.isEmpty on iOS when the sheet dismisses.
    return Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: GhC.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.key_rounded, color: GhC.accent, size: 16),
                ),
                const SizedBox(width: 10),
                Text('Gemini API Key', style: GhText.h2(c)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Enter your Google Gemini API key to enable AI-powered '
              'recommendations. Leave blank to use the free on-device engine.',
              style: GhText.muted(c),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: widget.controller,
              obscureText: _hideKey,
              style: TextStyle(color: c.fg, fontSize: 12, fontFamily: GhC.mono),
              decoration: InputDecoration(
                hintText: 'AIza…',
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _hideKey = !_hideKey),
                  child: Icon(
                    _hideKey
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color: c.fgSubtle,
                    size: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Action buttons — all use _DialogButton (no Theme.of, no animations)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.existing != null) ...[
                  _DialogButton(
                    c: c,
                    label: 'Clear',
                    onTap: () => Navigator.pop(context, 'clear'),
                  ),
                  const SizedBox(width: 8),
                ],
                _DialogButton(
                  c: c,
                  label: 'Cancel',
                  onTap: () => Navigator.pop(context, null),
                ),
                const SizedBox(width: 8),
                _DialogButton(
                  c: c,
                  label: 'Save',
                  filled: true,
                  onTap: () => Navigator.pop(context, 'save'),
                ),
              ],
            ),
          ],
        ),
    );
  }
}

/// Animation-free, Theme-independent button for use inside dialogs.
///
/// [GhButton] and [GhButtonOutline] both call `context.gc` (registering
/// InheritedWidget dependencies) and wrap content in [AnimatedOpacity]
/// (which fires setState during animations). Either can raise
/// '_dependents.isEmpty' / 'wrong build scope' assertions when placed inside
/// a dialog that is currently being dismissed. This widget avoids both issues
/// by accepting [AppColors] directly and having no implicit animations.
class _DialogButton extends StatelessWidget {
  final AppColors c;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _DialogButton({
    required this.c,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? GhC.accentEmphasis : c.subtle,
          border: Border.all(
              color: filled ? GhC.accentEmphasis : c.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.white : c.fg,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
