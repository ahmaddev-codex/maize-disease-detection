import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../config/app_env.dart';
import '../constants/diseases.dart';
import '../constants/thresholds.dart';
import '../design_system/design_system.dart';
import '../l10n/voice_scripts.dart';
import '../models/scan_record.dart';
import '../providers/app_provider.dart';
import '../providers/service_providers.dart';
import '../services/ai_advisor.dart';
import '../services/path_resolver.dart';
import '../services/yarn_tts_service.dart';
import '../services/recommendation_engine.dart';

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key});
  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

enum AudioSection {
  result,
  treatment,
  aiAdvisor,
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  // Scan whose advice and audio state this screen currently holds
  int? _renderedScanId;
  String? _renderedLanguage;

  // AI Agronomic Advice (Groq Frontier Model)
  String? _aiAdvice;
  String? _aiSource;
  String? _aiModel;
  String? _aiOfflineReason;
  bool _loadingAi = false;
  String? _aiError;

  // Multi-section Voice Controller State
  AudioSection? _activePlayingSection;
  AudioSection? _activeLoadingSection;
  bool _hasAutoPlayed = false;

  final _tts = FlutterTts();
  bool _ttsAvailable = true;

  // Active Treatment Tab: 0 = Immediate, 1 = Cultural, 2 = Chemical, 3 = Prevention
  int _activeTreatmentTab = 0;

  @override
  void initState() {
    super.initState();
    try {
      _tts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _activePlayingSection = null;
            _activeLoadingSection = null;
          });
        }
      });
      _tts.setErrorHandler((_) {
        if (mounted) {
          setState(() {
            _activePlayingSection = null;
            _activeLoadingSection = null;
          });
        }
      });
    } catch (_) {
      _ttsAvailable = false;
    }
  }

  @override
  void dispose() {
    try {
      _tts.stop();
    } catch (_) {}
    YarnTtsService.instance.stop();
    _hasAutoPlayed = false;
    _activePlayingSection = null;
    _activeLoadingSection = null;
    super.dispose();
  }

  /// Returns to wherever this scan was opened from, stopping audio first;
  /// falls back to Home when there is nothing to pop (T22).
  void _goBack() {
    // Stop audio without awaiting: the TTS engine must never hold up going back.
    unawaited(_stopAudio());
    // Navigator's own stack, not GoRouter.canPop(): with the result as the only
    // page the latter still reports true and popping does nothing.
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go('/');
    }
  }

  void _retake() {
    unawaited(_stopAudio());
    context.pushReplacement('/camera');
  }

  Future<void> _stopAudio() async {
    try {
      await _tts.stop();
    } catch (_) {}
    await YarnTtsService.instance.stop();
    if (mounted) {
      setState(() {
        _activeLoadingSection = null;
        _activePlayingSection = null;
      });
    }
  }

  Future<void> _playSectionAudio(
    AudioSection section,
    String text,
    DisplayLanguage lang,
  ) async {
    if (_activePlayingSection == section || _activeLoadingSection == section) {
      await _stopAudio();
      return;
    }

    await _stopAudio();

    final cleanText = _cleanMarkdownForSpeech(text);
    if (cleanText.trim().isEmpty) return;

    if (mounted) {
      setState(() => _activeLoadingSection = section);
    }

    final key = ref.read(yarnGptKeyProvider) ?? AppEnv.yarnGptApiKey;

    // 1. Prioritize YarnGPT high-fidelity voice when API key is available
    if (key.isNotEmpty) {
      try {
        await YarnTtsService.instance.speak(
          text: cleanText,
          apiKey: key,
          voice: lang.yarnVoice,
          onComplete: () {
            if (mounted && _activePlayingSection == section) {
              setState(() => _activePlayingSection = null);
            }
          },
        );
        if (mounted) {
          setState(() {
            _activeLoadingSection = null;
            _activePlayingSection = section;
          });
        }
        return;
      } catch (e) {
        debugPrint('[Audio] YarnGPT playback error: $e');
        if (!lang.isEnglish) {
          if (mounted) {
            setState(() {
              _activeLoadingSection = null;
              _activePlayingSection = null;
            });
          }
          _showSnack('YarnGPT error: $e');
          return;
        }
      }
    }

    // 2. Fallback to device TTS for English if YarnGPT is unconfigured or unavailable
    if (lang.isEnglish) {
      if (!_ttsAvailable) {
        if (mounted) setState(() => _activeLoadingSection = null);
        _showSnack('Device text-to-speech is unavailable.');
        return;
      }
      try {
        await _tts.setLanguage('en-US');
        await _tts.setSpeechRate(0.46);
        if (mounted) {
          setState(() {
            _activeLoadingSection = null;
            _activePlayingSection = section;
          });
        }
        await _tts.speak(cleanText);
      } catch (e) {
        if (mounted) {
          setState(() {
            _activePlayingSection = null;
            _activeLoadingSection = null;
            _ttsAvailable = false;
          });
        }
        _showSnack('Audio playback error: $e');
      }
    } else {
      if (mounted) setState(() => _activeLoadingSection = null);
      _showSnack('YarnGPT API key required for local languages. Configure in Settings or .env.json.');
    }
  }

  String _getResultSpokenSummary(
    DiseaseInfo disease,
    ClassificationResult result,
    Recommendation recs,
    DisplayLanguage lang,
  ) {
    final confPercent = (result.confidence * 100).toStringAsFixed(0);
    final isHealthy = result.classId == kHealthyClassId;

    // Too unsure to act on: ask for a better photo instead of urging treatment.
    // TODO(T27): have these three translations reviewed by native speakers.
    if (recs.needsRetake) {
      return switch (lang) {
        DisplayLanguage.yoruba => 'Aworan naa ko ye wa daradara. E tun ya aworan ewe naa ninu imole to peye ki a to pinnu arun ti o ni.',
        DisplayLanguage.hausa  => 'Hoton bai fito sosai ba. A sake daukar hoton ganyen cikin haske mai kyau kafin a tabbatar da cutar.',
        DisplayLanguage.igbo   => "Foto a edoghi anya nke oma. Biko sere foto akwukwo ahu ozo n'ihe nchacha tupu anyi ekwuo oria ya.",
        DisplayLanguage.english =>
          'This scan is not clear enough to be certain. Please retake the photo in good daylight, with the leaf flat inside the frame, before treating.',
      };
    }

    switch (lang) {
      case DisplayLanguage.yoruba:
        if (isHealthy) {
          return 'Ayewo ti pari. Agbado yin wa ni ilera to peye pelu idaniloju ogorun $confPercent. E tesiwaju lati ma se ayewo oko yin lorekore. Awon alaye to ku wa ni isale.';
        }
        return 'Akiyesi pataki fun agbado yin. Ayewo ti pari, a si ri arun ${disease.name} pelu idaniloju ogorun $confPercent. Igbese itoju kiakia ni a nilo. Awon igbese itoju ati ogun ti o ye ti wa ni imurasile ni isale fun oko yin.';

      case DisplayLanguage.hausa:
        if (isHealthy) {
          return 'Bincike ya kammala. Masarar ku tana da cikakkiyar lafiya da tabbacin kashi $confPercent. Ku ci gaba da kula da gonar akai-akai. Cikakkun bayanai suna nan a kasa.';
        }
        return 'Sanarwa ga manomi. An kammala bincike, an gano cutar ${disease.name} da tabbacin kashi $confPercent. Ana bukatan daukar matakin gaggawa. An shirya cikakken bayanin magani a kasa.';

      case DisplayLanguage.igbo:
        if (isHealthy) {
          return 'Nchoputa zuru ezu. Oka gi di ezigbo mma na ahuike na pasent $confPercent. Gaa n\'ihu na-elekota ubi gi. Ozi ndi ozo di n\'okpuru.';
        }
        return 'Nti nye onye oru ugbo. Nchoputa na-egosi oria ${disease.name} na pasent $confPercent. O di mkpa ime ihe ngwa ngwa iji chebe ubi gi. Atumatu ogwugwo di njikere n\'okpuru.';

      case DisplayLanguage.english:
        if (isHealthy) {
          return 'Diagnostic scan complete. Your maize crop is diagnosed as healthy with $confPercent percent confidence. Continue routine field scouting every 7 to 10 days. Agronomic guidance is outlined below.';
        }
        return 'Attention farmer. Diagnostic scan has identified ${disease.name} with $confPercent percent confidence. ${recs.urgencyLabel}. Recommended treatment actions and agronomic assistant advice are loaded below for your field.';
    }
  }

  String _getTreatmentSpokenSummary(
    DiseaseInfo disease,
    ClassificationResult result,
    Recommendation recs,
    DisplayLanguage lang,
  ) =>
      // One actives table drives every language, so Rust names a triazole in
      // Hausa exactly as it does in English (T25).
      treatmentScript(lang, disease, isLowConfidence: recs.needsRetake);

  String _cleanMarkdownForSpeech(String markdown) {
    var text = markdown;
    // Strip markdown hashtags
    text = text.replaceAll(RegExp(r'#+\s*'), '');
    // Strip bold and italics markers
    text = text.replaceAll(RegExp(r'\*\*|__'), '');
    text = text.replaceAll(RegExp(r'[\*_]'), '');
    text = text.replaceAll(RegExp(r'`+[^`]*`+'), '');
    text = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1');
    // Strip markdown table borders and pipe delimiters
    text = text.replaceAll(RegExp(r'\|[-:\s|]+\|'), '');
    text = text.replaceAll(RegExp(r'\|'), ' ');
    // Strip leading bullet icons
    text = text.replaceAll(RegExp(r'^[•\-\*]\s*', multiLine: true), '');
    text = text.replaceAll('•', '');
    // Ensure section titles pause naturally
    text = text.replaceAll(RegExp(r'([0-9]+\.\s+[A-Z\s]+):'), r'$1. ');
    // Replace newlines with natural pauses
    text = text.replaceAll(RegExp(r'\n+'), '. ');
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    text = text.replaceAll(RegExp(r'\.{2,}'), '.');
    return text.trim();
  }

  String _getAiAdvisorSpokenSummary(
    String advice,
    DiseaseInfo disease,
    ClassificationResult result,
    DisplayLanguage lang,
  ) {
    // Deliver the exact clinical response produced by the assistant
    final cleaned = _cleanMarkdownForSpeech(advice);
    if (cleaned.isNotEmpty) {
      return cleaned;
    }
    return 'Agronomic advisory for ${disease.name}. Follow immediate fungicide and prevention practices.';
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppTypography.bodySmall.copyWith(color: Colors.white)),
        backgroundColor: AppColors.charcoal900,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _fetchGroqAdvice(
    ClassificationResult result,
    String? variety,
    String? groqKey,
    String language, {
    int? scanId,
  }) async {
    setState(() {
      _loadingAi = true;
      _aiError = null;
    });

    try {
      final advice = await ref.read(aiAdvisorProvider).getAdvice(
        classId: result.classId,
        confidence: result.confidence,
        cropVariety: variety,
        apiKey: groqKey,
        language: language,
      );
      final text = AiAdvisor.sanitizeAiText(advice.text);
      // Kept with the scan: reopening it should cost neither a request nor a
      // fresh speech file (T24).
      if (scanId != null) {
        await ref.read(databaseServiceProvider).saveAdvice(
              scanId,
              advice: text,
              language: language,
              source: advice.source,
              model: advice.model,
            );
      }
      if (mounted) {
        setState(() {
          _aiAdvice = text;
          _aiSource = advice.source;
          _aiModel = advice.model;
          _aiOfflineReason = advice.offlineReason;
          _loadingAi = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiError = 'Advice retrieval failed: $e';
          _loadingAi = false;
        });
      }
    }
  }

  Future<void> _recordFeedback(int scanId, int value) async {
    await ref.read(scanListProvider.notifier).setFeedback(scanId, value);
    // Re-read the record so the selected option reflects what was saved.
    ref.invalidate(activeScanRecordProvider);
    if (mounted) {
      _showSnack('Clinical feedback recorded for model calibration');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(displayLanguageProvider);
    final groqKey = ref.watch(groqKeyProvider);
    final activeScanAsync = ref.watch(activeScanRecordProvider);

    // Render nothing scan-specific (and start no audio or advice) until the
    // record for the active scan has loaded.
    if (activeScanAsync.isLoading && !activeScanAsync.hasValue) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            key: Key('result-loading'),
            color: AppColors.emeraldBase,
          ),
        ),
      );
    }

    final ScanRecord? record = activeScanAsync.valueOrNull;

    if (record == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Diagnosis')),
        body: EmptyStateView(
          illustration: const MaizeGuardLogo(size: 60),
          title: 'No Active Scan',
          message: 'Point your camera at a maize leaf or select an image from your library to diagnose.',
          actionLabel: 'Back to Field',
          onAction: () => context.go('/'),
        ),
      );
    }

    // Advice and audio state belong to one scan in one language; start fresh
    // when either changes, and reuse advice already saved for that pair (T24).
    if (record.id != _renderedScanId || lang.label != _renderedLanguage) {
      final scanChanged = record.id != _renderedScanId;
      _renderedScanId = record.id;
      _renderedLanguage = lang.label;
      _aiAdvice = record.adviceFor(lang.label);
      _aiSource = _aiAdvice == null ? null : record.aiSource;
      _aiModel = _aiAdvice == null ? null : record.aiModel;
      _aiOfflineReason = null;
      _aiError = null;
      _loadingAi = false;
      if (scanChanged) _hasAutoPlayed = false;
    }

    final ClassificationResult result = record.toResult();
    final String? cropVariety = record.cropVariety;
    final String resolvedImagePath = PathResolver.resolve(record.imagePath);
    final bool hasImage = record.imagePath.isNotEmpty && File(resolvedImagePath).existsSync();
    final int? currentScanId = record.id;
    final int? existingFeedback = record.feedback;

    final disease = diseaseForClass(result.classId);
    // Urgency now reflects the real farm trend, so 'critical' is reachable (T15).
    final trendDelta = ref.watch(healthTrendProvider).valueOrNull ?? 0.0;
    final recs = RecommendationEngine.generate(result, trend: trendFromDelta(trendDelta));
    final isLowConf = recs.needsRetake;

    // Distinct audio texts for Result, Treatment Plan, and AI Advisor
    final String resultAudioText = _getResultSpokenSummary(disease, result, recs, lang);
    final String treatmentAudioText = _getTreatmentSpokenSummary(disease, result, recs, lang);
    final String? aiAudioText = _aiAdvice != null
        ? _getAiAdvisorSpokenSummary(_aiAdvice!, disease, result, lang)
        : null;

    // Immediate response on voice is auto-loaded as the result comes on
    if (!_hasAutoPlayed) {
      _hasAutoPlayed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _activePlayingSection == null && _activeLoadingSection == null) {
          _playSectionAudio(AudioSection.result, resultAudioText, lang);
        }
      });
    }

    // Auto-fetch Groq agronomic advice so it is loaded and ready with zero farmer friction
    if (_aiAdvice == null && !_loadingAi && _aiError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _aiAdvice == null && !_loadingAi && _aiError == null) {
          _fetchGroqAdvice(result, cropVariety, groqKey, lang.label,
              scanId: currentScanId);
        }
      });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        body: CustomScrollView(
        slivers: [
          // ── Hero Banner with Leaf Sample Image ─────────────────────────────
          SliverAppBar(
            expandedHeight: hasImage ? 260 : 130,
            pinned: true,
            backgroundColor: AppColors.forestDark,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              key: const Key('result-back'),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: _goBack,
            ),
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MaizeGuardLogo(size: 20, isDark: true),
                SizedBox(width: AppSpacing.xs + 2),
                Text(
                  'Diagnostic Result',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: hasImage
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(resolvedImagePath), fit: BoxFit.cover),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.25),
                                Colors.transparent,
                                AppColors.forestDark.withValues(alpha: 0.95),
                              ],
                              stops: const [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 50,
                          right: AppSpacing.md,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: AppRadii.full,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                MaizeGuardLogo(size: 13, isDark: true),
                                SizedBox(width: 4),
                                Text(
                                  'MaizeGuard Specimen',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: AppColors.forestDark,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const MaizeGuardLogo(
                              size: 56,
                              isDark: true,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'MaizeGuard Foliage Analysis',
                              style: AppTypography.caption.copyWith(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),

          // ── Main Content ──────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 1. Diagnosis Primary Card
                AppCard(
                  color: isDark ? AppColors.surfaceDark : AppColors.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  disease.name,
                                  style: AppTypography.h2.copyWith(
                                    color: isDark ? AppColors.charcoal50 : AppColors.charcoal900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Pathogen: ${disease.shortName} · Model Latency: ${result.latencyMs.toStringAsFixed(0)}ms',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.charcoal500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SeverityBadge(
                            classId: result.classId,
                            label: recs.urgencyLabel,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ConfidenceMeter(
                        confidence: result.confidence,
                        classId: result.classId,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Seed label captured before this scan (T23)
                if (record.cropVariety != null ||
                    record.batchNumber != null ||
                    record.plantingDate != null) ...[
                  AppCard(
                    key: const Key('result-seed-label'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.qr_code_rounded, size: 18, color: AppColors.emeraldBase),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'SEED LABEL ON THIS SCAN',
                              style: AppTypography.overline.copyWith(
                                color: AppColors.emeraldBase,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final field in [
                          ('Variety', record.cropVariety),
                          ('Batch', record.batchNumber),
                          ('Planted', record.plantingDate),
                        ])
                          if (field.$2 != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                '${field.$1}: ${field.$2}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: isDark ? AppColors.charcoal200 : AppColors.charcoal800,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 2. Low-Confidence Retake Alert
                if (isLowConf) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: AppRadii.md,
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Low confidence (below ${(ConfidenceThresholds.low * 100).round()}%) — retake recommended',
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.warning,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ensure direct daylight, clean the camera lens, and hold the leaf flat inside the frame for optimum neural feature extraction.',
                                style: AppTypography.bodySmall.copyWith(
                                  color: isDark ? AppColors.charcoal300 : AppColors.charcoal700,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              AppButton(
                                key: const Key('result-retake'),
                                label: 'Retake photo',
                                icon: Icons.camera_alt_rounded,
                                variant: AppButtonVariant.secondary,
                                onPressed: _retake,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 3. Audio Advisory Bar (Immediate Diagnostic Result Voice)
                AudioAdvisoryBar(
                  title: 'Diagnostic Report Voice',
                  subtitle: _activePlayingSection == AudioSection.result
                      ? 'Playing diagnostic report...'
                      : 'Auto-plays on arrival · Tap to replay',
                  isPlaying: _activePlayingSection == AudioSection.result,
                  isLoading: _activeLoadingSection == AudioSection.result,
                  language: lang.label,
                  onTogglePlay: () => _playSectionAudio(
                    AudioSection.result,
                    resultAudioText,
                    lang,
                  ),
                  onSelectLanguage: () => _showLanguageModal(
                    context,
                    ref,
                    result: result,
                    cropVariety: cropVariety,
                    groqKey: groqKey,
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // 4. Clinical Treatment & Agronomic Action Tabs
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.medication_outlined, size: 20, color: AppColors.emeraldBase),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'RECOMMENDED TREATMENT PLAN',
                            style: AppTypography.overline.copyWith(
                              color: AppColors.emeraldBase,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Dedicated Treatment Plan Audio Player
                      AudioAdvisoryBar(
                        title: 'Treatment Plan Voice',
                        subtitle: _activePlayingSection == AudioSection.treatment
                            ? 'Playing treatment guidelines...'
                            : 'Listen to step-by-step treatment actions',
                        isPlaying: _activePlayingSection == AudioSection.treatment,
                        isLoading: _activeLoadingSection == AudioSection.treatment,
                        language: lang.label,
                        onTogglePlay: () => _playSectionAudio(
                          AudioSection.treatment,
                          treatmentAudioText,
                          lang,
                        ),
                        onSelectLanguage: () => _showLanguageModal(
                          context,
                          ref,
                          result: result,
                          cropVariety: cropVariety,
                          groqKey: groqKey,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Segmented Tab Selector
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _TreatmentTabChip(
                              label: 'Immediate Action',
                              isSelected: _activeTreatmentTab == 0,
                              onTap: () => setState(() => _activeTreatmentTab = 0),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            _TreatmentTabChip(
                              label: 'Cultural Controls',
                              isSelected: _activeTreatmentTab == 1,
                              onTap: () => setState(() => _activeTreatmentTab = 1),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            _TreatmentTabChip(
                              label: 'Fungicides (NG)',
                              isSelected: _activeTreatmentTab == 2,
                              onTap: () => setState(() => _activeTreatmentTab = 2),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            _TreatmentTabChip(
                              label: 'Prevention',
                              isSelected: _activeTreatmentTab == 3,
                              onTap: () => setState(() => _activeTreatmentTab = 3),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: AppSpacing.lg),
                      _buildTreatmentContent(disease, recs, _activeTreatmentTab),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // 5. Groq AI Agronomic Advisor (GPT OSS 120B Frontier Model)
                AppCard(
                  surfaceColor: isDark ? AppColors.surfaceDark : AppColors.surface,
                  borderColor: isDark ? AppColors.charcoal800 : AppColors.charcoal200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.forestDark : AppColors.primaryContainer,
                              borderRadius: AppRadii.sm,
                            ),
                            child: const Icon(
                              Icons.psychology_outlined,
                              size: 20,
                              color: AppColors.emeraldBase,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Agronomic Assistant',
                                  style: AppTypography.h3.copyWith(
                                    color: isDark ? Colors.white : AppColors.charcoal900,
                                  ),
                                ),
                                // Says where this text came from: built-in
                                // rules must never read as a model's reply (T26).
                                Text(
                                  switch (_aiSource) {
                                    'offline' => 'Offline guidance · built-in agronomic rules',
                                    'groq' => 'Answered online by ${_aiModel ?? 'a Groq model'}',
                                    _ => 'Online when a key is set, built-in rules otherwise',
                                  },
                                  key: const Key('result-advice-source'),
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.charcoal400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_aiSource == 'offline' && _aiOfflineReason != null) ...[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.charcoal400.withValues(alpha: 0.12),
                            borderRadius: AppRadii.sm,
                          ),
                          child: Text(
                            _aiOfflineReason!,
                            style: AppTypography.caption.copyWith(color: AppColors.charcoal400),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (_aiError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.12),
                            borderRadius: AppRadii.sm,
                            border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                          ),
                          child: Text(_aiError!, style: AppTypography.caption.copyWith(color: AppColors.danger)),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (_loadingAi) ...[
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              children: [
                                const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    color: AppColors.emeraldBase,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Asking the agronomic assistant…',
                                  style: AppTypography.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else if (_aiAdvice != null) ...[
                        // Dedicated Groq AI Advisor Voice Player
                        AudioAdvisoryBar(
                          title: 'Groq Advisor Voice',
                          subtitle: _activePlayingSection == AudioSection.aiAdvisor
                              ? 'Speaking AI agronomic advisory...'
                              : 'Listen to frontier advice in ${lang.label}',
                          isPlaying: _activePlayingSection == AudioSection.aiAdvisor,
                          isLoading: _activeLoadingSection == AudioSection.aiAdvisor,
                          language: lang.label,
                          onTogglePlay: () => _playSectionAudio(
                            AudioSection.aiAdvisor,
                            aiAudioText ?? '',
                            lang,
                          ),
                          onSelectLanguage: () => _showLanguageModal(
                            context,
                            ref,
                            result: result,
                            cropVariety: cropVariety,
                            groqKey: groqKey,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.charcoal950.withValues(alpha: 0.5) : AppColors.surfaceMuted,
                            borderRadius: AppRadii.md,
                            border: Border.all(color: isDark ? AppColors.charcoal800 : AppColors.charcoal200),
                          ),
                          child: SelectableText(
                            AiAdvisor.sanitizeAiText(_aiAdvice!),
                            style: AppTypography.bodyMedium.copyWith(
                              color: isDark ? AppColors.charcoal100 : AppColors.charcoal900,
                              height: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _fetchGroqAdvice(
                                result,
                                cropVariety,
                                groqKey,
                                lang.label,
                                scanId: currentScanId,
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Regenerate Advice'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.emeraldBase,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          'Generate verified agronomic guidance tailored specifically to Nigerian agro-ecological zones, current rain patterns, and local chemical availability.',
                          style: AppTypography.bodySmall.copyWith(
                            color: isDark ? AppColors.charcoal300 : AppColors.charcoal700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: lang.isEnglish
                              ? 'Request Groq Agronomic Advice'
                              : 'Request Advice in ${lang.label}',
                          icon: Icons.psychology_rounded,
                          backgroundColor: AppColors.primary,
                          onPressed: () => _fetchGroqAdvice(
                            result,
                            cropVariety,
                            groqKey,
                            lang.label,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // 6. Neural Probability Spectrum
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NEURAL NETWORK PROBABILITY SPECTRUM',
                        style: AppTypography.overline.copyWith(
                          color: AppColors.charcoal500,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ...List.generate(4, (i) {
                        const labels = ['Northern Leaf Blight (NCLB)', 'Common Rust', 'Gray Leaf Spot (GLS)', 'Healthy Crop'];
                        final score = result.allScores.length > i ? result.allScores[i] : 0.0;
                        final isTop = i == result.classId;

                        final color = switch (i) {
                          0 => AppColors.nclb,
                          1 => AppColors.rust,
                          2 => AppColors.gls,
                          3 => AppColors.healthy,
                          _ => AppColors.charcoal500,
                        };

                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    labels[i],
                                    style: AppTypography.bodySmall.copyWith(
                                      fontWeight: isTop ? FontWeight.w700 : FontWeight.w500,
                                      color: isTop ? color : (isDark ? AppColors.charcoal300 : AppColors.charcoal700),
                                    ),
                                  ),
                                  Text(
                                    '${(score * 100).toStringAsFixed(1)}%',
                                    style: AppTypography.caption.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: isTop ? color : AppColors.charcoal500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: AppRadii.full,
                                child: LinearProgressIndicator(
                                  value: score,
                                  minHeight: 6,
                                  backgroundColor: color.withValues(alpha: 0.12),
                                  valueColor: AlwaysStoppedAnimation(color),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // 7. Clinical Feedback Rating Card (F65)
                AppCard(
                  child: Column(
                    children: [
                      Text(
                        'Agronomist Verification',
                        style: AppTypography.h3.copyWith(
                          color: isDark ? Colors.white : AppColors.charcoal900,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Does this diagnosis match your physical inspection of the crop?',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.charcoal500,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _FeedbackOption(
                            key: const Key('feedback-correct'),
                            icon: Icons.check_circle_outline_rounded,
                            label: 'Correct',
                            selected: existingFeedback == 1,
                            color: AppColors.healthy,
                            onTap: currentScanId != null
                                ? () => _recordFeedback(currentScanId, 1)
                                : null,
                          ),
                          _FeedbackOption(
                            key: const Key('feedback-incorrect'),
                            icon: Icons.highlight_off_rounded,
                            label: 'Incorrect',
                            selected: existingFeedback == 0,
                            color: AppColors.danger,
                            onTap: currentScanId != null
                                ? () => _recordFeedback(currentScanId, 0)
                                : null,
                          ),
                          _FeedbackOption(
                            key: const Key('feedback-uncertain'),
                            icon: Icons.help_outline_rounded,
                            label: 'Uncertain',
                            selected: existingFeedback == -1,
                            color: AppColors.charcoal400,
                            onTap: currentScanId != null
                                ? () => _recordFeedback(currentScanId, -1)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const MaizeGuardLogo(size: 16),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Verified by MaizeGuard Edge Neural Engine',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.charcoal400,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),
              ]),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildTreatmentContent(DiseaseInfo disease, Recommendation recs, int tabIndex) {
    switch (tabIndex) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: recs.immediateAction.map((action) => _BulletItem(text: action)).toList(),
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: disease.treatments
              .where((t) => !t.toLowerCase().contains('fungicide') && !t.toLowerCase().contains('spray'))
              .map((t) => _BulletItem(text: t))
              .toList(),
        );
      case 2:
        // Straight from the actives table, so the tab, the prompt and the voice
        // script name the same chemistry (T25).
        if (recs.needsRetake) {
          return const _BulletItem(
            text: 'Confirm the diagnosis before applying anything — this photo was not clear enough to be sure.',
          );
        }
        if (disease.actives.isEmpty) {
          return const _BulletItem(
            text: 'No fungicide is needed for this diagnosis. Keep scouting the field.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...disease.actives.map((a) => _BulletItem(text: a)),
            const _BulletItem(
              text: 'Rate, pre-harvest interval and protective equipment are on the product label. Confirm the product with your extension officer.',
            ),
          ],
        );
      case 3:
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: disease.prevention.map((p) => _BulletItem(text: p)).toList(),
        );
    }
  }

  void _showLanguageModal(
    BuildContext context,
    WidgetRef ref, {
    ClassificationResult? result,
    String? cropVariety,
    String? groqKey,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final current = ref.watch(displayLanguageProvider);
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Advisory Language', style: AppTypography.h3.copyWith(color: Colors.white)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Changes speech synthesis voice and agronomic advisory language across all sections',
                style: AppTypography.caption.copyWith(color: AppColors.charcoal400),
              ),
              const SizedBox(height: AppSpacing.md),
              ...DisplayLanguage.values.map(
                (l) => ListTile(
                  title: Text(l.label, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    l.isEnglish
                        ? 'Device Speech Engine · Standard Accent'
                        : 'YarnGPT Native Audio · Voice: ${l.yarnVoice}',
                    style: const TextStyle(color: AppColors.charcoal400, fontSize: 12),
                  ),
                  trailing: current == l ? const Icon(Icons.check_rounded, color: AppColors.emeraldBase) : null,
                  onTap: () {
                    _stopAudio();
                    ref.read(displayLanguageProvider.notifier).set(l);
                    if (_aiAdvice != null && result != null) {
                      _fetchGroqAdvice(result, cropVariety, groqKey, l.label);
                    }
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TreatmentTabChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TreatmentTabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.forestDark : AppColors.primaryContainer)
              : Colors.transparent,
          borderRadius: AppRadii.sm,
          border: Border.all(
            color: isSelected
                ? AppColors.emeraldBase
                : (isDark ? AppColors.charcoal700 : AppColors.charcoal300),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? Colors.white : AppColors.primary)
                : (isDark ? AppColors.charcoal400 : AppColors.charcoal600),
          ),
        ),
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7, right: AppSpacing.sm),
            decoration: const BoxDecoration(
              color: AppColors.emeraldBase,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyMedium.copyWith(
                color: isDark ? AppColors.charcoal100 : AppColors.charcoal800,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;

  const _FeedbackOption({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: AppRadii.md,
          border: Border.all(
            color: selected ? color : AppColors.charcoal700,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? color : AppColors.charcoal400),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : AppColors.charcoal400,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
