import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizeguard/providers/app_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// T28: keys belong to the farmer. Removing one had to stick, and nothing in a
/// shipped app may read a developer's machine for credentials.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> drain() => Future<void>.delayed(Duration.zero);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('a saved key is loaded on the next launch', () async {
    final first = GroqKeyNotifier();
    await first.save('gsk_farmer_key');
    await drain();

    final relaunched = GroqKeyNotifier();
    await drain();
    expect(relaunched.state, 'gsk_farmer_key');
  });

  test('a removed key stays removed after a relaunch', () async {
    final notifier = GroqKeyNotifier();
    await notifier.save('gsk_farmer_key');
    await drain();
    await notifier.clear();
    await drain();
    expect(notifier.state, isNull);

    final relaunched = GroqKeyNotifier();
    await drain();
    expect(relaunched.state, isNull,
        reason: 'the removed key came back from the build-time environment');
  });

  test('a key removed by the farmer is not re-seeded from the build', () async {
    // A build with --dart-define GROQ_API_KEY seeds the key once.
    final first = GroqKeyNotifier(envKey: 'gsk_from_build');
    await drain();
    expect(first.state, 'gsk_from_build');

    await first.clear();
    await drain();

    final relaunched = GroqKeyNotifier(envKey: 'gsk_from_build');
    await drain();
    expect(relaunched.state, isNull,
        reason: 'the build-time key was seeded again after the farmer removed it');
  });

  test('a farmer key is never overwritten by the build-time one', () async {
    final notifier = GroqKeyNotifier(envKey: 'gsk_from_build');
    await drain();
    await notifier.save('gsk_farmer_key');
    await drain();

    final relaunched = GroqKeyNotifier(envKey: 'gsk_from_build');
    await drain();
    expect(relaunched.state, 'gsk_farmer_key');
  });

  test('the same holds for the voice key', () async {
    final notifier = YarnGptKeyNotifier();
    await notifier.save('yarn_key');
    await drain();
    await notifier.clear();
    await drain();

    final relaunched = YarnGptKeyNotifier();
    await drain();
    expect(relaunched.state, isNull);
  });

  test('no shipped code reads a path on a developer machine', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains('/Users/') || source.contains('C:\\\\Users')) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty, reason: 'these files reference a developer path');
  });

  test('no key material is printed at startup', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main.contains('groqApiKey.length'), isFalse);
    expect(main.contains('yarnGptApiKey.length'), isFalse);
  });
}
