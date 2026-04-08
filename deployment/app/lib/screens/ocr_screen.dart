import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import '../models/prediction.dart';
import '../services/ocr_service.dart';

/// OCR capture screen — photograph a seed bag label and extract structured
/// metadata (crop variety, batch number, planting date) entirely on-device
/// via Google ML Kit (Android / iOS only).
class OcrScreen extends StatefulWidget {
  final OcrService ocrService;
  const OcrScreen({super.key, required this.ocrService});

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
    return Scaffold(
      backgroundColor: GhC.canvas,
      appBar: AppBar(
        backgroundColor: GhC.surface,
        foregroundColor: GhC.fg,
        surfaceTintColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(Icons.document_scanner_rounded,
                size: 16, color: GhC.attention),
            SizedBox(width: 8),
            Text('Seed label scanner',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: GhC.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoBanner(),
            const SizedBox(height: 16),
            _buildImageSection(),
            const SizedBox(height: 16),
            if (_isProcessing) _buildProcessingCard(),
            if (_result != null && !_isProcessing)
              _buildResultSection(_result!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GhC.accentEmphasis.withValues(alpha: 0.08),
        border: Border.all(color: GhC.accentEmphasis.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, color: GhC.accent, size: 15),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Point your camera at a seed bag label. '
              'ML Kit OCR processes text on-device — no internet required. '
              'Ensure good lighting and keep the label flat.',
              style: TextStyle(color: GhC.fgMuted, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      decoration: GhBox.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image preview
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            child: _imageFile != null
                ? Image.file(
                    _imageFile!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 200,
                    width: double.infinity,
                    color: GhC.subtle,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.document_scanner_rounded,
                            color: GhC.fgSubtle, size: 40),
                        SizedBox(height: 10),
                        Text('No label selected',
                            style:
                                TextStyle(color: GhC.fgSubtle, fontSize: 13)),
                        SizedBox(height: 4),
                        Text('Use Camera or Gallery below',
                            style:
                                TextStyle(color: GhC.fgSubtle, fontSize: 11)),
                      ],
                    ),
                  ),
          ),
          const GhDivider(),
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: GhButton(
                    'Camera',
                    icon: Icons.camera_alt_rounded,
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GhButtonOutline(
                    'Gallery',
                    icon: Icons.photo_library_rounded,
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GhBox.card(),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: GhC.accent),
          ),
          SizedBox(width: 12),
          Text('Running OCR…', style: GhText.body),
          SizedBox(width: 4),
          Text('ML Kit · on-device', style: GhText.muted),
        ],
      ),
    );
  }

  Widget _buildResultSection(SeedLabelData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Extracted fields card (GitHub sidebar style)
        Container(
          decoration: GhBox.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Row(
                  children: [
                    const Icon(Icons.list_alt_rounded,
                        color: GhC.fgSubtle, size: 14),
                    const SizedBox(width: 6),
                    const Text('Extracted fields', style: GhText.h3),
                    const Spacer(),
                    GhLabel(
                      data.hasAnyField ? 'parsed' : 'no match',
                      color: data.hasAnyField ? GhC.success : GhC.danger,
                      fontSize: 10,
                    ),
                  ],
                ),
              ),
              const GhDivider(),
              if (!data.hasAnyField)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: GhC.attention, size: 15),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'No known fields recognised. Try better lighting or a clearer photo.',
                          style: GhText.muted,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _FieldRow(
                        icon: Icons.grass_rounded,
                        label: 'Crop variety',
                        value: data.cropVariety,
                      ),
                      if (data.cropVariety != null)
                        const GhDivider(
                            margin: EdgeInsets.symmetric(vertical: 8)),
                      _FieldRow(
                        icon: Icons.tag_rounded,
                        label: 'Batch number',
                        value: data.batchNumber,
                      ),
                      if (data.batchNumber != null)
                        const GhDivider(
                            margin: EdgeInsets.symmetric(vertical: 8)),
                      _FieldRow(
                        icon: Icons.calendar_today_rounded,
                        label: 'Planting date',
                        value: data.plantingDate,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Raw OCR text (GitHub code block style)
        Container(
          decoration: GhBox.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Row(
                  children: const [
                    Icon(Icons.code_rounded, color: GhC.fgSubtle, size: 14),
                    SizedBox(width: 6),
                    Text('Raw OCR output', style: GhText.h3),
                  ],
                ),
              ),
              const GhDivider(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: GhC.canvas,
                child: SelectableText(
                  data.rawText.isEmpty ? '(no text recognised)' : data.rawText,
                  style: const TextStyle(
                    color: GhC.fgMuted,
                    fontSize: 11,
                    fontFamily: GhC.mono,
                    height: 1.6,
                  ),
                ),
              ),
              const GhDivider(),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  '${data.rawText.split('\n').where((l) => l.trim().isNotEmpty).length} lines · ML Kit Latin script',
                  style: GhText.subtle,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Field row ─────────────────────────────────────────────────────────────────

class _FieldRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  const _FieldRow({required this.icon, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    final found = value != null;
    return Row(
      children: [
        Icon(icon, color: found ? GhC.success : GhC.fgSubtle, size: 15),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Text(label,
              style: const TextStyle(color: GhC.fgMuted, fontSize: 12)),
        ),
        Expanded(
          child: Text(
            value ?? 'Not found',
            style: TextStyle(
              color: found ? GhC.fg : GhC.fgSubtle,
              fontSize: 13,
              fontWeight: found ? FontWeight.w600 : FontWeight.normal,
              fontFamily: found ? GhC.mono : null,
            ),
          ),
        ),
        Icon(
          found
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          color: found ? GhC.success : GhC.fgSubtle,
          size: 14,
        ),
      ],
    );
  }
}
