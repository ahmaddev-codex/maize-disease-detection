import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../design_system/design_system.dart';
import '../providers/app_provider.dart';
import '../services/database_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _groqCtrl = TextEditingController();
  final _yarnCtrl = TextEditingController();
  bool _groqObscure = true;
  bool _yarnObscure = true;
  bool _groqKeySaved = false;
  bool _yarnKeySaved = false;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    final groq = ref.read(groqKeyProvider);
    if (groq != null && groq.isNotEmpty) {
      _groqCtrl.text = groq;
      _groqKeySaved = true;
    }
    final yarn = ref.read(yarnGptKeyProvider);
    if (yarn != null && yarn.isNotEmpty) {
      _yarnCtrl.text = yarn;
      _yarnKeySaved = true;
    }
  }

  @override
  void dispose() {
    _groqCtrl.dispose();
    _yarnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
      appBar: AppBar(
        title: Row(
          children: [
            MaizeGuardLogo(size: 24, isDark: isDark),
            const SizedBox(width: AppSpacing.sm),
            const Text('System & Settings'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
        children: [
          // ── Executive Brand Overview ──────────────────────────────────────
          const MaizeGuardBrandCard(),
          const SizedBox(height: AppSpacing.lg),

          // ── Groq AI Assistant Key Configuration ───────────────────────────
          const _SectionTitle('AGRONOMIC AI ASSISTANT (GROQ)'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldBase.withValues(alpha: 0.12),
                        borderRadius: AppRadii.sm,
                      ),
                      child: const Icon(Icons.psychology_outlined, size: 20, color: AppColors.emeraldBase),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Groq API Key', style: AppTypography.h3),
                          Text(
                            'GPT OSS 120B Frontier Reasoning Model',
                            style: AppTypography.caption.copyWith(color: AppColors.charcoal400),
                          ),
                        ],
                      ),
                    ),
                    if (_groqKeySaved)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.healthy.withValues(alpha: 0.12),
                          borderRadius: AppRadii.full,
                          border: Border.all(color: AppColors.healthy.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'Active',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.healthy,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Powering instant agronomic consultations, chemical treatment regimens, and localized farming recommendations using Groq\'s fastest 120B reasoning engine.',
                  style: AppTypography.bodySmall.copyWith(
                    color: isDark ? AppColors.charcoal300 : AppColors.charcoal700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Groq API Key',
                  controller: _groqCtrl,
                  hintText: 'gsk_...',
                  obscureText: _groqObscure,
                  prefixWidget: const Icon(Icons.lock_outline_rounded, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(_groqObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _groqObscure = !_groqObscure),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Save Groq Key',
                        icon: Icons.check_circle_outline_rounded,
                        backgroundColor: AppColors.primary,
                        onPressed: () async {
                          final key = _groqCtrl.text.trim();
                          if (key.isEmpty) return;
                          await ref.read(groqKeyProvider.notifier).save(key);
                          if (!context.mounted) return;
                          setState(() => _groqKeySaved = true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Groq API key encrypted & saved')),
                          );
                        },
                      ),
                    ),
                    if (_groqKeySaved) ...[
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                        tooltip: 'Remove Key',
                        onPressed: () async {
                          await ref.read(groqKeyProvider.notifier).clear();
                          _groqCtrl.clear();
                          if (mounted) setState(() => _groqKeySaved = false);
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── YarnGPT Voice Synthesis Key Configuration ─────────────────────
          const _SectionTitle('LOCAL VOICE SYNTHESIS (YARNGPT)'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldBase.withValues(alpha: 0.12),
                        borderRadius: AppRadii.sm,
                      ),
                      child: const Icon(Icons.record_voice_over_outlined, size: 20, color: AppColors.emeraldBase),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('YarnGPT API Key', style: AppTypography.h3),
                          Text(
                            'Yoruba, Hausa, & Igbo Authentic Speech Engine',
                            style: AppTypography.caption.copyWith(color: AppColors.charcoal400),
                          ),
                        ],
                      ),
                    ),
                    if (_yarnKeySaved)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.healthy.withValues(alpha: 0.12),
                          borderRadius: AppRadii.full,
                          border: Border.all(color: AppColors.healthy.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'Active',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.healthy,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Synthesizes natural Nigerian language diagnostic audio directly into Yoruba, Hausa, and Igbo voices for non-literate smallholder farmers.',
                  style: AppTypography.bodySmall.copyWith(
                    color: isDark ? AppColors.charcoal300 : AppColors.charcoal700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'YarnGPT API Key',
                  controller: _yarnCtrl,
                  hintText: 'sk_live_...',
                  obscureText: _yarnObscure,
                  prefixWidget: const Icon(Icons.key_outlined, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(_yarnObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _yarnObscure = !_yarnObscure),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Save YarnGPT Key',
                        icon: Icons.check_circle_outline_rounded,
                        backgroundColor: AppColors.primary,
                        onPressed: () async {
                          final key = _yarnCtrl.text.trim();
                          if (key.isEmpty) return;
                          await ref.read(yarnGptKeyProvider.notifier).save(key);
                          if (!context.mounted) return;
                          setState(() => _yarnKeySaved = true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('YarnGPT API key encrypted & saved')),
                          );
                        },
                      ),
                    ),
                    if (_yarnKeySaved) ...[
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                        tooltip: 'Remove Key',
                        onPressed: () async {
                          await ref.read(yarnGptKeyProvider.notifier).clear();
                          _yarnCtrl.clear();
                          if (mounted) setState(() => _yarnKeySaved = false);
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Language Preferences ──────────────────────────────────────────
          const _SectionTitle('ADVISORY & AUDIO LANGUAGE'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Diagnostic Voice & Treatment Translation',
                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Advisory and audio playback language for local farming communities',
                  style: AppTypography.caption.copyWith(color: AppColors.charcoal400),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: DisplayLanguage.values.map((lang) {
                    final currentLang = ref.watch(displayLanguageProvider);
                    final isSelected = currentLang == lang;
                    return ChoiceChip(
                      label: Text(lang.label),
                      selected: isSelected,
                      selectedColor: AppColors.emeraldBase.withValues(alpha: 0.15),
                      backgroundColor: isDark ? AppColors.charcoal900 : AppColors.charcoal100,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.emeraldBase : (isDark ? Colors.white70 : AppColors.charcoal700),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: isSelected ? AppColors.emeraldBase : Colors.transparent,
                      ),
                      onSelected: (_) {
                        ref.read(displayLanguageProvider.notifier).set(lang);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Theme / Display Mode ──────────────────────────────────────────
          const _SectionTitle('INTERFACE PREFERENCES'),
          AppCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('High Contrast Dark Field Mode', style: AppTypography.h3),
              subtitle: Text(
                'Optimized for direct sunlight outdoor farm readability',
                style: AppTypography.caption.copyWith(color: AppColors.charcoal400),
              ),
              value: isDark,
              activeThumbColor: AppColors.emeraldBase,
              onChanged: (_) => ref.read(isDarkModeProvider.notifier).toggle(),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Storage and Diagnostics ───────────────────────────────────────
          const _SectionTitle('LOCAL DATA ENGINE'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: AppRadii.sm,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  ),
                  title: Text('Clear Local Diagnostic Records', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    'Permanently purge all scan logs, GPS coordinates, and cached leaf images',
                    style: AppTypography.caption.copyWith(color: AppColors.charcoal400),
                  ),
                  trailing: _clearing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: _clearing ? null : () => _confirmClear(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── System Metadata & Edge Runtime Specs ──────────────────────────
          const _SectionTitle('EDGE RUNTIME SPECIFICATIONS'),
          const AppCard(
            child: Column(
              children: [
                _SpecRow('Neural Architecture', 'EfficientNetB3 Quantized (INT8 / FP16)'),
                Divider(height: AppSpacing.md),
                _SpecRow('Training Corpus', 'PlantVillage & Field Validation (4,188 Samples)'),
                Divider(height: AppSpacing.md),
                _SpecRow('Active Diagnostic Classes', 'NCLB, Rust, GLS, Healthy Foliage'),
                Divider(height: AppSpacing.md),
                _SpecRow('Edge Framework', 'TensorFlow Lite C++ Runtime via FFI'),
                Divider(height: AppSpacing.md),
                _SpecRow('Target Agro-Ecological Region', 'Sub-Saharan Africa · Nigeria Focus'),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Brand Identity Signature ──────────────────────────────────────
          Center(
            child: Column(
              children: [
                MaizeGuardWordmark(
                  height: 26,
                  isDark: isDark,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Autonomous On-Device Foliage Phenotyping',
                  style: AppTypography.overline.copyWith(
                    color: AppColors.charcoal500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
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
        title: const Text('Purge All Diagnostic Data?'),
        content: const Text(
          'All diagnostic records, geolocation coordinates, and captured leaf pictures will be permanently removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Purge All', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _clearing = true);
    try {
      await DatabaseService.instance.clearAll();
      await ref.read(scanListProvider.notifier).load();
      ref.read(lastResultProvider.notifier).state = null;
      ref.read(lastImagePathProvider.notifier).state = null;
      ref.read(lastScanVarietyProvider.notifier).state = null;
      ref.read(activeScanIdProvider.notifier).state = null;
      messenger.showSnackBar(
        const SnackBar(content: Text('All local diagnostic records purged')),
      );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs, left: AppSpacing.xs),
      child: Text(
        title,
        style: AppTypography.overline.copyWith(
          color: AppColors.charcoal500,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final String value;
  const _SpecRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: isDark ? AppColors.charcoal400 : AppColors.charcoal600,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.charcoal900,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
