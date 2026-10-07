import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maizeguard/l10n/offline_advice.dart';
import 'package:maizeguard/providers/app_provider.dart' show DisplayLanguage;
import 'package:maizeguard/services/ai_advisor.dart';
import 'package:maizeguard/services/voice_fallback.dart';

/// T27: offline advice came back in English whatever language was selected and
/// said nothing about it, and a failed YarnGPT call put a raw exception in
/// front of the farmer.
void main() {
  group('what language the advice is actually in', () {
    test('offline advice reports English, not the language that was asked for', () async {
      final client = MockClient((_) async => http.Response('nope', 500));
      final advice = await AiAdvisor.withClient(client).getAdvice(
        classId: 1,
        confidence: 0.9,
        cropVariety: null,
        apiKey: 'test-key',
        language: 'Hausa',
      );

      expect(advice.source, 'offline');
      expect(advice.language, 'English');
    });

    test('a model answer is in the language that was requested', () async {
      final client = MockClient((_) async => http.Response(
            '{"choices":[{"message":{"content":"Yi amfani da triazole."}}]}',
            200,
          ));
      final advice = await AiAdvisor.withClient(client).getAdvice(
        classId: 1,
        confidence: 0.9,
        cropVariety: null,
        apiKey: 'test-key',
        language: 'Hausa',
      );

      expect(advice.source, 'groq');
      expect(advice.language, 'Hausa');
    });

    test('the badge says "English (offline)" when the farmer asked for another language', () {
      expect(
        adviceLanguageNote(requested: 'Hausa', actual: 'English', isOffline: true),
        'English (offline)',
      );
      expect(adviceLanguageNote(requested: 'English', actual: 'English', isOffline: true), isNull);
      expect(adviceLanguageNote(requested: 'Hausa', actual: 'Hausa', isOffline: false), isNull);
    });
  });

  group('device voice fallback', () {
    test('picks the first locale the device actually has', () {
      const installed = ['en-US', 'en-NG', 'ha-NG'];
      expect(pickTtsLocale(DisplayLanguage.hausa, installed), 'ha-NG');
      expect(pickTtsLocale(DisplayLanguage.igbo, installed), 'en-NG');
      expect(pickTtsLocale(DisplayLanguage.english, installed), 'en-US');
    });

    test('matches a base tag when only the regional one is installed', () {
      expect(pickTtsLocale(DisplayLanguage.yoruba, const ['yo']), 'yo');
      expect(pickTtsLocale(DisplayLanguage.yoruba, const ['YO-ng']), 'YO-ng');
    });

    test('returns nothing when the device has no usable voice', () {
      expect(pickTtsLocale(DisplayLanguage.hausa, const ['fr-FR']), isNull);
      expect(pickTtsLocale(DisplayLanguage.hausa, const []), isNull);
    });
  });

  group('what the farmer is told when voice fails', () {
    test('no exception class or stack detail reaches the snackbar', () {
      final messages = [
        friendlyVoiceError(const SocketException('Failed host lookup: api.yarngpt.ai')),
        friendlyVoiceError(Exception('500 Internal Server Error')),
        friendlyVoiceError(StateError('bad state')),
        friendlyVoiceError('plain string failure'),
      ];

      for (final message in messages) {
        expect(message, isNotEmpty);
        for (final leak in ['Exception', 'SocketException', 'StateError', 'errno', '#0 ']) {
          expect(message, isNot(contains(leak)), reason: '"$message" leaks $leak');
        }
      }
    });

    test('a connection failure is named as one', () {
      final message = friendlyVoiceError(const SocketException('Failed host lookup'));
      expect(message.toLowerCase(), anyOf(contains('internet'), contains('connect')));
    });
  });

  group('the language picker tells the truth about the engine', () {
    test('with a key, the YarnGPT voice is named', () {
      expect(voiceEngineLabel(DisplayLanguage.english, hasYarnKey: true), 'YarnGPT · Jude');
      expect(voiceEngineLabel(DisplayLanguage.hausa, hasYarnKey: true), 'YarnGPT · Zainab');
    });

    test('without a key, English falls back to the device and others cannot speak', () {
      expect(voiceEngineLabel(DisplayLanguage.english, hasYarnKey: false).toLowerCase(),
          contains('device'));
      final hausa = voiceEngineLabel(DisplayLanguage.hausa, hasYarnKey: false).toLowerCase();
      expect(hausa, contains('key'));
      expect(hausa, isNot(contains('.env')));
    });
  });
}
