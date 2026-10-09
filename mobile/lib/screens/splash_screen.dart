import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../design_system/design_system.dart';
import '../providers/app_provider.dart';
import '../providers/classifier_state.dart';

/// Cinematic, agtech-native animated splash screen for MaizeGuard.
///
/// Combines a deep bio-forest atmospheric canvas, resonant telemetry aura
/// rings, a glassmorphic knight shield brand emblem, live neural runtime
/// warmup stage tracking, and high-contrast clinical typography.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _entranceCtrl;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textOpacity;
  late final Animation<double> _progressOpacity;
  late final Animation<double> _footerOpacity;

  double _progress = 0.15;
  String _statusMessage = 'Initializing neural runtime...';

  @override
  void initState() {
    super.initState();

    // Continuous calm breathing pulse for the ambient halo & emblem
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.97, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _pulseOpacity = Tween<double>(begin: 0.18, end: 0.38).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Staggered entrance animation
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.60, curve: Curves.easeOutBack),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.40, curve: Curves.easeIn),
      ),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.22),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.20, 0.70, curve: Curves.easeOutCubic),
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.20, 0.60, curve: Curves.easeIn),
      ),
    );

    _progressOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.40, 0.85, curve: Curves.easeIn),
      ),
    );

    _footerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.55, 1.0, curve: Curves.easeIn),
      ),
    );

    _entranceCtrl.forward();
    _startInitialization();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  void _setProgress(double value, String message) {
    if (!mounted) return;
    setState(() {
      _progress = value;
      _statusMessage = message;
    });
  }

  Future<void> _startInitialization() async {
    final stopwatch = Stopwatch()..start();

    // Stage 1: Runtime initialization
    _setProgress(0.20, 'Initializing neural runtime...');

    // Stage 2: Load quantized model weights
    await Future.delayed(const Duration(milliseconds: 160));
    _setProgress(0.50, 'Loading MobileNetV3 edge model...');
    await ref.read(classifierStateProvider.notifier).load();

    // Stage 3: Load scan database
    _setProgress(0.80, 'Syncing crop health records...');
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

    // Stage 4: Engine ready
    _setProgress(1.0, 'Diagnostic engine ready');
    await Future.delayed(const Duration(milliseconds: 250));

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
      backgroundColor: const Color(0xFF07190E),
      body: Stack(
        children: [
          // ── Deep Bio-Forest Radial Gradient Backdrop ────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.22),
                  radius: 1.25,
                  colors: [
                    Color(0xFF14532D), // Rich ambient emerald glow
                    Color(0xFF0D361E), // AppColors.forestDark
                    Color(0xFF05170B), // Abyssal humus soil
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // ── Resonant Telemetry Radar Grid Custom Painter ────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, _) {
                return CustomPaint(
                  painter: _AgriAtmospherePainter(
                    pulseValue: _pulseCtrl.value,
                  ),
                );
              },
            ),
          ),

          // ── Central Hero Content ───────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),

                // Hero Emblem with Ambient Aura & Frosted Crest
                AnimatedBuilder(
                  animation: Listenable.merge([_pulseCtrl, _entranceCtrl]),
                  builder: (context, child) {
                    final currentScale = _logoScale.value * _pulseScale.value;
                    return Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: currentScale,
                        child: child,
                      ),
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer breathing glow aura
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (context, _) {
                          return Transform.scale(
                            scale: _pulseScale.value * 1.24,
                            child: Container(
                              width: 156,
                              height: 156,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.emeraldLight.withValues(
                                      alpha: _pulseOpacity.value * 0.95,
                                    ),
                                    AppColors.emeraldBase.withValues(
                                      alpha: _pulseOpacity.value * 0.40,
                                    ),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.55, 1.0],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Middle halo accent ring
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (context, _) {
                          return Transform.scale(
                            scale: _pulseScale.value * 1.08,
                            child: Container(
                              width: 132,
                              height: 132,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.emeraldLight.withValues(
                                    alpha: 0.18 + 0.16 * _pulseCtrl.value,
                                  ),
                                  width: 1.2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Main frosted glass shield container
                      Container(
                        width: 114,
                        height: 114,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.16),
                              Colors.white.withValues(alpha: 0.04),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.emeraldBase.withValues(
                                alpha: _pulseOpacity.value * 1.15,
                              ),
                              blurRadius: 36,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: AppColors.maizeGold.withValues(alpha: 0.16),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: MaizeGuardLogo(
                            size: 68,
                            isDark: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Brand Typography Section
                AnimatedBuilder(
                  animation: _entranceCtrl,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _textOpacity.value,
                      child: Transform.translate(
                        offset: _textSlide.value * 30,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // App Title
                      Text(
                        'MaizeGuard',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Tagline Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldBase.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.emeraldBase.withValues(alpha: 0.32),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.eco_rounded,
                              size: 13,
                              color: AppColors.emeraldLight,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'AI CROP DIAGNOSTICS & HEALTH',
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                                color: AppColors.emeraldLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 42),

                // Dynamic Status Capsule & Micro Progress Bar
                AnimatedBuilder(
                  animation: _entranceCtrl,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _progressOpacity.value,
                      child: child,
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Status Capsule
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_progress >= 1.0)
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: AppColors.emeraldLight,
                              )
                            else
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.8,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.emeraldLight,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 9),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                _statusMessage,
                                key: ValueKey(_statusMessage),
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.88),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Sleek Micro Progress Track
                      SizedBox(
                        width: 164,
                        height: 3.5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Stack(
                            children: [
                              Container(
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                              AnimatedFractionallySizedBox(
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.centerLeft,
                                widthFactor: _progress.clamp(0.06, 1.0),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.emeraldDark,
                                        AppColors.emeraldLight,
                                        AppColors.harvestGold,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 4),

                // ── Footer Metadata ──────────────────────────────────────────
                AnimatedBuilder(
                  animation: _entranceCtrl,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _footerOpacity.value,
                      child: child,
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(bottom: 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.memory_rounded,
                              size: 12,
                              color: Colors.white38,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'ON-DEVICE NEURAL INFERENCE',
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: Colors.white38,
                              ),
                            ),
                            SizedBox(width: 8),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white24,
                              ),
                              child: SizedBox(width: 3, height: 3),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'OFFLINE FIRST',
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: Colors.white38,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 5),
                        Text(
                          'v1.0.0 • MobileNetV3 Quantized',
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 10,
                            color: Colors.white24,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter rendering ambient agricultural telemetry range rings and micro-ticks.
class _AgriAtmospherePainter extends CustomPainter {
  final double pulseValue;

  const _AgriAtmospherePainter({required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.38);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Outer subtle sensor ring
    ringPaint.color = AppColors.emeraldBase.withValues(
      alpha: 0.05 + 0.03 * pulseValue,
    );
    canvas.drawCircle(center, 185 + 5 * pulseValue, ringPaint);

    // Middle telemetry ring
    ringPaint.color = AppColors.emeraldLight.withValues(
      alpha: 0.08 + 0.04 * pulseValue,
    );
    canvas.drawCircle(center, 134 + 3 * pulseValue, ringPaint);

    // Fine radial tick marks on middle telemetry ring
    final tickPaint = Paint()
      ..color = AppColors.maizeGold.withValues(alpha: 0.16 + 0.08 * pulseValue)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    const tickCount = 8;
    for (int i = 0; i < tickCount; i++) {
      final angle = (i * 2 * math.pi / tickCount) + (pulseValue * 0.08);
      final r1 = 130.0 + 3 * pulseValue;
      final r2 = 136.0 + 3 * pulseValue;
      final p1 = Offset(
        center.dx + r1 * math.cos(angle),
        center.dy + r1 * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + r2 * math.cos(angle),
        center.dy + r2 * math.sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AgriAtmospherePainter oldDelegate) =>
      oldDelegate.pulseValue != pulseValue;
}
