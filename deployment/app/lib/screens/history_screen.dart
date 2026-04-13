import 'dart:io';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/database.dart';
import '../services/path_resolver.dart';
import 'scan_detail_sheet.dart';
import 'settings_screen.dart';

/// Scan history screen — filterable list of all past scans from SQLite.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _dao = AppDatabase.instance.scanDao;

  List<ScanRecord> _all = [];
  List<ScanRecord> _filtered = [];
  bool _loading = true;

  // Filters
  int? _classFilter;        // null = show all
  final double _minConfidence = 0.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final scans = await _dao.allScans();
    if (mounted) {
      setState(() {
        _all = scans;
        _loading = false;
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    _filtered = _all.where((s) {
      if (_classFilter != null && s.classId != _classFilter) return false;
      if (s.confidence < _minConfidence) return false;
      return true;
    }).toList();
  }

  void _setClassFilter(int? classId) {
    setState(() {
      _classFilter = classId;
      _applyFilters();
    });
  }

  Future<void> _clearAll() async {
    final c = context.gc;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: c.border),
        ),
        title: Text('Clear all records?', style: GhText.h2(c)),
        content: Text(
          'This will permanently delete all ${_all.length} scan records. This cannot be undone.',
          style: GhText.muted(c),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GhDialogButton(
                'Cancel',
                c: c,
                onTap: () => Navigator.pop(context, false),
              ),
              const SizedBox(width: 8),
              GhDialogButton(
                'Clear all',
                c: c,
                filled: true,
                color: GhC.dangerEmphasis,
                onTap: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirm != true) return;

    for (final scan in List.of(_all)) {
      if (!mounted) return;
      await _dao.deleteScan(scan.id);
      try {
        final f = File(PathResolver.resolve(scan.imagePath));
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    if (mounted) _load();
  }

  Future<void> _deleteScan(ScanRecord scan) async {
    final c = context.gc;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: c.border),
        ),
        title: Text('Delete scan?', style: GhText.h2(c)),
        content: Text(
          'This will permanently delete the "${scan.className}" scan from ${_formatDate(scan.scannedAt)}.',
          style: GhText.muted(c),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GhDialogButton(
                'Cancel',
                c: c,
                onTap: () => Navigator.pop(context, false),
              ),
              const SizedBox(width: 8),
              GhDialogButton(
                'Delete',
                c: c,
                filled: true,
                color: GhC.dangerEmphasis,
                onTap: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    await _dao.deleteScan(scan.id);
    // Try to clean up the image file too
    try {
      final f = File(PathResolver.resolve(scan.imagePath));
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}

    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(
        title: Text('Scan History${_all.isNotEmpty ? ' (${_all.length})' : ''}'),
        actions: [
          if (_all.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: GhC.danger),
              tooltip: 'Clear all',
              onPressed: _clearAll,
            ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: c.fgMuted, size: 20),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
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
      body: Column(
        children: [
          _buildFilterBar(c),
          const GhDivider(),
          Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: GhC.accentEmphasis, strokeWidth: 2))
                  : _filtered.isEmpty
                      ? _buildEmpty(c)
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: GhC.accentEmphasis,
                          backgroundColor: c.surface,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) =>
                                const GhDivider(
                                    margin: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 0)),
                            itemBuilder: (_, i) =>
                                _ScanRow(
                                  scan: _filtered[i],
                                  onDelete: () => _deleteScan(_filtered[i]),
                                ),
                          ),
                        ),
            ),
          ],
        ),
    );
  }

  Widget _buildFilterBar(AppColors c) {
    final classes = [
      (null, 'All', c.fgMuted),
      (0, 'NCLB', GhC.danger),
      (1, 'Rust', GhC.attention),
      (2, 'GLS', GhC.accentEmphasis),
      (3, 'Healthy', GhC.success),
    ];

    return Container(
      height: 44,
      color: c.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: classes.map((item) {
          final (id, label, color) = item;
          final selected = _classFilter == id;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => _setClassFilter(id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.15)
                      : c.subtle,
                  border: Border.all(
                    color: selected
                        ? color.withValues(alpha: 0.5)
                        : c.border,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? color : c.fgMuted,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmpty(AppColors c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, color: c.fgSubtle, size: 40),
          const SizedBox(height: 12),
          Text(
            _classFilter != null
                ? 'No ${_classFilter == 0 ? 'NCLB' : _classFilter == 1 ? 'Rust' : _classFilter == 2 ? 'GLS' : 'Healthy'} scans'
                : 'No scans yet',
            style: GhText.h3(c),
          ),
          const SizedBox(height: 4),
          Text(
            'Scanned leaves will appear here.',
            style: GhText.muted(c),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

// ── Scan list row ─────────────────────────────────────────────────────────────

class _ScanRow extends StatelessWidget {
  final ScanRecord scan;
  final VoidCallback onDelete;
  const _ScanRow({required this.scan, required this.onDelete});

  Color get _color => switch (scan.classId) {
        0 => GhC.danger,
        1 => GhC.attention,
        2 => GhC.accentEmphasis,
        _ => GhC.success,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.gc;
    final file = File(PathResolver.resolve(scan.imagePath));
    return Dismissible(
      key: ValueKey(scan.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: GhC.dangerEmphasis.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_rounded, color: GhC.danger),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // We handle deletion ourselves inside onDelete
      },
      child: GestureDetector(
        onTap: () => showScanDetail(context, scan),
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 52,
                height: 52,
                child: file.existsSync()
                    ? Image.file(
                        file,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: c.subtle,
                          child: Icon(Icons.image_not_supported_rounded,
                              color: c.fgSubtle, size: 20),
                        ),
                      )
                    : Container(
                        color: c.subtle,
                        child: Icon(Icons.image_not_supported_rounded,
                            color: c.fgSubtle, size: 20),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        scan.className,
                        style: TextStyle(
                          color: _color,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GhLabel(scan.shortName, color: _color, fontSize: 9),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${(scan.confidence * 100).toStringAsFixed(1)}% confidence',
                        style: GhText.muted(c),
                      ),
                      if (scan.cropVariety != null) ...[
                        Text(' · ', style: TextStyle(color: c.fgSubtle)),
                        Text(scan.cropVariety!,
                            style: TextStyle(
                                color: c.fgSubtle,
                                fontSize: 11,
                                fontFamily: GhC.mono)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          color: c.fgSubtle, size: 11),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(scan.scannedAt),
                        style: TextStyle(color: c.fgSubtle, fontSize: 10),
                      ),
                      if (scan.latitude != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.location_on_rounded,
                            color: GhC.accentEmphasis, size: 11),
                        const Text(' GPS',
                            style: TextStyle(
                                color: GhC.accentEmphasis, fontSize: 10)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Confidence dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: scan.confidence >= 0.8
                    ? GhC.success
                    : scan.confidence >= 0.5
                        ? GhC.attention
                        : GhC.danger,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      )),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
