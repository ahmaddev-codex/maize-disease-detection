import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import '../models/prediction.dart';
import '../services/ocr_service.dart';

/// OCR capture screen — photograph a seed bag label and extract structured
/// metadata (crop variety, batch number, planting date) entirely on-device
/// via Apple Vision (iOS) or manual entry.
class OcrScreen extends StatefulWidget {
  final OcrService ocrService;

  /// Called when the user confirms extracted data.
  final void Function(SeedLabelData)? onDataSaved;

  const OcrScreen({super.key, required this.ocrService, this.onDataSaved});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  File? _imageFile;
  SeedLabelData? _result;
  bool _isProcessing = false;

  Future<void> _pickImage(ImageSource source) async {
    final picked =
        await ImagePicker().pickImage(source: source, imageQuality: 95);
    if (picked == null || !mounted) return;

    setState(() {
      _imageFile = File(picked.path);
      _result = null;
      _isProcessing = true;
    });

    try {
      final data = await widget.ocrService.extractFromImage(_imageFile!);
      if (mounted) setState(() => _result = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    final hasResult = _result != null && !_isProcessing;

    return Scaffold(
      backgroundColor: c.canvas,
      // Sticky "Use this data" bar at the bottom
      bottomNavigationBar: hasResult && widget.onDataSaved != null
          ? _buildBottomBar(c)
          : null,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(c),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildActionButtons(c),
                  if (_isProcessing) ...[
                    const SizedBox(height: 32),
                    _buildProcessingState(c),
                  ],
                  if (hasResult) ...[
                    const SizedBox(height: 24),
                    AnimatedEntry(
                        delayMs: 0, child: _buildExtractedFields(c, _result!)),
                    const SizedBox(height: 16),
                    AnimatedEntry(
                        delayMs: 80, child: _buildRawText(c, _result!)),
                  ],
                  if (!_isProcessing && _result == null && _imageFile == null)
                    _buildHint(c),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sliver app bar with image / placeholder ───────────────────────────────────

  Widget _buildSliverAppBar(AppColors c) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Seed Label Scanner',
        style: TextStyle(color: c.fg, fontSize: 15, fontWeight: FontWeight.w600),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: c.border),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: _imageFile != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(_imageFile!, fit: BoxFit.cover),
                  // Gradient fade to surface at bottom
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          c.canvas.withValues(alpha: 0.7),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              )
            : _buildPlaceholder(c),
      ),
    );
  }

  Widget _buildPlaceholder(AppColors c) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            GhC.attentionEmph.withValues(alpha: 0.85),
            GhC.attention.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.document_scanner_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Scan a seed bag label',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Apple Vision · on-device · no internet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ── Action buttons ─────────────────────────────────────────────────────────

  Widget _buildActionButtons(AppColors c) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            c: c,
            icon: Icons.camera_alt_rounded,
            label: 'Camera',
            color: GhC.successEmphasis,
            onTap: _isProcessing ? null : () => _pickImage(ImageSource.camera),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            c: c,
            icon: Icons.photo_library_rounded,
            label: 'Gallery',
            color: GhC.accentEmphasis,
            onTap:
                _isProcessing ? null : () => _pickImage(ImageSource.gallery),
            outlined: true,
          ),
        ),
      ],
    );
  }

  // ── Processing state ───────────────────────────────────────────────────────

  Widget _buildProcessingState(AppColors c) {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: GhC.attention.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: GhC.attentionEmph,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Scanning label…',
            style: TextStyle(
                color: c.fg, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text('Apple Vision · on-device',
              style: TextStyle(color: c.fgMuted, fontSize: 12)),
        ],
      ),
    );
  }

  // ── Extracted fields ───────────────────────────────────────────────────────

  Widget _buildExtractedFields(AppColors c, SeedLabelData data) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(Icons.list_alt_rounded, color: c.fgSubtle, size: 16),
                const SizedBox(width: 8),
                Text('Extracted fields',
                    style: TextStyle(
                        color: c.fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: data.hasAnyField
                        ? GhC.success.withValues(alpha: 0.12)
                        : GhC.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    data.hasAnyField ? 'parsed' : 'no match',
                    style: TextStyle(
                      color: data.hasAnyField ? GhC.success : GhC.danger,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const GhDivider(),
          if (!data.hasAnyField)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: GhC.attention, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No known fields recognised. Try better lighting or a clearer photo.',
                      style: TextStyle(color: c.fgMuted, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _FieldRow(
                      c: c,
                      icon: Icons.grass_rounded,
                      label: 'Variety',
                      value: data.cropVariety),
                  if (data.cropVariety != null)
                    const GhDivider(
                        margin: EdgeInsets.symmetric(vertical: 10)),
                  _FieldRow(
                      c: c,
                      icon: Icons.tag_rounded,
                      label: 'Batch',
                      value: data.batchNumber),
                  if (data.batchNumber != null)
                    const GhDivider(
                        margin: EdgeInsets.symmetric(vertical: 10)),
                  _FieldRow(
                      c: c,
                      icon: Icons.calendar_today_rounded,
                      label: 'Planting date',
                      value: data.plantingDate),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Raw OCR text (expandable) ──────────────────────────────────────────────

  Widget _buildRawText(AppColors c, SeedLabelData data) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Icon(Icons.code_rounded, color: c.fgSubtle, size: 16),
          title: Text(
            'Raw OCR output',
            style: TextStyle(
                color: c.fg, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          trailing: Icon(Icons.expand_more_rounded,
              color: c.fgSubtle, size: 18),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.canvas,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.borderMuted),
                    ),
                    child: SelectableText(
                      data.rawText.isEmpty
                          ? '(no text recognised)'
                          : data.rawText,
                      style: TextStyle(
                        color: c.fgMuted,
                        fontSize: 11,
                        fontFamily: GhC.mono,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${data.rawText.split('\n').where((l) => l.trim().isNotEmpty).length} lines · Apple Vision',
                    style: TextStyle(color: c.fgSubtle, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hint when nothing selected yet ────────────────────────────────────────

  Widget _buildHint(AppColors c) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.touch_app_rounded, color: c.fgSubtle, size: 36),
            const SizedBox(height: 10),
            Text(
              'Tap Camera or Gallery to begin',
              style: TextStyle(color: c.fgMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sticky bottom bar ──────────────────────────────────────────────────────

  Widget _buildBottomBar(AppColors c) {
    final data = _result!;
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.25 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: data.hasAnyField ? () => widget.onDataSaved!(data) : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: data.hasAnyField ? 1.0 : 0.4,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: data.hasAnyField ? GhC.successEmphasis : c.subtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Use this label data',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Action button ──────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final AppColors c;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool outlined;

  const _ActionButton({
    required this.c,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: onTap == null ? 0.4 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: outlined ? Colors.transparent : color,
            border: Border.all(
              color: outlined ? c.border : color,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: outlined ? c.fg : Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: outlined ? c.fg : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Field row ──────────────────────────────────────────────────────────────────

class _FieldRow extends StatelessWidget {
  final AppColors c;
  final IconData icon;
  final String label;
  final String? value;

  const _FieldRow({
    required this.c,
    required this.icon,
    required this.label,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    final found = value != null;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: (found ? GhC.success : c.fgSubtle)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: found ? GhC.success : c.fgSubtle,
            size: 15,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(color: c.fgMuted, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value ?? 'Not found',
            style: TextStyle(
              color: found ? c.fg : c.fgSubtle,
              fontSize: 13,
              fontWeight: found ? FontWeight.w600 : FontWeight.normal,
              fontFamily: found ? GhC.mono : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Icon(
          found
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: found ? GhC.success : c.fgSubtle,
          size: 15,
        ),
      ],
    );
  }
}
