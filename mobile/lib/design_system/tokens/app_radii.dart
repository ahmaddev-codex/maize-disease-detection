import 'package:flutter/material.dart';

abstract class AppRadii {
  // Raw doubles
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusFull = 999.0;

  // BorderRadius instances
  static BorderRadius get xs => BorderRadius.circular(radiusXs);
  static BorderRadius get sm => BorderRadius.circular(radiusSm);
  static BorderRadius get md => BorderRadius.circular(radiusMd);
  static BorderRadius get lg => BorderRadius.circular(radiusLg);
  static BorderRadius get xl => BorderRadius.circular(radiusXl);
  static BorderRadius get full => BorderRadius.circular(radiusFull);

  // Aliases for compatibility
  static BorderRadius get xsBR => xs;
  static BorderRadius get smBR => sm;
  static BorderRadius get mdBR => md;
  static BorderRadius get lgBR => lg;
  static BorderRadius get xlBR => xl;
  static BorderRadius get pillBR => full;
}
