import 'package:cih/features/data/patient_model.dart';
import 'package:cih/features/transmission_engine/logic/chunking.dart';
import 'package:cih/features/transmission_engine/logic/delta_encoder.dart';
import 'package:cih/features/transmission_engine/logic/priority_queue.dart';
import 'package:cih/features/transmission_engine/logic/protocol_engine.dart';
import 'package:cih/features/transmission_engine/logic/secure_transmission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('transmission engine', () {
    test('reconstructs a payload from data and parity chunks', () {
      const payload =
          'This is a patient payload that should survive partial loss.';
      final chunks = buildProtectedChunks(
        payload,
        chunkSize: 8,
        sparePieces: 2,
      );
      final dataChunks = chunks.where((chunk) => !chunk.parity).toList();
      final dropped = dataChunks.take(2).toList();
      final remaining = chunks
          .where((chunk) => !dropped.contains(chunk))
          .toList();

      final reconstructed = reconstructPayload(
        remaining,
        expectedDataChunkCount: dataChunks.length,
        recoveryGroupCount: 2,
      );

      expect(reconstructed, payload);
    });

    test('prioritizes urgent vitals before routine and media payloads', () {
      final ordered = prioritizePayloads([
        const QueuedPayload(
          label: 'photo',
          payload: 'img',
          priority: TransmissionPriority.media,
        ),
        const QueuedPayload(
          label: 'vitals',
          payload: 'bp',
          priority: TransmissionPriority.urgent,
        ),
        const QueuedPayload(
          label: 'note',
          payload: 'note',
          priority: TransmissionPriority.routine,
        ),
      ]);

      expect(ordered.first.label, 'vitals');
      expect(ordered.last.label, 'photo');
    });

    test(
      'delta encoding only emits changed fields and keeps the record id',
      () {
        final previous = {
          'id': 'P1',
          'name': 'Ada',
          'bp': '120/80',
          'hr': '72',
        };
        final current = {
          'id': 'P1',
          'name': 'Ada Lovelace',
          'bp': '120/80',
          'hr': '74',
        };

        final delta = encodeDelta(current, previous);

        expect(delta.hasDelta, isTrue);
        expect(delta.changedFields, containsAll(['name', 'hr']));
        expect(delta.payload, contains('id=P1'));
        expect(delta.payload, isNot(contains('bp=')));
      },
    );

    test(
      'encrypts payloads before chunking and keeps the ciphertext unreadable',
      () {
        final patient = PatientModel(
          id: 'P2',
          displayName: 'Grace Hopper',
          age: 79,
          bloodPressure: '118/74',
          heartRate: 84,
          oxygenSaturation: 98,
          temperature: 36.8,
          notes: 'Needs review',
          photoRef: 'xray-1',
        );

        final result = simulateSecureTransmission(
          patient: patient,
          previousRecord: null,
          reliability: 95,
          sparePieces: 2,
          randomSeed: 1,
        );

        expect(result.encryptedByteCount, greaterThan(0));
        expect(result.delta.payload, contains('id=P2'));
        expect(result.firstPayloadLabel, 'urgent vitals');
      },
    );

    test('prioritizes critical clinical fields ahead of lower-risk fields', () {
      final patient = PatientModel(
        id: 'P3',
        displayName: 'Katherine Johnson',
        age: 40,
        bloodPressure: '120/80',
        heartRate: 88,
        oxygenSaturation: 97,
        temperature: 37.1,
        notes: 'Needs review',
        photoRef: 'xray-2',
        symptoms: 'Chest tightness',
        diagnosis: 'Monitoring',
        medicalHistory: 'Asthma',
        allergies: 'Penicillin',
        emergencyNotes: 'Rapid onset',
        address: '4 Observatory Lane',
      );

      final plan = buildClinicalTransmissionPlan(patient);

      expect(plan.priorityFields.first.priority, ClinicalPriority.critical);
      expect(plan.priorityFields.first.key, 'heartRate');
      expect(plan.priorityFields.last.priority, ClinicalPriority.low);
      expect(plan.sections.first, TransmissionSection.vitals);
    });

    test('flags implausible clinical values locally', () {
      final patient = PatientModel(
        id: 'P4',
        displayName: 'Alan Turing',
        age: 41,
        bloodPressure: '-10/40',
        heartRate: 260,
        oxygenSaturation: 101,
        temperature: 29,
        notes: 'Urgent',
        photoRef: '',
      );

      final issues = validateClinicalValues(patient);

      expect(issues, isNotEmpty);
      expect(
        issues.any((issue) => issue.message.contains('Heart Rate')),
        isTrue,
      );
    });

    test('round-trips compressed payloads through encryption and recovery', () {
      final original = 'BP 118/74 | HR 92 | SPO2 97 | Temp 36.8';
      final packed = compressAndEncryptPayload(original);
      final chunks = buildProtectedChunks(
        packed,
        chunkSize: 10,
        sparePieces: 2,
      );
      final dataChunks = chunks.where((chunk) => !chunk.parity).toList();
      final dropped = dataChunks.take(2).toList();
      final remaining = chunks
          .where((chunk) => !dropped.contains(chunk))
          .toList();

      final reconstructed = reconstructPayload(
        remaining,
        expectedDataChunkCount: dataChunks.length,
        recoveryGroupCount: 2,
      );
      final restored = decryptAndDecompressPayload(reconstructed);

      expect(restored, original);
    });

    test('urgent cases trigger fallback sooner than routine ones', () {
      final patient = PatientModel(
        id: 'P5',
        displayName: 'Ruth Bader Ginsburg',
        age: 87,
        bloodPressure: '130/80',
        heartRate: 96,
        oxygenSaturation: 95,
        temperature: 37.2,
        notes: 'Needs rapid transport',
        photoRef: 'thumb-1',
        urgent: true,
      );

      final urgent = simulateSecureTransmission(
        patient: patient,
        previousRecord: null,
        reliability: 40,
        urgent: true,
        retryAttempt: 0,
      );
      final routine = simulateSecureTransmission(
        patient: patient.copyWith(urgent: false),
        previousRecord: null,
        reliability: 40,
        urgent: false,
        retryAttempt: 2,
      );

      expect(urgent.fallbackTriggered, isTrue);
      expect(
        urgent.fallbackTriggerAttempt,
        lessThan(routine.fallbackTriggerAttempt),
      );
      expect(routine.fallbackTriggered, isFalse);
    });

    test(
      'urgent fallback keeps the smallest image tier while routine fallback drops it',
      () {
        final patient = PatientModel(
          id: 'P6',
          displayName: 'Mary Anning',
          age: 72,
          bloodPressure: '122/78',
          heartRate: 88,
          oxygenSaturation: 96,
          temperature: 37.0,
          notes: 'Urgent review',
          photoRef: 'thumb-2',
          urgent: true,
        );

        final urgent = simulateSecureTransmission(
          patient: patient,
          previousRecord: null,
          reliability: 40,
          urgent: true,
          retryAttempt: 0,
        );
        final routine = simulateSecureTransmission(
          patient: patient.copyWith(urgent: false),
          previousRecord: null,
          reliability: 40,
          urgent: false,
          retryAttempt: 2,
        );

        expect(urgent.fallbackImageTier, 'tiny-blurred-thumbnail');
        expect(routine.fallbackImageTier, isEmpty);
      },
    );

    test('manual urgent cases send the emergency flag first', () {
      final patient = PatientModel(
        id: 'P7',
        displayName: 'Ada Lovelace',
        age: 36,
        bloodPressure: '85/53',
        heartRate: 132,
        oxygenSaturation: 91,
        temperature: 38.4,
        notes: 'Shock risk',
        photoRef: '',
        urgent: true,
      );

      final result = simulateSecureTransmission(
        patient: patient,
        previousRecord: null,
        reliability: 70,
        urgent: true,
        randomSeed: 4,
      );

      expect(result.firstPayloadLabel, 'manual urgent flag');
    });

    test('seeded loss inside parity threshold rebuilds exactly', () {
      final chunks = buildProtectedChunks(
        'vitals|vitals|vitals|vitals|vitals|vitals',
        chunkSize: 8,
        sparePieces: 3,
      );
      final dataChunks = chunks.where((chunk) => !chunk.parity).toList();
      final dropped = dataChunks.where((chunk) => chunk.index < 3).toSet();
      final remaining = chunks.where((chunk) => !dropped.contains(chunk));

      final reconstructed = reconstructPayload(
        remaining,
        expectedDataChunkCount: dataChunks.length,
        recoveryGroupCount: 3,
      );

      expect(reconstructed, 'vitals|vitals|vitals|vitals|vitals|vitals');
    });

    test('loss beyond parity threshold reports partial recovery', () {
      final chunks = buildProtectedChunks(
        '0123456789abcdef0123456789abcdef',
        chunkSize: 4,
        sparePieces: 2,
      );
      final dataChunks = chunks.where((chunk) => !chunk.parity).toList();
      final dropped = dataChunks.where((chunk) => chunk.index.isEven).toSet();
      final remaining = chunks.where((chunk) => !dropped.contains(chunk));

      final result = tryReconstructPayload(
        remaining,
        expectedDataChunkCount: dataChunks.length,
        recoveryGroupCount: 2,
      );

      expect(result.rebuilt, isFalse);
      expect(result.failedGroups, greaterThan(0));
      expect(result.confidencePercent, lessThan(100));
    });

    test('compression stage sizes are measured from real bytes', () {
      final patient = PatientModel(
        id: 'P8',
        displayName: 'Repeatable Payload',
        age: 45,
        bloodPressure: '120/80',
        heartRate: 72,
        oxygenSaturation: 98,
        temperature: 36.8,
        notes: List.filled(40, 'stable vitals stable vitals').join(' '),
        photoRef: '',
      );

      final result = simulateSecureTransmission(
        patient: patient,
        previousRecord: null,
        reliability: 100,
        sparePieces: 2,
        randomSeed: 2,
      );

      expect(result.encodedByteCount, lessThan(result.originalByteCount));
      expect(result.compressedByteCount, lessThan(result.encodedByteCount));
      expect(result.finalByteCount, greaterThan(result.compressedByteCount));
      expect(result.stageLog, hasLength(5));
      expect(result.stageLog[3], startsWith('Encrypted payload:'));
      expect(result.stageLog[4], startsWith('Redundant chunks:'));
    });

    test('confirmed baseline sends sparse positional delta bytes', () {
      final previous = PatientModel(
        id: 'P10',
        displayName: 'Baseline Patient',
        age: 45,
        bloodPressure: '120/80',
        heartRate: 72,
        oxygenSaturation: 98,
        temperature: 36.8,
        notes: List.filled(30, 'stable note').join(' '),
        photoRef: 'image-a',
      ).toWireMap();
      final patient = PatientModel(
        id: 'P10',
        displayName: 'Baseline Patient',
        age: 45,
        bloodPressure: '120/80',
        heartRate: 88,
        oxygenSaturation: 98,
        temperature: 36.8,
        notes: List.filled(30, 'stable note').join(' '),
        photoRef: 'image-a',
      );

      final full = simulateSecureTransmission(
        patient: patient,
        previousRecord: null,
        reliability: 100,
        sparePieces: 2,
        randomSeed: 3,
      );
      final delta = simulateSecureTransmission(
        patient: patient,
        previousRecord: previous,
        reliability: 100,
        sparePieces: 2,
        randomSeed: 3,
      );

      expect(delta.delta.changedFields, ['heartRate']);
      expect(delta.encodedByteCount, lessThan(full.encodedByteCount));
      expect(delta.delta.payload, isNot(contains('notes=')));
      expect(delta.checksumMatch, isTrue);
    });

    test('same loss percent with different seeds produces different drops', () {
      final patient = PatientModel(
        id: 'P9',
        displayName: 'Random Loss',
        age: 45,
        bloodPressure: '120/80',
        heartRate: 72,
        oxygenSaturation: 98,
        temperature: 36.8,
        notes: List.filled(25, 'network trial payload').join(' '),
        photoRef: '',
      );

      final outcomes = <String>{};
      for (var seed = 1; seed <= 8; seed++) {
        final result = simulateSecureTransmission(
          patient: patient,
          previousRecord: null,
          reliability: 65,
          sparePieces: 2,
          randomSeed: seed,
        );
        outcomes.add(result.missingChunkIds.join(','));
      }

      expect(outcomes.length, greaterThan(1));
    });
  });
}
