import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import 'app_button.dart';

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    this.icon,
    this.illustration,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData? icon;
  final Widget? illustration;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (illustration != null)
              illustration!
            else
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceMutedDark : AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon ?? Icons.info_outline_rounded,
                  size: 36,
                  color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: AppButtonVariant.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.actionText,
    this.onAction,
    this.topSpacing = AppSpacing.lg,
  });

  final String title;
  final String? actionText;
  final VoidCallback? onAction;
  final double topSpacing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(top: topSpacing, bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: isDark ? AppColors.textMutedDark : AppColors.textSecondary,
            ),
          ),
          if (actionText != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionText!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
