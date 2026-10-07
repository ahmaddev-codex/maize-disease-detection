import 'package:flutter_test/flutter_test.dart';
import 'package:maizeguard/constants/thresholds.dart';
import 'package:maizeguard/models/scan_record.dart';
import 'package:maizeguard/services/recommendation_engine.dart';

/// T15: the retake banner (<0.60), the confidence meter (<0.65) and the urgency
/// rules (0.55/0.70) disagreed, so a 62% scan read "Low Confidence (Verify)"
/// with no banner and "Urgency: Medium".
ClassificationResult _result(double confidence, {int classId = 2}) => ClassificationResult(
      classId: classId,
      className: 'Gray Leaf Spot',
      shortName: 'GLS',
      confidence: confidence,
      allScores: const [0.1, 0.1, 0.7, 0.1],
      latencyMs: 30,
    );

void main() {
  group('one threshold set', () {
    test('low confidence is the same number everywhere', () {
      expect(ConfidenceThresholds.low, 0.60);
      expect(ConfidenceThresholds.isLow(0.58), isTrue);
      expect(ConfidenceThresholds.isLow(0.62), isFalse);
      expect(ConfidenceThresholds.isHigh(0.90), isTrue);
    });

    test('a low-confidence scan asks for verification, not treatment', () {
      final rec = RecommendationEngine.generate(_result(0.58));

      expect(rec.urgencyLabel, contains('Verify'));
      expect(rec.needsRetake, isTrue);
    });

    test('a confident scan above the low bar is not flagged for retake', () {
      final rec = RecommendationEngine.generate(_result(0.62));

      expect(rec.needsRetake, isFalse);
      expect(rec.urgencyLabel, isNot(contains('Verify')));
    });

    test('a worsening trend at high confidence is critical', () {
      final rec = RecommendationEngine.generate(_result(0.90), trend: TrendType.worsening);

      expect(rec.urgencyLabel.toLowerCase(), contains('critical'));
    });

    test('a healthy scan needs no action', () {
      final rec = RecommendationEngine.generate(_result(0.95, classId: 3));

      expect(rec.urgencyLabel, 'No action needed');
      expect(rec.needsRetake, isFalse);
    });

    test('trend deltas map to trend types', () {
      expect(trendFromDelta(0.2), TrendType.improving);
      expect(trendFromDelta(-0.2), TrendType.worsening);
      expect(trendFromDelta(0.01), TrendType.stable);
    });
  });
}
