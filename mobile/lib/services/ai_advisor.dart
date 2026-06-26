import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_env.dart';
import '../constants/diseases.dart';

class AiAdvisor {
  static final AiAdvisor instance = AiAdvisor._();
  AiAdvisor._();

  static const _geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  String _prompt(int classId, double confidence, String? cropVariety) {
    final disease = diseaseForClass(classId);
    final variety = cropVariety != null ? 'Crop variety: $cropVariety.' : '';
    return '''
You are an agronomist advising a Nigerian smallholder maize farmer.

Diagnosis: ${disease.name} (confidence ${(confidence * 100).toStringAsFixed(0)}%).
$variety

Provide:
1. A brief explanation of the disease in plain language (2 sentences max).
2. Three immediate treatment steps using fungicides available in Nigerian markets.
3. Two prevention measures for the next planting season.
4. When to re-inspect the crop.

Keep the response concise and practical. Use Nigerian market fungicide names where possible
(e.g. Mancozeb, Ridomil, Funguran, Dithane M-45).
''';
  }

  /// Returns AI agronomic advice.
  ///
  /// Debug builds → Ollama (local, no key needed, config from .env.json).
  /// Release builds → Gemini (uses [apiKey] if supplied, falls back to
  ///   the GEMINI_API_KEY build define from .env.json).
  Future<String> getAdvice({
    required int classId,
    required double confidence,
    required String? cropVariety,
    String? apiKey,
  }) {
    final prompt = _prompt(classId, confidence, cropVariety);
    return AppEnv.useOllama
        ? _ollama(prompt)
        : _gemini(prompt, apiKey);
  }

  // ── Gemini ─────────────────────────────────────────────────────────────────
  Future<String> _gemini(String prompt, String? runtimeKey) async {
    final key = (runtimeKey?.isNotEmpty == true)
        ? runtimeKey!
        : AppEnv.geminiApiKey;
    if (key.isEmpty) throw Exception('No Gemini API key configured');

    final response = await http.post(
      Uri.parse('$_geminiEndpoint?key=$key'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {'parts': [{'text': prompt}]}
        ],
        'generationConfig': {'maxOutputTokens': 512, 'temperature': 0.3},
      }),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Gemini ${response.statusCode}: ${response.body}');
    }

    final json       = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Empty Gemini response');
    }
    return candidates.first['content']['parts'][0]['text'] as String;
  }

  // ── Ollama ─────────────────────────────────────────────────────────────────
  Future<String> _ollama(String prompt) async {
    final base = AppEnv.ollamaHost.replaceAll(RegExp(r'/+$'), '');
    final response = await http.post(
      Uri.parse('$base/api/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model':   AppEnv.ollamaModel,
        'prompt':  prompt,
        'stream':  false,
        'options': {'temperature': 0.3, 'num_predict': 512},
      }),
    ).timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw Exception('Ollama ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final text = json['response'] as String?;
    if (text == null || text.isEmpty) throw Exception('Empty Ollama response');
    return text;
  }
}
