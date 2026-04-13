import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/app_theme.dart';
import '../services/classifier.dart';

/// Full-screen camera with leaf framing guide, brightness hints,
/// tap-to-focus, and lifecycle-safe controller management.
class CameraScreen extends StatefulWidget {
  final MaizeClassifier classifier;
  final void Function(File) onImageCaptured;

  const CameraScreen({
    super.key,
    required this.classifier,
    required this.onImageCaptured,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCapturing = false;
  bool _disposed    = false;
  String? _hint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    // The camera package does NOT auto-request permissions.
    final status = await Permission.camera.request();
    if (!mounted) return;

    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Camera permission denied.'),
          action: SnackBarAction(label: 'Settings', onPressed: openAppSettings),
        ),
      );
      Navigator.pop(context);
      return;
    }

    try {
      _cameras = await availableCameras();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
      return;
    }

    if (_cameras.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No camera found on this device.')),
        );
      }
      return;
    }

    final rear = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    _controller = CameraController(
      rear,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start camera: $e')),
        );
      }
      return;
    }

    if (!mounted) return;
    await _controller!.startImageStream(_onFrame);
    setState(() {});
  }

  int _frameCount = 0;

  void _onFrame(CameraImage frame) {
    if (_disposed) return;
    _frameCount++;
    if (_frameCount % 15 != 0) return;

    final bytes      = frame.planes[0].bytes;
    final step       = bytes.length ~/ 200;
    double sum       = 0;
    int count        = 0;
    for (int i = 0; i < bytes.length; i += step) {
      sum += bytes[i];
      count++;
    }
    final brightness = sum / count;

    String? hint;
    if (brightness < 50) {
      hint = 'Too dark — move to better lighting';
    } else if (brightness > 230) {
      hint = 'Too bright — avoid direct sunlight';
    }

    if (!_disposed && mounted && hint != _hint) {
      setState(() => _hint = hint);
    }
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      await _controller!.stopImageStream();
      final xFile = await _controller!.takePicture();
      if (!mounted) return;
      Navigator.pop(context);
      widget.onImageCaptured(File(xFile.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
        setState(() => _isCapturing = false);
        await _controller!.startImageStream(_onFrame);
      }
    }
  }

  void _onTapFocus(TapDownDetails details) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final size = MediaQuery.of(context).size;
    final offset = Offset(
      details.localPosition.dx / size.width,
      details.localPosition.dy / size.height,
    );
    _controller!.setFocusPoint(offset);
    _controller!.setExposurePoint(offset);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final ctrl = _controller;
      _controller = null;
      ctrl?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller?.value.isInitialized ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      body: ready
          ? _buildCameraView()
          : _buildLoadingView(),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: GhC.success, strokeWidth: 2),
          SizedBox(height: 16),
          Text('Starting camera…',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview — tap to focus
        GestureDetector(
          onTapDown: _onTapFocus,
          child: CameraPreview(_controller!),
        ),

        // Dimmed overlay with transparent viewfinder cutout
        _ViewfinderOverlay(),

        // Brightness hint
        if (_hint != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 64,
            left: 16, right: 16,
            child: _HintBanner(text: _hint!),
          ),

        // Top bar
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: _TopBar(onBack: () => Navigator.pop(context)),
          ),
        ),

        // Instructions
        Positioned(
          bottom: 136,
          left: 0, right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: const Text(
                'Tap to focus · Fill the frame with one leaf',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ),

        // Capture button
        Positioned(
          bottom: 48,
          left: 0, right: 0,
          child: Center(
            child: _CaptureButton(
              isCapturing: _isCapturing,
              onTap: _capture,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Overlay: dimmed surround + cutout viewfinder ──────────────────────────────

class _ViewfinderOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size      = MediaQuery.of(context).size;
    final frameSize = size.width * 0.78;

    return Stack(
      children: [
        // Dimmed surround with punch-through hole
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.5),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(color: Colors.transparent),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: Container(
                    width: frameSize,
                    height: frameSize,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Green corner markers
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: SizedBox(
              width: frameSize,
              height: frameSize,
              child: CustomPaint(painter: _CornerPainter()),
            ),
          ),
        ),
      ],
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = GhC.success
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 22.0;
    const r   = 8.0;

    // Top-left
    canvas.drawLine(const Offset(r, 0), const Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, r), const Offset(0, len), paint);
    canvas.drawArc(const Rect.fromLTWH(0, 0, r * 2, r * 2), -3.14, 1.57, false, paint);
    // Top-right
    canvas.drawLine(Offset(size.width - len, 0), Offset(size.width - r, 0), paint);
    canvas.drawLine(Offset(size.width, r), Offset(size.width, len), paint);
    canvas.drawArc(Rect.fromLTWH(size.width - r * 2, 0, r * 2, r * 2), -1.57, 1.57, false, paint);
    // Bottom-left
    canvas.drawLine(Offset(0, size.height - len), Offset(0, size.height - r), paint);
    canvas.drawLine(Offset(r, size.height), Offset(len, size.height), paint);
    canvas.drawArc(Rect.fromLTWH(0, size.height - r * 2, r * 2, r * 2), 1.57, 1.57, false, paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height - len), Offset(size.width, size.height - r), paint);
    canvas.drawLine(Offset(size.width - len, size.height), Offset(size.width - r, size.height), paint);
    canvas.drawArc(Rect.fromLTWH(size.width - r * 2, size.height - r * 2, r * 2, r * 2), 0, 1.57, false, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: GhC.success.withValues(alpha: 0.6)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.eco_rounded, color: GhC.success, size: 12),
                SizedBox(width: 5),
                Text(
                  'MaizeGuard · Camera',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ── Hint banner ───────────────────────────────────────────────────────────────

class _HintBanner extends StatelessWidget {
  final String text;
  const _HintBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: GhC.attentionEmph.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 15),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── Capture button ────────────────────────────────────────────────────────────

class _CaptureButton extends StatelessWidget {
  final bool isCapturing;
  final VoidCallback onTap;
  const _CaptureButton({required this.isCapturing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isCapturing ? null : onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: 74, height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: GhC.success, width: 2.5),
            ),
          ),
          // Inner fill
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: isCapturing ? 44 : 58,
            height: isCapturing ? 44 : 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCapturing ? Colors.transparent : GhC.success,
            ),
            child: isCapturing
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: GhC.success,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
