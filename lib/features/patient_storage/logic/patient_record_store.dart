import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import '../../data/patient_model.dart';
import '../../data/patient_schema.dart';
import '../../transmission_engine/logic/delta_encoder.dart';

enum PatientSyncStatus { newRecord, updated, synced }

class PatientRecordDiff {
  const PatientRecordDiff({required this.changedFields});

  final List<String> changedFields;

  bool get hasChanges => changedFields.isNotEmpty;

  List<String> summaries(PatientModel current, PatientModel? previous) {
    if (previous == null) {
      return const ['New local patient record'];
    }
    final currentValues = current.toWireMap();
    final previousValues = previous.toWireMap();
    return changedFields
        .map(
          (field) =>
              '$field changed: ${_displayValue(field, previousValues[field])} -> ${_displayValue(field, currentValues[field])}',
        )
        .toList();
  }

  String _displayValue(String field, String? value) {
    if (field == 'gender') {
      return PatientSchema.genderLabel(value ?? '');
    }
    return value ?? '';
  }
}

class StoredPatientRecord {
  const StoredPatientRecord({
    required this.recordId,
    required this.schemaVersion,
    required this.lastUpdatedAt,
    required this.rawEncodedValue,
    this.pendingRawEncodedValue,
  });

  final String recordId;
  final String schemaVersion;
  final DateTime lastUpdatedAt;
  final String rawEncodedValue;
  final String? pendingRawEncodedValue;

  PatientModel? get confirmedPatient {
    if (rawEncodedValue.isEmpty) {
      return null;
    }
    return PatientModel.fromPayload(rawEncodedValue);
  }

  PatientModel? get pendingPatient {
    final raw = pendingRawEncodedValue;
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return PatientModel.fromPayload(raw);
  }

  PatientSyncStatus get status {
    if (rawEncodedValue.isEmpty) {
      return PatientSyncStatus.newRecord;
    }
    if (pendingRawEncodedValue != null &&
        pendingRawEncodedValue != rawEncodedValue) {
      return PatientSyncStatus.updated;
    }
    return PatientSyncStatus.synced;
  }
}

class PatientRecordStore {
  PatientRecordStore({sqflite.DatabaseFactory? factory, String? databasePath})
    : _factory = factory,
      _databasePath = databasePath;

  final sqflite.DatabaseFactory? _factory;
  final String? _databasePath;
  sqflite.Database? _database;

  Future<sqflite.Database> get _db async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }
    final factory = _factory ?? _defaultFactory();
    final dbPath = _databasePath ?? await _defaultPath(factory);
    _database = await factory.openDatabase(
      dbPath,
      options: sqflite.OpenDatabaseOptions(version: 1, onCreate: _create),
    );
    return _database!;
  }

  sqflite.DatabaseFactory _defaultFactory() {
    try {
      return sqflite.databaseFactory;
    } catch (_) {
      ffi.sqfliteFfiInit();
      return ffi.databaseFactoryFfi;
    }
  }

  Future<String> _defaultPath(sqflite.DatabaseFactory factory) async {
    if (identical(factory, ffi.databaseFactoryFfi)) {
      return path.join(Directory.systemTemp.path, 'medgate_patients.db');
    }
    return path.join(await sqflite.getDatabasesPath(), 'medgate_patients.db');
  }

  Future<void> _create(sqflite.Database db, int version) async {
    await db.execute('''
      CREATE TABLE patient_records (
        record_id TEXT PRIMARY KEY,
        schema_version TEXT NOT NULL,
        last_updated_at INTEGER NOT NULL,
        raw_encoded_value TEXT NOT NULL,
        pending_raw_encoded_value TEXT,
        name TEXT NOT NULL,
        age INTEGER NOT NULL,
        blood_pressure TEXT NOT NULL,
        heart_rate INTEGER NOT NULL,
        oxygen_saturation INTEGER NOT NULL,
        temperature REAL NOT NULL,
        notes TEXT NOT NULL,
        photo_ref TEXT NOT NULL,
        urgent INTEGER NOT NULL,
        symptoms TEXT NOT NULL,
        diagnosis TEXT NOT NULL,
        medical_history TEXT NOT NULL,
        current_medication TEXT NOT NULL,
        allergies TEXT NOT NULL,
        consciousness TEXT NOT NULL,
        emergency_notes TEXT NOT NULL,
        address TEXT NOT NULL,
        contact_details TEXT NOT NULL,
        insurance TEXT NOT NULL,
        gender INTEGER NOT NULL,
        blood_group TEXT NOT NULL
      )
    ''');
  }

  Future<StoredPatientRecord?> read(String recordId) async {
    final rows = await (await _db).query(
      'patient_records',
      where: 'record_id = ?',
      whereArgs: [recordId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _fromRow(rows.first);
  }

  Future<List<StoredPatientRecord>> readAll() async {
    final rows = await (await _db).query(
      'patient_records',
      orderBy: 'last_updated_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<PatientRecordDiff> stageCapture(PatientModel patient) async {
    final existing = await read(patient.id);
    final previous = existing?.confirmedPatient?.toWireMap();
    final diff = encodeDelta(patient.toWireMap(), previous).changedFields;
    final row = _rowFor(
      patient,
      confirmedPayload: existing?.rawEncodedValue ?? '',
      pendingPayload: patient.toPayload(),
    );
    await (await _db).insert(
      'patient_records',
      row,
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
    return PatientRecordDiff(changedFields: diff);
  }

  Future<Map<String, String>?> confirmedWireMap(String recordId) async {
    return (await read(recordId))?.confirmedPatient?.toWireMap();
  }

  Future<void> markTransmissionConfirmed(PatientModel patient) async {
    final row = _rowFor(
      patient,
      confirmedPayload: patient.toPayload(),
      pendingPayload: null,
    );
    await (await _db).insert(
      'patient_records',
      row,
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  StoredPatientRecord _fromRow(Map<String, Object?> row) {
    return StoredPatientRecord(
      recordId: row['record_id']! as String,
      schemaVersion: row['schema_version']! as String,
      lastUpdatedAt: DateTime.fromMillisecondsSinceEpoch(
        row['last_updated_at']! as int,
      ),
      rawEncodedValue: row['raw_encoded_value']! as String,
      pendingRawEncodedValue: row['pending_raw_encoded_value'] as String?,
    );
  }

  Map<String, Object?> _rowFor(
    PatientModel patient, {
    required String confirmedPayload,
    required String? pendingPayload,
  }) {
    return {
      'record_id': patient.id,
      'schema_version': PatientSchema.versionPrefix,
      'last_updated_at': DateTime.now().millisecondsSinceEpoch,
      'raw_encoded_value': confirmedPayload,
      'pending_raw_encoded_value': pendingPayload,
      'name': patient.displayName,
      'age': patient.age,
      'blood_pressure': patient.bloodPressure,
      'heart_rate': patient.heartRate,
      'oxygen_saturation': patient.oxygenSaturation,
      'temperature': patient.temperature,
      'notes': patient.notes,
      'photo_ref': patient.photoRef,
      'urgent': patient.urgent ? 1 : 0,
      'symptoms': patient.symptoms,
      'diagnosis': patient.diagnosis,
      'medical_history': patient.medicalHistory,
      'current_medication': patient.currentMedication,
      'allergies': patient.allergies,
      'consciousness': patient.consciousness,
      'emergency_notes': patient.emergencyNotes,
      'address': patient.address,
      'contact_details': patient.contactDetails,
      'insurance': patient.insurance,
      'gender':
          int.tryParse(PatientSchema.normalizeGenderCode(patient.gender)) ?? 0,
      'blood_group': patient.bloodGroup,
    };
  }
}
