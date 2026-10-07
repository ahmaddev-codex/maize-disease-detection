import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../design_system/design_system.dart';
import '../models/scan_record.dart';
import '../navigation/open_scan.dart';
import '../providers/app_provider.dart';
import '../services/database_service.dart';
import '../services/path_resolver.dart';
import '../utils/time_format.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _filter = 'All';
  static const _classes = ['All', 'NCLB', 'Rust', 'GLS', 'Healthy'];

  @override
  void initState() {
    super.initState();
    ref.read(scanListProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final scans = ref.watch(scanListProvider);
    final filtered = _filter == 'All'
        ? scans
        : scans.where((s) => s.shortName.toLowerCase() == _filter.toLowerCase()).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
      appBar: AppBar(
        title: Row(
          children: [
            MaizeGuardLogo(size: 22, isDark: isDark),
            const SizedBox(width: AppSpacing.sm),
            const Text('Field Diagnostic Records'),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _classes.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, i) {
                final cls = _classes[i];
                final isSelected = _filter == cls;
                return ChoiceChip(
                  label: Text(cls),
                  selected: isSelected,
                  selectedColor: isDark ? AppColors.forestDark : AppColors.primaryContainer,
                  backgroundColor: isDark ? AppColors.charcoal900 : AppColors.charcoal100,
                  labelStyle: AppTypography.bodySmall.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? (isDark ? Colors.white : AppColors.primary) : (isDark ? AppColors.charcoal300 : AppColors.charcoal700),
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.emeraldBase : Colors.transparent,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _filter = cls);
                  },
                );
              },
            ),
          ),
        ),
      ),
      body: filtered.isEmpty
          ? EmptyStateView(
              illustration: const MaizeGuardLogo(size: 56),
              title: _filter == 'All' ? 'No Scans Recorded' : 'No $_filter Records',
              message: 'Your field diagnostics and leaf scans will appear chronologically here.',
              actionLabel: 'Perform First Scan',
              onAction: () => context.push('/camera'),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 90),
              itemCount: filtered.length,
              itemBuilder: (context, i) => _ScanCard(scan: filtered[i]),
            ),
    );
  }
}

class _ScanCard extends ConsumerWidget {
  final ScanRecord scan;
  const _ScanCard({required this.scan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final absPath = PathResolver.resolve(scan.imagePath);
    final hasImage = scan.imagePath.isNotEmpty && File(absPath).existsSync();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final badgeColor = switch (scan.classId) {
      0 => AppColors.nclb,
      1 => AppColors.rust,
      2 => AppColors.gls,
      3 => AppColors.healthy,
      _ => AppColors.charcoal500,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        onTap: () => openScan(context, ref, scan.id!),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Disease & Confidence
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasImage)
                  ClipRRect(
                    borderRadius: AppRadii.md,
                    child: Image.file(
                      File(absPath),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: AppRadii.md,
                    ),
                    child: Icon(Icons.eco_outlined, color: badgeColor, size: 28),
                  ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              scan.className,
                              style: AppTypography.h3.copyWith(
                                color: isDark ? Colors.white : AppColors.charcoal900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.15),
                              borderRadius: AppRadii.sm,
                              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              '${(scan.confidence * 100).toStringAsFixed(0)}%',
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatScanDateTime(scan.scannedAt),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.charcoal400,
                        ),
                      ),
                      if (scan.cropVariety != null && scan.cropVariety!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.grass_rounded, size: 13, color: AppColors.emeraldBase),
                            const SizedBox(width: 4),
                            Text(
                              'Variety: ${scan.cropVariety}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.emeraldBase,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            if (scan.notes != null && scan.notes!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.charcoal900 : AppColors.charcoal100,
                  borderRadius: AppRadii.sm,
                ),
                child: Text(
                  scan.notes!,
                  style: AppTypography.bodySmall.copyWith(
                    color: isDark ? AppColors.charcoal300 : AppColors.charcoal700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            const Divider(height: AppSpacing.lg),

            // Card Footer: Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (scan.feedback != null)
                      Icon(
                        scan.feedback == 1
                            ? Icons.check_circle_rounded
                            : (scan.feedback == 0 ? Icons.cancel_rounded : Icons.help_rounded),
                        size: 16,
                        color: scan.feedback == 1
                            ? AppColors.healthy
                            : (scan.feedback == 0 ? AppColors.danger : AppColors.charcoal400),
                      ),
                    if (scan.feedback != null) const SizedBox(width: 4),
                    if (scan.feedback != null)
                      Text(
                        scan.feedback == 1
                            ? 'Verified'
                            : (scan.feedback == 0 ? 'Refuted' : 'Uncertain'),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.charcoal400,
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, size: 20),
                      color: AppColors.charcoal400,
                      tooltip: 'Edit Field Notes',
                      onPressed: () => _editNotes(context, ref),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      color: AppColors.charcoal400,
                      tooltip: 'Delete Record',
                      onPressed: () => _confirmDelete(context, ref),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.charcoal400),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editNotes(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: scan.notes ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Field Observations & Notes'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Record field observations, chemical dosage, or weather…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, ctrl.text),
            child: const Text('Save Notes'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (saved == null || scan.id == null) return;
    await DatabaseService.instance.updateNotes(scan.id!, saved);
    await ref.read(scanListProvider.notifier).load();
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Diagnostic Record?'),
        content: const Text('This will permanently delete this scan and its physical image reference.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true && scan.id != null) {
      await ref.read(scanListProvider.notifier).delete(scan.id!);
    }
  }
}
