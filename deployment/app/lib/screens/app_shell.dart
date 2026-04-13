import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'dashboard_screen.dart';
import 'map_screen.dart';
import 'history_screen.dart';

/// Root scaffold — persistent animated bottom navigation + tab body.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int _index = 0;

  void switchTo(int index) => setState(() => _index = index);

  static const _icons = [
    Icons.dashboard_rounded,
    Icons.camera_alt_rounded,
    Icons.map_rounded,
    Icons.history_rounded,
  ];
  static const _labels = ['Overview', 'Scan', 'Farm Map', 'History'];

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    return Scaffold(
      backgroundColor: c.canvas,
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(onScanTap: () => switchTo(1)),
          const HomeScreen(),
          const MapScreen(),
          const HistoryScreen(),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _index,
        onTap: switchTo,
        icons: _icons,
        labels: _labels,
      ),
    );
  }
}

// ── Animated bottom nav ────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<IconData> icons;
  final List<String> labels;

  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.icons,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    final isDark = context.isDark;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.07),
            blurRadius: 18,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(icons.length, (i) {
              final selected = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Pill indicator behind icon
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected
                              ? GhC.accentEmphasis.withValues(alpha: 0.13)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: AnimatedScale(
                          scale: selected ? 1.12 : 1.0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOut,
                          child: Icon(
                            icons[i],
                            color:
                                selected ? GhC.accentEmphasis : c.fgSubtle,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Animated label
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        style: TextStyle(
                          color:
                              selected ? GhC.accentEmphasis : c.fgSubtle,
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                        child: Text(labels[i]),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
