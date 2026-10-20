import 'dart:math';

import 'chunking.dart';
import 'recovery_strategy.dart';

/// Holds the results of a simulated image recovery execution.
class ImageRecoveryResult {
  const ImageRecoveryResult({
    required this.totalDataChunks,
    required this.totalParityChunks,
    required this.lostDataChunks,
    required this.lostParityChunks,
    required this.recoveredDataChunks,
    required this.survivingDataIndices,
    required this.recoveredDataIndices,
    required this.rebuilt,
    required this.state,
    required this.recoveryMessage,
  });

  final int totalDataChunks;
  final int totalParityChunks;
  final int lostDataChunks;
  final int lostParityChunks;
  final int recoveredDataChunks;
  final List<int> survivingDataIndices;
  final List<int> recoveredDataIndices;
  final bool rebuilt;
  final RecoveryState state;
  final String recoveryMessage;

  double get lossPercent {
    final total = totalDataChunks + totalParityChunks;
    if (total == 0) return 0.0;
    return ((lostDataChunks + lostParityChunks) / total) * 100;
  }

  double get recoveryPercent {
    if (lostDataChunks == 0) return 100.0;
    return (recoveredDataChunks / lostDataChunks) * 100;
  }
}

/// Simulates chunking a patient photo into a 4x4 grid of 16 tiles,
/// applying randomized network loss, and running the parity recovery strategy.
ImageRecoveryResult simulateImageRecovery({
  required int reliability,
  required int redundancy,
  required String activeStrategy,
  int? randomSeed,
}) {
  const totalData = 16;
  final totalParity = redundancy;

  // 1. Create virtual data chunks (16 tiles)
  final dataChunks = List.generate(
    totalData,
    (i) => ProtectedChunk(
      index: i,
      body: 'tile-$i',
      retrievalBit: i % 2,
    ),
  );

  // 2. Create virtual parity groups
  final parityChunks = <ProtectedChunk>[];
  if (totalParity > 0) {
    for (var g = 0; g < totalParity; g++) {
      parityChunks.add(
        ProtectedChunk(
          index: totalData + g,
          body: 'parity-$g',
          retrievalBit: g % 2,
          parity: true,
          parityGroup: g,
        ),
      );
    }
  }

  final allChunks = [...dataChunks, ...parityChunks];

  // 3. Apply randomized loss based on network reliability
  final lossRate = ((100 - reliability) / 100).clamp(0.0, 0.95);
  final random = randomSeed == null ? Random() : Random(randomSeed);
  final surviving = <ProtectedChunk>[];
  final dropped = <ProtectedChunk>[];

  for (final chunk in allChunks) {
    if (random.nextDouble() < lossRate) {
      dropped.add(chunk);
    } else {
      surviving.add(chunk);
    }
  }

  // 4. Count losses
  final lostDataChunks = dropped.where((c) => !c.parity).length;
  final lostParityChunks = dropped.where((c) => c.parity).length;

  // 5. Run the core recovery algorithm
  final recovery = tryReconstructPayload(
    surviving,
    expectedDataChunkCount: totalData,
    recoveryGroupCount: totalParity,
  );

  // 6. Identify which tile indices survived
  final survivingDataIndices = surviving
      .where((c) => !c.parity)
      .map((c) => c.index)
      .toList();

  // 7. Calculate which missing tile indices were recovered
  final recoveredDataIndices = <int>[];
  if (totalParity > 0) {
    for (var i = 0; i < totalData; i++) {
      if (survivingDataIndices.contains(i)) {
        continue;
      }
      final group = i % totalParity;
      final groupIndices = List.generate(totalData, (idx) => idx)
          .where((idx) => idx % totalParity == group)
          .toList();
      final missingInGroup = groupIndices
          .where((idx) => !survivingDataIndices.contains(idx))
          .toList();
      final paritySurvived = surviving
          .any((c) => c.parity && c.parityGroup == group);

      // If exactly one chunk in the group is missing and parity survived, we can recover it
      if (missingInGroup.length == 1 && paritySurvived) {
        recoveredDataIndices.add(i);
      }
    }
  }

  // 8. Evaluate status using recovery strategy
  final recoveryStrategy = activeStrategy == 'RS'
      ? const ReedSolomonRecoveryStrategy()
      : const XorParityRecoveryStrategy();

  final strategyResult = recoveryStrategy.evaluate(
    expectedChunks: totalData + totalParity,
    receivedChunks: surviving.length,
    recoveryChunks: totalParity,
    recoveredFields: const [],
    checksumMatched: recovery.rebuilt,
  );

  return ImageRecoveryResult(
    totalDataChunks: totalData,
    totalParityChunks: totalParity,
    lostDataChunks: lostDataChunks,
    lostParityChunks: lostParityChunks,
    recoveredDataChunks: recoveredDataIndices.length,
    survivingDataIndices: survivingDataIndices,
    recoveredDataIndices: recoveredDataIndices,
    rebuilt: recovery.rebuilt,
    state: strategyResult.state,
    recoveryMessage: strategyResult.message,
  );
}
