import 'dart:io';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/prediction.dart';
import '../theme/app_theme.dart';
import '../services/classifier.dart';
import '../services/database.dart';
import '../services/location_service.dart';
import '../services/ocr_service.dart';
import 'camera_screen.dart';
import 'result_screen.dart';
import 'ocr_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MaizeClassifier _classifier = MaizeClassifier();
  OcrService? _ocrService;

  _ModelState _modelState = _ModelState.loading;
  String? _modelError;

  /// Seed label data pending attachment to the next scan.
  SeedLabelData? _pendingLabel;

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

  // ── Platform flags ───────────────────────────────────────────────────────────

  bool get _liveCamera =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  bool get _nativeOcr =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  // ── Navigation ───────────────────────────────────────────────────────────────

  void _openCamera() {
    if (_modelState != _ModelState.ready) return;
    if (!_liveCamera) {
      _pickFromGallery();
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

  Future<void> _openOcrCapture() async {
    if (!_nativeOcr) {
      await _showManualLabelEntry();
      return;
    }
    _ocrService ??= OcrService();
    final result = await Navigator.push<SeedLabelData>(
      context,
      MaterialPageRoute(
        builder: (_) => OcrScreen(
          ocrService: _ocrService!,
          onDataSaved: (data) => Navigator.pop(context, data),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _pendingLabel = result);
      _showLabelSnackbar(result);
    }
  }

  void _showLabelSnackbar(SeedLabelData result) {
    final parts = [
      if (result.cropVariety != null) result.cropVariety!,
      if (result.batchNumber != null) result.batchNumber!,
      if (result.plantingDate != null) result.plantingDate!,
    ];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Label saved: ${parts.join(' · ')}'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showManualLabelEntry() async {
    final c = context.gc;
    // Capture colors before the async gap — the bottom sheet builder must not
    // call context.gc / Theme.of because those register InheritedWidget deps
    // on the sheet's element and cause _dependents.isEmpty on dismiss.
    final result = await showModalBottomSheet<SeedLabelData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: c.border),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return MediaQuery(
          data: MediaQuery.of(ctx).copyWith(viewInsets: EdgeInsets.zero),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottom),
            child: _ManualLabelSheet(c: c),
          ),
        );
      },
    );

    if (result != null && mounted) {
      setState(() => _pendingLabel = result);
      final parts = [
        if (result.cropVariety != null) result.cropVariety!,
        if (result.batchNumber != null) result.batchNumber!,
        if (result.plantingDate != null) result.plantingDate!,
      ];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Label saved: ${parts.join(' · ')}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Copies [src] into the persistent scans directory and returns:
  ///   - the saved [File] (for immediate display in ResultScreen), and
  ///   - a relative path string (for storage in the database).
  ///
  /// Storing a relative path (e.g. `scans/filename.jpg`) instead of the full
  /// absolute path means the record survives iOS app-container UUID changes
  /// that happen on reinstall / `flutter run`.
  Future<(File, String)> _persistImage(File src) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final scansDir = Directory('${docsDir.path}/scans');
    if (!scansDir.existsSync()) scansDir.createSync(recursive: true);
    final ext = src.path.contains('.') ? src.path.split('.').last : 'jpg';
    final name = 'scan_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final savedFile = await src.copy('${scansDir.path}/$name');
    return (savedFile, 'scans/$name');
  }

  Future<void> _classifyAndNavigate(File imageFile) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _InferenceDialog(),
    );

    try {
      // Run persist + classify + location in parallel.
      final persistFuture = _persistImage(imageFile);
      final classifyFuture = _classifier.classify(imageFile);
      final locationFuture = LocationService.currentPosition();

      final (savedImage, relativePath) = await persistFuture;
      final prediction = await classifyFuture;
      final position = await locationFuture;

      if (!mounted) return;

      final label = _pendingLabel;
      final entry = buildScanEntry(
        imagePath: relativePath, // relative → survives reinstalls on iOS
        classId: prediction.classId,
        className: prediction.className,
        shortName: prediction.shortName,
        confidence: prediction.confidence,
        allScores: prediction.allScores,
        latencyMs: prediction.latencyMs,
        latitude: position?.latitude,
        longitude: position?.longitude,
        cropVariety: label?.cropVariety,
        batchNumber: label?.batchNumber,
        plantingDate: label?.plantingDate,
      );
      await AppDatabase.instance.scanDao.insertScan(entry);
      if (mounted) setState(() => _pendingLabel = null);

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            imageFile: savedImage,
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
    final c = context.gc;
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            decoration: BoxDecoration(
              color: GhC.successEmphasis,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 17),
          ),
        ),
        title: const Text('MaizeGuard'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_rounded, color: c.fgMuted, size: 22),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedEntry(delayMs: 0, child: _buildHeroCard(c)),
            const SizedBox(height: 28),
            _buildSectionLabel(c, 'Scan a leaf'),
            const SizedBox(height: 10),
            AnimatedEntry(
              delayMs: 60,
              child: _buildActionCard(
                c: c,
                icon: Icons.camera_alt_rounded,
                color: GhC.successEmphasis,
                title: _liveCamera ? 'Open Camera' : 'Choose Image',
                subtitle: _liveCamera
                    ? 'Capture a maize leaf for instant diagnosis'
                    : 'Select a photo from your file system',
                enabled: _modelState == _ModelState.ready,
                onTap: _openCamera,
              ),
            ),
            const SizedBox(height: 10),
            AnimatedEntry(
              delayMs: 100,
              child: _buildActionCard(
                c: c,
                icon: Icons.photo_library_rounded,
                color: GhC.accentEmphasis,
                title: 'Choose from Gallery',
                subtitle: 'Select an existing photo for analysis',
                enabled: _modelState == _ModelState.ready,
                onTap: _pickFromGallery,
              ),
            ),
            const SizedBox(height: 28),
            _buildSectionLabel(c, 'Seed label'),
            const SizedBox(height: 10),
            AnimatedEntry(
              delayMs: 140,
              child: _buildActionCard(
                c: c,
                icon: Icons.document_scanner_rounded,
                color: GhC.attentionEmph,
                title: 'Scan Seed Label',
                subtitle: _nativeOcr
                    ? 'Extract variety, batch & planting date'
                    : 'Enter seed bag details manually',
                enabled: true,
                onTap: _openOcrCapture,
              ),
            ),
            if (_pendingLabel != null) ...[
              const SizedBox(height: 10),
              AnimatedEntry(child: _buildPendingLabelBadge(c)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Sub-builders ─────────────────────────────────────────────────────────────

  Widget _buildHeroCard(AppColors c) {
    final ready = _modelState == _ModelState.ready;
    final isError = _modelState == _ModelState.error;
    final isLoading = _modelState == _ModelState.loading;

    final startColor = ready
        ? GhC.successEmphasis
        : isError
            ? GhC.dangerEmphasis
            : c.subtle;
    final endColor = ready
        ? const Color(0xFF176B30)
        : isError
            ? const Color(0xFF8B1A17)
            : c.border;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  ready
                      ? Icons.eco_rounded
                      : isError
                          ? Icons.error_outline_rounded
                          : Icons.downloading_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ready
                          ? 'Ready to detect'
                          : isError
                              ? 'Model failed to load'
                              : 'Loading model…',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ready
                          ? (_classifier.activeModel.contains('int8')
                              ? 'EfficientNetB3 · INT8 · on-device'
                              : 'EfficientNetB3 · FP16 · on-device')
                          : isError
                              ? 'Tap retry below to reload'
                              : 'EfficientNetB3 · INT8 quantized',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              if (isError)
                GestureDetector(
                  onTap: _initModel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (isLoading) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 3,
              ),
            ),
          ],
          if (_modelError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _modelError!,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 11, height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionLabel(AppColors c, String label) {
    return Text(
      label,
      style: TextStyle(
        color: c.fgSubtle,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _buildActionCard({
    required AppColors c,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1.0 : 0.42,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: c.fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: c.fgMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: c.fgSubtle, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingLabelBadge(AppColors c) {
    final label = _pendingLabel!;
    final parts = [
      if (label.cropVariety != null) label.cropVariety!,
      if (label.batchNumber != null) label.batchNumber!,
      if (label.plantingDate != null) label.plantingDate!,
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: GhC.success.withValues(alpha: 0.08),
        border: Border.all(color: GhC.success.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: GhC.success, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Label queued · ${parts.join(' · ')}',
              style: const TextStyle(
                  color: GhC.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _pendingLabel = null),
            child: Icon(Icons.close_rounded, color: c.fgSubtle, size: 16),
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
    final c = context.gc;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: GhC.accentEmphasis.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                color: GhC.accentEmphasis,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Analysing leaf…',
              style: TextStyle(
                  color: c.fg, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'EfficientNetB3 · on-device',
              style: TextStyle(color: c.fgMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Manual label bottom sheet ─────────────────────────────────────────────────

/// Bottom sheet for manual seed-label entry.
/// Uses showModalBottomSheet so that TextField's Theme.of() dependencies
/// don't register on the parent widget tree — avoids _dependents.isEmpty.
/// Controllers are owned by the StatefulWidget so dispose() is called at the
/// correct time (after the exit animation fully completes).
class _ManualLabelSheet extends StatefulWidget {
  final AppColors c;
  const _ManualLabelSheet({required this.c});

  @override
  State<_ManualLabelSheet> createState() => _ManualLabelSheetState();
}

class _ManualLabelSheetState extends State<_ManualLabelSheet> {
  final _varietyCtrl  = TextEditingController();
  final _batchCtrl    = TextEditingController();
  final _plantingCtrl = TextEditingController();

  @override
  void dispose() {
    _varietyCtrl.dispose();
    _batchCtrl.dispose();
    _plantingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    // Keyboard avoidance padding is handled by the showModalBottomSheet builder.
    // This widget must NOT call MediaQuery.of(context) for viewInsets — doing so
    // registers it as a dependent of the route-local MediaQuery, which causes
    // _dependents.isEmpty assertions on iOS when the sheet is dismissed.
    return Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: GhC.attention.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_document, color: GhC.attention, size: 16),
                ),
                const SizedBox(width: 10),
                Text('Seed label entry',
                    style: TextStyle(color: c.fg, fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Enter seed bag details manually.',
                style: TextStyle(color: c.fgMuted, fontSize: 13)),
            const SizedBox(height: 16),
            _SheetField(label: 'Crop variety',    ctrl: _varietyCtrl,  hint: 'e.g. SAMMAZ 15',    c: c),
            const SizedBox(height: 10),
            _SheetField(label: 'Batch / lot no.', ctrl: _batchCtrl,    hint: 'e.g. BN-2024-003',  c: c),
            const SizedBox(height: 10),
            _SheetField(label: 'Planting date',   ctrl: _plantingCtrl, hint: 'e.g. 2024-04-01',   c: c),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _SheetButton(label: 'Cancel', c: c,
                    onTap: () => Navigator.pop(context, null)),
                const SizedBox(width: 8),
                _SheetButton(label: 'Save', c: c, filled: true,
                    onTap: () {
                      final v = _varietyCtrl.text.trim();
                      final b = _batchCtrl.text.trim();
                      final p = _plantingCtrl.text.trim();
                      if (v.isEmpty && b.isEmpty && p.isEmpty) {
                        Navigator.pop(context, null);
                        return;
                      }
                      Navigator.pop(context, SeedLabelData(
                        cropVariety:  v.isEmpty ? null : v,
                        batchNumber:  b.isEmpty ? null : b,
                        plantingDate: p.isEmpty ? null : p,
                        rawText: '',
                      ));
                    }),
              ],
            ),
          ],
        ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController ctrl;
  final AppColors c;
  const _SheetField({required this.label, required this.hint, required this.ctrl, required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: c.fgMuted, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          style: TextStyle(color: c.fg, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: c.fgSubtle, fontSize: 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

/// Animation-free, Theme-independent button for bottom sheets.
class _SheetButton extends StatelessWidget {
  final String label;
  final AppColors c;
  final VoidCallback onTap;
  final bool filled;
  const _SheetButton({required this.label, required this.c, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? GhC.accentEmphasis : c.subtle,
          border: Border.all(color: filled ? GhC.accentEmphasis : c.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                color: filled ? Colors.white : c.fg,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Enum ──────────────────────────────────────────────────────────────────────

enum _ModelState { loading, ready, error }
