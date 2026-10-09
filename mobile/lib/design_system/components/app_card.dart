import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.card,
    this.margin,
    this.onTap,
    this.accentColor,
    this.elevation = 0,
    this.color,
    this.surfaceColor,
    this.borderColor,
    this.border,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? accentColor;
  final double elevation;
  final Color? color;
  final Color? surfaceColor;
  final Color? borderColor;
  final BoxBorder? border;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultSurface = isDark ? AppColors.surfaceDark : AppColors.surface;
    final defaultBorder = isDark ? AppColors.borderDark : AppColors.border;

    final resolvedSurface = surfaceColor ?? color ?? defaultSurface;
    final resolvedBorder = border ?? Border.all(
      color: borderColor ?? defaultBorder,
      width: 1.0,
    );
    final effectiveRadius = borderRadius ?? AppRadii.card;

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: resolvedSurface,
        borderRadius: effectiveRadius,
        border: resolvedBorder,
        boxShadow: elevation > 0 ? AppColors.cardShadow : null,
      ),
      child: child,
    );

    if (accentColor != null) {
      content = ClipRRect(
        borderRadius: effectiveRadius,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accentColor),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: effectiveRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveRadius,
          child: content,
        ),
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}

/// Tactile candy folder card inspired by editorial tactile consumer apps.
class TactileFolderCard extends StatelessWidget {
  final Color folderColor;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final BoxBorder? border;

  const TactileFolderCard({
    super.key,
    required this.folderColor,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: folderColor,
        borderRadius: AppRadii.folder,
        border: border,
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadii.folder,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.folder,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Tactile speech bubble card with solid candy fill and rounded corners.
class TactileBubbleCard extends StatelessWidget {
  final Color backgroundColor;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const TactileBubbleCard({
    super.key,
    required this.backgroundColor,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadii.bubble,
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadii.bubble,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.bubble,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Floating navigation / action pill dock inspired by the reference screens.
class TactilePillDock extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;

  const TactilePillDock({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? AppColors.obsidianSurface : AppColors.paperSurface,
        borderRadius: AppRadii.dock,
        border: Border.all(
          color: isDark ? AppColors.obsidianBorder : AppColors.paperBorder,
          width: 1.0,
        ),
        boxShadow: AppColors.dockShadow,
      ),
      child: child,
    );
  }
}
