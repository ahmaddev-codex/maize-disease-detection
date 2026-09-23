import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_env.dart';
import '../constants/diseases.dart';
import 'advice_prompt.dart';

/// Advice plus where it came from. The screen stores the provenance with the
/// scan, so "offline mode" text is never replayed as if Groq had answered (T24).
class AdviceResponse {
  const AdviceResponse({required this.text, required this.source, this.model});

  /// 'groq' when a model answered, 'offline' for the built-in rules.
  final String source;
  final String text;
  final String? model;

  bool get isOffline => source == 'offline';
}

class AiAdvisor {
  static final AiAdvisor instance = AiAdvisor._();
  AiAdvisor._();

  static const _groqEndpoint = 'https://api.groq.com/openai/v1/chat/completions';

  /// Strips all markdown syntax (**, *, #, ##, ###, _, tables, backticks)
  /// so text displays cleanly in UI and reads naturally via voice.
  static String sanitizeAiText(String text) {
    var cleaned = text;
    // Remove markdown headers: #, ##, ###, ####
    cleaned = cleaned.replaceAll(RegExp(r'^#+\s*', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'#+'), '');

    // Convert markdown bullet asterisks or dashes at start of line into clean bullet points
    cleaned = cleaned.replaceAll(RegExp(r'^\s*[\*\-]\s+', multiLine: true), '• ');

    // Remove bold and italic markers: **, __, *, _
    cleaned = cleaned.replaceAll('**', '');
    cleaned = cleaned.replaceAll('__', '');
    cleaned = cleaned.replaceAll(RegExp(r'(?<!\w)\*([^*]+)\*(?!\w)'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'(?<!\w)_([^_]+)_(?!\w)'), r'$1');
    // Strip any remaining orphan asterisks
    cleaned = cleaned.replaceAll('*', '');

    // Remove backticks
    cleaned = cleaned.replaceAll('`', '');
    // Clean markdown table separators like |---|---|
    cleaned = cleaned.replaceAll(RegExp(r'\|[-:\s|]+\|'), '');
    // Replace markdown table pipes with clean bullets or separators
    cleaned = cleaned.replaceAll(RegExp(r'^\s*\|\s*', multiLine: true), '• ');
    cleaned = cleaned.replaceAll(RegExp(r'\s*\|\s*'), ' — ');
    cleaned = cleaned.replaceAll('|', ' ');
    // Clean excessive empty lines
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return cleaned.trim();
  }

  String _prompt(int classId, double confidence, String? cropVariety, String language) =>
      buildAdvicePrompt(
        classId: classId,
        confidence: confidence,
        cropVariety: cropVariety,
        language: language,
      );

  String _translatePrompt(String language, String englishContent) => '''
Translate the following agricultural advisory into $language for a Nigerian smallholder farmer.
CRITICAL FORMATTING RULES:
- Never use hashtags (#, ##, ###) or asterisks (** or *).
- Keep active ingredient names (e.g. mancozeb, azoxystrobin, propiconazole, tebuconazole) in English so they can be matched on a product label.
- Keep the same structure with plain capitalized headings and simple bullet points (•).
- Keep language direct, natural, and conversational for voice text-to-speech.

---
$englishContent
---
''';

  /// Generates agronomic advice using Groq (openai/gpt-oss-120b).
  /// Falls back seamlessly to built-in offline clinical rules if network or key fails.
  Future<AdviceResponse> getAdvice({
    required int classId,
    required double confidence,
    required String? cropVariety,
    String? apiKey,
    String language = 'English',
  }) async {
    final key = (apiKey != null && apiKey.trim().isNotEmpty)
        ? apiKey.trim()
        : AppEnv.groqApiKey;

    final prompt = _prompt(classId, confidence, cropVariety, language);

    if (key.isNotEmpty) {
      try {
        final response = await _callGroq(prompt, key);
        if (response.text.trim().isNotEmpty) {
          return AdviceResponse(
            text: sanitizeAiText(response.text),
            source: 'groq',
            model: response.model,
          );
        }
      } catch (_) {
        // Fall back to offline rule-based recommendation
      }
    }

    return AdviceResponse(
      text: sanitizeAiText(_buildOfflineAdvice(classId, confidence, cropVariety, language)),
      source: 'offline',
    );
  }

  /// Translates result text into [language] via Groq.
  Future<String> translateResult({
    required String englishContent,
    required String language,
    String? apiKey,
  }) async {
    if (language == 'English') return sanitizeAiText(englishContent);

    final key = (apiKey != null && apiKey.trim().isNotEmpty)
        ? apiKey.trim()
        : AppEnv.groqApiKey;

    if (key.isNotEmpty) {
      try {
        final prompt = _translatePrompt(language, englishContent);
        final response = await _callGroq(prompt, key);
        if (response.text.trim().isNotEmpty) {
          return sanitizeAiText(response.text);
        }
      } catch (_) {
        // Return original if translation service fails
      }
    }

    return sanitizeAiText(englishContent);
  }

  Future<({String text, String model})> _callGroq(String prompt, String apiKey) async {
    final candidateModels = <String>[
      AppEnv.groqModel,
      if (AppEnv.groqModel != 'openai/gpt-oss-120b') 'openai/gpt-oss-120b',
      'openai/gpt-oss-20b',
      'qwen/qwen3.6-27b',
      'qwen/qwen3.8-27b',
    ];

    String? lastError;

    for (final model in candidateModels) {
      try {
        final response = await http.post(
          Uri.parse(_groqEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {
                'role': 'system',
                'content':
                    'You are an expert agronomist advising Nigerian smallholder maize farmers. Provide practical, field-tested guidance. Do not use markdown headers (#) or bold asterisks (**). Use clean plain text with simple bullet points (•).',
              },
              {'role': 'user', 'content': prompt},
            ],
            'temperature': 0.2,
            'max_tokens': 800,
          }),
        ).timeout(const Duration(seconds: 25));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final choice = data['choices']?[0];
          String? text = choice?['message']?['content'] as String?;
          if (text == null || text.trim().isEmpty) {
            text = choice?['message']?['reasoning'] as String?;
          }
          if (text != null && text.trim().isNotEmpty) {
            return (text: sanitizeAiText(text), model: model);
          }
        }

        lastError = 'Groq API (${response.statusCode}): ${response.body}';
      } catch (e) {
        lastError = e.toString();
      }
    }

    throw Exception(lastError ?? 'Failed to get response from Groq API');
  }

  /// Offline clinical fallback generated from verified agronomic knowledge in diseases.dart
  String _buildOfflineAdvice(
      int classId, double confidence, String? cropVariety, String language) {
    final disease = diseaseForClass(classId);
    final mode = adviceModeFor(classId: classId, confidence: confidence);
    final buf = StringBuffer();

    if (mode == AdviceMode.uncertain) {
      // Too unsure to name a disease, so name nothing to spray.
      buf.writeln('OFFLINE ADVICE');
      buf.writeln('This photo was not clear enough to diagnose '
          '(confidence ${(confidence * 100).toStringAsFixed(1)}%).');
      buf.writeln();
      buf.writeln('1. BETTER PHOTO:');
      buf.writeln('• Fill the frame with one leaf, in even daylight');
      buf.writeln('• Avoid shadow, glare and a moving hand');
      buf.writeln();
      buf.writeln('2. MEANWHILE:');
      buf.writeln('• Do not apply any chemical until the disease is confirmed');
      buf.writeln('• Ask an extension officer if the symptoms spread');
      return buf.toString();
    }

    buf.writeln('CLINICAL AGRONOMIC ADVICE (OFFLINE MODE)');
    buf.writeln('Disease: ${disease.name} (${disease.shortName})');
    buf.writeln('Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
    if (cropVariety != null) buf.writeln('Crop Variety: $cropVariety');
    buf.writeln();

    buf.writeln('1. DISEASE SUMMARY:');
    buf.writeln(disease.description);
    buf.writeln();

    if (mode == AdviceMode.healthy) {
      buf.writeln('2. TREATMENT:');
      buf.writeln('• No fungicide is needed for a healthy plant');
    } else {
      buf.writeln('2. IMMEDIATE TREATMENT:');
      for (final t in disease.treatments) {
        buf.writeln('• $t');
      }
      buf.writeln('• Dose, pre-harvest interval and protective equipment are on '
          'the product label; an extension officer can confirm the choice locally');
    }
    buf.writeln();

    buf.writeln('3. PREVENTION:');
    for (final p in disease.prevention) {
      buf.writeln('• $p');
    }
    buf.writeln();

    buf.writeln('4. RE-INSPECTION:');
    buf.writeln(
        'Inspect the field again in 5–7 days to assess disease progression after treatment.');

    return buf.toString();
  }
}
