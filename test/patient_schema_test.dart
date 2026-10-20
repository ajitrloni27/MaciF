import 'package:cih/features/data/patient_model.dart';
import 'package:cih/features/data/patient_schema.dart';
import 'package:cih/features/transmission_engine/logic/recovery_strategy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('patient schema', () {
    test('round-trips binary payloads through the shared schema', () {
      final patient = PatientModel(
        id: 'P7',
        displayName: 'Ada Lovelace',
        age: 36,
        bloodPressure: '120/80',
        heartRate: 72,
        oxygenSaturation: 98,
        temperature: 36.7,
        notes: 'Stable',
        photoRef: 'img-7',
        urgent: true,
        symptoms: 'Fatigue',
        gender: '1',
      );

      final payload = patient.toPayload();
      final decoded = PatientModel.fromPayload(payload);
      final decodedBytes = decodePatientRecord(encodePatientRecord(patient));

      expect(payload, startsWith(PatientSchema.binaryPayloadPrefix));
      expect(decoded.displayName, 'Ada Lovelace');
      expect(decoded.bloodPressure, '120/80');
      expect(decoded.urgent, isTrue);
      expect(decoded.symptoms, 'Fatigue');
      expect(decoded.gender, '1');
      expect(decodedBytes.gender, '1');
    });

    test('binary encoding handles edge values and both gender codes', () {
      for (final gender in ['0', '1']) {
        final patient = PatientModel(
          id: 'P-edge',
          displayName: '',
          age: 255,
          bloodPressure: '0/0',
          heartRate: 255,
          oxygenSaturation: 100,
          temperature: 42.5,
          notes: '',
          photoRef: '',
          gender: gender,
        );

        final decoded = decodePatientRecord(encodePatientRecord(patient));

        expect(decoded.displayName, '');
        expect(decoded.age, 255);
        expect(decoded.gender, gender);
        expect(decoded.temperature, 42.5);
      }
    });

    test('binary payload is smaller than legacy delimited text', () {
      final patient = PatientModel(
        id: 'P8',
        displayName: 'Ahmed S',
        age: 20,
        bloodPressure: '100/70',
        heartRate: 89,
        oxygenSaturation: 97,
        temperature: 36.9,
        notes: 'Stable',
        photoRef: 'img',
        gender: '0',
      );

      final binary = encodePatientRecord(patient);
      final legacy = PatientSchema.encodeDelimitedValues(patient.toWireMap());

      expect(binary.length, lessThan(legacy.length));
    });

    test('legacy delimited payloads still decode cleanly', () {
      final decoded = PatientModel.fromPayload(
        'MGP1|P1|Ada|36|120/80|76|99|36.7|Stable|photo|false|||||||||||female|',
      );

      expect(decoded.displayName, 'Ada');
      expect(decoded.gender, '1');
    });
  });

  group('recovery strategy', () {
    test('does not smooth confidence upward beyond recovery bounds', () {
      const xor = XorParityRecoveryStrategy();
      const rs = ReedSolomonRecoveryStrategy();

      final xorResult = xor.evaluate(
        expectedChunks: 8,
        receivedChunks: 6,
        recoveryChunks: 2,
        recoveredFields: ['bloodPressure', 'heartRate'],
        checksumMatched: false,
      );
      final rsResult = rs.evaluate(
        expectedChunks: 8,
        receivedChunks: 6,
        recoveryChunks: 2,
        recoveredFields: ['bloodPressure', 'heartRate'],
        checksumMatched: false,
      );

      expect(xorResult.confidencePercent, 100);
      expect(rsResult.state, RecoveryState.recovered);
      final failed = rs.evaluate(
        expectedChunks: 8,
        receivedChunks: 3,
        recoveryChunks: 2,
        recoveredFields: ['bloodPressure'],
        checksumMatched: false,
      );
      expect(failed.confidencePercent, 38);
      expect(failed.state, RecoveryState.degraded);
    });
  });
}
