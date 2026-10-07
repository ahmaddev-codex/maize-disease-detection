import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';

enum AppButtonVariant { primary, secondary, outline, danger, ghost }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.backgroundColor,
    this.textColor,
    this.isLoading = false,
    this.isFullWidth = false,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final Color? backgroundColor;
  final Color? textColor;
  final bool isLoading;
  final bool isFullWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;
    BorderSide? border;

    if (backgroundColor != null) {
      bg = backgroundColor!;
      fg = textColor ?? Colors.white;
      border = null;
    } else {
      switch (variant) {
        case AppButtonVariant.primary:
          bg = AppColors.primary;
          fg = textColor ?? Colors.white;
          border = null;
          break;
        case AppButtonVariant.secondary:
          bg = isDark ? AppColors.surfaceMutedDark : AppColors.primaryContainer;
          fg = textColor ?? (isDark ? AppColors.textPrimaryDark : AppColors.primary);
          border = null;
          break;
        case AppButtonVariant.outline:
          bg = Colors.transparent;
          fg = textColor ?? (isDark ? AppColors.textPrimaryDark : AppColors.primary);
          border = BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
            width: 1.5,
          );
          break;
        case AppButtonVariant.danger:
          bg = AppColors.danger;
          fg = textColor ?? Colors.white;
          border = null;
          break;
        case AppButtonVariant.ghost:
          bg = Colors.transparent;
          fg = textColor ?? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary);
          border = null;
          break;
      }
    }

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.mdBR,
        side: border ?? BorderSide.none,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      minimumSize: Size(isFullWidth ? double.infinity : 0, height),
    );

    Widget child;
    if (isLoading) {
      child = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(fg),
        ),
      );
    } else if (icon != null) {
      child = Row(
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      );
    } else {
      child = Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: buttonStyle,
      child: child,
    );
  }
}
