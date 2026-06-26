import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'constants/colors.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/result_screen.dart';
import 'screens/ocr_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/map_screen.dart';
import 'screens/recommendation_screen.dart';
import 'screens/settings_screen.dart';

const _tabRoutes = ['/', '/history', '/dashboard', '/settings'];

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => _MainShell(child: child),
      routes: [
        GoRoute(path: '/',          builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/history',   builder: (_, __) => const HistoryScreen()),
        GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/settings',  builder: (_, __) => const SettingsScreen()),
      ],
    ),
    GoRoute(path: '/camera',         builder: (_, __) => const CameraScreen()),
    GoRoute(path: '/result',         builder: (_, __) => const ResultScreen()),
    GoRoute(path: '/ocr',            builder: (_, __) => const OcrScreen()),
    GoRoute(path: '/map',            builder: (_, __) => const MapScreen()),
    GoRoute(path: '/recommendation', builder: (_, __) => const RecommendationScreen()),
  ],
);

class MaizeGuardApp extends ConsumerWidget {
  const MaizeGuardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    return MaterialApp.router(
      title:        'MaizeGuard',
      theme:        AppColors.lightTheme,
      darkTheme:    AppColors.darkTheme,
      themeMode:    isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

// ── Shell with floating glassmorphic pill nav ─────────────────────────────────
class _MainShell extends ConsumerWidget {
  const _MainShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final tabIndex = _tabRoutes.indexOf(location).clamp(0, _tabRoutes.length - 1);
    final isDark   = ref.watch(isDarkModeProvider);

    return Scaffold(
      extendBody: false,
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvas,
      body: child,
      bottomNavigationBar: _FloatingPillNav(tabIndex: tabIndex, isDark: isDark),
    );
  }
}

// ── Floating pill navigation bar ──────────────────────────────────────────────
class _FloatingPillNav extends StatelessWidget {
  const _FloatingPillNav({required this.tabIndex, required this.isDark});
  final int tabIndex;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.surfaceDark : Colors.white;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: bg.withOpacity(0.80),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: isDark
                      ? AppColors.borderDark.withOpacity(0.5)
                      : Colors.white.withOpacity(0.90),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _NavTile(icon: Icons.home_rounded,     label: 'Home',     route: '/',          activeIndex: tabIndex, myIndex: 0, isDark: isDark),
                  _NavTile(icon: Icons.history_rounded,  label: 'History',  route: '/history',   activeIndex: tabIndex, myIndex: 1, isDark: isDark),
                  const _ScanButton(),
                  _NavTile(icon: Icons.bar_chart_rounded, label: 'Stats',   route: '/dashboard', activeIndex: tabIndex, myIndex: 2, isDark: isDark),
                  _NavTile(icon: Icons.settings_rounded, label: 'Settings', route: '/settings',  activeIndex: tabIndex, myIndex: 3, isDark: isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Centre scan action button ─────────────────────────────────────────────────
class _ScanButton extends StatelessWidget {
  const _ScanButton();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: GestureDetector(
      onTap: () => context.push('/camera'),
      child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.accent, AppColors.accentFg],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.38),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 22),
      ),
    ),
  );
}

// ── Individual nav tile ───────────────────────────────────────────────────────
class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.route,
    required this.activeIndex,
    required this.myIndex,
    required this.isDark,
  });

  final IconData icon;
  final String label, route;
  final int activeIndex, myIndex;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isActive     = activeIndex == myIndex;
    final activeColor  = AppColors.accent;
    final inactiveColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Expanded(
      child: GestureDetector(
        onTap: () => context.go(route),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Duotone: gradient fill icon + large transparent glow layer
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isActive
                  ? Stack(
                      key: const ValueKey('active'),
                      alignment: Alignment.center,
                      children: [
                        Icon(icon, color: activeColor.withOpacity(0.20), size: 28),
                        ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                            colors: [AppColors.accent, AppColors.accentFg],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(b),
                          child: Icon(icon, color: Colors.white, size: 22),
                        ),
                      ],
                    )
                  : Icon(icon, key: const ValueKey('inactive'),
                      color: inactiveColor, size: 22),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive ? activeColor : inactiveColor,
                fontFamily: 'DM Sans',
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
