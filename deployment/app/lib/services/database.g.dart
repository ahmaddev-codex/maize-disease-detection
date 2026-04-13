// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
mixin _$ScanDaoMixin on DatabaseAccessor<AppDatabase> {
  $ScanRecordsTable get scanRecords => attachedDatabase.scanRecords;
  ScanDaoManager get managers => ScanDaoManager(this);
}

class ScanDaoManager {
  final _$ScanDaoMixin _db;
  ScanDaoManager(this._db);
  $$ScanRecordsTableTableManager get scanRecords =>
      $$ScanRecordsTableTableManager(_db.attachedDatabase, _db.scanRecords);
}

class $ScanRecordsTable extends ScanRecords
    with TableInfo<$ScanRecordsTable, ScanRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScanRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _imagePathMeta =
      const VerificationMeta('imagePath');
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
      'image_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _classIdMeta =
      const VerificationMeta('classId');
  @override
  late final GeneratedColumn<int> classId = GeneratedColumn<int>(
      'class_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _classNameMeta =
      const VerificationMeta('className');
  @override
  late final GeneratedColumn<String> className = GeneratedColumn<String>(
      'class_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _shortNameMeta =
      const VerificationMeta('shortName');
  @override
  late final GeneratedColumn<String> shortName = GeneratedColumn<String>(
      'short_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _confidenceMeta =
      const VerificationMeta('confidence');
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
      'confidence', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _allScoresMeta =
      const VerificationMeta('allScores');
  @override
  late final GeneratedColumn<String> allScores = GeneratedColumn<String>(
      'all_scores', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _latencyMsMeta =
      const VerificationMeta('latencyMs');
  @override
  late final GeneratedColumn<double> latencyMs = GeneratedColumn<double>(
      'latency_ms', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _latitudeMeta =
      const VerificationMeta('latitude');
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
      'latitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _longitudeMeta =
      const VerificationMeta('longitude');
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
      'longitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _cropVarietyMeta =
      const VerificationMeta('cropVariety');
  @override
  late final GeneratedColumn<String> cropVariety = GeneratedColumn<String>(
      'crop_variety', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _batchNumberMeta =
      const VerificationMeta('batchNumber');
  @override
  late final GeneratedColumn<String> batchNumber = GeneratedColumn<String>(
      'batch_number', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _plantingDateMeta =
      const VerificationMeta('plantingDate');
  @override
  late final GeneratedColumn<String> plantingDate = GeneratedColumn<String>(
      'planting_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _scannedAtMeta =
      const VerificationMeta('scannedAt');
  @override
  late final GeneratedColumn<DateTime> scannedAt = GeneratedColumn<DateTime>(
      'scanned_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        imagePath,
        classId,
        className,
        shortName,
        confidence,
        allScores,
        latencyMs,
        latitude,
        longitude,
        cropVariety,
        batchNumber,
        plantingDate,
        scannedAt,
        notes
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_records';
  @override
  VerificationContext validateIntegrity(Insertable<ScanRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('image_path')) {
      context.handle(_imagePathMeta,
          imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta));
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('class_id')) {
      context.handle(_classIdMeta,
          classId.isAcceptableOrUnknown(data['class_id']!, _classIdMeta));
    } else if (isInserting) {
      context.missing(_classIdMeta);
    }
    if (data.containsKey('class_name')) {
      context.handle(_classNameMeta,
          className.isAcceptableOrUnknown(data['class_name']!, _classNameMeta));
    } else if (isInserting) {
      context.missing(_classNameMeta);
    }
    if (data.containsKey('short_name')) {
      context.handle(_shortNameMeta,
          shortName.isAcceptableOrUnknown(data['short_name']!, _shortNameMeta));
    } else if (isInserting) {
      context.missing(_shortNameMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
          _confidenceMeta,
          confidence.isAcceptableOrUnknown(
              data['confidence']!, _confidenceMeta));
    } else if (isInserting) {
      context.missing(_confidenceMeta);
    }
    if (data.containsKey('all_scores')) {
      context.handle(_allScoresMeta,
          allScores.isAcceptableOrUnknown(data['all_scores']!, _allScoresMeta));
    } else if (isInserting) {
      context.missing(_allScoresMeta);
    }
    if (data.containsKey('latency_ms')) {
      context.handle(_latencyMsMeta,
          latencyMs.isAcceptableOrUnknown(data['latency_ms']!, _latencyMsMeta));
    } else if (isInserting) {
      context.missing(_latencyMsMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(_latitudeMeta,
          latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta));
    }
    if (data.containsKey('longitude')) {
      context.handle(_longitudeMeta,
          longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta));
    }
    if (data.containsKey('crop_variety')) {
      context.handle(
          _cropVarietyMeta,
          cropVariety.isAcceptableOrUnknown(
              data['crop_variety']!, _cropVarietyMeta));
    }
    if (data.containsKey('batch_number')) {
      context.handle(
          _batchNumberMeta,
          batchNumber.isAcceptableOrUnknown(
              data['batch_number']!, _batchNumberMeta));
    }
    if (data.containsKey('planting_date')) {
      context.handle(
          _plantingDateMeta,
          plantingDate.isAcceptableOrUnknown(
              data['planting_date']!, _plantingDateMeta));
    }
    if (data.containsKey('scanned_at')) {
      context.handle(_scannedAtMeta,
          scannedAt.isAcceptableOrUnknown(data['scanned_at']!, _scannedAtMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScanRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      imagePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_path'])!,
      classId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}class_id'])!,
      className: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}class_name'])!,
      shortName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}short_name'])!,
      confidence: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}confidence'])!,
      allScores: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}all_scores'])!,
      latencyMs: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latency_ms'])!,
      latitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latitude']),
      longitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}longitude']),
      cropVariety: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}crop_variety']),
      batchNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}batch_number']),
      plantingDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}planting_date']),
      scannedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}scanned_at'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
    );
  }

  @override
  $ScanRecordsTable createAlias(String alias) {
    return $ScanRecordsTable(attachedDatabase, alias);
  }
}

class ScanRecord extends DataClass implements Insertable<ScanRecord> {
  final int id;
  final String imagePath;
  final int classId;
  final String className;
  final String shortName;
  final double confidence;
  final String allScores;
  final double latencyMs;
  final double? latitude;
  final double? longitude;
  final String? cropVariety;
  final String? batchNumber;
  final String? plantingDate;
  final DateTime scannedAt;
  final String? notes;
  const ScanRecord(
      {required this.id,
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
      this.notes});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['image_path'] = Variable<String>(imagePath);
    map['class_id'] = Variable<int>(classId);
    map['class_name'] = Variable<String>(className);
    map['short_name'] = Variable<String>(shortName);
    map['confidence'] = Variable<double>(confidence);
    map['all_scores'] = Variable<String>(allScores);
    map['latency_ms'] = Variable<double>(latencyMs);
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    if (!nullToAbsent || cropVariety != null) {
      map['crop_variety'] = Variable<String>(cropVariety);
    }
    if (!nullToAbsent || batchNumber != null) {
      map['batch_number'] = Variable<String>(batchNumber);
    }
    if (!nullToAbsent || plantingDate != null) {
      map['planting_date'] = Variable<String>(plantingDate);
    }
    map['scanned_at'] = Variable<DateTime>(scannedAt);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  ScanRecordsCompanion toCompanion(bool nullToAbsent) {
    return ScanRecordsCompanion(
      id: Value(id),
      imagePath: Value(imagePath),
      classId: Value(classId),
      className: Value(className),
      shortName: Value(shortName),
      confidence: Value(confidence),
      allScores: Value(allScores),
      latencyMs: Value(latencyMs),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      cropVariety: cropVariety == null && nullToAbsent
          ? const Value.absent()
          : Value(cropVariety),
      batchNumber: batchNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(batchNumber),
      plantingDate: plantingDate == null && nullToAbsent
          ? const Value.absent()
          : Value(plantingDate),
      scannedAt: Value(scannedAt),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
    );
  }

  factory ScanRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanRecord(
      id: serializer.fromJson<int>(json['id']),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      classId: serializer.fromJson<int>(json['classId']),
      className: serializer.fromJson<String>(json['className']),
      shortName: serializer.fromJson<String>(json['shortName']),
      confidence: serializer.fromJson<double>(json['confidence']),
      allScores: serializer.fromJson<String>(json['allScores']),
      latencyMs: serializer.fromJson<double>(json['latencyMs']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      cropVariety: serializer.fromJson<String?>(json['cropVariety']),
      batchNumber: serializer.fromJson<String?>(json['batchNumber']),
      plantingDate: serializer.fromJson<String?>(json['plantingDate']),
      scannedAt: serializer.fromJson<DateTime>(json['scannedAt']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'imagePath': serializer.toJson<String>(imagePath),
      'classId': serializer.toJson<int>(classId),
      'className': serializer.toJson<String>(className),
      'shortName': serializer.toJson<String>(shortName),
      'confidence': serializer.toJson<double>(confidence),
      'allScores': serializer.toJson<String>(allScores),
      'latencyMs': serializer.toJson<double>(latencyMs),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'cropVariety': serializer.toJson<String?>(cropVariety),
      'batchNumber': serializer.toJson<String?>(batchNumber),
      'plantingDate': serializer.toJson<String?>(plantingDate),
      'scannedAt': serializer.toJson<DateTime>(scannedAt),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  ScanRecord copyWith(
          {int? id,
          String? imagePath,
          int? classId,
          String? className,
          String? shortName,
          double? confidence,
          String? allScores,
          double? latencyMs,
          Value<double?> latitude = const Value.absent(),
          Value<double?> longitude = const Value.absent(),
          Value<String?> cropVariety = const Value.absent(),
          Value<String?> batchNumber = const Value.absent(),
          Value<String?> plantingDate = const Value.absent(),
          DateTime? scannedAt,
          Value<String?> notes = const Value.absent()}) =>
      ScanRecord(
        id: id ?? this.id,
        imagePath: imagePath ?? this.imagePath,
        classId: classId ?? this.classId,
        className: className ?? this.className,
        shortName: shortName ?? this.shortName,
        confidence: confidence ?? this.confidence,
        allScores: allScores ?? this.allScores,
        latencyMs: latencyMs ?? this.latencyMs,
        latitude: latitude.present ? latitude.value : this.latitude,
        longitude: longitude.present ? longitude.value : this.longitude,
        cropVariety: cropVariety.present ? cropVariety.value : this.cropVariety,
        batchNumber: batchNumber.present ? batchNumber.value : this.batchNumber,
        plantingDate:
            plantingDate.present ? plantingDate.value : this.plantingDate,
        scannedAt: scannedAt ?? this.scannedAt,
        notes: notes.present ? notes.value : this.notes,
      );
  ScanRecord copyWithCompanion(ScanRecordsCompanion data) {
    return ScanRecord(
      id: data.id.present ? data.id.value : this.id,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      classId: data.classId.present ? data.classId.value : this.classId,
      className: data.className.present ? data.className.value : this.className,
      shortName: data.shortName.present ? data.shortName.value : this.shortName,
      confidence:
          data.confidence.present ? data.confidence.value : this.confidence,
      allScores: data.allScores.present ? data.allScores.value : this.allScores,
      latencyMs: data.latencyMs.present ? data.latencyMs.value : this.latencyMs,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      cropVariety:
          data.cropVariety.present ? data.cropVariety.value : this.cropVariety,
      batchNumber:
          data.batchNumber.present ? data.batchNumber.value : this.batchNumber,
      plantingDate: data.plantingDate.present
          ? data.plantingDate.value
          : this.plantingDate,
      scannedAt: data.scannedAt.present ? data.scannedAt.value : this.scannedAt,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanRecord(')
          ..write('id: $id, ')
          ..write('imagePath: $imagePath, ')
          ..write('classId: $classId, ')
          ..write('className: $className, ')
          ..write('shortName: $shortName, ')
          ..write('confidence: $confidence, ')
          ..write('allScores: $allScores, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('cropVariety: $cropVariety, ')
          ..write('batchNumber: $batchNumber, ')
          ..write('plantingDate: $plantingDate, ')
          ..write('scannedAt: $scannedAt, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      imagePath,
      classId,
      className,
      shortName,
      confidence,
      allScores,
      latencyMs,
      latitude,
      longitude,
      cropVariety,
      batchNumber,
      plantingDate,
      scannedAt,
      notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanRecord &&
          other.id == this.id &&
          other.imagePath == this.imagePath &&
          other.classId == this.classId &&
          other.className == this.className &&
          other.shortName == this.shortName &&
          other.confidence == this.confidence &&
          other.allScores == this.allScores &&
          other.latencyMs == this.latencyMs &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.cropVariety == this.cropVariety &&
          other.batchNumber == this.batchNumber &&
          other.plantingDate == this.plantingDate &&
          other.scannedAt == this.scannedAt &&
          other.notes == this.notes);
}

class ScanRecordsCompanion extends UpdateCompanion<ScanRecord> {
  final Value<int> id;
  final Value<String> imagePath;
  final Value<int> classId;
  final Value<String> className;
  final Value<String> shortName;
  final Value<double> confidence;
  final Value<String> allScores;
  final Value<double> latencyMs;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<String?> cropVariety;
  final Value<String?> batchNumber;
  final Value<String?> plantingDate;
  final Value<DateTime> scannedAt;
  final Value<String?> notes;
  const ScanRecordsCompanion({
    this.id = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.classId = const Value.absent(),
    this.className = const Value.absent(),
    this.shortName = const Value.absent(),
    this.confidence = const Value.absent(),
    this.allScores = const Value.absent(),
    this.latencyMs = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.cropVariety = const Value.absent(),
    this.batchNumber = const Value.absent(),
    this.plantingDate = const Value.absent(),
    this.scannedAt = const Value.absent(),
    this.notes = const Value.absent(),
  });
  ScanRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String imagePath,
    required int classId,
    required String className,
    required String shortName,
    required double confidence,
    required String allScores,
    required double latencyMs,
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.cropVariety = const Value.absent(),
    this.batchNumber = const Value.absent(),
    this.plantingDate = const Value.absent(),
    this.scannedAt = const Value.absent(),
    this.notes = const Value.absent(),
  })  : imagePath = Value(imagePath),
        classId = Value(classId),
        className = Value(className),
        shortName = Value(shortName),
        confidence = Value(confidence),
        allScores = Value(allScores),
        latencyMs = Value(latencyMs);
  static Insertable<ScanRecord> custom({
    Expression<int>? id,
    Expression<String>? imagePath,
    Expression<int>? classId,
    Expression<String>? className,
    Expression<String>? shortName,
    Expression<double>? confidence,
    Expression<String>? allScores,
    Expression<double>? latencyMs,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? cropVariety,
    Expression<String>? batchNumber,
    Expression<String>? plantingDate,
    Expression<DateTime>? scannedAt,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (imagePath != null) 'image_path': imagePath,
      if (classId != null) 'class_id': classId,
      if (className != null) 'class_name': className,
      if (shortName != null) 'short_name': shortName,
      if (confidence != null) 'confidence': confidence,
      if (allScores != null) 'all_scores': allScores,
      if (latencyMs != null) 'latency_ms': latencyMs,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (cropVariety != null) 'crop_variety': cropVariety,
      if (batchNumber != null) 'batch_number': batchNumber,
      if (plantingDate != null) 'planting_date': plantingDate,
      if (scannedAt != null) 'scanned_at': scannedAt,
      if (notes != null) 'notes': notes,
    });
  }

  ScanRecordsCompanion copyWith(
      {Value<int>? id,
      Value<String>? imagePath,
      Value<int>? classId,
      Value<String>? className,
      Value<String>? shortName,
      Value<double>? confidence,
      Value<String>? allScores,
      Value<double>? latencyMs,
      Value<double?>? latitude,
      Value<double?>? longitude,
      Value<String?>? cropVariety,
      Value<String?>? batchNumber,
      Value<String?>? plantingDate,
      Value<DateTime>? scannedAt,
      Value<String?>? notes}) {
    return ScanRecordsCompanion(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      shortName: shortName ?? this.shortName,
      confidence: confidence ?? this.confidence,
      allScores: allScores ?? this.allScores,
      latencyMs: latencyMs ?? this.latencyMs,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      cropVariety: cropVariety ?? this.cropVariety,
      batchNumber: batchNumber ?? this.batchNumber,
      plantingDate: plantingDate ?? this.plantingDate,
      scannedAt: scannedAt ?? this.scannedAt,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (classId.present) {
      map['class_id'] = Variable<int>(classId.value);
    }
    if (className.present) {
      map['class_name'] = Variable<String>(className.value);
    }
    if (shortName.present) {
      map['short_name'] = Variable<String>(shortName.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (allScores.present) {
      map['all_scores'] = Variable<String>(allScores.value);
    }
    if (latencyMs.present) {
      map['latency_ms'] = Variable<double>(latencyMs.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (cropVariety.present) {
      map['crop_variety'] = Variable<String>(cropVariety.value);
    }
    if (batchNumber.present) {
      map['batch_number'] = Variable<String>(batchNumber.value);
    }
    if (plantingDate.present) {
      map['planting_date'] = Variable<String>(plantingDate.value);
    }
    if (scannedAt.present) {
      map['scanned_at'] = Variable<DateTime>(scannedAt.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScanRecordsCompanion(')
          ..write('id: $id, ')
          ..write('imagePath: $imagePath, ')
          ..write('classId: $classId, ')
          ..write('className: $className, ')
          ..write('shortName: $shortName, ')
          ..write('confidence: $confidence, ')
          ..write('allScores: $allScores, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('cropVariety: $cropVariety, ')
          ..write('batchNumber: $batchNumber, ')
          ..write('plantingDate: $plantingDate, ')
          ..write('scannedAt: $scannedAt, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ScanRecordsTable scanRecords = $ScanRecordsTable(this);
  late final ScanDao scanDao = ScanDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [scanRecords];
}

typedef $$ScanRecordsTableCreateCompanionBuilder = ScanRecordsCompanion
    Function({
  Value<int> id,
  required String imagePath,
  required int classId,
  required String className,
  required String shortName,
  required double confidence,
  required String allScores,
  required double latencyMs,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<String?> cropVariety,
  Value<String?> batchNumber,
  Value<String?> plantingDate,
  Value<DateTime> scannedAt,
  Value<String?> notes,
});
typedef $$ScanRecordsTableUpdateCompanionBuilder = ScanRecordsCompanion
    Function({
  Value<int> id,
  Value<String> imagePath,
  Value<int> classId,
  Value<String> className,
  Value<String> shortName,
  Value<double> confidence,
  Value<String> allScores,
  Value<double> latencyMs,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<String?> cropVariety,
  Value<String?> batchNumber,
  Value<String?> plantingDate,
  Value<DateTime> scannedAt,
  Value<String?> notes,
});

class $$ScanRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $ScanRecordsTable> {
  $$ScanRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get classId => $composableBuilder(
      column: $table.classId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get className => $composableBuilder(
      column: $table.className, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shortName => $composableBuilder(
      column: $table.shortName, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get confidence => $composableBuilder(
      column: $table.confidence, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get allScores => $composableBuilder(
      column: $table.allScores, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get latencyMs => $composableBuilder(
      column: $table.latencyMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cropVariety => $composableBuilder(
      column: $table.cropVariety, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get batchNumber => $composableBuilder(
      column: $table.batchNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get plantingDate => $composableBuilder(
      column: $table.plantingDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get scannedAt => $composableBuilder(
      column: $table.scannedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));
}

class $$ScanRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScanRecordsTable> {
  $$ScanRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get classId => $composableBuilder(
      column: $table.classId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get className => $composableBuilder(
      column: $table.className, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shortName => $composableBuilder(
      column: $table.shortName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get confidence => $composableBuilder(
      column: $table.confidence, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get allScores => $composableBuilder(
      column: $table.allScores, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get latencyMs => $composableBuilder(
      column: $table.latencyMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cropVariety => $composableBuilder(
      column: $table.cropVariety, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get batchNumber => $composableBuilder(
      column: $table.batchNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get plantingDate => $composableBuilder(
      column: $table.plantingDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get scannedAt => $composableBuilder(
      column: $table.scannedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));
}

class $$ScanRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScanRecordsTable> {
  $$ScanRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<int> get classId =>
      $composableBuilder(column: $table.classId, builder: (column) => column);

  GeneratedColumn<String> get className =>
      $composableBuilder(column: $table.className, builder: (column) => column);

  GeneratedColumn<String> get shortName =>
      $composableBuilder(column: $table.shortName, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
      column: $table.confidence, builder: (column) => column);

  GeneratedColumn<String> get allScores =>
      $composableBuilder(column: $table.allScores, builder: (column) => column);

  GeneratedColumn<double> get latencyMs =>
      $composableBuilder(column: $table.latencyMs, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get cropVariety => $composableBuilder(
      column: $table.cropVariety, builder: (column) => column);

  GeneratedColumn<String> get batchNumber => $composableBuilder(
      column: $table.batchNumber, builder: (column) => column);

  GeneratedColumn<String> get plantingDate => $composableBuilder(
      column: $table.plantingDate, builder: (column) => column);

  GeneratedColumn<DateTime> get scannedAt =>
      $composableBuilder(column: $table.scannedAt, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$ScanRecordsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ScanRecordsTable,
    ScanRecord,
    $$ScanRecordsTableFilterComposer,
    $$ScanRecordsTableOrderingComposer,
    $$ScanRecordsTableAnnotationComposer,
    $$ScanRecordsTableCreateCompanionBuilder,
    $$ScanRecordsTableUpdateCompanionBuilder,
    (ScanRecord, BaseReferences<_$AppDatabase, $ScanRecordsTable, ScanRecord>),
    ScanRecord,
    PrefetchHooks Function()> {
  $$ScanRecordsTableTableManager(_$AppDatabase db, $ScanRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScanRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScanRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScanRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> imagePath = const Value.absent(),
            Value<int> classId = const Value.absent(),
            Value<String> className = const Value.absent(),
            Value<String> shortName = const Value.absent(),
            Value<double> confidence = const Value.absent(),
            Value<String> allScores = const Value.absent(),
            Value<double> latencyMs = const Value.absent(),
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
            Value<String?> cropVariety = const Value.absent(),
            Value<String?> batchNumber = const Value.absent(),
            Value<String?> plantingDate = const Value.absent(),
            Value<DateTime> scannedAt = const Value.absent(),
            Value<String?> notes = const Value.absent(),
          }) =>
              ScanRecordsCompanion(
            id: id,
            imagePath: imagePath,
            classId: classId,
            className: className,
            shortName: shortName,
            confidence: confidence,
            allScores: allScores,
            latencyMs: latencyMs,
            latitude: latitude,
            longitude: longitude,
            cropVariety: cropVariety,
            batchNumber: batchNumber,
            plantingDate: plantingDate,
            scannedAt: scannedAt,
            notes: notes,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String imagePath,
            required int classId,
            required String className,
            required String shortName,
            required double confidence,
            required String allScores,
            required double latencyMs,
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
            Value<String?> cropVariety = const Value.absent(),
            Value<String?> batchNumber = const Value.absent(),
            Value<String?> plantingDate = const Value.absent(),
            Value<DateTime> scannedAt = const Value.absent(),
            Value<String?> notes = const Value.absent(),
          }) =>
              ScanRecordsCompanion.insert(
            id: id,
            imagePath: imagePath,
            classId: classId,
            className: className,
            shortName: shortName,
            confidence: confidence,
            allScores: allScores,
            latencyMs: latencyMs,
            latitude: latitude,
            longitude: longitude,
            cropVariety: cropVariety,
            batchNumber: batchNumber,
            plantingDate: plantingDate,
            scannedAt: scannedAt,
            notes: notes,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ScanRecordsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ScanRecordsTable,
    ScanRecord,
    $$ScanRecordsTableFilterComposer,
    $$ScanRecordsTableOrderingComposer,
    $$ScanRecordsTableAnnotationComposer,
    $$ScanRecordsTableCreateCompanionBuilder,
    $$ScanRecordsTableUpdateCompanionBuilder,
    (ScanRecord, BaseReferences<_$AppDatabase, $ScanRecordsTable, ScanRecord>),
    ScanRecord,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ScanRecordsTableTableManager get scanRecords =>
      $$ScanRecordsTableTableManager(_db, _db.scanRecords);
}
