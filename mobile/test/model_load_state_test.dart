import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizeguard/providers/app_provider.dart';
import 'package:maizeguard/providers/classifier_state.dart';
import 'package:maizeguard/providers/service_providers.dart';
import 'package:maizeguard/screens/home_screen.dart';

import 'fakes/fake_services.dart';

class _EmptyScanList extends ScanListNotifier {
  @override
  Future<void> load({int? classFilter}) async {}
}

ProviderContainer _containerWith(FakeClassifierService classifier) {
  final container = ProviderContainer(overrides: [
    classifierServiceProvider.overrideWithValue(classifier),
    scanListProvider.overrideWith((ref) => _EmptyScanList()),
  ]);
  addTearDown(container.dispose);
  return container;
}

Future<void> _pumpHome(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  group('ClassifierStateNotifier', () {
    test('a failed load becomes a failed state instead of throwing', () async {
      final container = _containerWith(FakeClassifierService(loadError: Exception('dlopen failed')));

      await container.read(classifierStateProvider.notifier).load();

      final state = container.read(classifierStateProvider);
      expect(state.phase, ClassifierPhase.failed);
      expect(state.error, isNotEmpty);
    });

    test('a successful load reports the variant that actually loaded', () async {
      final container = _containerWith(FakeClassifierService(status: 'EfficientNetB3 · FP16'));

      await container.read(classifierStateProvider.notifier).load();

      final state = container.read(classifierStateProvider);
      expect(state.phase, ClassifierPhase.ready);
      expect(state.status, 'EfficientNetB3 · FP16');
    });

    test('concurrent load calls load the model only once', () async {
      final fake = FakeClassifierService(loadDelay: const Duration(milliseconds: 20));
      final container = _containerWith(fake);
      final notifier = container.read(classifierStateProvider.notifier);

      await Future.wait([notifier.load(), notifier.load()]);

      expect(fake.loadCalls, 1);
    });
  });

  group('HomeScreen model status', () {
    testWidgets('shows the loaded model variant', (tester) async {
      final container = _containerWith(FakeClassifierService(status: 'EfficientNetB3 · FP16'));
      await container.read(classifierStateProvider.notifier).load();

      await _pumpHome(tester, container);

      expect(find.text('EfficientNetB3 · FP16'), findsOneWidget);
      expect(find.byKey(const Key('model-retry-button')), findsNothing);
    });

    testWidgets('a failed load shows an error with a Retry that reloads the model', (tester) async {
      final fake = FakeClassifierService(loadError: Exception('dlopen failed'));
      final container = _containerWith(fake);
      await container.read(classifierStateProvider.notifier).load();

      await _pumpHome(tester, container);

      expect(find.text('Disease model failed to load'), findsOneWidget);
      expect(tester.takeException(), isNull);

      fake.loadError = null;
      await tester.tap(find.byKey(const Key('model-retry-button')));
      await tester.pump();

      expect(fake.loadCalls, 2);
      expect(container.read(classifierStateProvider).phase, ClassifierPhase.ready);
    });
  });
}
