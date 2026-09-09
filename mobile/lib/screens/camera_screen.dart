import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../design_system/design_system.dart';
import '../services/path_resolver.dart';
import '../constants/diseases.dart';
import '../models/scan_record.dart';
import '../providers/app_provider.dart';
import '../services/classifier_service.dart';
import '../services/location_service.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});
  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCapturing = false;
  bool _isFlashOn = false;
  String? _brightnessHint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    _controller = CameraController(
      _cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});

    _startBrightnessStream();
  }

  void _startBrightnessStream() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isStreamingImages) return;

    // Live brightness feedback — sampled to avoid UI lag
    _controller!.startImageStream((image) {
      final luma = _estimateLuma(image);
      String? hint;
      if (luma < 55) {
        hint = 'Low light: move closer to daylight';
      } else if (luma > 215) {
        hint = 'Direct glare: shade leaf for accurate diagnosis';
      }
      if (hint != _brightnessHint && mounted) {
        setState(() => _brightnessHint = hint);
      }
    });
  }

  double _estimateLuma(CameraImage image) {
    if (image.planes.isEmpty) return 128;
    final plane = image.planes[0];
    final bytes = plane.bytes;
    double sum = 0;
    int count = 0;
    for (int i = 0; i < bytes.length; i += 12) {
      sum += bytes[i];
      count++;
    }
    return count > 0 ? sum / count : 128;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      if (_controller!.value.isStreamingImages) {
        _controller!.stopImageStream();
      }
      _controller!.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final next = !_isFlashOn;
      await _controller!.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      setState(() => _isFlashOn = next);
    } catch (_) {}
  }

  Future<void> _capture() async {
    if (_isCapturing || !(_controller?.value.isInitialized ?? false)) return;
    setState(() => _isCapturing = true);

    try {
      // Stop stream first to prevent Camera2 concurrent access lockup
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
      final file = await _controller!.takePicture();
      await _classify(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera capture error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
        _startBrightnessStream();
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    await _classify(picked.path);
  }

  Future<String> _persistImage(String tempPath) async {
    final dir = Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'scans'),
    );
    await dir.create(recursive: true);
    final dest = File(
      p.join(dir.path, '${DateTime.now().microsecondsSinceEpoch}.jpg'),
    );
    await File(tempPath).copy(dest.path);
    return dest.path;
  }

  Future<void> _classify(String tempPath) async {
    if (!mounted) return;
    final overlay = _showProcessing();
    bool success = false;

    try {
      final path     = await _persistImage(tempPath);
      final result   = await ClassifierService.instance.classify(path);
      final position = await LocationService.instance.getCurrentPosition();
      final pending  = ref.read(pendingOcrProvider);
      final disease  = diseaseForClass(result.classId);

      final record = ScanRecord(
        imagePath:    PathResolver.toRelative(path),
        classId:      result.classId,
        className:    disease.name,
        shortName:    disease.shortName,
        confidence:   result.confidence,
        allScores:    result.allScores,
        latencyMs:    result.latencyMs,
        latitude:     position?.latitude,
        longitude:    position?.longitude,
        cropVariety:  pending?.cropVariety,
        batchNumber:  pending?.batchNumber,
        plantingDate: pending?.plantingDate,
        scannedAt:    DateTime.now().toUtc(),
      );

      ref.read(lastResultProvider.notifier).state      = result;
      ref.read(lastImagePathProvider.notifier).state   = path;
      ref.read(lastScanVarietyProvider.notifier).state = pending?.cropVariety;
      ref.read(pendingOcrProvider.notifier).state      = null;

      final id = await ref.read(scanListProvider.notifier).add(record);
      ref.read(activeScanIdProvider.notifier).state = id;
      success = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Diagnosis failed: $e')),
        );
      }
    } finally {
      overlay.remove();
      if (mounted && success) {
        context.push('/result');
      }
    }
  }

  OverlayEntry _showProcessing() {
    final entry = OverlayEntry(builder: (_) => const _ProcessingOverlay());
    Overlay.of(context).insert(entry);
    return entry;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_controller?.value.isStreamingImages == true) {
      _controller!.stopImageStream();
    }
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInit = _controller?.value.isInitialized ?? false;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          if (isInit)
            Center(child: CameraPreview(_controller!))
          else
            const Center(
              child: CircularProgressIndicator(color: AppColors.emeraldBase),
            ),

          // High-precision Leaf Reticle
          if (isInit)
            Center(
              child: CustomPaint(
                size: const Size(280, 280),
                painter: _ReticlePainter(),
              ),
            ),

          // Top Action Header
          Positioned(
            top: topPadding + AppSpacing.sm,
            left: AppSpacing.md,
            right: AppSpacing.md,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _GlassIconButton(
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => context.pop(),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: AppRadii.full,
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const MaizeGuardLogo(size: 16, isDark: true),
                      const SizedBox(width: AppSpacing.xs + 2),
                      Text(
                        'ALIGN LEAF IN BOX',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                _GlassIconButton(
                  icon: _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  color: _isFlashOn ? AppColors.warning : Colors.white,
                  onPressed: _toggleFlash,
                ),
              ],
            ),
          ),

          // Dynamic Ambient Guidance Banner
          if (_brightnessHint != null)
            Positioned(
              top: topPadding + 64,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.charcoal900.withValues(alpha: 0.92),
                  borderRadius: AppRadii.md,
                  border: Border.all(
                    color: Colors.white24,
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline_rounded,
                      color: AppColors.warning,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _brightnessHint!,
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Grounded Control Dock
          Positioned(
            bottom: AppSpacing.xl,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Gallery import
                _DockButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onTap: _pickFromGallery,
                ),

                // Main capture trigger (Clean Pro Shutter Button)
                GestureDetector(
                  onTap: _capture,
                  child: Container(
                    width: 78,
                    height: 78,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 3.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x44000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isCapturing ? AppColors.emeraldDark : Colors.white,
                      ),
                      child: _isCapturing
                          ? const Center(
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            )
                          : const Center(
                              child: MaizeGuardLogo(
                                size: 34,
                                isDark: false,
                              ),
                            ),
                    ),
                  ),
                ),

                // Flip camera
                _DockButton(
                  icon: Icons.flip_camera_ios_outlined,
                  label: 'Flip',
                  onTap: _cameras.length > 1
                      ? () async {
                          final current = _controller!.description;
                          final next = _cameras.firstWhere(
                            (c) => c.lensDirection != current.lensDirection,
                            orElse: () => _cameras.first,
                          );
                          await _controller!.dispose();
                          _controller = CameraController(
                            next,
                            ResolutionPreset.high,
                            enableAudio: false,
                          );
                          await _controller!.initialize();
                          if (mounted) setState(() {});
                        }
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  const _GlassIconButton({
    required this.icon,
    this.onPressed,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white12),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _DockButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 32.0;
    final r = Rect.fromLTWH(0, 0, size.width, size.height);

    // 4 Corner Brackets
    // Top-Left
    canvas.drawLine(Offset(r.left, r.top), Offset(r.left + cornerLength, r.top), paint);
    canvas.drawLine(Offset(r.left, r.top), Offset(r.left, r.top + cornerLength), paint);

    // Top-Right
    canvas.drawLine(Offset(r.right, r.top), Offset(r.right - cornerLength, r.top), paint);
    canvas.drawLine(Offset(r.right, r.top), Offset(r.right, r.top + cornerLength), paint);

    // Bottom-Left
    canvas.drawLine(Offset(r.left, r.bottom), Offset(r.left + cornerLength, r.bottom), paint);
    canvas.drawLine(Offset(r.left, r.bottom), Offset(r.left, r.bottom - cornerLength), paint);

    // Bottom-Right
    canvas.drawLine(Offset(r.right, r.bottom), Offset(r.right - cornerLength, r.bottom), paint);
    canvas.drawLine(Offset(r.right, r.bottom), Offset(r.right, r.bottom - cornerLength), paint);

    // Subtle crosshair center mark
    final centerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(Offset(cx - 8, cy), Offset(cx + 8, cy), centerPaint);
    canvas.drawLine(Offset(cx, cy - 8), Offset(cx, cy + 8), centerPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _ProcessingOverlay extends StatelessWidget {
  const _ProcessingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: AppColors.charcoal900,
            borderRadius: AppRadii.lg,
            border: Border.all(color: Colors.white12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x88000000),
                blurRadius: 24,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 38,
                height: 38,
                child: CircularProgressIndicator(
                  color: AppColors.emeraldBase,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Analyzing Leaf Sample…',
                style: AppTypography.h3.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Running local Edge Neural Model',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.charcoal400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
