import 'package:geolocator/geolocator.dart';
import 'package:maizeguard/models/scan_record.dart';
import 'package:maizeguard/services/classifier_service.dart';
import 'package:maizeguard/services/location_service.dart';

/// Test double for [ClassifierService]; records calls and returns canned results.
class FakeClassifierService implements ClassifierService {
  FakeClassifierService({
    this.status = 'EfficientNetB3 · FP16',
    this.result,
    this.loadError,
  });

  final String status;
  final ClassificationResult? result;
  final Object? loadError;

  int loadCalls = 0;
  final List<String> classifiedPaths = [];

  @override
  String get modelStatus => status;

  @override
  Future<void> loadModel() async {
    loadCalls++;
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
  void dispose() {}
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
