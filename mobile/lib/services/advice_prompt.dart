import '../constants/diseases.dart';
import '../constants/thresholds.dart';

/// What kind of advice a result deserves.
enum AdviceMode {
  /// Nothing to treat: monitoring only.
  healthy,

  /// The model is not sure enough to name a disease, let alone a chemical.
  uncertain,

  /// A confident diagnosis: name the chemistry, never invent a dose.
  disease,
}

AdviceMode adviceModeFor({required int classId, required double confidence}) {
  if (ConfidenceThresholds.isLow(confidence)) return AdviceMode.uncertain;
  if (classId == kHealthyClassId) return AdviceMode.healthy;
  return AdviceMode.disease;
}

const String _formatRules = '''
FORMATTING RULES:
- No markdown: no #, no ** or *, no tables or pipes.
- Plain capital letters for headings, and • for list items.
- Write so it can be read aloud without sounding like syntax.
- Keep it under 180 words.''';

/// Builds the advice prompt for one result.
///
/// The old single prompt asked for "three treatment steps with dosage" for
/// every class, healthy leaves included, and suggested products that do not
/// control these fungi. Each branch below only asks for what the diagnosis
/// actually supports (T25).
String buildAdvicePrompt({
  required int classId,
  required double confidence,
  String? cropVariety,
  String language = 'English',
}) {
  final disease = diseaseForClass(classId);
  final mode = adviceModeFor(classId: classId, confidence: confidence);
  final percent = (confidence * 100).toStringAsFixed(1);
  final variety = (cropVariety != null && cropVariety.trim().isNotEmpty)
      ? 'Crop variety: ${cropVariety.trim()}.'
      : '';
  final languageRule = language == 'English'
      ? ''
      : '\nWrite the whole answer in $language, but keep the active ingredient '
          'names in English so they can be matched on a product label.';

  const audience =
      'You are an expert agronomist advising a Nigerian smallholder maize farmer.';

  return switch (mode) {
    AdviceMode.healthy => '''
$audience

Diagnosis: no disease detected (confidence $percent%).
$variety

The leaf is healthy. Do not recommend any pesticide: say plainly that no fungicide is needed now.

Structure the advisory as:
1. WHAT THIS MEANS: (2 sentences)
2. KEEP IT THAT WAY: (two field practices, e.g. scouting, spacing, residue removal)
3. WHEN TO LOOK AGAIN: (a clear timeline, and the weather that raises risk)

$_formatRules$languageRule
''',
    AdviceMode.uncertain => '''
$audience

The photo could not be diagnosed with enough confidence ($percent%). Do not name a disease and do not recommend any chemical.
$variety

Structure the advisory as:
1. WHAT WE KNOW: (say honestly that the photo was not clear enough to diagnose)
2. BETTER PHOTO: (how to retake it — fill the frame with one leaf, even daylight, no shadow or glare, hold steady)
3. IF IT REPEATS: (verify with an extension officer, and what to watch for meanwhile)

$_formatRules$languageRule
''',
    AdviceMode.disease => '''
$audience

Diagnosis: ${disease.name} (confidence $percent%).
$variety

Use only these active ingredients, which control ${disease.shortName}:
${disease.actives.map((a) => '• $a').join('\n')}

Rules about chemicals:
- Name active ingredients, not brand names; brands differ by market.
- Recommend nothing outside the list above. Metalaxyl and copper products, sold widely for other crops, do not control this fungus.
- Do not state any dose, rate or mixing ratio. Say the rate, the pre-harvest interval and the protective equipment are on the product label, and that an extension officer can confirm the choice locally.

Structure the advisory as:
1. WHAT IT IS: (2 sentences in plain language)
2. WHAT TO DO NOW: (three steps: the active ingredient to look for, when to spray relative to the day's heat, and what to do with badly infected leaves)
3. PREVENTION: (two practices such as resistant varieties, rotation, residue destruction)
4. RE-INSPECTION: (when to check the field again)

$_formatRules$languageRule
''',
  };
}
