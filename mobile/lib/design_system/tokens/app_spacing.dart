import 'package:flutter/material.dart';

abstract class AppSpacing {
  // ── 4px Base Scale ────────────────────────────────────────────────────────
  static const double xxs = 2.0;
  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 12.0;
  static const double lg  = 16.0;
  static const double xl  = 20.0;
  static const double xxl = 24.0;
  static const double xxxl= 32.0;
  static const double huge= 48.0;

  // ── Semantic Screen Margins & Paddings ────────────────────────────────────
  static const EdgeInsets page = EdgeInsets.fromLTRB(16, 12, 16, 96);
  static const EdgeInsets card = EdgeInsets.all(16);
  static const EdgeInsets cardCompact = EdgeInsets.all(12);
  static const EdgeInsets cardHorizontal = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  static const EdgeInsets horizontal = EdgeInsets.symmetric(horizontal: 16);
  static const EdgeInsets vertical = EdgeInsets.symmetric(vertical: 16);
}
