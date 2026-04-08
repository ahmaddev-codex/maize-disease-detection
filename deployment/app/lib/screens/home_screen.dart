import 'dart:io';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import '../services/classifier.dart';
import '../services/ocr_service.dart';
import 'camera_screen.dart';
import 'result_screen.dart';
import 'ocr_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MaizeClassifier _classifier = MaizeClassifier();
  // Only instantiate OcrService on Android/iOS — ML Kit has no macOS support.
  OcrService? _ocrService;

  _ModelState _modelState = _ModelState.loading;
  String?     _modelError;

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    setState(() {
      _modelState = _ModelState.loading;
      _modelError = null;
    });
    try {
      await _classifier.init();
      if (mounted) setState(() => _modelState = _ModelState.ready);
    } catch (e) {
      if (mounted) {
        setState(() {
          _modelState = _ModelState.error;
          _modelError = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _classifier.dispose();
    _ocrService?.dispose();
    super.dispose();
  }

  // ── Navigation ───────────────────────────────────────────────────────────────

  void _openCamera() {
    if (_modelState != _ModelState.ready) return;
    if (!_cameraSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live camera is only available on Android and iOS.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          classifier: _classifier,
          onImageCaptured: _classifyAndNavigate,
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    if (_modelState != _ModelState.ready) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;
    _classifyAndNavigate(File(picked.path));
  }

  // camera package only ships an implementation for Android, iOS, and web.
  // On macOS/desktop the plugin is not registered and availableCameras() throws.
  bool get _cameraSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  bool get _ocrSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  void _openOcrCapture() {
    if (!_ocrSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OCR is only available on Android and iOS.'),
        ),
      );
      return;
    }
    // Lazy-init OcrService only when actually needed on a supported platform.
    _ocrService ??= OcrService();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OcrScreen(ocrService: _ocrService!)),
    );
  }

  Future<void> _classifyAndNavigate(File imageFile) async {
    if (!mounted) return;

    // Show loading modal
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _InferenceDialog(),
    );

    try {
      final prediction = await _classifier.classify(imageFile);
      if (!mounted) return;
      Navigator.pop(context); // dismiss loader
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            imageFile: imageFile,
            prediction: prediction,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Inference failed: $e')),
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GhC.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(),
            const GhDivider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRepoHeader(),
                    const SizedBox(height: 16),
                    _buildModelStatusCard(),
                    const SizedBox(height: 20),
                    _buildSectionLabel('Leaf analysis'),
                    const SizedBox(height: 8),
                    _buildActionList(),
                    const SizedBox(height: 20),
                    _buildSectionLabel('Seed records'),
                    const SizedBox(height: 8),
                    _buildOcrCard(),
                    const SizedBox(height: 24),
                    _buildInfoGrid(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Sub-builders ─────────────────────────────────────────────────────────────

  Widget _buildNavBar() {
    return Container(
      color: GhC.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: GhC.successEmphasis,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          const Text(
            'ahmaddev-codex / maizeguard',
            style: TextStyle(
              color: GhC.fg,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: GhC.mono,
            ),
          ),
          const Spacer(),
          GhLabel(
            'v1.0',
            color: GhC.accentEmphasis,
            fontSize: 11,
          ),
        ],
      ),
    );
  }

  Widget _buildRepoHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MaizeGuard',
          style: TextStyle(
            color: GhC.fg,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'On-device maize disease detection for Nigerian smallholder farmers. '
          'EfficientNetB3 · TFLite INT8 · fully offline.',
          style: TextStyle(color: GhC.fgMuted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: const [
            GhLabel('machine-learning',  color: GhC.accentEmphasis),
            GhLabel('agriculture',       color: GhC.successEmphasis),
            GhLabel('nigeria',           color: GhC.attentionEmph),
            GhLabel('tflite',            color: GhC.fgSubtle),
          ],
        ),
      ],
    );
  }

  Widget _buildModelStatusCard() {
    return Container(
      decoration: GhBox.card(
        highlight: _modelState == _ModelState.ready,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _modelStateIcon(),
                const SizedBox(width: 12),
                Expanded(child: _modelStateText()),
                if (_modelState == _ModelState.error)
                  GhButtonOutline(
                    'Retry',
                    small: true,
                    icon: Icons.refresh_rounded,
                    onTap: _initModel,
                  ),
              ],
            ),
          ),
          if (_modelState == _ModelState.loading)
            const LinearProgressIndicator(
              backgroundColor: GhC.subtle,
              color: GhC.accentEmphasis,
              minHeight: 2,
            ),
          if (_modelError != null) ...[
            const GhDivider(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              child: Text(
                _modelError!,
                style: const TextStyle(
                  color: GhC.danger,
                  fontSize: 11,
                  fontFamily: GhC.mono,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _modelStateIcon() {
    return switch (_modelState) {
      _ModelState.loading => const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2, color: GhC.accentEmphasis,
          ),
        ),
      _ModelState.ready => const Icon(
          Icons.check_circle_rounded, color: GhC.success, size: 18,
        ),
      _ModelState.error => const Icon(
          Icons.error_rounded, color: GhC.danger, size: 18,
        ),
    };
  }

  Widget _modelStateText() {
    return switch (_modelState) {
      _ModelState.loading => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Loading model…', style: TextStyle(color: GhC.fg, fontSize: 13, fontWeight: FontWeight.w600)),
            Text('EfficientNetB3 · INT8 quantized', style: TextStyle(color: GhC.fgMuted, fontSize: 11)),
          ],
        ),
      _ModelState.ready => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Model ready', style: TextStyle(color: GhC.success, fontSize: 13, fontWeight: FontWeight.w600)),
            Text(
              _classifier.activeModel.contains('int8') ? 'EfficientNetB3 · INT8 · on-device' : 'EfficientNetB3 · FP16 · on-device',
              style: const TextStyle(color: GhC.fgMuted, fontSize: 11),
            ),
          ],
        ),
      _ModelState.error => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Model failed to load', style: TextStyle(color: GhC.danger, fontSize: 13, fontWeight: FontWeight.w600)),
            Text('See error details below', style: TextStyle(color: GhC.fgMuted, fontSize: 11)),
          ],
        ),
    };
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: GhC.fgSubtle,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildActionList() {
    final ready = _modelState == _ModelState.ready;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: GhC.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          _ActionItem(
            icon: Icons.camera_alt_rounded,
            iconColor: GhC.success,
            title: 'Open Camera',
            subtitle: _cameraSupported
                ? 'Capture a maize leaf for instant diagnosis'
                : 'Camera not available on this platform — use Gallery',
            badge: _cameraSupported ? 'Camera' : 'Mobile only',
            badgeColor: _cameraSupported ? GhC.success : GhC.fgSubtle,
            enabled: ready && _cameraSupported,
            onTap: _openCamera,
            isFirst: true,
          ),
          const GhDivider(),
          _ActionItem(
            icon: Icons.photo_library_rounded,
            iconColor: GhC.accent,
            title: 'Choose from Gallery',
            subtitle: 'Select an existing photo for analysis',
            badge: 'Gallery',
            badgeColor: GhC.accent,
            enabled: ready,
            onTap: _pickFromGallery,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildOcrCard() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: GhC.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: _ActionItem(
        icon: Icons.document_scanner_rounded,
        iconColor: GhC.attention,
        title: 'Scan Seed Label',
        subtitle: _ocrSupported
            ? 'Extract variety, batch & planting date via ML Kit OCR'
            : 'Available on Android & iOS only',
        badge: _ocrSupported ? 'OCR' : 'Mobile only',
        badgeColor: _ocrSupported ? GhC.attention : GhC.fgSubtle,
        enabled: true,
        onTap: _openOcrCapture,
        isFirst: true,
        isLast: true,
      ),
    );
  }

  Widget _buildInfoGrid() {
    return Container(
      decoration: GhBox.subtle(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('About', style: GhText.h3),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.hub_rounded,      label: 'Architecture', value: 'EfficientNetB3 + OCR fusion'),
          _InfoRow(icon: Icons.dataset_rounded,  label: 'Dataset',      value: 'PlantVillage · 4,188 images'),
          _InfoRow(icon: Icons.category_rounded, label: 'Classes',      value: 'NCLB · Rust · GLS · Healthy'),
          _InfoRow(icon: Icons.wifi_off_rounded, label: 'Inference',    value: '100% on-device · no internet'),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: GhC.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, color: GhC.fgSubtle, size: 12),
          const SizedBox(width: 6),
          const Text(
            'All inference on-device · No data leaves your phone',
            style: TextStyle(color: GhC.fgSubtle, fontSize: 11),
          ),
          const Spacer(),
          Text(
            'Build ${DateTime.now().year}',
            style: const TextStyle(color: GhC.fgSubtle, fontSize: 11, fontFamily: GhC.mono),
          ),
        ],
      ),
    );
  }
}

// ── Action list item ──────────────────────────────────────────────────────────

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final bool enabled;
  final VoidCallback? onTap;
  final bool isFirst;
  final bool isLast;

  const _ActionItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.enabled,
    this.onTap,
    this.isFirst = false,
    this.isLast  = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          decoration: BoxDecoration(
            color: GhC.surface,
            borderRadius: BorderRadius.vertical(
              top:    Radius.circular(isFirst ? 5 : 0),
              bottom: Radius.circular(isLast  ? 5 : 0),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: iconColor.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: iconColor, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(
                      color: GhC.fg, fontSize: 14, fontWeight: FontWeight.w600,
                    )),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(
                      color: GhC.fgMuted, fontSize: 12,
                    )),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GhLabel(badge, color: badgeColor, fontSize: 10),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: GhC.fgSubtle, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: GhC.fgSubtle, size: 14),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: GhC.fgMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: GhC.fg, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ── Inference loading dialog ──────────────────────────────────────────────────

class _InferenceDialog extends StatelessWidget {
  const _InferenceDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.all(24),
        decoration: GhBox.card(),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: GhC.accentEmphasis, strokeWidth: 2),
            SizedBox(height: 16),
            Text('Running inference…', style: GhText.body),
            SizedBox(height: 4),
            Text('EfficientNetB3 · on-device', style: GhText.muted),
          ],
        ),
      ),
    );
  }
}

// ── Enum ─────────────────────────────────────────────────────────────────────

enum _ModelState { loading, ready, error }
