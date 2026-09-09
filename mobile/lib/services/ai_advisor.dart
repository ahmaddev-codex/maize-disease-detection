import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_env.dart';
import '../constants/diseases.dart';

class AiAdvisor {
  static final AiAdvisor instance = AiAdvisor._();
  AiAdvisor._();

  static const _groqEndpoint = 'https://api.groq.com/openai/v1/chat/completions';

  String _prompt(int classId, double confidence, String? cropVariety, String language) {
    final disease = diseaseForClass(classId);
    final variety = cropVariety != null ? 'Crop variety: $cropVariety.' : '';
    final langInstruction = language == 'English'
        ? ''
        : '\nRespond entirely in $language. Keep all fungicide brand names in '
          'their original form (do not translate product names like Mancozeb, Ridomil Gold, etc.).';

    return '''
You are an expert agronomist advising a Nigerian smallholder maize farmer.

Diagnosis: ${disease.name} (confidence ${(confidence * 100).toStringAsFixed(1)}%).
$variety

Provide a clear, practical, field-ready diagnosis structured as:
1. Disease summary (2 sentences max in plain, accessible language).
2. Three immediate treatment steps using fungicides available in Nigerian agro-dealer shops (e.g. Mancozeb, Ridomil Gold, Funguran, Dithane M-45, Azoxystrobin). Specify dosage and safety instructions.
3. Two prevention practices for the next planting cycle (e.g. resistant seed varieties, crop rotation, debris burning).
4. Re-inspection schedule.

Keep formatting clean with clear bullet points.$langInstruction
''';
  }

  String _translatePrompt(String language, String englishContent) => '''
Translate the following agricultural advisory into $language for a Nigerian smallholder farmer.
Keep all fungicide brand names (e.g. Mancozeb, Dithane M-45, Ridomil Gold, Funguran) unchanged.
Keep the same structure and concise bullet points.

---
$englishContent
---
''';

  /// Generates agronomic advice using Groq (Llama-3.3-70b-versatile).
  /// Falls back seamlessly to built-in offline clinical rules if network or key fails.
  Future<String> getAdvice({
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
        if (response.trim().isNotEmpty) return response.trim();
      } catch (_) {
        // Fall back to offline rule-based recommendation
      }
    }

    return _buildOfflineAdvice(classId, confidence, cropVariety, language);
  }

  /// Translates result text into [language] via Groq.
  Future<String> translateResult({
    required String englishContent,
    required String language,
    String? apiKey,
  }) async {
    if (language == 'English') return englishContent;

    final key = (apiKey != null && apiKey.trim().isNotEmpty)
        ? apiKey.trim()
        : AppEnv.groqApiKey;

    if (key.isNotEmpty) {
      try {
        final prompt = _translatePrompt(language, englishContent);
        final response = await _callGroq(prompt, key);
        if (response.trim().isNotEmpty) return response.trim();
      } catch (_) {
        // Return original if translation service fails
      }
    }

    return englishContent;
  }

  Future<String> _callGroq(String prompt, String apiKey) async {
    final candidateModels = <String>[
      AppEnv.groqModel,
      if (AppEnv.groqModel != 'openai/gpt-oss-120b') 'openai/gpt-oss-120b',
      'openai/gpt-oss-20b',
      'qwen/qwen3.6-27b',
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
                    'You are an expert agronomist specializing in Nigerian maize farming and crop diseases. Provide direct, practical, field-tested guidance without filler.',
              },
              {'role': 'user', 'content': prompt},
            ],
            'temperature': 0.3,
            'max_tokens': 1024,
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
            return text.trim();
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
    final buf = StringBuffer();

    buf.writeln('CLINICAL AGRONOMIC ADVICE (OFFLINE MODE)');
    buf.writeln('Disease: ${disease.name} (${disease.shortName})');
    buf.writeln('Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
    if (cropVariety != null) buf.writeln('Crop Variety: $cropVariety');
    buf.writeln();

    buf.writeln('1. OVERVIEW:');
    buf.writeln(disease.description);
    buf.writeln();

    buf.writeln('2. IMMEDIATE FIELD ACTIONS:');
    for (final t in disease.treatments) {
      buf.writeln(' • $t');
    }
    buf.writeln();

    buf.writeln('3. PREVENTION & RESISTANCE:');
    for (final p in disease.prevention) {
      buf.writeln(' • $p');
    }
    buf.writeln();

    buf.writeln('4. RE-INSPECTION:');
    buf.writeln(
        'Inspect the field again in 5–7 days to assess disease progression after treatment.');

    return buf.toString();
  }
}
