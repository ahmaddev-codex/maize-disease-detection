import '../constants/diseases.dart';

/// Turns a model output tensor into probabilities.
///
/// The rule is shared with the Python pipeline through
/// `tests/fixtures/postprocess_cases.json` (ADR-006, T33):
///
///   1. dequantise integer output with the tensor's own scale and zero point;
///   2. renormalise by the sum;
///   3. never apply a softmax — the model's last layer already did.
List<double> normalizeScores(List<double> scores) {
  if (scores.isEmpty) return scores;
  final sum = scores.fold<double>(0, (a, b) => a + b);
  if (sum <= 0 || !sum.isFinite) {
    // Nothing usable came back; an even split beats a confident wrong answer.
    return List<double>.filled(scores.length, 1 / scores.length);
  }
  if ((sum - 1.0).abs() <= 1e-6) return scores;
  return scores.map((s) => s / sum).toList();
}

List<double> dequantizeScores(
  List<num> raw, {
  required bool integerOutput,
  required double scale,
  required int zeroPoint,
}) {
  if (!integerOutput || scale <= 0) {
    return raw.map((v) => v.toDouble()).toList();
  }
  return raw.map((v) => (v.toDouble() - zeroPoint) * scale).toList();
}

/// Dequantise then renormalise: the whole path, in one call.
List<double> probabilitiesFrom(
  List<num> raw, {
  required bool integerOutput,
  required double scale,
  required int zeroPoint,
}) =>
    normalizeScores(dequantizeScores(
      raw,
      integerOutput: integerOutput,
      scale: scale,
      zeroPoint: zeroPoint,
    ));

/// Index of the highest probability.
int argmax(List<double> probabilities) {
  var best = 0;
  for (var i = 1; i < probabilities.length; i++) {
    if (probabilities[i] > probabilities[best]) best = i;
  }
  return best;
}

/// Display name for a class id, from the one disease table.
String classDisplayName(int classId) => diseaseForClass(classId).name;
