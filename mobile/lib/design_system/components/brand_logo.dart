import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'app_card.dart';

/// Renders the MaizeGuard knight shield brand emblem.
///
/// Automatically resolves between light and dark asset variants:
/// - [isDark] = true uses `assets/images/logo_dark.png` (white stroke emblem for dark surfaces).
/// - [isDark] = false uses `assets/images/logo_light.png` (emerald green emblem for light surfaces).
class MaizeGuardLogo extends StatelessWidget {
  final double size;
  final bool? isDark;
  final BoxFit fit;
  final String? semanticLabel;

  const MaizeGuardLogo({
    super.key,
    this.size = 32,
    this.isDark,
    this.fit = BoxFit.contain,
    this.semanticLabel = 'MaizeGuard Emblem',
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDark = isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final assetPath = effectiveDark
        ? 'assets/images/logo_dark.png'
        : 'assets/images/logo_light.png';

    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: fit,
      semanticLabel: semanticLabel,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: effectiveDark ? AppColors.forestDark : AppColors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.shield_outlined,
            size: size * 0.55,
            color: effectiveDark ? Colors.white70 : AppColors.emeraldBase,
          ),
        );
      },
    );
  }
}

/// Renders the full horizontal MaizeGuard brand mark (knight shield + wordmark).
///
/// Automatically resolves between light and dark asset variants:
/// - [isDark] = true uses `assets/images/logo_wordmark_dark.png` (white typography + knight shield).
/// - [isDark] = false uses `assets/images/logo_wordmark_light.png` (emerald typography + knight shield).
class MaizeGuardWordmark extends StatelessWidget {
  final double height;
  final double? width;
  final bool? isDark;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final String? semanticLabel;

  const MaizeGuardWordmark({
    super.key,
    this.height = 28,
    this.width,
    this.isDark,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.centerLeft,
    this.semanticLabel = 'MaizeGuard AI',
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDark = isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final assetPath = effectiveDark
        ? 'assets/images/logo_wordmark_dark.png'
        : 'assets/images/logo_wordmark_light.png';

    return Image.asset(
      assetPath,
      height: height,
      width: width,
      fit: fit,
      alignment: alignment,
      semanticLabel: semanticLabel,
      errorBuilder: (context, error, stackTrace) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MaizeGuardLogo(size: height, isDark: effectiveDark),
            const SizedBox(width: 8),
            Text(
              'MaizeGuard',
              style: TextStyle(
                fontFamily: 'Cabinet Grotesk',
                fontSize: height * 0.75,
                fontWeight: FontWeight.w800,
                color: effectiveDark ? Colors.white : AppColors.forestDark,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Executive brand overview card for Settings, About dialogs, or onboarding.
class MaizeGuardBrandCard extends StatelessWidget {
  final String version;

  const MaizeGuardBrandCard({
    super.key,
    this.version = 'v1.0.0 (Clinical Edge Engine)',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      color: isDark ? AppColors.surfaceDark : AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MaizeGuardWordmark(
                      height: 28,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      version,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.emeraldBase,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.emeraldBase.withValues(alpha: 0.12),
                  borderRadius: AppRadii.full,
                  border: Border.all(
                    color: AppColors.emeraldBase.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  'Clinical',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.emeraldBase,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Edge-quantized neural foliage diagnostics and regional crop protection engineered for Sub-Saharan African smallholder farmers.',
            style: AppTypography.bodySmall.copyWith(
              color: isDark ? AppColors.charcoal300 : AppColors.charcoal600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
