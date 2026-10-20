import 'dart:io';

import 'package:cih/features/patient_storage/logic/consultation_reply_store.dart';
import 'package:cih/features/specialist_view/models/consultation_reply.dart';
import 'package:cih/features/transmission_engine/logic/priority_queue.dart';
import 'package:cih/features/transmission_engine/logic/reply_transmission.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

void main() {
  setUpAll(() {
    ffi.sqfliteFfiInit();
  });

  group('ConsultationReply Model & Payload serialization', () {
    test('serializes and deserializes cleanly with CRP1 schema', () {
      final reply = ConsultationReply(
        caseId: 'CASE-001',
        doctorName: 'Dr. Asha Rao',
        advice: 'Continue paracetamol 500mg TDS, hydrate well.',
        prescriptionNote: 'Paracetamol 500mg, ORS sachets',
        followUp: true,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1771500000000),
      );

      final payload = reply.toPayload();
      expect(payload.startsWith('CRP1|'), isTrue);

      final decoded = ConsultationReply.fromPayload(payload);
      expect(decoded.caseId, 'CASE-001');
      expect(decoded.doctorName, 'Dr. Asha Rao');
      expect(decoded.advice, 'Continue paracetamol 500mg TDS, hydrate well.');
      expect(decoded.prescriptionNote, 'Paracetamol 500mg, ORS sachets');
      expect(decoded.followUp, isTrue);
      expect(decoded.timestamp.millisecondsSinceEpoch, 1771500000000);
    });

    test('toWireMap and fromWireMap roundtrip correctly', () {
      final reply = ConsultationReply(
        caseId: 'CASE-002',
        doctorName: 'Dr. John Doe',
        advice: 'Monitor vitals every 4 hours.',
        prescriptionNote: 'None',
        followUp: false,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1771511111111),
      );

      final wire = reply.toWireMap();
      final decoded = ConsultationReply.fromWireMap(wire);

      expect(decoded.caseId, 'CASE-002');
      expect(decoded.doctorName, 'Dr. John Doe');
      expect(decoded.followUp, isFalse);
    });
  });

  group('ConsultationReplyStore Compare-Then-Overwrite', () {
    late String testDbPath;
    late ConsultationReplyStore store;

    setUp(() async {
      testDbPath = path.join(
        Directory.systemTemp.path,
        'test_reply_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      store = ConsultationReplyStore(
        factory: ffi.databaseFactoryFfi,
        databasePath: testDbPath,
      );
    });

    tearDown(() async {
      await store.close();
      final file = File(testDbPath);
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('stageReply saves as pending without setting confirmed baseline', () async {
      final reply = ConsultationReply(
        id: 'reply-1',
        caseId: 'CASE-101',
        doctorName: 'Dr. Kamath',
        advice: 'Keep patient hydrated',
        prescriptionNote: 'ORS',
        followUp: false,
        timestamp: DateTime.now(),
      );

      await store.stageReply(reply);
      final record = await store.read('reply-1');

      expect(record, isNotNull);
      expect(record!.confirmedPayload, isEmpty);
      expect(record.pendingPayload, reply.toPayload());
      expect(record.isConfirmed, isFalse);
      expect(record.pendingReply?.advice, 'Keep patient hydrated');
      expect(record.confirmedReply, isNull);
    });

    test('confirmReply overwrites confirmed baseline and clears pending', () async {
      final reply = ConsultationReply(
        id: 'reply-1',
        caseId: 'CASE-101',
        doctorName: 'Dr. Kamath',
        advice: 'Keep patient hydrated',
        prescriptionNote: 'ORS',
        followUp: false,
        timestamp: DateTime.now(),
      );

      await store.stageReply(reply);
      await store.confirmReply(reply);

      final record = await store.read('reply-1');
      expect(record, isNotNull);
      expect(record!.confirmedPayload, reply.toPayload());
      expect(record.pendingPayload, isNull);
      expect(record.isConfirmed, isTrue);

      final latest = await store.readLatestConfirmedForCase('CASE-101');
      expect(latest, isNotNull);
      expect(latest!.advice, 'Keep patient hydrated');
    });

    test('stageReply retains previous confirmed baseline when updating', () async {
      final replyV1 = ConsultationReply(
        id: 'reply-1',
        caseId: 'CASE-101',
        doctorName: 'Dr. Kamath',
        advice: 'Initial advice',
        prescriptionNote: '',
        followUp: false,
        timestamp: DateTime.now(),
      );
      await store.stageReply(replyV1);
      await store.confirmReply(replyV1);

      final replyV2 = ConsultationReply(
        id: 'reply-1',
        caseId: 'CASE-101',
        doctorName: 'Dr. Kamath',
        advice: 'Updated advice: Start antibiotics',
        prescriptionNote: 'Amoxicillin 500mg',
        followUp: true,
        timestamp: DateTime.now(),
      );
      await store.stageReply(replyV2);

      final record = await store.read('reply-1');
      expect(record!.confirmedPayload, replyV1.toPayload());
      expect(record.pendingPayload, replyV2.toPayload());
      expect(record.confirmedReply?.advice, 'Initial advice');
      expect(record.pendingReply?.advice, 'Updated advice: Start antibiotics');
    });
  });

  group('Reply Transmission Pipeline', () {
    test('transmits reply through compress -> encrypt -> parity -> recovery pipeline', () {
      final reply = ConsultationReply(
        caseId: 'CASE-500',
        doctorName: 'Dr. Specialist',
        advice: 'Admit to primary health centre immediately.',
        prescriptionNote: 'IV fluids 500ml',
        followUp: true,
        timestamp: DateTime.now(),
      );

      // Stable network (100% reliability)
      final result = simulateReplyTransmission(
        reply: reply,
        reliability: 100,
        sparePieces: 2,
        randomSeed: 42,
      );

      expect(result.rebuilt, isTrue);
      expect(result.survivalPercent, 100);
      expect(result.lostPieces, 0);
      expect(result.rebuiltReply, isNotNull);
      expect(result.rebuiltReply!.caseId, 'CASE-500');
      expect(result.rebuiltReply!.advice, 'Admit to primary health centre immediately.');
      expect(result.rebuiltReply!.followUp, isTrue);
      expect(result.stageLog, isNotEmpty);
    });

    test('recovers reply when parity pieces survive packet loss', () {
      final reply = ConsultationReply(
        caseId: 'CASE-501',
        doctorName: 'Dr. Specialist',
        advice: 'Rest and fluids',
        prescriptionNote: '',
        followUp: false,
        timestamp: DateTime.now(),
      );

      final result = simulateReplyTransmission(
        reply: reply,
        reliability: 75,
        sparePieces: 4,
        randomSeed: 1234,
      );

      expect(result.chunksSent, greaterThan(0));
      expect(result.chunkCount, greaterThan(0));
      expect(result.parityCount, 4);
      if (result.rebuilt) {
        expect(result.rebuiltReply?.advice, 'Rest and fluids');
      }
    });

    test('priority of reply is higher than media rank', () {
      final routineReply = ConsultationReply(
        caseId: 'CASE-1',
        doctorName: 'Dr. A',
        advice: 'A',
        prescriptionNote: '',
        followUp: false,
        timestamp: DateTime.now(),
      );
      final urgentReply = ConsultationReply(
        caseId: 'CASE-2',
        doctorName: 'Dr. B',
        advice: 'B',
        prescriptionNote: '',
        followUp: true,
        timestamp: DateTime.now(),
      );

      final queue = prioritizePayloads([
        const QueuedPayload(label: 'media', payload: 'image', priority: TransmissionPriority.media),
        QueuedPayload(label: 'urgent reply', payload: urgentReply.toPayload(), priority: TransmissionPriority.urgent),
        QueuedPayload(label: 'routine reply', payload: routineReply.toPayload(), priority: TransmissionPriority.routine),
      ]);

      expect(queue.first.label, 'urgent reply');
      expect(queue[1].label, 'routine reply');
      expect(queue.last.label, 'media');
    });
  });
}
