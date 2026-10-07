import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';

class AudioAdvisoryBar extends StatelessWidget {
  const AudioAdvisoryBar({
    super.key,
    this.title,
    this.subtitle,
    this.language,
    this.languageLabel,
    required this.isPlaying,
    required this.isLoading,
    this.onTogglePlay,
    this.onPlayPause,
    this.onSelectLanguage,
    this.onLanguageTap,
    this.audioSource = 'YarnGPT Voice',
  });

  final String? title;
  final String? subtitle;
  final String? language;
  final String? languageLabel;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback? onTogglePlay;
  final VoidCallback? onPlayPause;
  final VoidCallback? onSelectLanguage;
  final VoidCallback? onLanguageTap;
  final String audioSource;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedLanguage = language ?? languageLabel ?? 'English';
    final resolvedToggle = onTogglePlay ?? onPlayPause ?? () {};
    final resolvedSelectLang = onSelectLanguage ?? onLanguageTap;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: AppRadii.lgBR,
        border: Border.all(
          color: isPlaying
              ? AppColors.primary
              : (isDark ? AppColors.borderDark : AppColors.border),
          width: isPlaying ? 1.5 : 1.0,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          // Play/Pause Action Button
          Material(
            color: isPlaying
                ? AppColors.primary
                : (isDark ? AppColors.surfaceMutedDark : AppColors.primaryContainer),
            borderRadius: AppRadii.pillBR,
            child: InkWell(
              onTap: isLoading ? null : resolvedToggle,
              borderRadius: AppRadii.pillBR,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            isPlaying ? Colors.white : AppColors.primary,
                          ),
                        ),
                      )
                    : Icon(
                        isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
                        color: isPlaying ? Colors.white : AppColors.primary,
                        size: 24,
                      ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Audio Info
          Expanded(
            child: GestureDetector(
              onTap: resolvedSelectLang,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title ?? 'Listen in $resolvedLanguage',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (resolvedSelectLang != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceMutedDark
                                : AppColors.primaryContainer,
                            borderRadius: AppRadii.smBR,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                resolvedLanguage,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.emeraldBase
                                      : AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 16,
                                color: isDark
                                    ? AppColors.emeraldBase
                                    : AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(width: AppSpacing.xs),
                      if (isPlaying)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: AppRadii.smBR,
                          ),
                          child: const Text(
                            'PLAYING',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 2),
                Text(
                  isPlaying
                      ? 'Tap button to stop audio'
                      : (subtitle ?? 'High-clarity native audio advice · $audioSource'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
}
