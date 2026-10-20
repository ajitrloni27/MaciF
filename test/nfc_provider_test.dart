import 'package:cih/features/data/patient_model.dart';
import 'package:cih/features/nfc_capture/logic/nfc_patient_reader.dart';
import 'package:cih/features/nfc_capture/providers/nfc_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeNfcReader implements NfcPatientReaderInterface {
  FakeNfcReader({this.patient});

  final PatientModel? patient;
  bool wrote = false;

  @override
  Future<PatientModel> readPatient() async {
    final patient = this.patient;
    if (patient != null) {
      return patient;
    }
    throw const NfcPermissionException('Enable NFC in settings to continue.');
  }

  @override
  Future<void> writePatient(PatientModel patient) async {
    wrote = true;
  }
}

void main() {
  test('permission errors switch the NFC flow into a guidance state', () async {
    final container = ProviderContainer(
      overrides: [
        nfcProvider.overrideWith(() => NfcController(reader: FakeNfcReader())),
      ],
    );
    addTearDown(container.dispose);

    await container.read(nfcProvider.notifier).scanTag();
    final state = container.read(nfcProvider);

    expect(state.status, 'permission-required');
    expect(state.requiresPermission, isTrue);
    expect(state.message, contains('Enable NFC'));
  });

  test('manual records can be written back to an NFC card', () async {
    final reader = FakeNfcReader();
    final container = ProviderContainer(
      overrides: [
        nfcProvider.overrideWith(() => NfcController(reader: reader)),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(nfcProvider.notifier)
        .importPayload(
          'id=P1|name=Ada|age=36|bp=120/80|hr=76|spo2=99|temp=36.7',
        );
    await container.read(nfcProvider.notifier).writePatientCard();
    final state = container.read(nfcProvider);

    expect(reader.wrote, isTrue);
    expect(state.status, 'written');
    expect(state.captureSource, 'manual');
  });
}
