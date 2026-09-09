import 'dart:convert';

class ScanRecord {
  final int? id;
  final String imagePath;
  final int classId;
  final String className;
  final String shortName;
  final double confidence;
  final List<double> allScores;
  final double latencyMs;
  final double? latitude;
  final double? longitude;
  final String? cropVariety;
  final String? batchNumber;
  final String? plantingDate;
  final DateTime scannedAt;
  final String? notes;
  // 1 = correct, 0 = incorrect, -1 = unsure, null = no feedback
  final int? feedback;

  const ScanRecord({
    this.id,
    required this.imagePath,
    required this.classId,
    required this.className,
    required this.shortName,
    required this.confidence,
    required this.allScores,
    required this.latencyMs,
    this.latitude,
    this.longitude,
    this.cropVariety,
    this.batchNumber,
    this.plantingDate,
    required this.scannedAt,
    this.notes,
    this.feedback,
  });

  bool get hasGps => latitude != null && longitude != null;
  bool get isHealthy => classId == 3;

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'image_path':    imagePath,
    'class_id':      classId,
    'class_name':    className,
    'short_name':    shortName,
    'confidence':    confidence,
    'all_scores':    jsonEncode(allScores),
    'latency_ms':    latencyMs,
    'latitude':      latitude,
    'longitude':     longitude,
    'crop_variety':  cropVariety,
    'batch_number':  batchNumber,
    'planting_date': plantingDate,
    'scanned_at':    scannedAt.toUtc().toIso8601String(),
    'notes':         notes,
    'feedback':      feedback,
  };

  ClassificationResult toResult() => ClassificationResult(
    classId: classId,
    className: className,
    shortName: shortName,
    confidence: confidence,
    allScores: allScores,
    latencyMs: latencyMs,
  );

  factory ScanRecord.fromMap(Map<String, dynamic> m) => ScanRecord(
    id:            m['id'] as int?,
    imagePath:     m['image_path'] as String,
    classId:       m['class_id'] as int,
    className:     m['class_name'] as String,
    shortName:     m['short_name'] as String,
    confidence:    (m['confidence'] as num).toDouble(),
    allScores:     (jsonDecode(m['all_scores'] as String) as List)
                       .map((e) => (e as num).toDouble())
                       .toList(),
    latencyMs:     (m['latency_ms'] as num).toDouble(),
    latitude:      (m['latitude'] as num?)?.toDouble(),
    longitude:     (m['longitude'] as num?)?.toDouble(),
    cropVariety:   m['crop_variety'] as String?,
    batchNumber:   m['batch_number'] as String?,
    plantingDate:  m['planting_date'] as String?,
    scannedAt:     DateTime.parse(m['scanned_at'] as String).toUtc(),
    notes:         m['notes'] as String?,
    feedback:      m['feedback'] as int?,
  );

  ScanRecord copyWith({String? notes, int? feedback}) => ScanRecord(
    id:            id,
    imagePath:     imagePath,
    classId:       classId,
    className:     className,
    shortName:     shortName,
    confidence:    confidence,
    allScores:     allScores,
    latencyMs:     latencyMs,
    latitude:      latitude,
    longitude:     longitude,
    cropVariety:   cropVariety,
    batchNumber:   batchNumber,
    plantingDate:  plantingDate,
    scannedAt:     scannedAt,
    notes:         notes ?? this.notes,
    feedback:      feedback ?? this.feedback,
  );
}

class OcrFields {
  final String? cropVariety;
  final String? batchNumber;
  final String? plantingDate;
  final String rawText;

  const OcrFields({
    this.cropVariety,
    this.batchNumber,
    this.plantingDate,
    required this.rawText,
  });

  bool get hasAnyField =>
      cropVariety != null || batchNumber != null || plantingDate != null;
}

class ClassificationResult {
  final int classId;
  final String className;
  final String shortName;
  final double confidence;
  final List<double> allScores;
  final double latencyMs;

  const ClassificationResult({
    required this.classId,
    required this.className,
    required this.shortName,
    required this.confidence,
    required this.allScores,
    required this.latencyMs,
  });
}
