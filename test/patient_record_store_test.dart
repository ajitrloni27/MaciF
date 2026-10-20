import 'dart:io';

import 'package:cih/features/data/patient_model.dart';
import 'package:cih/features/network_simulator/providers/network_simulator_provider.dart';
import 'package:cih/features/patient_storage/logic/patient_record_store.dart';
import 'package:cih/features/patient_storage/providers/patient_storage_provider.dart';
import 'package:cih/features/transmission_engine/providers/transmission_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

PatientModel _patient({
  int heartRate = 76,
  String bp = '120/80',
  String gender = '0',
}) {
  return PatientModel(
    id: 'P1',
    displayName: 'Ada Lovelace',
    age: 36,
    bloodPressure: bp,
    heartRate: heartRate,
    oxygenSaturation: 99,
    temperature: 36.7,
    notes: 'Stable',
    photoRef: 'photo-1',
    gender: gender,
  );
}

Future<PatientRecordStore> _store(String name) async {
  sqfliteFfiInit();
  final file = File('${Directory.systemTemp.path}/$name.db');
  if (file.existsSync()) {
    file.deleteSync();
  }
  return PatientRecordStore(
    factory: databaseFactoryFfi,
    databasePath: file.path,
  );
}

void main() {
  test(
    'diffs a changed capture against the database-confirmed baseline',
    () async {
      final store = await _store('medgate-diff');
      addTearDown(store.close);

      await store.markTransmissionConfirmed(_patient());
      final diff = await store.stageCapture(_patient(heartRate: 82));

      expect(diff.changedFields, ['heartRate']);
      expect((await store.read('P1'))!.status, PatientSyncStatus.updated);
    },
  );

  test('failed transmission keeps the last known-good baseline', () async {
    final store = await _store('medgate-failed');
    addTearDown(store.close);
    await store.markTransmissionConfirmed(_patient());

    final container = ProviderContainer(
      overrides: [patientRecordStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    container.read(patientStorageProvider.notifier);
    final changed = _patient(heartRate: 88);
    await store.stageCapture(changed);
    container.read(networkSimulatorProvider.notifier).setReliability(1);
    await container
        .read(transmissionProvider.notifier)
        .sendPatientRecord(patient: changed, sparePieces: 1);

    final confirmed = (await store.read('P1'))!.confirmedPatient!;
    expect(container.read(transmissionProvider).rebuilt, isFalse);
    expect(confirmed.heartRate, 76);
  });

  test('stores gender as schema code and flags gender deltas', () async {
    final store = await _store('medgate-gender');
    addTearDown(store.close);

    await store.markTransmissionConfirmed(_patient(gender: '0'));
    final diff = await store.stageCapture(_patient(gender: '1'));
    final pending = (await store.read('P1'))!.pendingPatient!;

    expect(pending.gender, '1');
    expect(diff.changedFields, contains('gender'));
    expect(
      diff.summaries(pending, _patient(gender: '0')).single,
      contains('Male -> Female'),
    );
  });

  test('successful transmission overwrites the confirmed baseline', () async {
    final store = await _store('medgate-success');
    addTearDown(store.close);
    await store.markTransmissionConfirmed(_patient());

    final container = ProviderContainer(
      overrides: [patientRecordStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    final changed = _patient(bp: '118/74');
    await store.stageCapture(changed);
    await container
        .read(transmissionProvider.notifier)
        .sendPatientRecord(patient: changed);

    final confirmed = (await store.read('P1'))!.confirmedPatient!;
    expect(container.read(transmissionProvider).rebuilt, isTrue);
    expect(confirmed.bloodPressure, '118/74');
    expect((await store.read('P1'))!.status, PatientSyncStatus.synced);
  });

  test('send stages and confirms the current capture in one flow', () async {
    final store = await _store('medgate-send-stages');
    addTearDown(store.close);
    final container = ProviderContainer(
      overrides: [patientRecordStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    await container
        .read(transmissionProvider.notifier)
        .sendPatientRecord(patient: _patient(heartRate: 90));

    final stored = await store.read('P1');
    expect(container.read(transmissionProvider).status, 'delivered');
    expect(stored?.status, PatientSyncStatus.synced);
    expect(stored?.confirmedPatient?.heartRate, 90);
  });

  test('database state survives store recreation', () async {
    sqfliteFfiInit();
    final file = File('${Directory.systemTemp.path}/medgate-restart.db');
    if (file.existsSync()) {
      file.deleteSync();
    }
    final first = PatientRecordStore(
      factory: databaseFactoryFfi,
      databasePath: file.path,
    );
    await first.markTransmissionConfirmed(_patient());
    await first.close();

    final second = PatientRecordStore(
      factory: databaseFactoryFfi,
      databasePath: file.path,
    );
    addTearDown(second.close);

    expect(
      (await second.read('P1'))!.confirmedPatient!.displayName,
      'Ada Lovelace',
    );
  });
}
