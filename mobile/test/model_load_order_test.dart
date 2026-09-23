import 'package:flutter_test/flutter_test.dart';
import 'package:maizeguard/services/classifier_service.dart';

/// ADR-001: FP16 is the primary model (91.10% vs INT8 88.08% on the test split,
/// and INT8 measured slower on CPU). INT8 stays as a fallback.
void main() {
  test('tries FP16 first, then falls back to INT8', () async {
    final tried = <String>[];
    final service = ClassifierService.forTesting((asset) async {
      tried.add(asset);
      throw Exception('no native interpreter in tests');
    });

    await expectLater(service.loadModel(), throwsA(isA<Exception>()));

    expect(tried, hasLength(2));
    expect(tried.first, contains('fp16'));
    expect(tried.last, contains('int8'));
  });
}
