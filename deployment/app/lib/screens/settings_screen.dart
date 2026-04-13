import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

/// App-wide settings: theme toggle + about info.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          _SectionLabel(label: 'Appearance', c: c),
          const SizedBox(height: 8),
          _ThemeRow(c: c),
          const SizedBox(height: 28),
          _SectionLabel(label: 'About', c: c),
          const SizedBox(height: 8),
          _AboutCard(c: c),
        ],
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final AppColors c;
  const _SectionLabel({required this.label, required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: c.fgSubtle,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ── Theme toggle row ───────────────────────────────────────────────────────────

class _ThemeRow extends StatelessWidget {
  final AppColors c;
  const _ThemeRow({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.mode,
        builder: (_, mode, __) {
          final isDark = mode == ThemeMode.dark;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: ThemeController.toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? GhC.attention.withValues(alpha: 0.15)
                          : GhC.accentEmphasis.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) => RotationTransition(
                        turns:
                            Tween(begin: 0.75, end: 1.0).animate(anim),
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                      child: Icon(
                        isDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        key: ValueKey(isDark),
                        color: isDark ? GhC.attention : GhC.accentEmphasis,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDark ? 'Dark mode' : 'Light mode',
                          style: TextStyle(
                            color: c.fg,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isDark
                              ? 'Switch to light theme'
                              : 'Switch to dark theme',
                          style: TextStyle(color: c.fgMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isDark,
                    onChanged: (_) => ThemeController.toggle(),
                    activeThumbColor: Colors.white,
                    activeTrackColor: GhC.accentEmphasis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── About card ─────────────────────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  final AppColors c;
  const _AboutCard({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _AboutRow(
            c: c,
            icon: Icons.eco_rounded,
            iconColor: GhC.successEmphasis,
            label: 'Application',
            value: 'MaizeGuard v1.0',
            isFirst: true,
          ),
          GhDivider(margin: const EdgeInsets.symmetric(horizontal: 16)),
          _AboutRow(
            c: c,
            icon: Icons.memory_rounded,
            iconColor: GhC.accentEmphasis,
            label: 'Model',
            value: 'EfficientNetB3 · INT8',
          ),
          GhDivider(margin: const EdgeInsets.symmetric(horizontal: 16)),
          _AboutRow(
            c: c,
            icon: Icons.grain_rounded,
            iconColor: GhC.attention,
            label: 'Dataset',
            value: 'PlantVillage · 4,188 images',
          ),
          GhDivider(margin: const EdgeInsets.symmetric(horizontal: 16)),
          _AboutRow(
            c: c,
            icon: Icons.wifi_off_rounded,
            iconColor: GhC.success,
            label: 'Inference',
            value: '100% on-device',
          ),
          GhDivider(margin: const EdgeInsets.symmetric(horizontal: 16)),
          _AboutRow(
            c: c,
            icon: Icons.location_on_rounded,
            iconColor: GhC.danger,
            label: 'Target region',
            value: 'Nigeria — West Africa',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final AppColors c;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isFirst;
  final bool isLast;

  const _AboutRow({
    required this.c,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        isFirst ? 14 : 10,
        16,
        isLast ? 14 : 10,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: c.fgMuted, fontSize: 13),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: c.fg,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
