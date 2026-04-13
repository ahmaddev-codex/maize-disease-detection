import 'dart:io';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../theme/app_theme.dart';
import '../models/prediction.dart';
import 'recommendation_screen.dart';

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
    final c = context.gc;

    return Scaffold(
      backgroundColor: c.canvas,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, info, c),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedEntry(delayMs: 0,   child: _StatusHeader(prediction: prediction, info: info)),
                  const SizedBox(height: 16),
                  AnimatedEntry(delayMs: 80,  child: _ConfidenceCard(prediction: prediction)),
                  const SizedBox(height: 16),
                  AnimatedEntry(delayMs: 160, child: _ScoreMatrix(prediction: prediction)),
                  const SizedBox(height: 16),
                  AnimatedEntry(delayMs: 240, child: _TreatmentCard(info: info)),
                  const SizedBox(height: 16),
                  AnimatedEntry(delayMs: 320, child: _AiAdvisorButton(prediction: prediction)),
                  const SizedBox(height: 16),
                  AnimatedEntry(delayMs: 400, child: _MetaRow(prediction: prediction)),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, DiseaseInfo info, AppColors c) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
      ),
      title: Text(
        'Detection result',
        style: TextStyle(color: c.fg, fontSize: 15, fontWeight: FontWeight.w600),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(imageFile, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, c.canvas],
                  stops: const [0.45, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: c.border),
      ),
    );
  }
}

// ── Status header ─────────────────────────────────────────────────────────────

class _StatusHeader extends StatelessWidget {
  final Prediction prediction;
  final DiseaseInfo info;
  const _StatusHeader({required this.prediction, required this.info});

  Color get _statusColor => switch (info.severity) {
        'high'   => GhC.danger,
        'medium' => GhC.attention,
        _        => GhC.success,
      };

  IconData get _statusIcon =>
      prediction.isHealthy ? Icons.check_circle_rounded : Icons.bug_report_rounded;

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    return Container(
      decoration: GhBox.card(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.1),
              border: Border(bottom: BorderSide(color: c.border)),
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
                GhLabel(info.severity.toUpperCase(),
                    color: _statusColor, fontSize: 10),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(info.description, style: GhText.muted(c)),
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
    final conf = prediction.confidence;
    if (conf >= 0.80) return GhC.success;
    if (conf >= 0.50) return GhC.attention;
    return GhC.danger;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    final pct = prediction.confidence * 100;

    return Container(
      decoration: GhBox.card(c),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Confidence', style: GhText.h3(c)),
              const Spacer(),
              AnimatedNumber(
                value: pct,
                duration: const Duration(milliseconds: 900),
                builder: (_, v, __) => Text(
                  '${v.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: _barColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: GhC.mono,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: prediction.confidence.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOut,
            builder: (_, v, __) => LinearPercentIndicator(
              lineHeight: 8,
              percent: v,
              backgroundColor: c.subtle,
              progressColor: _barColor,
              barRadius: const Radius.circular(4),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pct >= 80
                ? 'High confidence — reliable result'
                : pct >= 50
                    ? 'Medium confidence — consider re-scanning'
                    : 'Low confidence — use better lighting and retry',
            style: TextStyle(color: _barColor, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Score matrix ──────────────────────────────────────────────────────────────

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
                Icon(Icons.bar_chart_rounded, color: c.fgSubtle, size: 14),
                const SizedBox(width: 6),
                Text('Class scores', style: GhText.h3(c)),
              ],
            ),
          ),
          GhDivider(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: List.generate(_labels.length, (i) {
                final score    = prediction.allScores[i];
                final isWinner = i == prediction.classId;
                final (short, _) = _labels[i];
                final color = isWinner ? GhC.success : c.fgSubtle;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(
                        isWinner
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: color,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 52,
                        child: Text(
                          short,
                          style: TextStyle(
                            color: isWinner ? c.fg : c.fgMuted,
                            fontSize: 12,
                            fontWeight: isWinner
                                ? FontWeight.w700
                                : FontWeight.normal,
                            fontFamily: GhC.mono,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: score.clamp(0.0, 1.0)),
                          duration: Duration(milliseconds: 700 + i * 80),
                          curve: Curves.easeOut,
                          builder: (_, v, __) => LinearPercentIndicator(
                            lineHeight: 6,
                            percent: v,
                            backgroundColor: c.subtle,
                            progressColor: color,
                            barRadius: const Radius.circular(3),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${(score * 100).toStringAsFixed(1)}%',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: isWinner ? c.fg : c.fgMuted,
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

// ── Treatment card ────────────────────────────────────────────────────────────

class _TreatmentCard extends StatelessWidget {
  final DiseaseInfo info;
  const _TreatmentCard({required this.info});

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
                Icon(Icons.medical_services_rounded, color: c.fgSubtle, size: 14),
                const SizedBox(width: 6),
                Text('Recommended action', style: GhText.h3(c)),
              ],
            ),
          ),
          GhDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              children: List.generate(info.treatments.length,
                  (i) => _StepRow(step: i + 1, text: info.treatments[i])),
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
    final c = context.gc;
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
              border:
                  Border.all(color: GhC.successEmphasis.withValues(alpha: 0.4)),
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
          Expanded(child: Text(text, style: GhText.body(c))),
        ],
      ),
    );
  }
}

// ── AI Advisor button ─────────────────────────────────────────────────────────

class _AiAdvisorButton extends StatelessWidget {
  final Prediction prediction;
  const _AiAdvisorButton({required this.prediction});

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecommendationScreen(
            classId: prediction.classId,
            confidence: prediction.confidence,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: GhC.accentEmphasis.withValues(alpha: 0.08),
          border:
              Border.all(color: GhC.accentEmphasis.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            const Icon(Icons.psychology_rounded, color: GhC.accent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Get AI Recommendations',
                      style: TextStyle(
                          color: GhC.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                      'Detailed fungicide options, timing & resistance advice',
                      style: TextStyle(color: c.fgMuted, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: GhC.accent, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Meta row ──────────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  final Prediction prediction;
  const _MetaRow({required this.prediction});

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    final ms  = prediction.latencyMs;
    final ok  = ms < 2000;
    final clr = ms < 1000
        ? GhC.success
        : ms < 2000
            ? GhC.attention
            : GhC.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: GhBox.subtle(c),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: c.fgSubtle, size: 13),
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
          Text('EfficientNetB3 · on-device',
              style: TextStyle(color: c.fgSubtle, fontSize: 11)),
        ],
      ),
    );
  }
}
