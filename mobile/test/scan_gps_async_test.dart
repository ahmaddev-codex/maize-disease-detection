import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maizeguard/models/scan_record.dart';
import 'package:maizeguard/providers/app_provider.dart';
import 'package:maizeguard/services/database_service.dart';
import 'package:maizeguard/services/scan_flow.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fakes/fake_services.dart';

/// T18: classification waited for a high-accuracy GPS fix (up to 10s) before the
/// result appeared. The scan must be saved and shown immediately, with the fix
/// attached afterwards.
const _result = ClassificationResult(
  classId: 2,
  className: 'Gray Leaf Spot',
  shortName: 'GLS',
  confidence: 0.88,
  allScores: [0.04, 0.04, 0.88, 0.04],
  latencyMs: 35,
);

Position _position() => Position(
      latitude: 7.3775,
      longitude: 3.9470,
      timestamp: DateTime.utc(2026, 9, 23),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseService db;
  late ScanListNotifier scans;

  setUp(() async {
    db = DatabaseService.forTesting();
    await db.init(path: inMemoryDatabasePath);
    scans = ScanListNotifier(db);
  });

  tearDown(() => db.close());

  test('the scan is saved before the GPS fix arrives', () async {
    final location = FakeLocationService(
      position: _position(),
      delay: const Duration(seconds: 10),
    );

    final saved = await saveScan(
      imagePath: 'scans/leaf.jpg',
      result: _result,
      pending: null,
      scans: scans,
      location: location,
      db: db,
    );

    // Available straight away, with no location yet.
    final beforeFix = await db.getScanById(saved.id);
    expect(beforeFix, isNotNull);
    expect(beforeFix!.hasGps, isFalse);

    await saved.locationAttached;

    final afterFix = await db.getScanById(saved.id);
    expect(afterFix!.latitude, closeTo(7.3775, 0.0001));
    expect(afterFix.longitude, closeTo(3.9470, 0.0001));
  });

  test('a denied or unavailable fix still leaves a usable scan', () async {
    final location = FakeLocationService(); // returns null, as a denial does

    final saved = await saveScan(
      imagePath: 'scans/leaf.jpg',
      result: _result,
      pending: null,
      scans: scans,
      location: location,
      db: db,
    );
    await saved.locationAttached;

    final record = await db.getScanById(saved.id);
    expect(record!.hasGps, isFalse);
    expect(record.classId, 2);
  });

  test('seed label fields captured before the scan are stored with it', () async {
    final saved = await saveScan(
      imagePath: 'scans/leaf.jpg',
      result: _result,
      pending: const OcrFields(
        cropVariety: 'SAMMAZ 15',
        batchNumber: 'BN-2024-042',
        plantingDate: '2024-03-15',
        rawText: 'SAMMAZ 15',
      ),
      scans: scans,
      location: FakeLocationService(),
      db: db,
    );
    await saved.locationAttached;

    final record = await db.getScanById(saved.id);
    expect(record!.cropVariety, 'SAMMAZ 15');
    expect(record.batchNumber, 'BN-2024-042');
    expect(record.plantingDate, '2024-03-15');
  });
}
