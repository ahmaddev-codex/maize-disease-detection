import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: GhC.canvas,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const MaizeApp());
}

class MaizeApp extends StatelessWidget {
  const MaizeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MaizeGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: GhC.canvas,
        colorScheme: const ColorScheme.dark(
          primary: GhC.accent,
          secondary: GhC.success,
          surface: GhC.surface,
          error: GhC.danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: GhC.surface,
          foregroundColor: GhC.fg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: GhC.fg, fontSize: 15, fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: GhC.fgMuted),
        ),
        textTheme: const TextTheme(
          bodyLarge:  TextStyle(color: GhC.fg),
          bodyMedium: TextStyle(color: GhC.fgMuted),
          bodySmall:  TextStyle(color: GhC.fgSubtle),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: GhC.subtle,
          contentTextStyle: const TextStyle(color: GhC.fg),
          actionTextColor: GhC.accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: GhC.border),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: GhC.accent,
        ),
        dividerColor: GhC.border,
        cardColor: GhC.surface,
        iconTheme: const IconThemeData(color: GhC.fgMuted),
      ),
      home: const HomeScreen(),
    );
  }
}
