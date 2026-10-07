import 'package:flutter/material.dart';
import '../../constants/thresholds.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

class ConfidenceMeter extends StatelessWidget {
  const ConfidenceMeter({
    super.key,
    required this.confidence,
    this.classId,
    this.diseaseIndex,
    this.height = 10,
    this.showLabel = true,
  });

  final double confidence; // 0.0 to 1.0
  final int? classId;
  final int? diseaseIndex;
  final double height;
  final bool showLabel;

  int get _resolvedClassId => classId ?? diseaseIndex ?? 0;

  String get _confidenceText {
    if (ConfidenceThresholds.isHigh(confidence)) return 'High Confidence';
    if (!ConfidenceThresholds.isLow(confidence)) return 'Moderate Confidence';
    return 'Low Confidence (Verify)';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = AppColors.forClass(_resolvedClassId);
    final clamped = confidence.clamp(0.0, 1.0);
    final pctText = '${(clamped * 100).toStringAsFixed(1)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _confidenceText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                ),
              ),
              Text(
                pctText,
                style: AppTypography.tabularFigures(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        ClipRRect(
          borderRadius: AppRadii.pillBR,
          child: Container(
            height: height,
            width: double.infinity,
            color: isDark ? AppColors.surfaceMutedDark : AppColors.surfaceMuted,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: clamped,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: AppRadii.pillBR,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
