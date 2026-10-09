import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../design_system/design_system.dart';
import '../providers/app_provider.dart';
import '../providers/classifier_state.dart';

/// Tactile, editorial splash screen for MaizeGuard.
///
/// Crafted in a clean, human aesthetic inspired by modern editorial iOS apps:
/// warm paper canvas (no grid lines), tactile folder/badge hero cards,
/// bold character-rich typography, playful candy-colored status bubbles,
/// and a floating action dock.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _springCtrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _cardScale;
  late final Animation<double> _cardSlide;
  late final Animation<double> _titleFade;
  late final Animation<double> _bubbleFade;
  late final Animation<double> _dockSlide;

  double _progress = 0.20;
  String _statusMessage = 'Warming up on-device neural engine...';

  @override
  void initState() {
    super.initState();

    // Physical spring entrance controller
    _springCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Subtle tactile card breathing pulse
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _cardScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _springCtrl,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _cardSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _springCtrl,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _springCtrl,
        curve: const Interval(0.25, 0.70, curve: Curves.easeOut),
      ),
    );

    _bubbleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _springCtrl,
        curve: const Interval(0.40, 0.85, curve: Curves.easeOut),
      ),
    );

    _dockSlide = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _springCtrl,
        curve: const Interval(0.50, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _springCtrl.forward();
    _startInitialization();
  }

  @override
  void dispose() {
    _springCtrl.dispose();
    _pulseCtrl.dispose();
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

    // Stage 1: Runtime ready
    _setProgress(0.25, 'Warming up on-device neural engine...');

    // Stage 2: Load quantized TFLite model weights
    await Future.delayed(const Duration(milliseconds: 180));
    _setProgress(0.55, 'Loading MobileNetV3 INT8 model...');
    await ref.read(classifierStateProvider.notifier).load();

    // Stage 3: Sync farm scans
    _setProgress(0.80, 'Syncing crop health records...');
    try {
      await ref.read(scanListProvider.notifier).load();
    } catch (e) {
      debugPrint('[Splash] Database load notice: $e');
    }

    // Minimum display duration for a calm, premium tactile feel (2.0s)
    const minDurationMs = 2000;
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < minDurationMs) {
      await Future.delayed(Duration(milliseconds: minDurationMs - elapsed));
    }

    // Stage 4: Ready
    _setProgress(1.0, 'Diagnostic engine ready');
    await Future.delayed(const Duration(milliseconds: 260));

    if (!mounted) return;

    try {
      context.go('/');
    } catch (_) {
      // Fallback for isolated widget test environments
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canvasBg = isDark ? AppColors.obsidianDark : AppColors.paperCream;
    final inkText = isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimary;
    final inkMutedText = isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondary;

    return Scaffold(
      backgroundColor: canvasBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // ── Top Metadata Bar (Season & Mode Pill) ─────────────────────
              FadeTransition(
                opacity: _titleFade,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.folderGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Season '26 • Agro-Defense",
                          style: AppTypography.caption.copyWith(
                            color: inkMutedText,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.obsidianSurface
                            : AppColors.paperSurface,
                        borderRadius: AppRadii.full,
                        border: Border.all(
                          color: isDark
                              ? AppColors.obsidianBorder
                              : AppColors.paperBorder,
                          width: 1,
                        ),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Text(
                        'OFFLINE FIRST',
                        style: AppTypography.overline.copyWith(
                          color: AppColors.folderYellow,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // ── Hero Section: Tactile Card + Brand Identity ────────────────
              AnimatedBuilder(
                animation: Listenable.merge([_springCtrl, _pulseCtrl]),
                builder: (context, child) {
                  final scale = _cardScale.value * (1.0 + 0.015 * _pulseCtrl.value);
                  return Transform.translate(
                    offset: Offset(0, _cardSlide.value),
                    child: Transform.scale(
                      scale: scale,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: 136,
                  height: 136,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.folderDark : AppColors.primary,
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                      color: isDark
                          ? AppColors.obsidianBorder
                          : AppColors.emeraldLight.withValues(alpha: 0.35),
                      width: 2.0,
                    ),
                    boxShadow: AppColors.elevatedShadow,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Subtle corner grain/leaf accent
                      Positioned(
                        top: 12,
                        right: 14,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.folderYellow,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const MaizeGuardLogo(
                        size: 74,
                        isDark: true,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Editorial Brand Typography ─────────────────────────────────
              FadeTransition(
                opacity: _titleFade,
                child: Column(
                  children: [
                    Text(
                      'MaizeGuard',
                      style: AppTypography.displayLarge.copyWith(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                        color: inkText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.folderGreenLight,
                        borderRadius: AppRadii.full,
                      ),
                      child: const Text(
                        'AI CROP DIAGNOSTICS & HEALTH',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 34),

              // ── Tactile Status Bubble (Candy Pill Card) ────────────────────
              FadeTransition(
                opacity: _bubbleFade,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _progress >= 1.0
                        ? AppColors.folderGreen
                        : AppColors.folderYellow,
                    borderRadius: AppRadii.bubble,
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: _progress >= 1.0
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: AppColors.folderGreen,
                                )
                              : const SizedBox(
                                  width: 13,
                                  height: 13,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.folderYellow,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            _statusMessage,
                            key: ValueKey(_statusMessage),
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // ── Bottom Floating Pill Dock (From Reference Screen 2 & 3) ─────
              Transform.translate(
                offset: Offset(0, _dockSlide.value),
                child: FadeTransition(
                  opacity: _bubbleFade,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.obsidianSurface
                          : AppColors.paperSurface,
                      borderRadius: AppRadii.dock,
                      border: Border.all(
                        color: isDark
                            ? AppColors.obsidianBorder
                            : AppColors.paperBorder,
                        width: 1.0,
                      ),
                      boxShadow: AppColors.dockShadow,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left Pill Tag
                        Row(
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 14,
                              color: inkMutedText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ON-DEVICE NEURAL INFERENCE',
                              style: AppTypography.overline.copyWith(
                                color: inkMutedText,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),

                        // Center Micro Progress Line
                        SizedBox(
                          width: 46,
                          height: 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: Stack(
                              children: [
                                Container(
                                  color: isDark
                                      ? Colors.white12
                                      : const Color(0xFFE5E7EB),
                                ),
                                AnimatedFractionallySizedBox(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _progress.clamp(0.08, 1.0),
                                  child: Container(
                                    color: _progress >= 1.0
                                        ? AppColors.folderGreen
                                        : AppColors.folderYellow,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Right Model Version Badge
                        Text(
                          'v1.0.0 • MobileNetV3 Quantized',
                          style: AppTypography.caption.copyWith(
                            color: inkMutedText,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
