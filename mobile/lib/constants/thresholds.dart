/// One source of truth for confidence handling (ADR-006).
///
/// The retake banner, the confidence meter, the urgency label and the spoken
/// summary all read these. They used to disagree: banner < 0.60, meter < 0.65,
/// urgency 0.55/0.70, so a 62% scan said "Low Confidence (Verify)" with no
/// banner and "Urgency: Medium" (T15).
abstract final class ConfidenceThresholds {
  /// Below this the diagnosis is not dependable: ask for a retake before treating.
  static const double low = 0.60;

  /// At or above this the model is confident.
  static const double high = 0.85;

  static bool isLow(double confidence) => confidence < low;
  static bool isHigh(double confidence) => confidence >= high;
}

/// Change in healthy-scan rate (this week vs last) that counts as a real move.
abstract final class TrendThresholds {
  static const double delta = 0.05;
}
