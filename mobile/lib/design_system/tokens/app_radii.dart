import 'package:flutter/material.dart';

abstract class AppRadii {
  // Raw doubles
  static const double radiusXs = 6.0;
  static const double radiusSm = 10.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 22.0;
  static const double radiusXl = 28.0;
  static const double radiusFull = 999.0;

  // Semantic tactile doubles
  static const double radiusCard = 26.0;
  static const double radiusFolder = 28.0;
  static const double radiusBubble = 24.0;
  static const double radiusDock = 999.0;

  // BorderRadius instances
  static BorderRadius get xs => BorderRadius.circular(radiusXs);
  static BorderRadius get sm => BorderRadius.circular(radiusSm);
  static BorderRadius get md => BorderRadius.circular(radiusMd);
  static BorderRadius get lg => BorderRadius.circular(radiusLg);
  static BorderRadius get xl => BorderRadius.circular(radiusXl);
  static BorderRadius get full => BorderRadius.circular(radiusFull);

  // Semantic tactile BorderRadius
  static BorderRadius get card => BorderRadius.circular(radiusCard);
  static BorderRadius get folder => BorderRadius.circular(radiusFolder);
  static BorderRadius get bubble => BorderRadius.circular(radiusBubble);
  static BorderRadius get dock => BorderRadius.circular(radiusDock);

  // Aliases for compatibility
  static BorderRadius get xsBR => xs;
  static BorderRadius get smBR => sm;
  static BorderRadius get mdBR => md;
  static BorderRadius get lgBR => lg;
  static BorderRadius get xlBR => xl;
  static BorderRadius get pillBR => full;
}
