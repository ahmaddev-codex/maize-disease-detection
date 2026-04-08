import 'dart:io';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../theme/app_theme.dart';
import '../models/prediction.dart';

/// Displays the CNN inference result in a GitHub Actions / check-run style.
class ResultScreen extends StatelessWidget {
  final File imageFile;
  final Prediction prediction;

  const ResultScreen({
    super.key,
    required this.imageFile,
    required this.prediction,
  });

  @override
  Widget build(BuildContext context) {
    final info = DiseaseInfo.catalogue[prediction.classId]!;

    return Scaffold(
      backgroundColor: GhC.canvas,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, info),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusHeader(prediction: prediction, info: info),
                  const SizedBox(height: 16),
                  _ConfidenceCard(prediction: prediction),
                  const SizedBox(height: 16),
                  _ScoreMatrix(prediction: prediction),
                  const SizedBox(height: 16),
                  _TreatmentCard(info: info),
                  const SizedBox(height: 16),
                  _MetaRow(prediction: prediction),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, DiseaseInfo info) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: GhC.surface,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Detection result',
        style: TextStyle(color: GhC.fg, fontSize: 15, fontWeight: FontWeight.w600),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(imageFile, fit: BoxFit.cover),
            // Gradient overlay
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, GhC.canvas],
                  stops: [0.45, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: GhC.border),
      ),
    );
  }
}

// ── Status header (like a GitHub Actions workflow summary) ────────────────────

class _StatusHeader extends StatelessWidget {
  final Prediction prediction;
  final DiseaseInfo info;
  const _StatusHeader({required this.prediction, required this.info});

  Color get _statusColor => switch (info.severity) {
    'high'   => GhC.danger,
    'medium' => GhC.attention,
    _        => GhC.success,
  };

  IconData get _statusIcon => prediction.isHealthy
      ? Icons.check_circle_rounded
      : Icons.bug_report_rounded;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: GhBox.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.1),
              border: Border(bottom: BorderSide(color: GhC.border)),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            ),
            child: Row(
              children: [
                Icon(_statusIcon, color: _statusColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    info.fullName,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GhLabel(
                  info.severity.toUpperCase(),
                  color: _statusColor,
                  fontSize: 10,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(info.description, style: GhText.muted),
          ),
        ],
      ),
    );
  }
}

// ── Confidence card ───────────────────────────────────────────────────────────

class _ConfidenceCard extends StatelessWidget {
  final Prediction prediction;
  const _ConfidenceCard({required this.prediction});

  Color get _barColor {
    final c = prediction.confidence;
    if (c >= 0.80) return GhC.success;
    if (c >= 0.50) return GhC.attention;
    return GhC.danger;
  }

  @override
  Widget build(BuildContext context) {
    final pct = (prediction.confidence * 100);

    return Container(
      decoration: GhBox.card(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Confidence', style: GhText.h3),
              const Spacer(),
              Text(
                '${pct.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: _barColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: GhC.mono,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearPercentIndicator(
            lineHeight: 8,
            percent: prediction.confidence.clamp(0.0, 1.0),
            backgroundColor: GhC.subtle,
            progressColor: _barColor,
            barRadius: const Radius.circular(4),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          Text(
            pct >= 80 ? 'High confidence — reliable result'
            : pct >= 50 ? 'Medium confidence — consider re-scanning'
            : 'Low confidence — use better lighting and retry',
            style: TextStyle(color: _barColor, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Score matrix (like a GitHub checks matrix) ────────────────────────────────

class _ScoreMatrix extends StatelessWidget {
  final Prediction prediction;
  const _ScoreMatrix({required this.prediction});

  static const _labels = [
    ('NCLB', 'Northern Corn Leaf Blight'),
    ('Rust', 'Common Rust'),
    ('GLS', 'Gray Leaf Spot'),
    ('Healthy', 'No disease'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: GhBox.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: const [
                Icon(Icons.bar_chart_rounded, color: GhC.fgSubtle, size: 14),
                SizedBox(width: 6),
                Text('Class scores', style: GhText.h3),
              ],
            ),
          ),
          const GhDivider(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: List.generate(_labels.length, (i) {
                final score    = prediction.allScores[i];
                final isWinner = i == prediction.classId;
                final (short, full) = _labels[i];
                final color = isWinner ? GhC.success : GhC.fgSubtle;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      isWinner
                          ? const Icon(Icons.check_circle_rounded,
                              color: GhC.success, size: 14)
                          : const Icon(Icons.circle_outlined,
                              color: GhC.fgSubtle, size: 14),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 52,
                        child: Text(
                          short,
                          style: TextStyle(
                            color: isWinner ? GhC.fg : GhC.fgMuted,
                            fontSize: 12,
                            fontWeight: isWinner
                                ? FontWeight.w700
                                : FontWeight.normal,
                            fontFamily: GhC.mono,
                          ),
                        ),
                      ),
                      Expanded(
                        child: LinearPercentIndicator(
                          lineHeight: 6,
                          percent: score.clamp(0.0, 1.0),
                          backgroundColor: GhC.subtle,
                          progressColor: color,
                          barRadius: const Radius.circular(3),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${(score * 100).toStringAsFixed(1)}%',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: isWinner ? GhC.fg : GhC.fgMuted,
                            fontSize: 11,
                            fontFamily: GhC.mono,
                          ),
                        ),
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

// ── Treatment card (like GitHub's annotation / suggestion list) ───────────────

class _TreatmentCard extends StatelessWidget {
  final DiseaseInfo info;
  const _TreatmentCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: GhBox.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: const [
                Icon(Icons.medical_services_rounded, color: GhC.fgSubtle, size: 14),
                SizedBox(width: 6),
                Text('Recommended action', style: GhText.h3),
              ],
            ),
          ),
          const GhDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              children: List.generate(info.treatments.length, (i) {
                return _StepRow(step: i + 1, text: info.treatments[i]);
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int step;
  final String text;
  const _StepRow({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: GhC.successEmphasis.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: GhC.successEmphasis.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(
                '$step',
                style: const TextStyle(
                  color: GhC.success,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  fontFamily: GhC.mono,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: GhText.body),
          ),
        ],
      ),
    );
  }
}

// ── Meta row (latency + model info) ──────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  final Prediction prediction;
  const _MetaRow({required this.prediction});

  @override
  Widget build(BuildContext context) {
    final ms  = prediction.latencyMs;
    final ok  = ms < 2000;
    final clr = ms < 1000 ? GhC.success : ms < 2000 ? GhC.attention : GhC.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: GhBox.subtle(),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: GhC.fgSubtle, size: 13),
          const SizedBox(width: 6),
          Text(
            '${ms.toStringAsFixed(0)} ms',
            style: TextStyle(
              color: clr,
              fontSize: 12,
              fontFamily: GhC.mono,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            ok ? '· ✓ <2s target' : '· ✗ >2s target',
            style: TextStyle(color: clr, fontSize: 12),
          ),
          const Spacer(),
          const Text('EfficientNetB3 · on-device',
              style: TextStyle(color: GhC.fgSubtle, fontSize: 11)),
        ],
      ),
    );
  }
}
