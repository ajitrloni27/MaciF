import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import '../../specialist_view/models/consultation_reply.dart';

class StoredConsultationReply {
  const StoredConsultationReply({
    required this.replyId,
    required this.caseId,
    required this.confirmedPayload,
    this.pendingPayload,
    required this.lastUpdatedAt,
  });

  final String replyId;
  final String caseId;
  final String confirmedPayload;
  final String? pendingPayload;
  final DateTime lastUpdatedAt;

  ConsultationReply? get confirmedReply =>
      confirmedPayload.isEmpty ? null : ConsultationReply.fromPayload(confirmedPayload);

  ConsultationReply? get pendingReply =>
      (pendingPayload == null || pendingPayload!.isEmpty)
          ? null
          : ConsultationReply.fromPayload(pendingPayload!);

  bool get isConfirmed => confirmedPayload.isNotEmpty && pendingPayload == null;
}

class ConsultationReplyStore {
  ConsultationReplyStore({sqflite.DatabaseFactory? factory, String? databasePath})
      : _factory = factory,
        _databasePath = databasePath;

  final sqflite.DatabaseFactory? _factory;
  final String? _databasePath;
  sqflite.Database? _database;

  Future<sqflite.Database> get _db async {
    final existing = _database;
    if (existing != null) return existing;
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
      return path.join(Directory.systemTemp.path, 'medgate_replies.db');
    }
    return path.join(await sqflite.getDatabasesPath(), 'medgate_replies.db');
  }

  Future<void> _create(sqflite.Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS consultation_replies (
        reply_id TEXT PRIMARY KEY,
        case_id TEXT NOT NULL,
        doctor_name TEXT NOT NULL,
        advice TEXT NOT NULL,
        prescription_note TEXT NOT NULL,
        follow_up INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        confirmed_payload TEXT NOT NULL,
        pending_payload TEXT,
        last_updated_at INTEGER NOT NULL
      )
    ''');
  }

  /// Compare-then-overwrite rule: Stage local captures as pending while keeping the
  /// baseline intact.
  Future<void> stageReply(ConsultationReply reply) async {
    final db = await _db;
    final existing = await read(reply.replyId);
    final confirmedBaseline = existing?.confirmedPayload ?? '';

    await db.insert(
      'consultation_replies',
      {
        'reply_id': reply.replyId,
        'case_id': reply.caseId,
        'doctor_name': reply.doctorName,
        'advice': reply.advice,
        'prescription_note': reply.prescriptionNote,
        'follow_up': reply.followUp ? 1 : 0,
        'timestamp': reply.timestamp.millisecondsSinceEpoch,
        'confirmed_payload': confirmedBaseline,
        'pending_payload': reply.toPayload(),
        'last_updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  /// Compare-then-overwrite rule: Overwrite confirmed baseline only after reconstruction
  /// is confirmed successful.
  Future<void> confirmReply(ConsultationReply reply) async {
    final db = await _db;
    await db.insert(
      'consultation_replies',
      {
        'reply_id': reply.replyId,
        'case_id': reply.caseId,
        'doctor_name': reply.doctorName,
        'advice': reply.advice,
        'prescription_note': reply.prescriptionNote,
        'follow_up': reply.followUp ? 1 : 0,
        'timestamp': reply.timestamp.millisecondsSinceEpoch,
        'confirmed_payload': reply.toPayload(),
        'pending_payload': null,
        'last_updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  Future<StoredConsultationReply?> read(String replyId) async {
    final db = await _db;
    final rows = await db.query(
      'consultation_replies',
      where: 'reply_id = ?',
      whereArgs: [replyId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  Future<ConsultationReply?> readLatestConfirmedForCase(String caseId) async {
    final db = await _db;
    final rows = await db.query(
      'consultation_replies',
      where: "case_id = ? AND confirmed_payload != ''",
      whereArgs: [caseId],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first).confirmedReply;
  }

  Future<List<ConsultationReply>> readAllConfirmed() async {
    final db = await _db;
    final rows = await db.query(
      'consultation_replies',
      where: "confirmed_payload != ''",
      orderBy: 'timestamp DESC',
    );
    return rows.map((r) => _fromRow(r).confirmedReply).whereType<ConsultationReply>().toList();
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  StoredConsultationReply _fromRow(Map<String, Object?> row) {
    return StoredConsultationReply(
      replyId: row['reply_id']! as String,
      caseId: row['case_id']! as String,
      confirmedPayload: row['confirmed_payload']! as String,
      pendingPayload: row['pending_payload'] as String?,
      lastUpdatedAt: DateTime.fromMillisecondsSinceEpoch(row['last_updated_at']! as int),
    );
  }
}
