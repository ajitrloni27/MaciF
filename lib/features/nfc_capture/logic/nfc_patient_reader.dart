import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

import '../../data/patient_model.dart';

abstract class NfcPatientReaderInterface {
  Future<PatientModel> readPatient();
  Future<void> writePatient(PatientModel patient);
}

class NfcPermissionException implements Exception {
  const NfcPermissionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NfcPatientReader implements NfcPatientReaderInterface {
  @override
  Future<PatientModel> readPatient() async {
    final availability = await NfcManager.instance.checkAvailability();
    if (availability != NfcAvailability.enabled) {
      throw NfcPermissionException(
        'Enable NFC in device settings and try again. You can still continue by typing patient details manually.',
      );
    }

    final completer = Completer<PatientModel>();
    await NfcManager.instance.startSession(
      pollingOptions: const {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
      },
      alertMessageIos: 'Hold near a patient card',
      onDiscovered: (tag) async {
        try {
          final payload = await _readPayload(tag);
          final patient = PatientModel.fromPayload(payload);
          if (!patient.isValidForSend) {
            throw FormatException('Patient card is missing required fields');
          }
          if (!completer.isCompleted) {
            completer.complete(patient);
          }
          await NfcManager.instance.stopSession(
            alertMessageIos: 'Patient loaded',
          );
        } catch (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
          await NfcManager.instance.stopSession(
            errorMessageIos: 'Could not read patient card',
          );
        }
      },
    );
    return completer.future.timeout(const Duration(seconds: 20));
  }

  @override
  Future<void> writePatient(PatientModel patient) async {
    final availability = await NfcManager.instance.checkAvailability();
    if (availability != NfcAvailability.enabled) {
      throw const NfcPermissionException(
        'Enable NFC in device settings before writing a patient card.',
      );
    }

    final completer = Completer<void>();
    await NfcManager.instance.startSession(
      pollingOptions: const {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
      },
      alertMessageIos: 'Hold near a writable patient card',
      onDiscovered: (tag) async {
        try {
          await _writePayload(tag, patient.toPayload());
          if (!completer.isCompleted) {
            completer.complete();
          }
          await NfcManager.instance.stopSession(
            alertMessageIos: 'Patient card written',
          );
        } catch (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
          await NfcManager.instance.stopSession(
            errorMessageIos: 'Could not write patient card',
          );
        }
      },
    );
    return completer.future.timeout(const Duration(seconds: 20));
  }

  Future<String> _readPayload(NfcTag tag) async {
    final message = await _readNdefMessage(tag);
    final records = message?.records ?? const <NdefRecord>[];
    if (records.isEmpty) {
      throw const FormatException('No NDEF records found');
    }
    final record = records.firstWhere(
      _isTextRecord,
      orElse: () => records.first,
    );
    return _decodeRecord(record);
  }

  Future<NdefMessage?> _readNdefMessage(NfcTag tag) async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final ndef = NdefAndroid.from(tag);
        return ndef?.getNdefMessage();
      case TargetPlatform.iOS:
        final ndef = NdefIos.from(tag);
        return ndef?.readNdef();
      default:
        throw UnsupportedError('NFC is not supported on this platform');
    }
  }

  Future<void> _writePayload(NfcTag tag, String payload) async {
    final message = NdefMessage(records: [_textRecord(payload)]);
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final ndef = NdefAndroid.from(tag);
        if (ndef == null || !ndef.isWritable) {
          throw const NfcPermissionException('This NFC tag is not writable.');
        }
        await ndef.writeNdefMessage(message);
      case TargetPlatform.iOS:
        final ndef = NdefIos.from(tag);
        final status = await ndef?.queryNdefStatus();
        if (ndef == null || status?.status != NdefStatusIos.readWrite) {
          throw const NfcPermissionException('This NFC tag is not writable.');
        }
        await ndef.writeNdef(message);
      default:
        throw UnsupportedError('NFC is not supported on this platform');
    }
  }

  NdefRecord _textRecord(String value) {
    final language = utf8.encode('en');
    final text = utf8.encode(value);
    return NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,
      type: Uint8List.fromList(utf8.encode('T')),
      identifier: Uint8List(0),
      payload: Uint8List.fromList([language.length, ...language, ...text]),
    );
  }

  bool _isTextRecord(NdefRecord record) {
    return utf8.decode(record.type, allowMalformed: true) == 'T';
  }

  String _decodeRecord(NdefRecord record) {
    if (_isTextRecord(record) && record.payload.isNotEmpty) {
      final languageLength = record.payload.first & 0x3f;
      return utf8.decode(
        record.payload.skip(1 + languageLength).toList(),
        allowMalformed: true,
      );
    }
    return utf8.decode(record.payload, allowMalformed: true);
  }
}
