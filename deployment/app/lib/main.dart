import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'screens/app_shell.dart';
import 'services/path_resolver.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cache the documents directory path before the UI renders so that
  // PathResolver.resolve() can be called synchronously anywhere in the tree.
  await PathResolver.init();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MaizeApp());
}

class MaizeApp extends StatelessWidget {
  const MaizeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (_, mode, __) {
        // Keep status bar icons legible on both themes
        SystemChrome.setSystemUIOverlayStyle(
          mode == ThemeMode.dark
              ? const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                  systemNavigationBarColor: Color(0xFF0D1117),
                  systemNavigationBarIconBrightness: Brightness.light,
                )
              : const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                  systemNavigationBarColor: Color(0xFFF6F8FA),
                  systemNavigationBarIconBrightness: Brightness.dark,
                ),
        );

        return MaterialApp(
          title: 'MaizeGuard',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: _buildTheme(AppColors.light, Brightness.light),
          darkTheme: _buildTheme(AppColors.dark, Brightness.dark),
          home: const AppShell(),
        );
      },
    );
  }

  ThemeData _buildTheme(AppColors c, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.canvas,
      extensions: [c],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: GhC.accentEmphasis,
        onPrimary: Colors.white,
        secondary: GhC.successEmphasis,
        onSecondary: Colors.white,
        error: GhC.danger,
        onError: Colors.white,
        surface: c.surface,
        onSurface: c.fg,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.fg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: c.fg, fontSize: 15, fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: c.fgMuted),
      ),
      textTheme: TextTheme(
        bodyLarge:  TextStyle(color: c.fg),
        bodyMedium: TextStyle(color: c.fgMuted),
        bodySmall:  TextStyle(color: c.fgSubtle),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.subtle,
        contentTextStyle: TextStyle(color: c.fg),
        actionTextColor: GhC.accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: c.border),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: GhC.accentEmphasis,
      ),
      dividerColor: c.border,
      cardColor: c.surface,
      iconTheme: IconThemeData(color: c.fgMuted),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: c.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.canvas,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: GhC.accentEmphasis),
        ),
        hintStyle: TextStyle(color: c.fgSubtle, fontSize: 12),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
