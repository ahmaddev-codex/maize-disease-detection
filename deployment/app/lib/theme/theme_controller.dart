import 'package:flutter/material.dart';

/// Global theme-mode controller.
/// Any widget can call [ThemeController.toggle()] to switch modes.
/// The [ValueNotifier] drives [MaizeApp]'s [ValueListenableBuilder].
class ThemeController {
  ThemeController._();

  static final mode = ValueNotifier<ThemeMode>(ThemeMode.dark);

  static void toggle() {
    mode.value =
        mode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  static bool get isDark => mode.value == ThemeMode.dark;
}
