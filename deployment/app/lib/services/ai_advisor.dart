import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/prediction.dart';
import 'database.dart';
import 'recommendation_engine.dart';

/// Gemini API advisor with on-device fallback.
///
/// Calls Google Gemini 2.0 Flash with a structured agronomic prompt.
/// Falls back to [RecommendationEngine] on network errors; surfaces
/// auth / parse errors so the UI can show them to the user.
class AiAdvisor {
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'gemini_api_key';
  static const _model = 'gemini-2.0-flash';
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  /// Last error from the Gemini API call, if any.
  /// Cleared on every successful call; set when the API key is present but
  /// the call fails for a non-network reason (auth, quota, parse, etc.).
  static String? lastApiError;

  // ── In-memory fallback ──────────────────────────────────────────────────────
  // Used on macOS when the app is unsigned and Keychain access (-34018) fails.
  // The key is session-only in that case but the feature still works.
  static String? _memoryKey;

  // ── API key management ──────────────────────────────────────────────────────

  static Future<String?> getApiKey() async {
    if (_memoryKey != null) return _memoryKey;
    try {
      return await _storage.read(key: _keyName);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveApiKey(String key) async {
    final trimmed = key.trim();
    _memoryKey = trimmed;
    try {
      await _storage.write(key: _keyName, value: trimmed);
    } catch (_) {
      // Keychain unavailable (e.g. unsigned macOS debug build) — keep in memory.
    }
  }

  static Future<void> clearApiKey() async {
    _memoryKey = null;
    try {
      await _storage.delete(key: _keyName);
    } catch (_) {}
  }

  // ── Main entry point ────────────────────────────────────────────────────────

  /// Returns a [RecommendationResult].
  /// Tries Gemini API first; falls back to on-device engine on transient
  /// network errors. Auth / parse errors are stored in [lastApiError] and
  /// also returned via [RecommendationResult.apiError].
  static Future<RecommendationResult> advise({
    required int classId,
    required double confidence,
    required String? cropVariety,
    required String? plantingDate,
    required String? batchNumber,
    required double? latitude,
    required double? longitude,
    List<ScanRecord>? recentHistory,
  }) async {
    lastApiError = null;
    final apiKey = await getApiKey();
    String? apiError;

    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final result = await _callGeminiApi(
          apiKey: apiKey,
          classId: classId,
          confidence: confidence,
          cropVariety: cropVariety,
          plantingDate: plantingDate,
          batchNumber: batchNumber,
          latitude: latitude,
          longitude: longitude,
          recentHistory: recentHistory,
        );
        return result;
      } on SocketException catch (e) {
        // Network unreachable — silent fallback is acceptable
        apiError = 'Network error: ${e.message}';
        debugPrint('[AiAdvisor] Network error, falling back: $e');
      } on http.ClientException catch (e) {
        apiError = 'Network error: ${e.message}';
        debugPrint('[AiAdvisor] HTTP client error, falling back: $e');
      } catch (e) {
        // Auth / quota / parse errors — expose to UI
        apiError = e.toString();
        debugPrint('[AiAdvisor] Gemini API failed: $e');
      }
    }

    lastApiError = apiError;

    // On-device fallback
    final result = await RecommendationEngine.generate(
      classId: classId,
      confidence: confidence,
      cropVariety: cropVariety,
      plantingDate: plantingDate,
      recentHistory: recentHistory,
    );

    // Surface the API error through the result so the UI can show it
    if (apiError != null) {
      return RecommendationResult(
        urgency: result.urgency,
        headline: result.headline,
        summary: result.summary,
        immediateActions: result.immediateActions,
        fungicideOptions: result.fungicideOptions,
        timingAdvice: result.timingAdvice,
        resistanceNote: result.resistanceNote,
        preventionTips: result.preventionTips,
        trend: result.trend,
        season: result.season,
        source: result.source,
        apiError: apiError,
      );
    }
    return result;
  }

  // ── Gemini API call ─────────────────────────────────────────────────────────

  static Future<RecommendationResult> _callGeminiApi({
    required String apiKey,
    required int classId,
    required double confidence,
    required String? cropVariety,
    required String? plantingDate,
    required String? batchNumber,
    required double? latitude,
    required double? longitude,
    List<ScanRecord>? recentHistory,
  }) async {
    final diseaseInfo = DiseaseInfo.catalogue[classId]!;

    String historySummary = 'No prior scan history available.';
    if (recentHistory != null && recentHistory.isNotEmpty) {
      final counts = <String, int>{};
      for (final s in recentHistory.take(10)) {
        counts[s.className] = (counts[s.className] ?? 0) + 1;
      }
      historySummary = counts.entries
          .map((e) => '${e.key}: ${e.value} scan(s)')
          .join(', ');
    }

    final prompt = '''You are an expert agronomist advising Nigerian smallholder maize farmers.

SCAN RESULT:
- Disease detected: ${diseaseInfo.fullName}
- Confidence: ${(confidence * 100).toStringAsFixed(1)}%
- Crop variety: ${cropVariety ?? 'Unknown'}
- Planting date: ${plantingDate ?? 'Unknown'}
- Seed batch: ${batchNumber ?? 'Unknown'}
- GPS location: ${latitude != null ? '${latitude.toStringAsFixed(4)}°N, ${longitude!.toStringAsFixed(4)}°E (Nigeria)' : 'Not available'}
- Recent scan history (last 10 scans): $historySummary

Provide practical, specific advice structured as follows:

1. URGENCY: one of [none / low / medium / high]
2. IMMEDIATE STEPS (3–5 bullet points, specific to Nigerian conditions)
3. FUNGICIDE RECOMMENDATIONS (mention specific brands available in Nigeria with application rates)
4. APPLICATION TIMING (consider Nigerian growing seasons: main season Mar–Jul, off-season Aug–Nov)
5. RESISTANCE MANAGEMENT (if applicable)
6. PREVENTION (2–3 tips for next season)

Keep advice concise and practical for farmers with limited resources. Mention specific product brands sold in Nigerian agro-dealer shops where possible.''';

    final uri = Uri.parse('$_baseUrl?key=$apiKey');
    final response = await http
        .post(
          uri,
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              'maxOutputTokens': 1024,
              'temperature': 0.4,
            },
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception(
          'Gemini API error ${response.statusCode}: ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    // Null-safe navigation through the response tree.
    // Gemini can return candidates without a content field (e.g. safety blocks).
    final candidates = body['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception(
          'Gemini returned no candidates. The prompt may have been blocked '
          'by safety filters.');
    }
    final firstCandidate = candidates[0] as Map<String, dynamic>;
    final content = firstCandidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    String? text;
    if (parts != null && parts.isNotEmpty) {
      final part0 = parts[0] as Map<String, dynamic>?;
      text = part0?['text'] as String?;
    }
    if (text == null || text.isEmpty) {
      final finishReason = firstCandidate['finishReason'] ?? 'UNKNOWN';
      throw Exception(
          'Gemini response contained no text (finishReason: $finishReason). '
          'Check your API key and quota.');
    }

    return _parseResponse(
      text: text,
      classId: classId,
      confidence: confidence,
      cropVariety: cropVariety,
      plantingDate: plantingDate,
      recentHistory: recentHistory,
    );
  }

  // ── Parse Gemini's free-text response into a RecommendationResult ───────────

  static Future<RecommendationResult> _parseResponse({
    required String text,
    required int classId,
    required double confidence,
    required String? cropVariety,
    required String? plantingDate,
    List<ScanRecord>? recentHistory,
  }) async {
    Urgency urgency = Urgency.medium;
    final urgencyMatch =
        RegExp(r'URGENCY[:\s]+(\w+)', caseSensitive: false).firstMatch(text);
    if (urgencyMatch != null) {
      urgency = switch (urgencyMatch.group(1)!.toLowerCase()) {
        'none'   => Urgency.none,
        'low'    => Urgency.low,
        'high'   => Urgency.high,
        _        => Urgency.medium,
      };
    }

    final sections = _extractSections(text);

    final baseline = await RecommendationEngine.generate(
      classId: classId,
      confidence: confidence,
      cropVariety: cropVariety,
      plantingDate: plantingDate,
      recentHistory: recentHistory,
    );

    return RecommendationResult(
      urgency: urgency,
      headline: baseline.headline,
      summary: sections['IMMEDIATE STEPS'] ?? text.split('\n').take(3).join(' '),
      immediateActions: _extractBullets(sections['IMMEDIATE STEPS'] ?? ''),
      fungicideOptions: baseline.fungicideOptions,
      timingAdvice: sections['APPLICATION TIMING'] ?? baseline.timingAdvice,
      resistanceNote: sections['RESISTANCE MANAGEMENT'],
      preventionTips: _extractBullets(sections['PREVENTION'] ?? ''),
      trend: baseline.trend,
      season: baseline.season,
      source: RecommendationSource.geminiApi,
    );
  }

  static Map<String, String> _extractSections(String text) {
    final sections = <String, String>{};
    final lines = text.split('\n');
    String? currentKey;
    final buffer = StringBuffer();

    for (final line in lines) {
      final headerMatch =
          RegExp(r'^\d+\.\s+([A-Z][A-Z\s]+[A-Z])', caseSensitive: true)
              .firstMatch(line.trim());
      if (headerMatch != null) {
        if (currentKey != null) {
          sections[currentKey] = buffer.toString().trim();
          buffer.clear();
        }
        currentKey = headerMatch.group(1)!.trim();
      } else if (currentKey != null) {
        buffer.writeln(line);
      }
    }
    if (currentKey != null) {
      sections[currentKey] = buffer.toString().trim();
    }
    return sections;
  }

  static List<String> _extractBullets(String section) {
    return section
        .split('\n')
        .map((l) => l.trim())
        .where((l) =>
            l.startsWith('-') || l.startsWith('•') || l.startsWith('*'))
        .map((l) => l.replaceFirst(RegExp(r'^[-•*]\s*'), ''))
        .where((l) => l.isNotEmpty)
        .toList();
  }
}
