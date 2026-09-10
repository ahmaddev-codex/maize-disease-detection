import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maizeguard/providers/service_providers.dart';
import 'package:maizeguard/services/ai_advisor.dart';
import 'package:maizeguard/services/classifier_service.dart';
import 'package:maizeguard/services/database_service.dart';
import 'package:maizeguard/services/location_service.dart';
import 'package:maizeguard/services/yarn_tts_service.dart';

import 'fakes/fake_services.dart';

void main() {
  testWidgets('a widget reads the fake classifier when the provider is overridden', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classifierServiceProvider.overrideWithValue(FakeClassifierService(status: 'Fake · FP16')),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Text(ref.watch(classifierServiceProvider).modelStatus),
          ),
        ),
      ),
    );

    expect(find.text('Fake · FP16'), findsOneWidget);
  });

  test('service providers default to the app singletons', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(classifierServiceProvider), same(ClassifierService.instance));
    expect(container.read(locationServiceProvider), same(LocationService.instance));
    expect(container.read(databaseServiceProvider), same(DatabaseService.instance));
    expect(container.read(aiAdvisorProvider), same(AiAdvisor.instance));
    expect(container.read(yarnTtsServiceProvider), same(YarnTtsService.instance));
  });
}
