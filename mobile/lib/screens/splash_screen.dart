import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../design_system/design_system.dart';
import '../providers/app_provider.dart';
import '../services/classifier_service.dart';

/// Minimalist, serene animated splash screen for MaizeGuard.
///
/// Simply displays the brand logo inside a container with a calm,
/// breathing background pulse animation while warming up on-device
/// runtime services in the background.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();

    // Continuous calm ambient pulse
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.96, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _pulseOpacity = Tween<double>(begin: 0.15, end: 0.35).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _startInitialization();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _startInitialization() async {
    final stopwatch = Stopwatch()..start();

    // Background pre-warming
    try {
      await ClassifierService.instance.loadModel();
      if (mounted) {
        ref.read(classifierReadyProvider.notifier).state = true;
      }
    } catch (e) {
      debugPrint('[Splash] Model load notice: $e');
    }

    try {
      await ref.read(scanListProvider.notifier).load();
    } catch (e) {
      debugPrint('[Splash] Database load notice: $e');
    }

    // Minimum display duration for a calm, premium pulse feel (2.0 seconds)
    const minDurationMs = 2000;
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < minDurationMs) {
      await Future.delayed(Duration(milliseconds: minDurationMs - elapsed));
    }

    if (!mounted) return;

    try {
      context.go('/');
    } catch (_) {
      // Fallback for isolated widget test environments
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.forestDark,
      body: Center(
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Outer pulsing background ambient aura
                Transform.scale(
                  scale: _pulseScale.value * 1.18,
                  child: Container(
                    width: 144,
                    height: 144,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.emeraldBase.withValues(
                        alpha: _pulseOpacity.value,
                      ),
                    ),
                  ),
                ),
                // Main logo container with gentle breathing scale
                Transform.scale(
                  scale: _pulseScale.value,
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.20),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emeraldBase.withValues(
                            alpha: _pulseOpacity.value,
                          ),
                          blurRadius: 32,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: MaizeGuardLogo(
                        size: 66,
                        isDark: true,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
