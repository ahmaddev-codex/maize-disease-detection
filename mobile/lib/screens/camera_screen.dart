import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../constants/colors.dart';
import '../services/path_resolver.dart';
import '../constants/diseases.dart';
import '../models/scan_record.dart';
import '../providers/app_provider.dart';
import '../services/classifier_service.dart';
import '../services/database_service.dart';
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

    // Live brightness feedback — throttled to avoid per-frame setState spam
    _controller!.startImageStream((image) {
      final luma = _estimateLuma(image);
      String? hint;
      if (luma < 60)       hint = 'Too dark — move to better light';
      else if (luma > 200) hint = 'Too bright — find some shade';
      if (hint != _brightnessHint) setState(() => _brightnessHint = hint);
    });
  }

  double _estimateLuma(CameraImage image) {
    // Sample every 10th pixel from the Y plane for speed
    final plane = image.planes[0];
    final bytes = plane.bytes;
    double sum = 0;
    int count = 0;
    for (int i = 0; i < bytes.length; i += 10) {
      sum += bytes[i];
      count++;
    }
    return count > 0 ? sum / count : 128;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller!.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _capture() async {
    if (_isCapturing || !(_controller?.value.isInitialized ?? false)) return;
    setState(() => _isCapturing = true);
    try {
      final file = await _controller!.takePicture();
      await _classify(file.path);
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    await _classify(picked.path);
  }

  // Copy the captured/picked image to the app's permanent documents directory
  // so it survives app restarts. Uses microseconds to avoid timestamp collisions.
  Future<String> _persistImage(String tempPath) async {
    final dir = Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'scans'),
    );
    await dir.create(recursive: true);
    final dest = File(
        p.join(dir.path, '${DateTime.now().microsecondsSinceEpoch}.jpg'));
    await File(tempPath).copy(dest.path);
    return dest.path;
  }

  Future<void> _classify(String tempPath) async {
    if (!mounted) return;
    final overlay = _showProcessing();
    try {
      final path     = await _persistImage(tempPath);
      final result   = await ClassifierService.instance.classify(path);
      final position = await LocationService.instance.getCurrentPosition();
      final pending  = ref.read(pendingOcrProvider);
      final disease  = diseaseForClass(result.classId);

      final record = ScanRecord(
        imagePath:    PathResolver.toRelative(path), // portable across reinstalls
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
      ref.read(lastImagePathProvider.notifier).state  = path;
      ref.read(lastScanVarietyProvider.notifier).state = pending?.cropVariety;
      ref.read(pendingOcrProvider.notifier).state      = null;
      await ref.read(scanListProvider.notifier).add(record);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Classification failed: $e')),
        );
      }
    } finally {
      overlay.remove();
      if (mounted) context.push('/result');
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
    // Stop the image stream before disposing to prevent memory accumulation
    if (_controller?.value.isStreamingImages == true) {
      _controller!.stopImageStream();
    }
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInit = _controller?.value.isInitialized ?? false;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // Camera preview
        if (isInit)
          Center(child: CameraPreview(_controller!))
        else
          const Center(child: CircularProgressIndicator()),

        // Frame guide
        if (isInit)
          Center(child: CustomPaint(
            size: const Size(280, 280),
            painter: _FramePainter(),
          )),

        // Brightness hint
        if (_brightnessHint != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.attentionFg.withOpacity(0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_brightnessHint!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black, fontSize: 13)),
            ),
          ),

        // Back button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),

        // Bottom controls
        Positioned(
          bottom: 48, left: 0, right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Gallery
              IconButton(
                icon: const Icon(Icons.photo_library_rounded,
                    color: Colors.white, size: 32),
                onPressed: _pickFromGallery,
              ),
              // Capture
              GestureDetector(
                onTap: _capture,
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    color: _isCapturing
                        ? AppColors.accentFg.withOpacity(0.8)
                        : Colors.white.withOpacity(0.15),
                  ),
                  child: _isCapturing
                      ? const Center(child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.camera, color: Colors.white, size: 32),
                ),
              ),
              // Flip camera (if multiple cameras)
              IconButton(
                icon: const Icon(Icons.flip_camera_ios_rounded,
                    color: Colors.white, size: 32),
                onPressed: _cameras.length > 1 ? () async {
                  final current = _controller!.description;
                  final next = _cameras.firstWhere(
                      (c) => c.lensDirection != current.lensDirection,
                      orElse: () => _cameras.first);
                  await _controller!.dispose();
                  _controller = CameraController(next, ResolutionPreset.high,
                      enableAudio: false);
                  await _controller!.initialize();
                  if (mounted) setState(() {});
                } : null,
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _FramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentFg
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const len = 30.0;
    final r = Rect.fromLTWH(0, 0, size.width, size.height);
    for (final (dx, dy) in [(r.left, r.top), (r.right, r.top),
                             (r.left, r.bottom), (r.right, r.bottom)]) {
      final sx = dx == r.left ? 1.0 : -1.0;
      final sy = dy == r.top  ? 1.0 : -1.0;
      canvas.drawLine(Offset(dx, dy), Offset(dx + sx * len, dy), paint);
      canvas.drawLine(Offset(dx, dy), Offset(dx, dy + sy * len), paint);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

class _ProcessingOverlay extends StatelessWidget {
  const _ProcessingOverlay();
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black54,
    child: const Center(child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: AppColors.accentFg),
        SizedBox(height: 16),
        Text('Analysing…', style: TextStyle(color: Colors.white, fontSize: 16)),
      ],
    )),
  );
}
