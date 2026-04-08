import 'package:flutter/material.dart';

/// GitHub Primer dark-mode colour tokens.
/// Reference: https://primer.style/primitives/colors
abstract final class GhC {
  // Canvas
  static const canvas        = Color(0xFF0D1117);
  static const surface       = Color(0xFF161B22);
  static const subtle        = Color(0xFF21262D);

  // Borders
  static const border        = Color(0xFF30363D);
  static const borderMuted   = Color(0xFF21262D);

  // Foreground
  static const fg            = Color(0xFFE6EDF3);
  static const fgMuted       = Color(0xFF8B949E);
  static const fgSubtle      = Color(0xFF6E7681);

  // Accent (blue)
  static const accent        = Color(0xFF58A6FF);
  static const accentEmphasis= Color(0xFF1F6FEB);
  static const accentSubtle  = Color(0x26388BFD);  // ~15% opacity

  // Success (green)
  static const success       = Color(0xFF3FB950);
  static const successEmphasis=Color(0xFF238636);

  // Attention (yellow)
  static const attention     = Color(0xFFE3B341);
  static const attentionEmph = Color(0xFFD29922);

  // Danger (red)
  static const danger        = Color(0xFFF85149);
  static const dangerEmphasis= Color(0xFFDA3633);

  // Monospace font family
  static const mono = 'monospace';
}

/// Pre-built box decorations reused across screens.
abstract final class GhBox {
  static BoxDecoration card({Color? bg, bool highlight = false}) => BoxDecoration(
    color: bg ?? GhC.surface,
    border: Border.all(
      color: highlight ? GhC.accentEmphasis : GhC.border,
      width: 1,
    ),
    borderRadius: BorderRadius.circular(6),
  );

  static BoxDecoration subtle() => BoxDecoration(
    color: GhC.subtle,
    border: Border.all(color: GhC.border),
    borderRadius: BorderRadius.circular(6),
  );

  static BoxDecoration pill(Color bg) => BoxDecoration(
    color: bg.withValues(alpha: 0.18),
    border: Border.all(color: bg.withValues(alpha: 0.4)),
    borderRadius: BorderRadius.circular(20),
  );
}

/// Common text styles.
abstract final class GhText {
  static const h1 = TextStyle(
    color: GhC.fg, fontSize: 20, fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
  );
  static const h2 = TextStyle(
    color: GhC.fg, fontSize: 16, fontWeight: FontWeight.w600,
  );
  static const h3 = TextStyle(
    color: GhC.fg, fontSize: 14, fontWeight: FontWeight.w600,
  );
  static const body = TextStyle(color: GhC.fg, fontSize: 14, height: 1.5);
  static const muted = TextStyle(color: GhC.fgMuted, fontSize: 12, height: 1.4);
  static const subtle = TextStyle(color: GhC.fgSubtle, fontSize: 11);
  static const code = TextStyle(
    color: GhC.fg, fontSize: 12, fontFamily: GhC.mono, height: 1.6,
  );
  static const codeMuted = TextStyle(
    color: GhC.fgMuted, fontSize: 12, fontFamily: GhC.mono, height: 1.6,
  );
}

/// Reusable widget: a GitHub-style label/badge pill.
class GhLabel extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;

  const GhLabel(this.text, {super.key, required this.color, this.fontSize = 11});

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

/// Reusable widget: horizontal divider matching GitHub's border.
class GhDivider extends StatelessWidget {
  final EdgeInsetsGeometry? margin;
  const GhDivider({super.key, this.margin});

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    height: 1,
    color: GhC.border,
  );
}

/// Reusable primary action button (green filled).
class GhButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool small;
  final Color? color;

  const GhButton(this.label, {
    super.key,
    this.onTap,
    this.icon,
    this.small = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
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
            color: disabled ? GhC.subtle : bg,
            border: Border.all(
              color: disabled ? GhC.border : bg,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: small ? 14 : 16),
                SizedBox(width: small ? 6 : 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: small ? 12 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable secondary/outline button.
class GhButtonOutline extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool small;

  const GhButtonOutline(this.label, {
    super.key, this.onTap, this.icon, this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 12 : 16,
          vertical: small ? 6 : 10,
        ),
        decoration: BoxDecoration(
          color: GhC.subtle,
          border: Border.all(color: GhC.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: GhC.fg, size: small ? 14 : 16),
              SizedBox(width: small ? 6 : 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: GhC.fg,
                fontSize: small ? 12 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
