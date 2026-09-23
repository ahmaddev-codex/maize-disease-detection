import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/diseases.dart';
import '../constants/thresholds.dart';
import '../models/scan_record.dart';

enum SeasonType { main, off, dry }
enum TrendType  { worsening, stable, improving }

/// Maps the health-rate change from healthTrendProvider onto a trend.
TrendType trendFromDelta(double delta) {
  if (delta > TrendThresholds.delta) return TrendType.improving;
  if (delta < -TrendThresholds.delta) return TrendType.worsening;
  return TrendType.stable;
}

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
    this.needsRetake = false,
  });
  final String urgencyLabel;
  final String season;
  final List<RecommendationSection> sections;

  /// True when confidence is too low to act on: the UI shows retake guidance
  /// and the spoken summary asks for a better photo instead of urging treatment.
  final bool needsRetake;

  List<String> get immediateActions => sections.isNotEmpty ? sections.first.items : const [];
  List<String> get immediateAction => immediateActions;
}

class RecommendationEngine {
  // Static entry-point for the UI — takes a ClassificationResult and returns
  // structured recommendation sections ready to render.
  static Recommendation generate(
    ClassificationResult result, {
    TrendType trend = TrendType.stable,
  }) {
    final engine  = RecommendationEngine.instance;
    final season  = engine._detectSeason();
    final disease = diseaseForClass(result.classId);
    final urgency = engine._urgency(result.classId, result.confidence, trend);

    final sections = <RecommendationSection>[];

    if (result.classId == kHealthyClassId) {
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
      urgencyLabel: switch (urgency) {
        'none'   => 'No action needed',
        'verify' => 'Verify — retake photo',
        _        => 'Urgency: ${urgency[0].toUpperCase()}${urgency.substring(1)}',
      },
      season: engine._seasonName(season),
      sections: sections,
      needsRetake: urgency == 'verify',
    );
  }

  static final RecommendationEngine instance = RecommendationEngine._();
  RecommendationEngine._();

  SeasonType _detectSeason() {
    final month = DateTime.now().month;
    if (month >= 4 && month <= 7) return SeasonType.main;   // April–July
    if (month >= 8 && month <= 11) return SeasonType.off;   // August–November
    return SeasonType.dry;                                    // Dec–March
  }

  String _urgency(int classId, double confidence, TrendType trend) {
    if (classId == kHealthyClassId) return 'none';
    // Too unsure to act on: ask for a better photo first.
    if (ConfidenceThresholds.isLow(confidence)) return 'verify';
    if (ConfidenceThresholds.isHigh(confidence) && trend == TrendType.worsening) return 'critical';
    if (ConfidenceThresholds.isHigh(confidence) || trend == TrendType.worsening) return 'high';
    return 'medium';
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
