import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/colors.dart';
import '../models/scan_record.dart';
import '../providers/app_provider.dart';
import '../services/ocr_service.dart';
import '../widgets/ds.dart';

class OcrScreen extends ConsumerStatefulWidget {
  const OcrScreen({super.key});
  @override
  ConsumerState<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends ConsumerState<OcrScreen> {
  OcrFields? _fields;
  bool _isProcessing = false;
  String? _error;

  Future<void> _scan(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;
    setState(() { _isProcessing = true; _error = null; });
    try {
      final result = await OcrService.instance.extractFields(picked.path);
      setState(() { _fields = result; _isProcessing = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isProcessing = false; });
    }
  }

  void _attach() {
    if (_fields == null) return;
    ref.read(pendingOcrProvider.notifier).state = _fields;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(
          'Seed label attached — will be linked to your next leaf scan')),
    );
    context.push('/camera');
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = ref.watch(isDarkModeProvider);
    final pending  = ref.watch(pendingOcrProvider);
    final hasFields = _fields != null;

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvas,
      body: CustomScrollView(
        slivers: [
          // ── Glass app bar ────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 90,
            backgroundColor:
                (isDark ? AppColors.surfaceDark : AppColors.surface).withOpacity(0.88),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: const FlexibleSpaceBar(
                  title: Text('Seed Label Scanner',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                  titlePadding: EdgeInsets.only(left: 16, bottom: 14),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: AppSpacing.pagePad,
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 12),

                // ── Pending label banner ─────────────────────────────────
                if (pending != null)
                  GlassCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(children: [
                      const DuotoneIcon(Icons.check_circle_rounded,
                          primaryColor: AppColors.successFg,
                          secondaryColor: Color(0xFF69F0AE)),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Label attached — ready to scan a leaf',
                          style: TextStyle(fontSize: 13, color: AppColors.successFg,
                              fontWeight: FontWeight.w600))),
                      TextButton(
                        onPressed: () => ref.read(pendingOcrProvider.notifier).state = null,
                        child: const Text('Clear',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ),
                    ]),
                  ),

                // ── Instruction card ─────────────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    const DuotoneIcon(Icons.info_rounded,
                        primaryColor: AppColors.accent,
                        secondaryColor: AppColors.accentFg),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Photograph the front of a seed bag label to extract crop variety, batch number, and planting date. The data will be linked to your next disease scan.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                // ── Camera / Gallery buttons ─────────────────────────────
                Row(children: [
                  Expanded(child: _ScanButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: _isProcessing ? null : () => _scan(ImageSource.camera),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _ScanButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: _isProcessing ? null : () => _scan(ImageSource.gallery),
                  )),
                ]),

                // ── Processing ───────────────────────────────────────────
                if (_isProcessing) ...[
                  const SizedBox(height: 24),
                  GlassCard(
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Extracting text from label…',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],

                // ── Error ────────────────────────────────────────────────
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  GlassCard(
                    child: Row(children: [
                      const Icon(Icons.error_rounded, color: AppColors.dangerFg),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_error!,
                          style: const TextStyle(color: AppColors.dangerFg, fontSize: 12))),
                    ]),
                  ),
                ],

                // ── Extracted fields ─────────────────────────────────────
                if (hasFields) ...[
                  const SectionLabel('Extracted Fields'),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      _FieldRow(
                        icon: Icons.grass_rounded,
                        iconColor: AppColors.successFg,
                        label: 'Crop variety',
                        value: _fields!.cropVariety,
                      ),
                      const Divider(height: 1, indent: 56),
                      _FieldRow(
                        icon: Icons.qr_code_rounded,
                        iconColor: AppColors.accent,
                        label: 'Batch number',
                        value: _fields!.batchNumber,
                      ),
                      const Divider(height: 1, indent: 56),
                      _FieldRow(
                        icon: Icons.calendar_today_rounded,
                        iconColor: AppColors.attentionFg,
                        label: 'Planting date',
                        value: _fields!.plantingDate,
                      ),
                    ]),
                  ),

                  const SectionLabel('Raw OCR Text'),
                  GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      _fields!.rawText.isEmpty ? '(no text detected)' : _fields!.rawText,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.5),
                    ),
                  ),

                  if (_fields!.hasAnyField) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _attach,
                        icon: const Icon(Icons.link_rounded),
                        label: const Text('Attach to next scan'),
                      ),
                    ),
                  ],
                ],

                // ── Empty state ──────────────────────────────────────────
                if (!hasFields && !_isProcessing && _error == null) ...[
                  const SizedBox(height: 40),
                  EmptyState(
                    icon: Icons.document_scanner_rounded,
                    title: 'No label scanned yet',
                    subtitle: 'Point your camera at a seed bag label\nto extract variety and batch info.',
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(children: [
        DuotoneIcon(icon,
            primaryColor: AppColors.accent,
            secondaryColor: AppColors.accentFg),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    ),
  );
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.value,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: iconColor),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
      Text(
        value ?? '—',
        style: TextStyle(
          fontSize: 13,
          fontWeight: value != null ? FontWeight.w600 : FontWeight.w400,
          color: value != null ? AppColors.textPrimary : AppColors.textMuted,
        ),
      ),
    ]),
  );
}
