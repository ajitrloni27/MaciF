import 'dart:convert';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:encrypt/encrypt.dart';

import '../../data/patient_model.dart';
import '../../data/patient_schema.dart';
import 'chunking.dart';
import 'delta_encoder.dart';
import 'priority_queue.dart';
import 'protocol_engine.dart';

class SecureTransmissionResult {
  const SecureTransmissionResult({
    required this.delta,
    required this.lostPieces,
    required this.rebuilt,
    required this.survivalPercent,
    required this.chunkCount,
    required this.parityCount,
    required this.chunksSent,
    required this.chunksUsed,
    required this.checksumMatch,
    required this.sourceChecksum,
    required this.rebuiltChecksum,
    required this.naiveStatus,
    required this.naiveSucceeded,
    required this.firstPayloadLabel,
    required this.encryptedByteCount,
    required this.payload,
    required this.compressedByteCount,
    required this.encodedByteCount,
    required this.originalByteCount,
    required this.finalByteCount,
    required this.compressionRatio,
    required this.stageLog,
    required this.missingChunkIds,
    required this.recoveryConfidencePercent,
    required this.fallbackTriggered,
    required this.fallbackTriggerAttempt,
    required this.fallbackImageTier,
  });

  final DeltaResult delta;
  final int lostPieces;
  final bool rebuilt;
  final int survivalPercent;
  final int chunkCount;
  final int parityCount;
  final int chunksSent;
  final int chunksUsed;
  final bool checksumMatch;
  final String sourceChecksum;
  final String rebuiltChecksum;
  final String naiveStatus;
  final bool naiveSucceeded;
  final String firstPayloadLabel;
  final int encryptedByteCount;
  final String payload;
  final int compressedByteCount;
  final int encodedByteCount;
  final int originalByteCount;
  final int finalByteCount;
  final double compressionRatio;
  final List<String> stageLog;
  final List<String> missingChunkIds;
  final int recoveryConfidencePercent;
  final bool fallbackTriggered;
  final int fallbackTriggerAttempt;
  final String fallbackImageTier;
}

SecureTransmissionResult simulateSecureTransmission({
  required PatientModel patient,
  required Map<String, String>? previousRecord,
  required int reliability,
  int sparePieces = 3,
  int chunkSize = 18,
  bool urgent = false,
  int retryAttempt = 0,
  int? randomSeed,
}) {
  final delta = encodeDelta(patient.toWireMap(), previousRecord);
  final plan = buildClinicalTransmissionPlan(patient);
  final clinicalPayloads = plan.priorityFields
      .map(
        (field) => QueuedPayload(
          label: field.label,
          payload: '${field.priority.name}:${field.value}',
          priority: switch (field.priority) {
            ClinicalPriority.critical => TransmissionPriority.urgent,
            ClinicalPriority.high => TransmissionPriority.urgent,
            ClinicalPriority.medium => TransmissionPriority.routine,
            ClinicalPriority.low => TransmissionPriority.media,
          },
        ),
      )
      .toList();
  final queue = prioritizePayloads([
    if (urgent || patient.urgent)
      QueuedPayload(
        label: 'manual urgent flag',
        payload: buildEmergencySnapshot(patient),
        priority: TransmissionPriority.emergency,
      ),
    QueuedPayload(
      label: 'urgent vitals',
      payload: delta.payload,
      priority: TransmissionPriority.urgent,
    ),
    ...clinicalPayloads,
    if (patient.notes.trim().isNotEmpty)
      QueuedPayload(
        label: 'clinical note',
        payload: patient.notes,
        priority: TransmissionPriority.routine,
      ),
    if (patient.photoRef.trim().isNotEmpty)
      QueuedPayload(
        label: 'photo reference',
        payload: patient.photoRef,
        priority: TransmissionPriority.media,
      ),
  ]);
  final currentWireMap = patient.toWireMap();
  final deltaWireMap = _deltaWireMap(currentWireMap, delta);
  final rawPayload = delta.payload;
  final recordBytes = PatientSchema.encodeValueBytes(deltaWireMap);
  // Compress before encrypt so the payload is reduced with DEFLATE/gzip and the
  // ciphertext does not remain as raw, incompressible noise.
  final compressedPayload = _compressBytes(recordBytes);
  final encryptedPayload = _encrypted(compressedPayload);
  final chunks = buildProtectedChunks(
    encryptedPayload,
    chunkSize: chunkSize,
    sparePieces: sparePieces,
  );
  final lossRate = ((100 - reliability) / 100).clamp(0.0, 0.9);
  final random = randomSeed == null ? Random() : Random(randomSeed);
  final survivingChunks = <ProtectedChunk>[];
  final droppedChunks = <ProtectedChunk>[];
  for (final chunk in chunks) {
    if (random.nextDouble() < lossRate) {
      droppedChunks.add(chunk);
    } else {
      survivingChunks.add(chunk);
    }
  }
  final recovery = tryReconstructPayload(
    survivingChunks,
    expectedDataChunkCount: chunks.where((chunk) => !chunk.parity).length,
    recoveryGroupCount: sparePieces,
  );
  final lostPieces = droppedChunks.length;
  final dataChunks = chunks.where((chunk) => !chunk.parity).length;
  final rebuilt = recovery.rebuilt;
  final chunksUsed = recovery.recoveredDataChunks;
  final sourceChecksum = _checksum(encryptedPayload);
  final fallbackTriggered = urgent || (retryAttempt >= 3 && reliability < 60);
  final fallbackTriggerAttempt = urgent ? 0 : (retryAttempt + 1).clamp(0, 4);
  final fallbackImageTier = urgent && fallbackTriggered
      ? 'tiny-blurred-thumbnail'
      : '';
  final rebuiltChecksum = _checksum(recovery.payload);
  final checksumMatch = rebuilt && recovery.payload == encryptedPayload;
  final survival = rebuilt ? 100 : recovery.confidencePercent;
  final originalBytes = utf8.encode(rawPayload).length;
  final encodedBytes = recordBytes.length;
  final compressedBytes = base64.decode(compressedPayload).length;
  final encryptedBytes = utf8.encode(encryptedPayload).length;
  final finalBytes = chunks.fold<int>(
    0,
    (sum, chunk) => sum + utf8.encode(chunk.body).length,
  );

  return SecureTransmissionResult(
    delta: delta,
    lostPieces: lostPieces,
    rebuilt: rebuilt,
    survivalPercent: survival,
    chunkCount: dataChunks,
    parityCount: sparePieces,
    chunksSent: chunks.length,
    chunksUsed: chunksUsed,
    checksumMatch: checksumMatch,
    sourceChecksum: sourceChecksum,
    rebuiltChecksum: rebuiltChecksum,
    naiveStatus: lostPieces == 0
        ? 'Delivered'
        : reliability < 65
        ? 'Failed after full resend'
        : 'Stalled on full resend',
    naiveSucceeded: lostPieces == 0,
    firstPayloadLabel: queue.first.label,
    encryptedByteCount: encryptedBytes,
    payload: encryptedPayload,
    compressedByteCount: compressedBytes,
    encodedByteCount: encodedBytes,
    originalByteCount: originalBytes,
    finalByteCount: finalBytes,
    compressionRatio: _compressionRatio(rawPayload, compressedBytes),
    stageLog: _stageLog(
      originalBytes: originalBytes,
      encodedBytes: encodedBytes,
      compressedBytes: compressedBytes,
      encryptedBytes: encryptedBytes,
      finalBytes: finalBytes,
    ),
    missingChunkIds: droppedChunks
        .map((chunk) => '${chunk.parity ? 'parity' : 'data'}-${chunk.index}')
        .toList(),
    recoveryConfidencePercent: recovery.confidencePercent,
    fallbackTriggered: fallbackTriggered,
    fallbackTriggerAttempt: fallbackTriggerAttempt,
    fallbackImageTier: fallbackImageTier,
  );
}

Map<String, String> _deltaWireMap(
  Map<String, String> current,
  DeltaResult delta,
) {
  if (delta.changedFields.length == current.length) {
    return current;
  }
  return <String, String>{
    'id': current['id'] ?? '',
    for (final field in delta.changedFields) field: current[field] ?? '',
  };
}

String _compressPayload(String value) {
  final input = utf8.encode(value);
  return _compressBytes(input);
}

String _compressBytes(List<int> input) {
  final gzip = GZipEncoder();
  final output = gzip.encode(input, level: 9);
  return base64.encode(output);
}

String _decryptPayload(String value) {
  final decoded = base64.decode(value);
  final gzip = GZipDecoder();
  final output = gzip.decodeBytes(decoded);
  return utf8.decode(output);
}

String _checksum(String value) {
  final hash = value.codeUnits.fold<int>(
    0x811c9dc5,
    (current, unit) => (current ^ unit) * 0x01000193,
  );
  return hash.toUnsigned(32).toRadixString(16).padLeft(8, '0');
}

double _compressionRatio(String original, int compressedBytes) {
  final originalBytes = utf8.encode(original).length;
  if (originalBytes <= 0) {
    return 1.0;
  }
  return (originalBytes / compressedBytes).clamp(0.0, 10.0);
}

List<String> _stageLog({
  required int originalBytes,
  required int encodedBytes,
  required int compressedBytes,
  required int encryptedBytes,
  required int finalBytes,
}) {
  return [
    'Raw payload: $originalBytes B',
    'Positional payload: $encodedBytes B (${_saved(originalBytes, encodedBytes)} saved)',
    'GZip level 9: $compressedBytes B (${_saved(encodedBytes, compressedBytes)} saved)',
    'Encrypted payload: $encryptedBytes B (${_growth(compressedBytes, encryptedBytes)} overhead)',
    'Redundant chunks: $finalBytes B (${_growth(encryptedBytes, finalBytes)} overhead)',
  ];
}

String _saved(int before, int after) {
  if (before <= 0) {
    return '0.0%';
  }
  return '${(((before - after) / before) * 100).toStringAsFixed(1)}%';
}

String _growth(int before, int after) {
  if (before <= 0) {
    return '0.0%';
  }
  return '${(((after - before) / before) * 100).toStringAsFixed(1)}%';
}

String _encrypted(String value) {
  final key = Key.fromUtf8('0123456789abcdef0123456789abcdef');
  final iv = IV.fromSecureRandom(16);
  final encrypted = Encrypter(AES(key)).encrypt(value, iv: iv);
  return '${iv.base64}:${encrypted.base64}';
}

String compressAndEncryptPayload(String payload) {
  final compressedPayload = _compressPayload(payload);
  return _encrypted(compressedPayload);
}

String decryptAndDecompressPayload(String payload) {
  final parts = payload.split(':');
  if (parts.length < 2) {
    return payload;
  }
  final iv = IV.fromBase64(parts.first);
  final ciphertext = parts.sublist(1).join(':');
  final decrypted = Encrypter(
    AES(Key.fromUtf8('0123456789abcdef0123456789abcdef')),
  ).decrypt(Encrypted.fromBase64(ciphertext), iv: iv);
  return _decryptPayload(decrypted);
}
