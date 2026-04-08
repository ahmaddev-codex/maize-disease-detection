/// Holds the result of a single CNN inference pass.
class Prediction {
  final int classId;
  final String className;
  final double confidence;
  final List<double> allScores;
  final double latencyMs;

  const Prediction({
    required this.classId,
    required this.className,
    required this.confidence,
    required this.allScores,
    required this.latencyMs,
  });

  bool get isHealthy => classId == 3;

  String get shortName => const [
        'NCLB',
        'Rust',
        'GLS',
        'Healthy',
      ][classId];
}

/// Holds structured fields extracted from a seed label via OCR.
class SeedLabelData {
  final String? cropVariety;
  final String? batchNumber;
  final String? plantingDate;
  final String rawText;

  const SeedLabelData({
    this.cropVariety,
    this.batchNumber,
    this.plantingDate,
    required this.rawText,
  });

  bool get hasAnyField =>
      cropVariety != null || batchNumber != null || plantingDate != null;
}

/// Disease metadata: full name + treatment advice.
class DiseaseInfo {
  final String fullName;
  final String description;
  final List<String> treatments;
  final String severity; // 'low' | 'medium' | 'high'

  const DiseaseInfo({
    required this.fullName,
    required this.description,
    required this.treatments,
    required this.severity,
  });

  static const Map<int, DiseaseInfo> catalogue = {
    0: DiseaseInfo(
      fullName: 'Northern Corn Leaf Blight (NCLB)',
      description:
          'Caused by the fungus Exserohilum turcicum. '
          'Appears as long, tan to grey-green lesions on leaves.',
      treatments: [
        'Apply foliar fungicide (mancozeb or azoxystrobin)',
        'Remove and destroy heavily infected leaves',
        'Plant resistant varieties: SAMMAZ 15, SAMMAZ 29',
        'Avoid overhead irrigation; improve field drainage',
      ],
      severity: 'high',
    ),
    1: DiseaseInfo(
      fullName: 'Common Rust',
      description:
          'Caused by Puccinia sorghi. Brick-red pustules on both '
          'leaf surfaces; spreads rapidly in cool, humid conditions.',
      treatments: [
        'Apply triazole fungicide early (propiconazole)',
        'Scout weekly — rust spreads rapidly in cool humid weather',
        'Plant rust-resistant hybrids for next season',
        'Ensure adequate potassium nutrition',
      ],
      severity: 'medium',
    ),
    2: DiseaseInfo(
      fullName: 'Gray Leaf Spot (GLS)',
      description:
          'Caused by Cercospora zeae-maydis. Rectangular grey-tan '
          'lesions bounded by leaf veins; thrives in warm, humid weather.',
      treatments: [
        'Apply strobilurin fungicide (azoxystrobin) at first sign',
        'Increase plant spacing to improve air circulation',
        'Practice crop rotation — avoid maize monoculture',
        'Remove crop debris after harvest',
      ],
      severity: 'medium',
    ),
    3: DiseaseInfo(
      fullName: 'Healthy',
      description: 'No disease detected. Leaf appears healthy.',
      treatments: [
        'Continue regular scouting every 7–10 days',
        'Maintain balanced NPK fertilisation schedule',
        'Monitor for early-stage symptoms',
      ],
      severity: 'low',
    ),
  };
}
