import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';

class SeverityBadge extends StatelessWidget {
  const SeverityBadge({
    super.key,
    this.classId,
    this.label,
    this.diseaseName,
    this.severityLabel,
    this.showIcon = true,
    this.compact = false,
  });

  final int? classId;
  final String? label;
  final String? diseaseName;
  final String? severityLabel;
  final bool showIcon;
  final bool compact;

  int get _resolvedClassId {
    if (classId != null) return classId!;
    if (diseaseName != null) {
      final dn = diseaseName!.toLowerCase();
      if (dn.contains('blight') || dn.contains('nclb')) return 0;
      if (dn.contains('rust')) return 1;
      if (dn.contains('spot') || dn.contains('gls')) return 2;
      if (dn.contains('healthy')) return 3;
    }
    return 0;
  }

  String get _resolvedLabel => label ?? severityLabel ?? 'Status';

  IconData get _icon {
    switch (_resolvedClassId) {
      case 0: return Icons.warning_rounded;       // NCLB
      case 1: return Icons.grain_rounded;         // Rust
      case 2: return Icons.blur_on_rounded;       // GLS
      case 3: return Icons.check_circle_rounded;  // Healthy
      default: return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = AppColors.forClass(_resolvedClassId);
    final bgColor = AppColors.containerForClass(_resolvedClassId, isDark: isDark);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: compact ? AppSpacing.xs : 6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadii.pillBR,
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.4 : 0.3),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(_icon, size: compact ? 12 : 14, color: color),
            SizedBox(width: compact ? AppSpacing.xs : AppSpacing.sm),
          ],
          Text(
            _resolvedLabel,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class DiseaseDot extends StatelessWidget {
  const DiseaseDot(this.color, {super.key, this.size = 8});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
