import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_env.dart';
import '../constants/colors.dart';
import '../providers/app_provider.dart';
import '../services/database_service.dart';
import '../widgets/ds.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _keyCtrl = TextEditingController();
  bool _obscure  = true;
  bool _keySaved = false;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    final key = ref.read(geminiKeyProvider);
    if (key != null && key.isNotEmpty) {
      _keyCtrl.text = key;
      _keySaved = true;
    }
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvas,
      body: CustomScrollView(
        slivers: [
          // ── Glass app bar ─────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 90,
            backgroundColor: (isDark ? AppColors.surfaceDark : AppColors.surface)
                .withOpacity(0.88),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: const FlexibleSpaceBar(
                  title: Text('Settings',
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
                // ── Appearance ─────────────────────────────────────────────
                const SectionLabel('Appearance', topMargin: 8),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: SwitchListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: const Text('Dark mode',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: const Text('Switch between light and dark theme',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    secondary: DuotoneIcon(
                      isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      primaryColor: AppColors.accent,
                      secondaryColor: AppColors.accentFg,
                    ),
                    value: isDark,
                    activeColor: AppColors.accent,
                    onChanged: (_) => ref.read(isDarkModeProvider.notifier).toggle(),
                  ),
                ),

                // ── AI Advisor (production only — Gemini key) ──────────────
                if (!kDebugMode) ...[
                  const SectionLabel('AI Advisor'),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const DuotoneIcon(Icons.auto_awesome_rounded,
                              primaryColor: AppColors.attentionFg,
                              secondaryColor: Color(0xFFFFD54F)),
                          const SizedBox(width: 10),
                          Expanded(child: Text('Gemini API Key',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700))),
                          if (_keySaved)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.successFg.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Saved',
                                  style: TextStyle(fontSize: 11,
                                      color: AppColors.successFg,
                                      fontWeight: FontWeight.w600)),
                            ),
                        ]),
                        const SizedBox(height: 4),
                        const Text(
                          'Stored securely on this device — never sent to our servers.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _keyCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Gemini API key',
                            hintText: 'AIza…',
                            prefixIcon: const Icon(Icons.key_rounded, size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 18,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          ElevatedButton(
                            onPressed: () async {
                              final key = _keyCtrl.text.trim();
                              if (key.isEmpty) return;
                              await ref.read(geminiKeyProvider.notifier).save(key);
                              if (mounted) {
                                setState(() => _keySaved = true);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('API key saved')));
                              }
                            },
                            child: const Text('Save key'),
                          ),
                          const SizedBox(width: 12),
                          if (_keySaved)
                            TextButton(
                              onPressed: () async {
                                await ref.read(geminiKeyProvider.notifier).clear();
                                _keyCtrl.clear();
                                if (mounted) setState(() => _keySaved = false);
                              },
                              child: const Text('Remove',
                                  style: TextStyle(color: AppColors.dangerFg)),
                            ),
                        ]),
                      ],
                    ),
                  ),
                ],

                // ── Developer (debug only — Ollama info from .env.json) ────
                if (kDebugMode) ...[
                  const SectionLabel('Developer'),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _DevRow(
                          icon: Icons.psychology_rounded,
                          iconColor: AppColors.successFg,
                          label: 'AI backend',
                          value: 'Ollama (debug)',
                        ),
                        const Divider(height: 1, indent: 56),
                        _DevRow(
                          icon: Icons.dns_rounded,
                          iconColor: AppColors.accent,
                          label: 'Host',
                          value: AppEnv.ollamaHost,
                        ),
                        const Divider(height: 1, indent: 56),
                        _DevRow(
                          icon: Icons.model_training_rounded,
                          iconColor: AppColors.attentionFg,
                          label: 'Model',
                          value: AppEnv.ollamaModel,
                        ),
                      ],
                    ),
                  ),
                  GlassCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      const Icon(Icons.info_rounded,
                          size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Edit mobile/.env.json and re-run with '
                          '--dart-define-from-file=.env.json to change these values.',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textMuted, height: 1.5),
                        ),
                      ),
                    ]),
                  ),
                ],

                // ── Data & Privacy ─────────────────────────────────────────
                const SectionLabel('Data & Privacy'),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: DuotoneIcon(Icons.delete_rounded,
                        primaryColor: AppColors.dangerFg,
                        secondaryColor: const Color(0xFFFF8A80)),
                    title: const Text('Clear all scan data',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: const Text(
                        'Permanently removes all scans from this device',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    trailing: _clearing
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.chevron_right,
                            color: AppColors.textSecondary),
                    onTap: _clearing ? null : () => _confirmClear(context),
                  ),
                ),

                // ── About ──────────────────────────────────────────────────
                const SectionLabel('About'),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _AboutTile(icon: Icons.agriculture_rounded,
                          iconColor: AppColors.successFg,
                          title: 'MaizeGuard', value: 'v1.0.0'),
                      _Divider(),
                      _AboutTile(icon: Icons.memory_rounded,
                          iconColor: AppColors.accent,
                          title: 'Model', value: 'EfficientNetB3 · INT8'),
                      _Divider(),
                      _AboutTile(icon: Icons.dataset_rounded,
                          iconColor: AppColors.attentionFg,
                          title: 'Training data',
                          value: 'PlantVillage · 4,188 images'),
                      _Divider(),
                      _AboutTile(icon: Icons.category_rounded,
                          iconColor: AppColors.rust,
                          title: 'Classes',
                          value: 'NCLB · Rust · GLS · Healthy'),
                      _Divider(),
                      _AboutTile(icon: Icons.public_rounded,
                          iconColor: AppColors.nclb,
                          title: 'Target region',
                          value: 'Nigeria · Smallholder farmers'),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Built with ❤ for Nigerian farmers',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext ctx) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
            'All scan records will be permanently deleted. '
            'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Delete all',
                  style: TextStyle(color: AppColors.dangerFg))),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _clearing = true);
    try {
      await DatabaseService.instance.clearAll();
      await ref.read(scanListProvider.notifier).load();
      ref.read(lastResultProvider.notifier).state      = null;
      ref.read(lastImagePathProvider.notifier).state   = null;
      ref.read(lastScanVarietyProvider.notifier).state = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All scan data cleared')));
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }
}

// ── Dev info row (read-only) ──────────────────────────────────────────────────
class _DevRow extends StatelessWidget {
  const _DevRow({required this.icon, required this.iconColor,
      required this.label, required this.value});
  final IconData icon;
  final Color iconColor;
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
      Flexible(child: Text(value,
          textAlign: TextAlign.end,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              fontFamily: 'monospace'))),
    ]),
  );
}

class _AboutTile extends StatelessWidget {
  const _AboutTile({required this.icon, required this.iconColor,
      required this.title, required this.value});
  final IconData icon;
  final Color iconColor;
  final String title, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
      Text(value,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ]),
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 64, endIndent: 16);
}
