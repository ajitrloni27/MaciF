import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/patient_model.dart';
import '../logic/patient_record_store.dart';

class PatientStorageState {
  const PatientStorageState({
    this.records = const <StoredPatientRecord>[],
    this.latestDiff = const PatientRecordDiff(changedFields: <String>[]),
    this.latestPatient,
  });

  final List<StoredPatientRecord> records;
  final PatientRecordDiff latestDiff;
  final PatientModel? latestPatient;

  StoredPatientRecord? recordFor(String id) {
    for (final record in records) {
      if (record.recordId == id) {
        return record;
      }
    }
    return null;
  }

  PatientStorageState copyWith({
    List<StoredPatientRecord>? records,
    PatientRecordDiff? latestDiff,
    PatientModel? latestPatient,
  }) {
    return PatientStorageState(
      records: records ?? this.records,
      latestDiff: latestDiff ?? this.latestDiff,
      latestPatient: latestPatient ?? this.latestPatient,
    );
  }
}

final patientRecordStoreProvider = Provider<PatientRecordStore>((ref) {
  final store = PatientRecordStore();
  ref.onDispose(store.close);
  return store;
});

class PatientStorageController extends Notifier<PatientStorageState> {
  @override
  PatientStorageState build() {
    Future.microtask(refresh);
    return const PatientStorageState();
  }

  Future<void> refresh() async {
    final records = await ref.read(patientRecordStoreProvider).readAll();
    state = state.copyWith(records: records);
  }

  Future<PatientRecordDiff> stageCapture(PatientModel patient) async {
    final diff = await ref
        .read(patientRecordStoreProvider)
        .stageCapture(patient);
    final records = await ref.read(patientRecordStoreProvider).readAll();
    state = PatientStorageState(
      records: records,
      latestDiff: diff,
      latestPatient: patient,
    );
    return diff;
  }

  Future<Map<String, String>?> confirmedWireMap(String recordId) {
    return ref.read(patientRecordStoreProvider).confirmedWireMap(recordId);
  }

  Future<void> markTransmissionConfirmed(PatientModel patient) async {
    await ref
        .read(patientRecordStoreProvider)
        .markTransmissionConfirmed(patient);
    final records = await ref.read(patientRecordStoreProvider).readAll();
    state = PatientStorageState(
      records: records,
      latestDiff: const PatientRecordDiff(changedFields: <String>[]),
      latestPatient: patient,
    );
  }
}

final patientStorageProvider =
    NotifierProvider<PatientStorageController, PatientStorageState>(
      PatientStorageController.new,
    );
