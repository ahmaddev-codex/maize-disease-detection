import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../design_system/design_system.dart';
import '../navigation/open_scan.dart';
import '../providers/app_provider.dart';
import '../providers/service_providers.dart';
import '../services/crop_geometry.dart';
import '../services/luma.dart';
import '../services/scan_flow.dart';
import '../services/yarn_tts_service.dart';

/// Side of the on-screen alignment box, in logical pixels. The painter and the
/// crop geometry must agree on it, so it lives in one place (T19).
const double kReticleSide = 280;

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
  String? _cameraError;
  bool _initializing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  /// takePicture always writes a JPEG file; the format group only decides what
  /// the preview stream delivers, and luma needs a real one (T20).
  CameraController _newController(CameraDescription description) => CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
      );

  /// Stops the stream, then hands the camera back to the OS.
  Future<void> _releaseController(CameraController controller) async {
    try {
      if (controller.value.isStreamingImages) await controller.stopImageStream();
    } catch (e) {
      debugPrint('[Camera] stream stop failed: $e');
    }
    await controller.dispose();
  }

  Future<void> _initCamera() async {
    if (_initializing) return;
    _initializing = true;
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _cameraError = 'No camera found on this device.');
        return;
      }
      final controller = _newController(_cameras.first);
      await controller.initialize();
      if (!mounted) {
        await _releaseController(controller);
        return;
      }
      setState(() {
        _controller = controller;
        _cameraError = null;
      });

      _startBrightnessStream();
    } catch (e) {
      debugPrint('[Camera] unavailable: $e');
      if (mounted) setState(() => _cameraError = 'Camera unavailable. Use Gallery to pick a photo.');
    } finally {
      _initializing = false;
    }
  }

  void _startBrightnessStream() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isStreamingImages) return;

    // Live brightness feedback — sampled to avoid UI lag
    _controller!.startImageStream((image) {
      final hint = lightingHint(lightingFrom(_lumaOf(image)));
      if (hint != _brightnessHint && mounted) {
        setState(() => _brightnessHint = hint);
      }
    });
  }

  Future<void> _stopBrightnessStream() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (!controller.value.isStreamingImages) return;
    try {
      await controller.stopImageStream();
    } catch (e) {
      debugPrint('[Camera] stream stop failed: $e');
    }
  }

  /// 128 (mid-grey) for a layout we cannot read, so no false hint is shown.
  double _lumaOf(CameraImage image) {
    if (image.planes.isEmpty) return 128;
    final plane = image.planes.first;
    return switch (image.format.group) {
      ImageFormatGroup.yuv420 => lumaFromYPlane(
          plane.bytes,
          width: image.width,
          height: image.height,
          bytesPerRow: plane.bytesPerRow,
        ),
      ImageFormatGroup.bgra8888 => lumaFromBgra(
          plane.bytes,
          width: image.width,
          height: image.height,
          bytesPerRow: plane.bytesPerRow,
        ),
      _ => 128,
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      final controller = _controller;
      if (controller == null) return;
      // Cleared first: the build must never touch a controller being disposed.
      setState(() => _controller = null);
      unawaited(_releaseController(controller));
    } else if (state == AppLifecycleState.resumed) {
      if (_controller == null) _initCamera();
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
      await _classify(file.path, fromCamera: true);
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

  Future<void> _classify(String tempPath, {bool fromCamera = false}) async {
    if (!mounted) return;
    // Read before any await: the crop needs the preview area off the screen.
    final previewArea = MediaQuery.of(context).size;
    // Stop any audio from a previous scan result to prevent stale playback
    YarnTtsService.instance.stop();
    final overlay = _showProcessing();
    int? scanId;
    String? persistedPath;

    try {
      final path   = await _persistImage(tempPath);
      persistedPath = path;
      if (fromCamera && ref.read(cropToReticleProvider)) {
        await _cropToReticle(path, previewArea);
      }
      final result = await ref.read(classifierServiceProvider).classify(path);

      // Saved and shown straight away; the GPS fix follows in the background (T18).
      final saved = await saveScan(
        imagePath: path,
        result: result,
        pending: ref.read(pendingOcrProvider),
        scans: ref.read(scanListProvider.notifier),
        location: ref.read(locationServiceProvider),
        db: ref.read(databaseServiceProvider),
      );
      ref.read(pendingOcrProvider.notifier).state = null;
      scanId = saved.id;
    } catch (e) {
      // No record was saved, so the copied photo would be an orphan (T21).
      if (persistedPath != null) {
        await ref.read(scanStorageProvider).deleteImage(persistedPath);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Diagnosis failed: $e')),
        );
      }
    } finally {
      overlay.remove();
      if (mounted && scanId != null) {
        await _stopBrightnessStream();
        if (mounted) {
          await openScan(context, ref, scanId);
          if (mounted) _startBrightnessStream();
        }
      }
    }
  }

  /// Keeps only what the box framed. A failure leaves the full capture in
  /// place: a whole-frame diagnosis beats no diagnosis.
  Future<void> _cropToReticle(String path, Size previewArea) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final width = previewArea.width;
      final height = previewArea.height;
      final cropped = await Isolate.run(
        () => cropJpegToReticle(
          bytes,
          previewArea: Size(width, height),
          reticleSide: kReticleSide,
        ),
      );
      if (cropped != null) await file.writeAsBytes(cropped, flush: true);
    } catch (e) {
      debugPrint('[Camera] reticle crop skipped: $e');
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
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(_releaseController(controller));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInit = _controller?.value.isInitialized ?? false;
    final topPadding = MediaQuery.of(context).padding.top;
    final pendingSeedLabel = ref.watch(pendingOcrProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          if (isInit)
            Center(child: CameraPreview(_controller!))
          else if (_cameraError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  _cameraError!,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: AppColors.emeraldBase),
            ),

          // High-precision Leaf Reticle
          if (isInit)
            Center(
              child: CustomPaint(
                size: const Size.square(kReticleSide),
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

          // Seed label that will be attached to the next scan (T23)
          if (pendingSeedLabel != null)
            Positioned(
              top: topPadding + 64,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.forestDark.withValues(alpha: 0.92),
                  borderRadius: AppRadii.md,
                  border: Border.all(color: AppColors.emeraldBase.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_rounded, size: 16, color: AppColors.emeraldBase),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Seed label linked: ${pendingSeedLabel.cropVariety ?? pendingSeedLabel.batchNumber ?? 'details only'}',
                        style: AppTypography.caption.copyWith(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      key: const Key('camera-clear-seed-label'),
                      onPressed: () => ref.read(pendingOcrProvider.notifier).state = null,
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
            ),

          // Dynamic Ambient Guidance Banner
          if (_brightnessHint != null)
            Positioned(
              top: topPadding + (pendingSeedLabel != null ? 118 : 64),
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
                          final previous = _controller;
                          if (previous == null) return;
                          final next = _cameras.firstWhere(
                            (c) => c.lensDirection != previous.description.lensDirection,
                            orElse: () => _cameras.first,
                          );
                          setState(() => _controller = null);
                          await _releaseController(previous);
                          final replacement = _newController(next);
                          await replacement.initialize();
                          if (!mounted) {
                            await _releaseController(replacement);
                            return;
                          }
                          setState(() => _controller = replacement);
                          _startBrightnessStream();
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
