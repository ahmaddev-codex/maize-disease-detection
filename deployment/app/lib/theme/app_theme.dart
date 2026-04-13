import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// ── Semantic / accent colours (same in both themes) ──────────────────────────

/// GitHub Primer semantic colour tokens — accent, success, attention, danger.
/// These do NOT change between light and dark themes.
abstract final class GhC {
  // Accent (blue)
  static const accent         = Color(0xFF58A6FF);
  static const accentEmphasis = Color(0xFF1F6FEB);
  static const accentSubtle   = Color(0x26388BFD);

  // Success (green)
  static const success        = Color(0xFF3FB950);
  static const successEmphasis= Color(0xFF238636);

  // Attention (yellow)
  static const attention      = Color(0xFFE3B341);
  static const attentionEmph  = Color(0xFFD29922);

  // Danger (red)
  static const danger         = Color(0xFFF85149);
  static const dangerEmphasis = Color(0xFFDA3633);

  // Monospace font family
  static const mono = 'monospace';
}

// ── Theme-adaptive colour set ─────────────────────────────────────────────────

/// Neutral palette that flips between dark and light themes.
/// Access via [BuildContext.gc] extension.
class AppColors extends ThemeExtension<AppColors> {
  final Color canvas;
  final Color surface;
  final Color subtle;
  final Color border;
  final Color borderMuted;
  final Color fg;
  final Color fgMuted;
  final Color fgSubtle;

  const AppColors({
    required this.canvas,
    required this.surface,
    required this.subtle,
    required this.border,
    required this.borderMuted,
    required this.fg,
    required this.fgMuted,
    required this.fgSubtle,
  });

  // ── Dark palette (GitHub dark) ──────────────────────────────────────────────
  static const dark = AppColors(
    canvas:      Color(0xFF0D1117),
    surface:     Color(0xFF161B22),
    subtle:      Color(0xFF21262D),
    border:      Color(0xFF30363D),
    borderMuted: Color(0xFF21262D),
    fg:          Color(0xFFE6EDF3),
    fgMuted:     Color(0xFF8B949E),
    fgSubtle:    Color(0xFF6E7681),
  );

  // ── Light palette (GitHub light) ───────────────────────────────────────────
  static const light = AppColors(
    canvas:      Color(0xFFF6F8FA),
    surface:     Color(0xFFFFFFFF),
    subtle:      Color(0xFFEFF1F3),
    border:      Color(0xFFD0D7DE),
    borderMuted: Color(0xFFEAECEF),
    fg:          Color(0xFF24292F),
    fgMuted:     Color(0xFF57606A),
    fgSubtle:    Color(0xFF6E7781),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  // ── ThemeExtension overrides ────────────────────────────────────────────────

  @override
  AppColors copyWith({
    Color? canvas, Color? surface, Color? subtle,
    Color? border, Color? borderMuted,
    Color? fg, Color? fgMuted, Color? fgSubtle,
  }) =>
      AppColors(
        canvas:      canvas      ?? this.canvas,
        surface:     surface     ?? this.surface,
        subtle:      subtle      ?? this.subtle,
        border:      border      ?? this.border,
        borderMuted: borderMuted ?? this.borderMuted,
        fg:          fg          ?? this.fg,
        fgMuted:     fgMuted     ?? this.fgMuted,
        fgSubtle:    fgSubtle    ?? this.fgSubtle,
      );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      canvas:      Color.lerp(canvas,      other.canvas,      t)!,
      surface:     Color.lerp(surface,     other.surface,     t)!,
      subtle:      Color.lerp(subtle,      other.subtle,      t)!,
      border:      Color.lerp(border,      other.border,      t)!,
      borderMuted: Color.lerp(borderMuted, other.borderMuted, t)!,
      fg:          Color.lerp(fg,          other.fg,          t)!,
      fgMuted:     Color.lerp(fgMuted,     other.fgMuted,     t)!,
      fgSubtle:    Color.lerp(fgSubtle,    other.fgSubtle,    t)!,
    );
  }
}

// ── BuildContext shorthand ────────────────────────────────────────────────────

extension AppColorsX on BuildContext {
  AppColors get gc => AppColors.of(this);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

// ── Box decorations (context-aware) ──────────────────────────────────────────

abstract final class GhBox {
  static BoxDecoration card(AppColors c, {bool highlight = false}) =>
      BoxDecoration(
        color: c.surface,
        border: Border.all(
          color: highlight ? GhC.accentEmphasis : c.border,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(6),
      );

  static BoxDecoration subtle(AppColors c) => BoxDecoration(
        color: c.subtle,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(6),
      );

  static BoxDecoration pill(Color bg) => BoxDecoration(
        color: bg.withValues(alpha: 0.18),
        border: Border.all(color: bg.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(20),
      );
}

// ── Text styles ───────────────────────────────────────────────────────────────

abstract final class GhText {
  static TextStyle h1(AppColors c) => TextStyle(
      color: c.fg, fontSize: 20, fontWeight: FontWeight.w600,
      letterSpacing: -0.5);

  static TextStyle h2(AppColors c) => TextStyle(
      color: c.fg, fontSize: 16, fontWeight: FontWeight.w600);

  static TextStyle h3(AppColors c) => TextStyle(
      color: c.fg, fontSize: 14, fontWeight: FontWeight.w600);

  static TextStyle body(AppColors c) =>
      TextStyle(color: c.fg, fontSize: 14, height: 1.5);

  static TextStyle muted(AppColors c) =>
      TextStyle(color: c.fgMuted, fontSize: 12, height: 1.4);

  static TextStyle subtle(AppColors c) =>
      TextStyle(color: c.fgSubtle, fontSize: 11);

  static const code = TextStyle(
    color: Color(0xFFE6EDF3), fontSize: 12,
    fontFamily: GhC.mono, height: 1.6,
  );
  static const codeMuted = TextStyle(
    color: Color(0xFF8B949E), fontSize: 12,
    fontFamily: GhC.mono, height: 1.6,
  );
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

/// GitHub-style label/badge pill.
class GhLabel extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;

  const GhLabel(this.text,
      {super.key, required this.color, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: GhBox.pill(color),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Horizontal divider matching the theme's border colour.
class GhDivider extends StatelessWidget {
  final EdgeInsetsGeometry? margin;
  const GhDivider({super.key, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      height: 1,
      color: context.gc.border,
    );
  }
}

/// Filled primary action button.
class GhButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool small;
  final Color? color;

  const GhButton(this.label,
      {super.key, this.onTap, this.icon, this.small = false, this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    final bg = color ?? GhC.successEmphasis;
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: disabled ? 0.5 : 1.0,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: small ? 12 : 16,
            vertical: small ? 6 : 10,
          ),
          decoration: BoxDecoration(
            color: disabled ? c.subtle : bg,
            border: Border.all(
                color: disabled ? c.border : bg, width: 1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: small ? 14 : 16),
                SizedBox(width: small ? 6 : 8),
              ],
              Text(label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: small ? 12 : 14,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

/// Outline secondary button.
class GhButtonOutline extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool small;

  const GhButtonOutline(this.label,
      {super.key, this.onTap, this.icon, this.small = false});

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 12 : 16,
          vertical: small ? 6 : 10,
        ),
        decoration: BoxDecoration(
          color: c.subtle,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: c.fg, size: small ? 14 : 16),
              SizedBox(width: small ? 6 : 8),
            ],
            Text(label,
                style: TextStyle(
                  color: c.fg,
                  fontSize: small ? 12 : 14,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}

/// Dialog-safe button — use inside [AlertDialog.actions] instead of [GhButton]
/// or [GhButtonOutline]. Receives [AppColors] explicitly so it never calls
/// Theme.of(context), and has no [AnimationController], making it safe during
/// the dialog dismiss animation.
class GhDialogButton extends StatelessWidget {
  final String label;
  final AppColors c;
  final VoidCallback onTap;
  final bool filled;
  final Color? color;

  const GhDialogButton(
    this.label, {
    super.key,
    required this.c,
    required this.onTap,
    this.filled = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? GhC.accentEmphasis;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? bg : c.subtle,
          border: Border.all(color: filled ? bg : c.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.white : c.fg,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Animation helpers ─────────────────────────────────────────────────────────

/// Fades + slides a child in on first build, with a configurable delay.
/// Use [delayMs] to stagger multiple cards.
class AnimatedEntry extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final Duration duration;

  const AnimatedEntry({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.duration = const Duration(milliseconds: 450),
  });

  @override
  State<AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<AnimatedEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    if (widget.delayMs == 0) {
      _ctrl.forward();
    } else {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _opacity,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

/// Counts up from 0 to [value] with an animated number.
class AnimatedNumber extends StatelessWidget {
  final double value;
  final Duration duration;
  final Widget Function(BuildContext, double, Widget?) builder;

  const AnimatedNumber({
    super.key,
    required this.value,
    required this.builder,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOut,
      builder: builder,
    );
  }
}

// ── Animated circular arc (custom painter) ────────────────────────────────────

/// Full circular progress arc with smooth animation.
class AnimatedArcScore extends StatelessWidget {
  final double score;   // 0–100
  final Color color;
  final double size;
  final double strokeWidth;
  final Widget center;

  const AnimatedArcScore({
    super.key,
    required this.score,
    required this.color,
    required this.center,
    this.size = 180,
    this.strokeWidth = 14,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: (score / 100).clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (_, progress, __) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _ArcPainter(
                progress: progress,
                arcColor: color,
                trackColor: c.subtle,
                strokeWidth: strokeWidth,
              ),
            ),
            center,
          ],
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color arcColor;
  final Color trackColor;
  final double strokeWidth;

  _ArcPainter({
    required this.progress,
    required this.arcColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: centre, radius: radius);

    final startAngle = -math.pi / 2;

    // Track
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = trackColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0) return;

    // Arc
    canvas.drawArc(
      rect,
      startAngle,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = arcColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Glow dot at arc tip
    final angle = startAngle + 2 * math.pi * progress;
    final dotX = centre.dx + radius * math.cos(angle);
    final dotY = centre.dy + radius * math.sin(angle);
    canvas.drawCircle(
      Offset(dotX, dotY),
      strokeWidth / 2,
      Paint()..color = arcColor,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.arcColor != arcColor;
}
