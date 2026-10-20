import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/patient_model.dart';
import '../../patient_storage/providers/patient_storage_provider.dart';
import '../logic/nfc_patient_reader.dart';

class NfcState {
  const NfcState({
    this.status = 'idle',
    this.payload = 'No patient card scanned yet',
    this.message = 'Awaiting scan',
    this.valid = false,
    this.confidence = 0,
    this.patient,
    this.buffered = false,
    this.requiresPermission = false,
    this.showGuide = false,
    this.captureSource = 'none',
  });

  final String status;
  final String payload;
  final String message;
  final bool valid;
  final int confidence;
  final PatientModel? patient;
  final bool buffered;
  final bool requiresPermission;
  final bool showGuide;
  final String captureSource;

  NfcState copyWith({
    String? status,
    String? payload,
    String? message,
    bool? valid,
    int? confidence,
    PatientModel? patient,
    bool? buffered,
    bool? requiresPermission,
    bool? showGuide,
    String? captureSource,
  }) {
    return NfcState(
      status: status ?? this.status,
      payload: payload ?? this.payload,
      message: message ?? this.message,
      valid: valid ?? this.valid,
      confidence: confidence ?? this.confidence,
      patient: patient ?? this.patient,
      buffered: buffered ?? this.buffered,
      requiresPermission: requiresPermission ?? this.requiresPermission,
      showGuide: showGuide ?? this.showGuide,
      captureSource: captureSource ?? this.captureSource,
    );
  }
}

class NfcController extends Notifier<NfcState> {
  NfcController({NfcPatientReaderInterface? reader})
    : _reader = reader ?? NfcPatientReader();

  final NfcPatientReaderInterface _reader;

  @override
  NfcState build() => const NfcState();

  Future<void> scanTag() async {
    state = state.copyWith(
      status: 'scanning',
      message: 'Hold the phone near a patient NFC card',
      valid: false,
      confidence: 0,
      requiresPermission: false,
      showGuide: true,
    );

    try {
      final patient = await _reader.readPatient();
      state = NfcState(
        status: 'captured',
        payload: patient.toPayload(),
        message: 'Patient card read and validated',
        valid: true,
        confidence: 100,
        patient: patient,
        showGuide: false,
        captureSource: 'nfc',
      );
      unawaited(
        ref.read(patientStorageProvider.notifier).stageCapture(patient),
      );
    } catch (error) {
      final permissionRequired =
          error is NfcPermissionException ||
          error.toString().toLowerCase().contains('permission') ||
          error.toString().toLowerCase().contains('nfc is');
      state = state.copyWith(
        status: permissionRequired ? 'permission-required' : 'scan failed',
        message: permissionRequired
            ? 'NFC is not available right now. Enable NFC in settings or continue by entering patient details manually.'
            : 'NFC could not be read. Type patient data instead.',
        valid: false,
        confidence: 0,
        requiresPermission: permissionRequired,
        showGuide: false,
      );
    }
  }

  void loadFallback() {
    state = NfcState(
      status: 'manual',
      payload: PatientModel.empty.toPayload(),
      message: 'Enter patient data manually',
      valid: false,
      confidence: 0,
      patient: PatientModel.empty,
      captureSource: 'manual',
    );
  }

  void importPayload(String payload) {
    final patient = PatientModel.fromPayload(payload);
    state = NfcState(
      status: 'manual',
      payload: patient.toPayload(),
      message: patient.isValidForSend
          ? 'Manual patient data validated'
          : 'Enter all required patient fields',
      valid: patient.isValidForSend,
      confidence: patient.isValidForSend ? 100 : 0,
      patient: patient,
      captureSource: 'manual',
    );
    if (patient.isValidForSend) {
      unawaited(
        ref.read(patientStorageProvider.notifier).stageCapture(patient),
      );
    }
  }

  Future<void> writePatientCard() async {
    final patient = state.patient;
    if (patient == null || !patient.isValidForSend) {
      state = state.copyWith(
        status: 'manual',
        message: 'Complete required patient fields before writing a card',
        valid: false,
      );
      return;
    }

    state = state.copyWith(
      status: 'writing',
      message: 'Hold near a writable patient NFC card',
      requiresPermission: false,
      showGuide: true,
    );

    try {
      await _reader.writePatient(patient);
      state = state.copyWith(
        status: 'written',
        payload: patient.toPayload(),
        message: 'Patient card written and ready to scan',
        valid: true,
        confidence: 100,
        buffered: false,
        showGuide: false,
      );
    } catch (error) {
      final permissionRequired =
          error is NfcPermissionException ||
          error.toString().toLowerCase().contains('permission') ||
          error.toString().toLowerCase().contains('nfc is') ||
          error.toString().toLowerCase().contains('not writable');
      state = state.copyWith(
        status: permissionRequired ? 'permission-required' : 'write failed',
        message: permissionRequired
            ? 'NFC writing is not available. Check NFC settings or use manual entry.'
            : 'NFC card could not be written. Try another tag or keep manual entry.',
        requiresPermission: permissionRequired,
        showGuide: false,
      );
    }
  }

  void updateVitals({
    String? id,
    String? displayName,
    int? age,
    String? bloodPressure,
    int? heartRate,
    int? oxygenSaturation,
    double? temperature,
    String? notes,
    String? photoRef,
    bool? urgent,
    String? symptoms,
    String? diagnosis,
    String? medicalHistory,
    String? currentMedication,
    String? allergies,
    String? consciousness,
    String? emergencyNotes,
    String? address,
    String? contactDetails,
    String? insurance,
    String? gender,
    String? bloodGroup,
  }) {
    final current = state.patient ?? PatientModel.empty;
    final updated = current.copyWith(
      id: id,
      displayName: displayName,
      age: age,
      bloodPressure: bloodPressure,
      heartRate: heartRate,
      oxygenSaturation: oxygenSaturation,
      temperature: temperature,
      notes: notes,
      photoRef: photoRef,
      urgent: urgent,
      symptoms: symptoms,
      diagnosis: diagnosis,
      medicalHistory: medicalHistory,
      currentMedication: currentMedication,
      allergies: allergies,
      consciousness: consciousness,
      emergencyNotes: emergencyNotes,
      address: address,
      contactDetails: contactDetails,
      insurance: insurance,
      gender: gender,
      bloodGroup: bloodGroup,
    );
    final isComplete = updated.isValidForSend;
    state = state.copyWith(
      status: isComplete ? 'manual' : 'manual',
      payload: updated.toPayload(),
      patient: updated,
      valid: isComplete,
      buffered: true,
      message: isComplete
          ? 'Patient update buffered for delta send'
          : 'Enter all required patient fields',
      confidence: isComplete ? 100 : 0,
      showGuide: false,
    );
    if (isComplete) {
      unawaited(
        ref.read(patientStorageProvider.notifier).stageCapture(updated),
      );
    }
  }

  void clear() {
    state = const NfcState();
  }
}

final nfcProvider = NotifierProvider<NfcController, NfcState>(
  NfcController.new,
);
