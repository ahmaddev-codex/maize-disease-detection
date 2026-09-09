import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'design_system/design_system.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/result_screen.dart';
import 'screens/ocr_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/map_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';

const _tabRoutes = ['/', '/history', '/dashboard', '/settings'];

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (_, __) => const SplashScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => _MainShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
        GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      ],
    ),
    GoRoute(path: '/camera', builder: (_, __) => const CameraScreen()),
    GoRoute(path: '/result', builder: (_, __) => const ResultScreen()),
    GoRoute(path: '/recommendation', builder: (_, __) => const ResultScreen()),
    GoRoute(path: '/ocr', builder: (_, __) => const OcrScreen()),
    GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
  ],
);

class MaizeGuardApp extends ConsumerWidget {
  const MaizeGuardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    return MaterialApp.router(
      title: 'MaizeGuard',
      theme: AgTechTheme.lightTheme,
      darkTheme: AgTechTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class _MainShell extends ConsumerWidget {
  const _MainShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final tabIndex = _tabRoutes.indexOf(location).clamp(0, _tabRoutes.length - 1);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
      body: child,
      bottomNavigationBar: _GroundedAgTechNav(tabIndex: tabIndex, isDark: isDark),
    );
  }
}

class _GroundedAgTechNav extends StatelessWidget {
  final int tabIndex;
  final bool isDark;

  const _GroundedAgTechNav({required this.tabIndex, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final navBg = isDark ? AppColors.surfaceDark : Colors.white;
    final borderColor = isDark ? AppColors.charcoal800 : AppColors.charcoal200;

    return Container(
      decoration: BoxDecoration(
        color: navBg,
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.grass_outlined,
                activeIcon: Icons.grass_rounded,
                label: 'Field',
                route: '/',
                isSelected: tabIndex == 0,
              ),
              _NavItem(
                icon: Icons.history_rounded,
                activeIcon: Icons.manage_history_rounded,
                label: 'Records',
                route: '/history',
                isSelected: tabIndex == 1,
              ),
              // Prominent Elevated Scan Trigger
              const _CenterScanTrigger(),
              _NavItem(
                icon: Icons.analytics_outlined,
                activeIcon: Icons.analytics_rounded,
                label: 'Analytics',
                route: '/dashboard',
                isSelected: tabIndex == 2,
              ),
              _NavItem(
                icon: Icons.tune_outlined,
                activeIcon: Icons.tune_rounded,
                label: 'Settings',
                route: '/settings',
                isSelected: tabIndex == 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterScanTrigger extends StatelessWidget {
  const _CenterScanTrigger();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () => context.push('/camera'),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: MaizeGuardLogo(
              size: 26,
              isDark: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  final bool isSelected;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.emeraldBase;
    const inactiveColor = AppColors.charcoal400;

    return Expanded(
      child: InkWell(
        onTap: () => context.go(route),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
