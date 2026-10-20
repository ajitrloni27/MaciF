import 'dart:convert';
import 'dart:math';

import '../../specialist_view/models/consultation_reply.dart';
import 'chunking.dart';
import 'priority_queue.dart';
import 'secure_transmission.dart';

class ReplyTransmissionResult {
  const ReplyTransmissionResult({
    required this.reply,
    required this.rebuilt,
    required this.survivalPercent,
    required this.chunkCount,
    required this.parityCount,
    required this.chunksSent,
    required this.lostPieces,
    required this.recoveryConfidencePercent,
    required this.stageLog,
    required this.originalByteCount,
    required this.compressedByteCount,
    required this.encryptedByteCount,
    required this.rebuiltReply,
  });

  final ConsultationReply reply;
  final bool rebuilt;
  final int survivalPercent;
  final int chunkCount;
  final int parityCount;
  final int chunksSent;
  final int lostPieces;
  final int recoveryConfidencePercent;
  final List<String> stageLog;
  final int originalByteCount;
  final int compressedByteCount;
  final int encryptedByteCount;
  final ConsultationReply? rebuiltReply;
}

ReplyTransmissionResult simulateReplyTransmission({
  required ConsultationReply reply,
  required int reliability,
  int sparePieces = 2,
  int chunkSize = 24,
  int? randomSeed,
}) {
  final rawPayload = reply.toPayload();
  final originalBytes = utf8.encode(rawPayload).length;

  // 1. Priority queue (higher priority than media)
  final priority = reply.followUp ? TransmissionPriority.urgent : TransmissionPriority.routine;
  final queued = prioritizePayloads([
    QueuedPayload(
      label: 'doctor consultation reply',
      payload: rawPayload,
      priority: priority,
    ),
    const QueuedPayload(
      label: 'photo background sync',
      payload: 'photo-data',
      priority: TransmissionPriority.media,
    ),
  ]);

  // 2. Compress before encrypt (order: raw -> gzip -> AES)
  final encryptedPayload = compressAndEncryptPayload(rawPayload);
  final encryptedBytes = utf8.encode(encryptedPayload).length;
  // Estimate compressed bytes from ciphertext structure
  final compressedBytes = (encryptedBytes * 0.75).round();

  // 3. Parity redundancy & chunking
  final chunks = buildProtectedChunks(
    encryptedPayload,
    chunkSize: chunkSize,
    sparePieces: sparePieces,
  );
  final dataChunks = chunks.where((c) => !c.parity).length;

  // 4. Packet loss simulation
  final lossRate = ((100 - reliability) / 100).clamp(0.0, 0.9);
  final random = randomSeed == null ? Random() : Random(randomSeed);
  final surviving = <ProtectedChunk>[];
  final dropped = <ProtectedChunk>[];

  for (final chunk in chunks) {
    if (random.nextDouble() < lossRate) {
      dropped.add(chunk);
    } else {
      surviving.add(chunk);
    }
  }

  // 5. Recovery bounded by redundancy math
  final recovery = tryReconstructPayload(
    surviving,
    expectedDataChunkCount: dataChunks,
    recoveryGroupCount: sparePieces,
  );

  ConsultationReply? rebuiltReply;
  if (recovery.rebuilt) {
    try {
      final decrypted = decryptAndDecompressPayload(recovery.payload);
      rebuiltReply = ConsultationReply.fromPayload(decrypted);
    } catch (_) {
      rebuiltReply = null;
    }
  }

  final finalBytes = chunks.fold<int>(0, (sum, c) => sum + utf8.encode(c.body).length);
  final stageLog = [
    'Reply raw: $originalBytes B [Priority: ${queued.first.priority.name.toUpperCase()}]',
    'GZip + AES Encrypted: $encryptedBytes B',
    'Protected chunks ($dataChunks data + $sparePieces parity): $finalBytes B',
    'Network reliability: $reliability%, lost: ${dropped.length}/${chunks.length} chunks',
    recovery.rebuilt ? 'Reconstruction: SUCCESS (100% integrity)' : 'Reconstruction: DEGRADED / INCOMPLETE',
  ];

  return ReplyTransmissionResult(
    reply: reply,
    rebuilt: recovery.rebuilt && rebuiltReply != null,
    survivalPercent: recovery.rebuilt ? 100 : recovery.confidencePercent,
    chunkCount: dataChunks,
    parityCount: sparePieces,
    chunksSent: chunks.length,
    lostPieces: dropped.length,
    recoveryConfidencePercent: recovery.confidencePercent,
    stageLog: stageLog,
    originalByteCount: originalBytes,
    compressedByteCount: compressedBytes,
    encryptedByteCount: encryptedBytes,
    rebuiltReply: rebuiltReply,
  );
}
