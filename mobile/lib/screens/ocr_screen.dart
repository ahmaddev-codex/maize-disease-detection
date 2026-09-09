import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../design_system/design_system.dart';
import '../models/scan_record.dart';
import '../providers/app_provider.dart';
import '../services/ocr_service.dart';

class OcrScreen extends ConsumerStatefulWidget {
  const OcrScreen({super.key});
  @override
  ConsumerState<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends ConsumerState<OcrScreen> {
  OcrFields? _fields;
  bool _isProcessing = false;
  String? _error;

  final _varietyCtrl = TextEditingController();
  final _batchCtrl   = TextEditingController();
  final _dateCtrl    = TextEditingController();

  @override
  void dispose() {
    _varietyCtrl.dispose();
    _batchCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;
    setState(() {
      _isProcessing = true;
      _error = null;
    });
    try {
      final result = await OcrService.instance.extractFields(picked.path);
      _varietyCtrl.text = result.cropVariety ?? '';
      _batchCtrl.text   = result.batchNumber  ?? '';
      _dateCtrl.text    = result.plantingDate  ?? '';
      setState(() {
        _fields = result;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isProcessing = false;
      });
    }
  }

  void _attach() {
    if (_fields == null) return;
    final corrected = OcrFields(
      cropVariety: _varietyCtrl.text.trim().isEmpty ? null : _varietyCtrl.text.trim(),
      batchNumber: _batchCtrl.text.trim().isEmpty ? null : _batchCtrl.text.trim(),
      plantingDate: _dateCtrl.text.trim().isEmpty ? null : _dateCtrl.text.trim(),
      rawText: _fields!.rawText,
    );
    ref.read(pendingOcrProvider.notifier).state = corrected;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Seed metadata linked — will attach to your next leaf scan'),
      ),
    );
    context.push('/camera');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pending = ref.watch(pendingOcrProvider);
    final hasFields = _fields != null;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
      appBar: AppBar(
        title: Row(
          children: [
            MaizeGuardLogo(size: 22, isDark: isDark),
            const SizedBox(width: AppSpacing.sm),
            const Text('Seed Bag Label OCR Scanner'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
        children: [
          // Active Linked Metadata Banner
          if (pending != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.healthy.withValues(alpha: 0.12),
                borderRadius: AppRadii.md,
                border: Border.all(color: AppColors.healthy.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.healthy, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seed Metadata Active',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.healthy,
                          ),
                        ),
                        Text(
                          'Linked: ${pending.cropVariety ?? "Unknown Variety"}',
                          style: AppTypography.caption.copyWith(
                            color: isDark ? AppColors.charcoal300 : AppColors.charcoal700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.read(pendingOcrProvider.notifier).state = null,
                    child: const Text('Clear', style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Guidance Card
          AppCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldBase.withValues(alpha: 0.15),
                    borderRadius: AppRadii.sm,
                  ),
                  child: const MaizeGuardLogo(size: 24, isDark: false),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Capture the printed label on your certified maize seed package to automatically read the crop variety, seed lot batch number, and planting date.',
                    style: AppTypography.bodySmall.copyWith(
                      color: isDark ? AppColors.charcoal300 : AppColors.charcoal700,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Camera',
                  icon: Icons.camera_alt_outlined,
                  backgroundColor: AppColors.forestDark,
                  onPressed: _isProcessing ? null : () => _scan(ImageSource.camera),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'Gallery',
                  icon: Icons.photo_library_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: _isProcessing ? null : () => _scan(ImageSource.gallery),
                ),
              ),
            ],
          ),

          if (_isProcessing) ...[
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(color: AppColors.emeraldBase),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Parsing label text with on-device ML Kit OCR…', style: AppTypography.bodySmall),
                ],
              ),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: AppRadii.md,
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
              ),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ),
          ],

          // Form to review & correct OCR extraction
          if (hasFields) ...[
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Extracted Agronomic Metadata', style: AppTypography.h3),
                  const SizedBox(height: 4),
                  Text(
                    'Review and adjust values below prior to linking to field scan:',
                    style: AppTypography.caption.copyWith(color: AppColors.charcoal500),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Crop Variety',
                    hint: 'e.g. Oba Super 2, SAMMAZ 15',
                    controller: _varietyCtrl,
                    prefixIcon: Icons.grass_rounded,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: 'Lot / Batch Number',
                    hint: 'e.g. BATCH-2024-NG04',
                    controller: _batchCtrl,
                    prefixIcon: Icons.qr_code_rounded,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    label: 'Planting Date',
                    hint: 'YYYY-MM-DD',
                    controller: _dateCtrl,
                    prefixIcon: Icons.calendar_today_rounded,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Attach Seed Metadata to Next Scan',
                    icon: Icons.link_rounded,
                    backgroundColor: AppColors.emeraldBase,
                    onPressed: _attach,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RAW DETECTED TEXT STREAM',
                    style: AppTypography.overline.copyWith(color: AppColors.charcoal500),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SelectableText(
                    _fields!.rawText.isEmpty ? '(No textual patterns recognized)' : _fields!.rawText,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
