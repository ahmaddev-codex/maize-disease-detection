import '../models/prediction.dart';
import 'database.dart';

/// On-device contextual recommendation engine (Phase C1).

/// Produces structured agronomic advice by combining:
///   – CNN detection result (class + confidence)
///   – Seed label metadata (variety, planting date)
///   – Scan history trend (worsening / stable / improving)
///   – Nigerian region / season heuristics
class RecommendationEngine {
  /// Generate a full [RecommendationResult] for a given scan.
  static Future<RecommendationResult> generate({
    required int classId,
    required double confidence,
    required String? cropVariety,
    required String? plantingDate,
    List<ScanRecord>? recentHistory,
  }) async {
    final trend = _analyseTrend(recentHistory, classId);
    final season = _currentSeason();
    final urgency = _calcUrgency(classId, confidence, trend);
    final fungicides = _fungicideOptions(classId, cropVariety);
    final timingAdvice = _timingAdvice(classId, plantingDate, season);
    final resistanceNote = _resistanceNote(classId);

    return RecommendationResult(
      urgency: urgency,
      headline: _headline(classId, urgency, confidence),
      summary: _summary(classId, confidence, trend, season),
      immediateActions: _immediateActions(classId, confidence),
      fungicideOptions: fungicides,
      timingAdvice: timingAdvice,
      resistanceNote: resistanceNote,
      preventionTips: _preventionTips(classId, cropVariety),
      trend: trend,
      season: season,
      source: RecommendationSource.onDevice,
    );
  }

  // ── Trend analysis ──────────────────────────────────────────────────────────

  static DiseaseTrend _analyseTrend(List<ScanRecord>? history, int classId) {
    if (history == null || history.length < 3) return DiseaseTrend.unknown;
    // Look at last 5 scans — how many were this disease vs healthy
    final recent = history.take(5).toList();
    final diseased = recent.where((s) => s.classId == classId).length;
    final healthy = recent.where((s) => s.classId == 3).length;
    if (diseased >= 3) return DiseaseTrend.worsening;
    if (healthy >= 4) return DiseaseTrend.improving;
    return DiseaseTrend.stable;
  }

  // ── Season detection (Nigeria growing calendar) ─────────────────────────────

  static NigerianSeason _currentSeason() {
    final month = DateTime.now().month;
    // Main season: March–July; Off season: Aug–Nov; Dry: Dec–Feb
    if (month >= 3 && month <= 7) return NigerianSeason.mainSeason;
    if (month >= 8 && month <= 11) return NigerianSeason.offSeason;
    return NigerianSeason.drySeason;
  }

  // ── Urgency calculation ─────────────────────────────────────────────────────

  static Urgency _calcUrgency(
      int classId, double confidence, DiseaseTrend trend) {
    if (classId == 3) return Urgency.none;
    if (classId == 0 && confidence >= 0.7) return Urgency.high; // NCLB spreads fast
    if (trend == DiseaseTrend.worsening) return Urgency.high;
    if (confidence >= 0.8) return Urgency.medium;
    return Urgency.low;
  }

  // ── Headline ────────────────────────────────────────────────────────────────

  static String _headline(int classId, Urgency urgency, double confidence) {
    if (classId == 3) return 'Crop appears healthy — maintain routine scouting';
    final conf =
        confidence >= 0.8 ? 'High-confidence detection' : 'Possible detection';
    final urg = switch (urgency) {
      Urgency.high => '— immediate action required',
      Urgency.medium => '— treat within 3–5 days',
      Urgency.low => '— monitor closely',
      Urgency.none => '',
    };
    return '$conf of ${DiseaseInfo.catalogue[classId]!.fullName} $urg';
  }

  // ── Summary paragraph ───────────────────────────────────────────────────────

  static String _summary(int classId, double confidence, DiseaseTrend trend,
      NigerianSeason season) {
    if (classId == 3) {
      return 'No signs of disease detected in this leaf sample. '
          'Continue your regular 7–10 day scouting schedule and maintain balanced NPK nutrition.';
    }
    final info = DiseaseInfo.catalogue[classId]!;
    final trendText = switch (trend) {
      DiseaseTrend.worsening =>
        'Your recent scan history shows a worsening trend — act promptly.',
      DiseaseTrend.improving =>
        'Recent history shows improvement — continue current treatment.',
      DiseaseTrend.stable =>
        'Disease pressure appears stable based on recent scans.',
      DiseaseTrend.unknown => '',
    };
    final seasonText = switch (season) {
      NigerianSeason.mainSeason =>
        'The current main-season conditions favour rapid disease spread.',
      NigerianSeason.offSeason =>
        'Off-season humidity may be slowing spread — remain vigilant.',
      NigerianSeason.drySeason =>
        'Dry-season conditions reduce spreading risk but stress plants.',
    };
    return '${info.description} $trendText $seasonText';
  }

  // ── Immediate actions ───────────────────────────────────────────────────────

  static List<String> _immediateActions(int classId, double confidence) {
    final base = DiseaseInfo.catalogue[classId]!.treatments;
    if (classId == 3) return base;
    final prefix = confidence >= 0.8
        ? ['Confirm diagnosis on 3–5 more leaves in the same area']
        : [
            'Re-scan under better lighting to confirm diagnosis',
            'Check neighbouring plants for similar symptoms'
          ];
    return [...prefix, ...base];
  }

  // ── Fungicide options for Nigerian market ───────────────────────────────────

  static List<FungicideOption> _fungicideOptions(int classId, String? variety) {
    return switch (classId) {
      0 => [
          // NCLB
          FungicideOption(
            activeIngredient: 'Mancozeb',
            brandNames: ['Dithane M-45', 'Mancozeb 80WP'],
            ratePerHectare: '2.0–2.5 kg/ha',
            applicationInterval: 'Every 7–10 days',
            notes:
                'Protectant — apply before disease spreads beyond 10% severity',
          ),
          FungicideOption(
            activeIngredient: 'Azoxystrobin + Difenoconazole',
            brandNames: ['Amistar Top'],
            ratePerHectare: '0.75–1.0 L/ha',
            applicationInterval: 'Every 14 days (max 3 applications)',
            notes: 'Systemic curative. Preferred for advanced infection.',
          ),
        ],
      1 => [
          // Common Rust
          FungicideOption(
            activeIngredient: 'Propiconazole',
            brandNames: ['Tilt 250 EC', 'Propiconazole 250 EC'],
            ratePerHectare: '0.5 L/ha',
            applicationInterval: 'Every 14 days',
            notes:
                'Apply at first sign of rust pustules. Most effective early.',
          ),
          FungicideOption(
            activeIngredient: 'Tebuconazole',
            brandNames: ['Folicur 250 EW'],
            ratePerHectare: '0.75 L/ha',
            applicationInterval: 'Every 14 days',
            notes: 'Triazole — excellent curative activity against rust.',
          ),
        ],
      2 => [
          // GLS
          FungicideOption(
            activeIngredient: 'Azoxystrobin',
            brandNames: ['Amistar 250 SC', 'Quadris'],
            ratePerHectare: '0.75 L/ha',
            applicationInterval: 'Every 14 days (max 2 applications)',
            notes: 'Strobilurin — highly effective against Cercospora.',
          ),
          FungicideOption(
            activeIngredient: 'Chlorothalonil',
            brandNames: ['Daconil 720 SC'],
            ratePerHectare: '1.5–2.0 L/ha',
            applicationInterval: 'Every 7–14 days',
            notes: 'Broad-spectrum protectant. Good tank-mix partner.',
          ),
        ],
      _ => [],
    };
  }

  // ── Application timing based on planting date & growth stage ───────────────

  static String _timingAdvice(
      int classId, String? plantingDate, NigerianSeason season) {
    if (classId == 3) return 'No fungicide application needed.';
    String base = 'Apply fungicide in the early morning or late afternoon '
        'to avoid evaporation. Avoid application during peak heat (10am–2pm).';
    if (plantingDate != null) {
      try {
        final parts = plantingDate.split(RegExp(r'[-/]'));
        if (parts.length == 3) {
          final planted = DateTime(
            int.parse(parts[0].length == 4 ? parts[0] : parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0].length == 4 ? parts[2] : parts[0]),
          );
          final dap = DateTime.now().difference(planted).inDays;
          if (dap < 30) {
            base = 'Plants are in early vegetative stage (~$dap DAP). '
                'Use lower label rates and add a sticker-spreader adjuvant. $base';
          } else if (dap < 70) {
            base = 'Plants are in vegetative–tasseling stage (~$dap DAP). '
                'Full label rate recommended. $base';
          } else {
            base = 'Plants are post-silking (~$dap DAP). '
                'Prioritise grain-fill protection. Final application window. $base';
          }
        }
      } catch (_) {}
    }
    if (season == NigerianSeason.mainSeason) {
      base +=
          ' Rain likely — use a rain-fast formulation or apply before dry period.';
    }
    return base;
  }

  // ── Resistance management note ──────────────────────────────────────────────

  static String? _resistanceNote(int classId) {
    if (classId == 0) {
      return 'Rotate between fungicide groups (FRAC codes M3 ↔ 11 ↔ 3) across seasons '
          'to prevent resistance development in NCLB populations.';
    }
    if (classId == 1) {
      return 'Rust populations in West Africa show reduced sensitivity to some DMI fungicides. '
          'If propiconazole is ineffective after 2 applications, switch to a strobilurin blend.';
    }
    return null;
  }

  // ── Prevention tips ─────────────────────────────────────────────────────────

  static List<String> _preventionTips(int classId, String? variety) {
    final tips = <String>[
      'Scout fields weekly during the vegetative and reproductive stages',
      'Destroy crop residue promptly after harvest to reduce inoculum',
      'Maintain 60–75 cm row spacing for adequate air circulation',
    ];
    if (classId == 0 || classId == 2) {
      // NCLB and GLS favour resistant varieties
      tips.add(
          'Next season: plant SAMMAZ 15, SAMMAZ 29, or ART98SW6-OB (IITA releases — rated resistant)');
    }
    if (classId == 1) {
      tips.add(
          'Next season: plant hybrid varieties with Rp gene resistance to common rust');
    }
    if (variety != null && variety.contains('SAMMAZ 15')) {
      tips.add(
          'Note: SAMMAZ 15 has good NCLB resistance — verify your field diagnosis with a 2nd scan');
    }
    tips.add(
        'Apply a balanced NPK + micronutrient programme to reduce plant stress');
    return tips;
  }
}

// ── Data classes ─────────────────────────────────────────────────────────────

enum Urgency { none, low, medium, high }

enum DiseaseTrend { unknown, improving, stable, worsening }

enum NigerianSeason { mainSeason, offSeason, drySeason }

enum RecommendationSource { onDevice, geminiApi }

class FungicideOption {
  final String activeIngredient;
  final List<String> brandNames;
  final String ratePerHectare;
  final String applicationInterval;
  final String notes;

  const FungicideOption({
    required this.activeIngredient,
    required this.brandNames,
    required this.ratePerHectare,
    required this.applicationInterval,
    required this.notes,
  });
}

class RecommendationResult {
  final Urgency urgency;
  final String headline;
  final String summary;
  final List<String> immediateActions;
  final List<FungicideOption> fungicideOptions;
  final String timingAdvice;
  final String? resistanceNote;
  final List<String> preventionTips;
  final DiseaseTrend trend;
  final NigerianSeason season;
  final RecommendationSource source;
  /// Non-null when an API key was configured but the Gemini call failed.
  /// The on-device fallback is used in this case.
  final String? apiError;

  const RecommendationResult({
    required this.urgency,
    required this.headline,
    required this.summary,
    required this.immediateActions,
    required this.fungicideOptions,
    required this.timingAdvice,
    this.resistanceNote,
    required this.preventionTips,
    required this.trend,
    required this.season,
    required this.source,
    this.apiError,
  });
}
