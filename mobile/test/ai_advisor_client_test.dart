import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:maizeguard/config/app_env.dart';
import 'package:maizeguard/services/ai_advisor.dart';

/// T26: the advisor tried five models at 25 s each, could show the model's
/// private "reasoning" as advice, and presented offline fallback text under a
/// "Powered by GPT OSS 120B" badge.
void main() {
  String chatBody({String? content, String? reasoning}) => jsonEncode({
        'choices': [
          {
            'message': {
              if (content != null) 'content': content,
              if (reasoning != null) 'reasoning': reasoning,
            }
          }
        ]
      });

  Future<AdviceResponse> adviceFrom(
    MockClient client, {
    Duration deadline = const Duration(seconds: 20),
  }) =>
      AiAdvisor.withClient(client, deadline: deadline).getAdvice(
        classId: 1,
        confidence: 0.92,
        cropVariety: 'SAMMAZ 15',
        apiKey: 'test-key',
      );

  test('a good answer is attributed to the model that gave it', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response(chatBody(content: 'Look for a triazole.'), 200);
    });

    final advice = await adviceFrom(client);

    expect(requests, 1);
    expect(advice.source, 'groq');
    expect(advice.model, isNotEmpty);
    expect(advice.text, contains('triazole'));
    expect(advice.offlineReason, isNull);
  });

  test('a rejected key stops after one request and says why', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response('{"error":{"message":"Invalid API Key"}}', 401);
    });

    final advice = await adviceFrom(client);

    expect(requests, 1, reason: 'a bad key was retried against every model');
    expect(advice.source, 'offline');
    expect(advice.offlineReason, contains('key'));
    expect(advice.text, isNotEmpty);
  });

  test('no connection stops after one request and says so', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      throw const SocketException('Failed host lookup');
    });

    final advice = await adviceFrom(client);

    expect(requests, 1, reason: 'an offline phone was dialled once per model');
    expect(advice.source, 'offline');
    expect(advice.offlineReason!.toLowerCase(), anyOf(contains('connect'), contains('offline'), contains('internet')));
  });

  test('the model\'s private reasoning is never passed off as advice', () async {
    const secret = 'The user probably wants me to guess a disease';
    final client = MockClient((request) async =>
        http.Response(chatBody(content: '', reasoning: secret), 200));

    final advice = await adviceFrom(client);

    expect(advice.source, 'offline');
    expect(advice.text, isNot(contains(secret)));
  });

  test('a hanging server does not hold the farmer past the deadline', () async {
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(seconds: 5));
      return http.Response(chatBody(content: 'too late'), 200);
    });

    final stopwatch = Stopwatch()..start();
    final advice = await adviceFrom(client, deadline: const Duration(milliseconds: 150));
    stopwatch.stop();

    expect(advice.source, 'offline');
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
    expect(advice.offlineReason!.toLowerCase(), contains('time'));
  });

  test('a server error tries the next model, but only while time remains', () async {
    final tried = <String>[];
    final client = MockClient((request) async {
      tried.add(jsonDecode(request.body)['model'] as String);
      return http.Response('{"error":"overloaded"}', 503);
    });

    final advice = await adviceFrom(client);

    expect(tried.length, greaterThan(1), reason: 'a transient 503 should fall through to a backup model');
    expect(tried.toSet(), hasLength(tried.length), reason: 'the same model was tried twice');
    expect(advice.source, 'offline');
  });

  test('every configured model is one Groq actually serves', () async {
    final fixture = jsonDecode(
      File('test/fixtures/groq_models.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final served = (fixture['data'] as List)
        .map((entry) => (entry as Map<String, dynamic>)['id'] as String)
        .toSet();

    expect(AppEnv.groqModels, isNotEmpty);
    for (final model in AppEnv.groqModels) {
      expect(served, contains(model), reason: '$model is not in the recorded model list');
    }
  });

  test('no key at all is an offline result, not a failed request', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response(chatBody(content: 'never'), 200);
    });

    final advice = await AiAdvisor.withClient(client).getAdvice(
      classId: 3,
      confidence: 0.97,
      cropVariety: null,
      apiKey: '',
    );

    expect(requests, 0);
    expect(advice.source, 'offline');
    expect(advice.offlineReason!.toLowerCase(), contains('key'));
  });
}
