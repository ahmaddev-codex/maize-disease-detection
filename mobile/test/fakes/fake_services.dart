import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:maizeguard/models/scan_record.dart';
import 'package:maizeguard/services/ai_advisor.dart';
import 'package:maizeguard/services/classifier_service.dart';
import 'package:maizeguard/services/database_service.dart';
import 'package:maizeguard/services/location_service.dart';

/// In-memory stand-in for [DatabaseService]; only the members tests use are real.
class FakeDatabaseService implements DatabaseService {
  FakeDatabaseService([Map<int, ScanRecord>? records]) : records = records ?? {};

  final Map<int, ScanRecord> records;

  /// When set, getScanById waits on this completer (to observe loading states).
  Completer<void>? lookupGate;

  @override
  Future<ScanRecord?> getScanById(int id) async {
    if (lookupGate != null) await lookupGate!.future;
    return records[id];
  }

  @override
  Future<void> updateFeedback(int id, int feedback) async {
    final record = records[id];
    if (record != null) records[id] = record.copyWith(feedback: feedback);
  }

  /// Advice writes, recorded so tests can assert what was stored (T24).
  final List<({int id, String language, String source})> adviceWrites = [];

  @override
  Future<void> saveAdvice(
    int id, {
    required String advice,
    required String language,
    required String source,
    String? model,
    DateTime? createdAt,
  }) async {
    adviceWrites.add((id: id, language: language, source: source));
    final record = records[id];
    if (record != null) {
      records[id] = record.copyWith(
        aiAdvice: advice,
        aiLanguage: language,
        aiSource: source,
        aiModel: model,
        aiCreatedAt: createdAt ?? DateTime.now().toUtc(),
      );
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records advice requests instead of calling Groq.
class FakeAiAdvisor implements AiAdvisor {
  final List<({int classId, String? cropVariety})> calls = [];

  @override
  Future<AdviceResponse> getAdvice({
    required int classId,
    required double confidence,
    required String? cropVariety,
    String? apiKey,
    String language = 'English',
  }) async {
    calls.add((classId: classId, cropVariety: cropVariety));
    return AdviceResponse(
      text: 'Advice for class $classId',
      source: 'groq',
      model: 'fake-model',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Test double for [ClassifierService]; records calls and returns canned results.
class FakeClassifierService implements ClassifierService {
  FakeClassifierService({
    this.status = 'EfficientNetB3 · FP16',
    this.result,
    this.loadError,
    this.loadDelay = Duration.zero,
  });

  final String status;
  final ClassificationResult? result;
  Object? loadError;
  final Duration loadDelay;

  int loadCalls = 0;
  final List<String> classifiedPaths = [];

  @override
  String get modelStatus => status;

  @override
  Future<void> loadModel() async {
    loadCalls++;
    // Only schedule a timer when asked: testWidgets' fake clock never fires
    // timers unless the test pumps, so an unconditional delay hangs the test.
    if (loadDelay > Duration.zero) await Future<void>.delayed(loadDelay);
    if (loadError != null) throw loadError!;
  }

  @override
  Future<ClassificationResult> classify(String imagePath) async {
    classifiedPaths.add(imagePath);
    return result ??
        const ClassificationResult(
          classId: 3,
          className: 'Healthy',
          shortName: 'Healthy',
          confidence: 0.9,
          allScores: [0.03, 0.03, 0.04, 0.9],
          latencyMs: 12,
        );
  }

  @override
  Future<void> dispose() async {}
}

/// Test double for [LocationService] with an optional artificial delay.
class FakeLocationService implements LocationService {
  FakeLocationService({this.position, this.delay = Duration.zero});

  final Position? position;
  final Duration delay;
  int calls = 0;

  @override
  Future<Position?> getCurrentPosition() async {
    calls++;
    await Future<void>.delayed(delay);
    return position;
  }
}
