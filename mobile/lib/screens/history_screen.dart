import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../constants/colors.dart';
import '../models/scan_record.dart';
import '../providers/app_provider.dart';
import '../services/database_service.dart';
import '../services/path_resolver.dart';
import '../widgets/ds.dart';

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
    final scans    = ref.watch(scanListProvider);
    final filtered = _filter == 'All'
        ? scans
        : scans.where((s) => s.shortName == _filter).toList();
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvas,
      body: CustomScrollView(
        slivers: [
          // ── Glass app bar ────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 100,
            backgroundColor: (isDark ? AppColors.surfaceDark : AppColors.surface).withOpacity(0.88),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: const FlexibleSpaceBar(
                  title: Text('Scan History',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                  titlePadding: EdgeInsets.only(left: 16, bottom: 14),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(54),
              child: _FilterBar(
                selected: _filter,
                classes: _classes,
                isDark: isDark,
                onSelect: (v) => setState(() => _filter = v),
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          if (filtered.isEmpty)
            SliverFillRemaining(
              child: EmptyState(
                icon: Icons.history_rounded,
                title: _filter == 'All' ? 'No scans yet' : 'No $_filter scans',
                subtitle: 'Scan maize leaves to build\nyour disease history.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _ScanCard(scan: filtered[i], isDark: isDark),
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Filter bar ────────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.classes,
    required this.isDark,
    required this.onSelect,
  });
  final String selected;
  final List<String> classes;
  final bool isDark;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        height: 54,
        color: Colors.transparent,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: classes.asMap().entries.map((e) {
              final cls       = e.value;
              final active    = selected == cls;
              final chipColor = e.key == 0
                  ? AppColors.accent
                  : AppColors.forClass(e.key - 1);
              return GestureDetector(
                onTap: () => onSelect(cls),
                child: AnimatedContainer(
                  duration: AppDuration.fast,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: active ? chipColor : chipColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active ? chipColor : chipColor.withOpacity(0.30),
                    ),
                  ),
                  child: Text(cls,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                        color: active ? Colors.white : chipColor,
                      )),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    ),
  );
}

// ── Scan card ─────────────────────────────────────────────────────────────────
class _ScanCard extends ConsumerWidget {
  const _ScanCard({required this.scan, required this.isDark});
  final ScanRecord scan;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color    = AppColors.forClass(scan.classId);
    final absPath  = PathResolver.resolve(scan.imagePath);
    final hasImage = scan.imagePath.isNotEmpty && File(absPath).existsSync();

    return GestureDetector(
      onLongPress: () => _showActions(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: (isDark ? AppColors.surfaceDark : Colors.white).withOpacity(0.90),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: (isDark ? AppColors.borderDark : AppColors.border).withOpacity(0.7),
          ),
          boxShadow: AppColors.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero image ────────────────────────────────────────────
              if (hasImage)
                Stack(
                  children: [
                    Image.file(File(absPath),
                        width: double.infinity, height: 180, fit: BoxFit.cover),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 70,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [color.withOpacity(0.55), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    // Glass confidence pill on image
                    Positioned(
                      bottom: 10, right: 12,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            color: Colors.black.withOpacity(0.32),
                            child: Text(
                              '${(scan.confidence * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Container(
                  width: double.infinity, height: 100,
                  color: color.withOpacity(0.10),
                  child: Center(child: Icon(Icons.grass_rounded,
                      size: 48, color: color.withOpacity(0.35))),
                ),

              // ── Details row ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      DiseaseDot(color),
                      const SizedBox(width: 8),
                      Expanded(child: Text(scan.shortName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                          ))),
                      // Confidence badge (only when no image overlay)
                      if (!hasImage)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(scan.confidence * 100).toStringAsFixed(0)}%',
                            style: TextStyle(color: color,
                                fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    Text(DateFormat('d MMM yyyy  ·  HH:mm').format(scan.scannedAt),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    if (scan.cropVariety != null) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.grass_rounded,
                            size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(scan.cropVariety!,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                      ]),
                    ],
                    // Notes (if any)
                    if (scan.notes != null && scan.notes!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(scan.notes!,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.accent, height: 1.4)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActionSheet(scan: scan),
    );

    if (action == 'notes' && context.mounted) {
      await _editNotes(context, ref);
    } else if (action == 'delete' && context.mounted) {
      await _confirmDelete(context, ref);
    }
  }

  Future<void> _editNotes(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: scan.notes ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Add notes'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Field observations, treatment applied…',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, ctrl.text),
              child: const Text('Save')),
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
        title: const Text('Delete scan?'),
        content: const Text('This will remove the record permanently.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.dangerFg))),
        ],
      ),
    );
    if (ok == true && scan.id != null) {
      await ref.read(scanListProvider.notifier).delete(scan.id!);
    }
  }
}

// ── Action bottom sheet ───────────────────────────────────────────────────────
class _ActionSheet extends StatelessWidget {
  const _ActionSheet({required this.scan});
  final ScanRecord scan;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forClass(scan.classId);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16,
          16 + MediaQuery.of(context).padding.bottom),
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(children: [
              DiseaseDot(color),
              const SizedBox(width: 8),
              Text(scan.shortName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
            const SizedBox(height: 16),
            ListTile(
              leading: const DuotoneIcon(Icons.edit_note_rounded,
                  primaryColor: AppColors.accent,
                  secondaryColor: AppColors.accentFg),
              title: Text(scan.notes?.isNotEmpty == true ? 'Edit notes' : 'Add notes'),
              subtitle: scan.notes?.isNotEmpty == true
                  ? Text(scan.notes!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11))
                  : null,
              contentPadding: EdgeInsets.zero,
              onTap: () => Navigator.pop(context, 'notes'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const DuotoneIcon(Icons.delete_rounded,
                  primaryColor: AppColors.dangerFg,
                  secondaryColor: Color(0xFFFF8A80)),
              title: const Text('Delete scan',
                  style: TextStyle(color: AppColors.dangerFg)),
              contentPadding: EdgeInsets.zero,
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
  }
}
