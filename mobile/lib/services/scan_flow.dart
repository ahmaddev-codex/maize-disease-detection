import 'package:flutter/foundation.dart';
import '../constants/diseases.dart';
import '../models/scan_record.dart';
import '../providers/app_provider.dart';
import 'database_service.dart';
import 'location_service.dart';
import 'path_resolver.dart';

/// A scan that is already saved, plus the background work still finishing.
class SavedScan {
  const SavedScan({required this.id, required this.locationAttached});

  final int id;

  /// Completes once a GPS fix has been attached, or skipped when unavailable.
  final Future<void> locationAttached;
}

/// Saves a finished scan and returns as soon as it is in the database so the
/// result can be shown immediately. Waiting for a high-accuracy fix first
/// delayed every diagnosis by up to 10 seconds (T18).
Future<SavedScan> saveScan({
  required String imagePath,
  required ClassificationResult result,
  required OcrFields? pending,
  required ScanListNotifier scans,
  required LocationService location,
  required DatabaseService db,
}) async {
  final disease = diseaseForClass(result.classId);
  final record = ScanRecord(
    imagePath:    PathResolver.toRelative(imagePath),
    classId:      result.classId,
    className:    disease.name,
    shortName:    disease.shortName,
    confidence:   result.confidence,
    allScores:    result.allScores,
    latencyMs:    result.latencyMs,
    cropVariety:  pending?.cropVariety,
    batchNumber:  pending?.batchNumber,
    plantingDate: pending?.plantingDate,
    scannedAt:    DateTime.now().toUtc(),
  );

  final id = await scans.add(record);
  return SavedScan(
    id: id,
    locationAttached: _attachLocation(id, location, db, scans),
  );
}

Future<void> _attachLocation(
  int id,
  LocationService location,
  DatabaseService db,
  ScanListNotifier scans,
) async {
  try {
    final position = await location.getCurrentPosition();
    if (position == null) return; // denied or unavailable: the scan stays usable
    await db.updateLocation(id, position.latitude, position.longitude);
    await scans.load();
  } catch (e) {
    debugPrint('[Scan] could not attach location: $e');
  }
}
