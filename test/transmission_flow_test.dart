import 'dart:io';

import 'package:cih/features/data/patient_model.dart';
import 'package:cih/features/network_simulator/providers/network_simulator_provider.dart';
import 'package:cih/features/patient_storage/logic/patient_record_store.dart';
import 'package:cih/features/patient_storage/providers/patient_storage_provider.dart';
import 'package:cih/features/transmission_engine/logic/chunking.dart';
import 'package:cih/features/transmission_engine/logic/parity.dart';
import 'package:cih/features/transmission_engine/providers/transmission_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<ProviderContainer> _containerWithFreshStore(String name) async {
  sqfliteFfiInit();
  final file = File('${Directory.systemTemp.path}/$name.db');
  if (file.existsSync()) {
    file.deleteSync();
  }
  final store = PatientRecordStore(
    factory: databaseFactoryFfi,
    databasePath: file.path,
  );
  final container = ProviderContainer(
    overrides: [patientRecordStoreProvider.overrideWithValue(store)],
  );
  addTearDown(() async {
    container.dispose();
    await store.close();
    if (file.existsSync()) {
      file.deleteSync();
    }
  });
  return container;
}

void main() {
  test('parity values are generated from chunks', () {
    final chunks = chunkText('abc', 2);
    final parity = generateParity(chunks);

    expect(chunks, ['ab', 'c']);
    expect(parity, isNotEmpty);
  });

  test('sending on stable network completes as delivered', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(transmissionProvider.notifier);
    await controller.sendTransmission();

    final state = container.read(transmissionProvider);
    expect(state.status, 'delivered');
    expect(state.progress, 100);
  });

  test('sending records an activity entry in the history', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(transmissionProvider.notifier);
    await controller.sendTransmission(
      payload:
          'id=40A1|name=Asha Raman|age=47|bp=132/86|hr=112|spo2=93|temp=101.2',
      networkMode: 'stable',
    );

    final state = container.read(transmissionProvider);
    expect(state.history, isNotEmpty);
    expect(state.history.first.status, 'delivered');
  });

  test(
    'compare mode distinguishes MedGate rebuild from naive resend',
    () async {
      final container = await _containerWithFreshStore('medgate-flow-send');

      container.read(networkSimulatorProvider.notifier).setReliability(95);
      await container
          .read(transmissionProvider.notifier)
          .sendPatientRecord(
            patient: const PatientModel(
              id: 'P2',
              displayName: 'Grace Hopper',
              age: 79,
              bloodPressure: '118/74',
              heartRate: 84,
              oxygenSaturation: 98,
              temperature: 36.8,
              notes: 'Needs review',
              photoRef: 'xray-1',
            ),
            sparePieces: 3,
            randomSeed: 1,
          );
      final state = container.read(transmissionProvider);

      expect(state.rebuilt, isTrue);
      expect(state.receipts, isNotEmpty);
      expect(state.receipts.first.checksumMatch, isTrue);
      expect(state.normalAppStatus, isNot('Delivered'));
    },
  );

  test(
    'urgent packets preempt a routine packet in the visible queue',
    () async {
      final container = await _containerWithFreshStore(
        'medgate-priority-queue',
      );
      container.read(networkSimulatorProvider.notifier).setLatency(1200);
      final controller = container.read(transmissionProvider.notifier);

      final routineFuture = controller.sendPatientRecord(
        patient: const PatientModel(
          id: 'P10',
          displayName: 'Routine Patient',
          age: 45,
          bloodPressure: '120/80',
          heartRate: 76,
          oxygenSaturation: 98,
          temperature: 36.7,
          notes: 'Routine update',
          photoRef: '',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await controller.sendPatientRecord(
        patient: const PatientModel(
          id: 'P11',
          displayName: 'Urgent Patient',
          age: 52,
          bloodPressure: '85/53',
          heartRate: 132,
          oxygenSaturation: 91,
          temperature: 38.4,
          notes: 'Shock risk',
          photoRef: '',
          urgent: true,
        ),
      );
      await routineFuture;

      final state = container.read(transmissionProvider);
      expect(state.queueItems.first.isUrgent, isTrue);
      expect(
        state.queueItems.where((item) => item.status == 'delivered'),
        hasLength(2),
      );
      expect(
        state.logs.any((log) => log.contains('Paused routine packet P10')),
        isTrue,
      );
    },
  );
}
