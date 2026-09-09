import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/diseases.dart';
import '../models/scan_record.dart';

enum SeasonType { main, off, dry }
enum TrendType  { worsening, stable, improving }

// ── Structured output used by RecommendationScreen ────────────────────────────
class RecommendationSection {
  const RecommendationSection({
    required this.title,
    required this.items,
    this.color,
  });
  final String title;
  final List<String> items;
  final Color? color;
}

class Recommendation {
  const Recommendation({
    required this.urgencyLabel,
    required this.season,
    required this.sections,
  });
  final String urgencyLabel;
  final String season;
  final List<RecommendationSection> sections;

  List<String> get immediateActions => sections.isNotEmpty ? sections.first.items : const [];
  List<String> get immediateAction => immediateActions;
}

class RecommendationEngine {
  // Static entry-point for the UI — takes a ClassificationResult and returns
  // structured recommendation sections ready to render.
  static Recommendation generate(ClassificationResult result) {
    final engine  = RecommendationEngine.instance;
    final season  = engine._detectSeason();
    final disease = diseaseForClass(result.classId);
    final urgency = engine._urgency(result.classId, result.confidence,
        TrendType.stable);

    final sections = <RecommendationSection>[];

    if (result.classId == 3) {
      sections.add(RecommendationSection(
        title: 'Plant status',
        items: [
          'No disease detected — crop looks healthy.',
          'Continue routine scouting every 7–10 days.',
          'Disease risk is ${engine._seasonRisk(season)} in the current season.',
        ],
        color: AppColors.successFg,
      ));
    } else {
      sections.add(RecommendationSection(
        title: 'Immediate actions',
        items: disease.treatments,
        color: AppColors.dangerFg,
      ));
      sections.add(RecommendationSection(
        title: 'Prevention',
        items: disease.prevention,
        color: AppColors.accentFg,
      ));
      final seasonAdvice = engine._seasonAdvice(result.classId, season);
      sections.add(RecommendationSection(
        title: 'Season note',
        items: [seasonAdvice],
        color: AppColors.attentionFg,
      ));
    }

    return Recommendation(
      urgencyLabel: urgency == 'none'
          ? 'No action needed'
          : 'Urgency: ${urgency[0].toUpperCase()}${urgency.substring(1)}',
      season: engine._seasonName(season),
      sections: sections,
    );
  }

  static final RecommendationEngine instance = RecommendationEngine._();
  RecommendationEngine._();

  String getRecommendation({
    required int classId,
    required double confidence,
    required TrendType trend,
  }) {
    final disease = diseaseForClass(classId);
    final season  = _detectSeason();
    final urgency = _urgency(classId, confidence, trend);

    if (classId == 3) {
      return 'No disease detected. Continue routine scouting every 7–10 days. '
             'Risk ${_seasonRisk(season)} during ${_seasonName(season)} season.';
    }

    final buffer = StringBuffer();
    buffer.writeln('${disease.name} detected (${ (confidence * 100).toStringAsFixed(0)}% confidence)');
    buffer.writeln('Urgency: ${urgency.toUpperCase()}');
    buffer.writeln('');
    buffer.writeln('Immediate actions:');
    for (final t in disease.treatments) {
      buffer.writeln('  • $t');
    }
    buffer.writeln('');
    buffer.writeln('Prevention for next season:');
    for (final p in disease.prevention) {
      buffer.writeln('  • $p');
    }
    buffer.writeln('');
    buffer.writeln(_seasonAdvice(classId, season));
    return buffer.toString().trim();
  }

  SeasonType _detectSeason() {
    final month = DateTime.now().month;
    if (month >= 4 && month <= 7) return SeasonType.main;   // April–July
    if (month >= 8 && month <= 11) return SeasonType.off;   // August–November
    return SeasonType.dry;                                    // Dec–March
  }

  String _urgency(int classId, double confidence, TrendType trend) {
    if (classId == 3) return 'none';
    if (confidence > 0.85 && trend == TrendType.worsening) return 'critical';
    if (confidence > 0.70 || trend == TrendType.worsening) return 'high';
    if (confidence > 0.55) return 'medium';
    return 'low';
  }

  String _seasonName(SeasonType s) => switch (s) {
    SeasonType.main => 'main (Apr–Jul)',
    SeasonType.off  => 'off (Aug–Nov)',
    SeasonType.dry  => 'dry (Dec–Mar)',
  };

  String _seasonRisk(SeasonType s) => switch (s) {
    SeasonType.main => 'is highest',
    SeasonType.off  => 'is moderate',
    SeasonType.dry  => 'is low',
  };

  String _seasonAdvice(int classId, SeasonType season) {
    if (season == SeasonType.dry) {
      return 'Dry season: disease pressure is lower. '
             'Focus on field hygiene — remove residue before next planting.';
    }
    if (classId == 1 && season == SeasonType.main) {
      return 'Main season + Rust: cool nights increase spread. '
             'Apply triazole fungicide within 48 hours of detection.';
    }
    return 'Scout neighbouring plots — disease may be spreading from adjacent farms.';
  }
}
