import 'dart:convert';

import 'rust_chunking_bridge.dart';

List<String> chunkText(String input, int chunkSize) {
  return chunkTextOptimized(input, chunkSize);
}

List<String> chunkTextOptimized(String input, int chunkSize) {
  final rustChunks = RustChunkingBridge.instance.tryChunkText(input, chunkSize);
  if (rustChunks != null) {
    return rustChunks;
  }

  if (input.isEmpty || chunkSize <= 0) {
    return const <String>[];
  }

  final chunks = <String>[];
  for (var offset = 0; offset < input.length; offset += chunkSize) {
    chunks.add(
      input.substring(
        offset,
        offset + chunkSize > input.length ? input.length : offset + chunkSize,
      ),
    );
  }
  return chunks;
}

class ProtectedChunk {
  const ProtectedChunk({
    required this.index,
    required this.body,
    required this.retrievalBit,
    this.parity = false,
    this.parityGroup = -1,
  });

  final int index;
  final String body;
  final int retrievalBit;
  final bool parity;
  final int parityGroup;
}

class PayloadRecoveryResult {
  const PayloadRecoveryResult({
    required this.rebuilt,
    required this.payload,
    required this.recoveredDataChunks,
    required this.failedGroups,
    required this.totalGroups,
  });

  final bool rebuilt;
  final String payload;
  final int recoveredDataChunks;
  final int failedGroups;
  final int totalGroups;

  int get confidencePercent {
    if (totalGroups <= 0) {
      return rebuilt ? 100 : 0;
    }
    return (((totalGroups - failedGroups) / totalGroups) * 100)
        .clamp(0, 100)
        .round();
  }
}

List<ProtectedChunk> buildProtectedChunks(
  String input, {
  int chunkSize = 18,
  int sparePieces = 2,
}) {
  return buildProtectedChunksOptimized(
    input,
    chunkSize: chunkSize,
    sparePieces: sparePieces,
  );
}

/// A simplified erasure-coding scheme using XOR-based parity, conceptually similar
/// to the parity mechanism used in RAID 5 disk arrays. If one chunk in a group is
/// lost, it can be reconstructed from the remaining chunks in that group.
List<ProtectedChunk> buildProtectedChunksOptimized(
  String input, {
  int chunkSize = 18,
  int sparePieces = 2,
}) {
  final chunks = chunkTextOptimized(input, chunkSize);
  if (chunks.isEmpty) {
    return const <ProtectedChunk>[];
  }

  final dataChunks = <ProtectedChunk>[
    for (var index = 0; index < chunks.length; index++)
      ProtectedChunk(
        index: index,
        body: chunks[index],
        retrievalBit: _retrievalBit(chunks[index], index),
      ),
  ];

  final parityChunks = <ProtectedChunk>[];
  if (sparePieces > 0) {
    final groups = <List<ProtectedChunk>>[];
    for (var groupIndex = 0; groupIndex < sparePieces; groupIndex++) {
      groups.add(<ProtectedChunk>[]);
    }
    for (var index = 0; index < dataChunks.length; index++) {
      groups[index % sparePieces].add(dataChunks[index]);
    }

    for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final parityBody = _buildParityChunk(groups[groupIndex]);
      parityChunks.add(
        ProtectedChunk(
          index: dataChunks.length + groupIndex,
          body: parityBody,
          retrievalBit: _retrievalBit(parityBody, groupIndex),
          parity: true,
          parityGroup: groupIndex,
        ),
      );
    }
  }

  return [...dataChunks, ...parityChunks];
}

/// Reconstructs a payload from the surviving data chunks and their parity blocks.
String reconstructPayload(
  Iterable<ProtectedChunk> availableChunks, {
  required int expectedDataChunkCount,
  int? recoveryGroupCount,
}) {
  final result = tryReconstructPayload(
    availableChunks,
    expectedDataChunkCount: expectedDataChunkCount,
    recoveryGroupCount: recoveryGroupCount,
  );
  if (!result.rebuilt) {
    throw StateError('Not enough chunks to reconstruct payload');
  }
  return result.payload;
}

/// Reconstructs only groups that are within the XOR parity correction limit.
///
/// Each parity group can recover one missing data chunk if its parity chunk
/// survived. Groups beyond that limit are reported as failed instead of being
/// silently treated as recovered.
PayloadRecoveryResult tryReconstructPayload(
  Iterable<ProtectedChunk> availableChunks, {
  required int expectedDataChunkCount,
  int? recoveryGroupCount,
}) {
  final availableDataChunks =
      availableChunks.where((chunk) => !chunk.parity).toList()
        ..sort((a, b) => a.index.compareTo(b.index));
  final parityChunks = availableChunks.where((chunk) => chunk.parity).toList();
  final recoveredByIndex = <int, ProtectedChunk>{};
  final failedGroups = <int>{};

  for (final chunk in availableDataChunks) {
    recoveredByIndex[chunk.index] = chunk;
  }

  final totalGroups =
      recoveryGroupCount ??
      _expectedParityGroups(expectedDataChunkCount, availableChunks);
  for (final parityChunk in parityChunks) {
    if (totalGroups <= 0) {
      continue;
    }

    final groupIndices = <int>[
      for (var index = 0; index < expectedDataChunkCount; index++)
        if (index % totalGroups == parityChunk.parityGroup) index,
    ];
    final missingIndices = groupIndices
        .where((index) => !recoveredByIndex.containsKey(index))
        .toList();
    if (missingIndices.isEmpty) {
      continue;
    }
    if (missingIndices.length > 1) {
      failedGroups.add(parityChunk.parityGroup);
      continue;
    }
    final missingIndex = missingIndices.single;

    final survivingChunks = groupIndices
        .where(
          (index) =>
              index != missingIndex && recoveredByIndex.containsKey(index),
        )
        .map((index) => recoveredByIndex[index]!)
        .toList();
    if (survivingChunks.isEmpty) {
      continue;
    }

    final reconstructedBody = _recoverMissingChunk(
      parityChunk.body,
      survivingChunks,
    );
    recoveredByIndex[missingIndex] = ProtectedChunk(
      index: missingIndex,
      body: reconstructedBody,
      retrievalBit: _retrievalBit(reconstructedBody, missingIndex),
    );
  }

  for (var groupIndex = 0; groupIndex < totalGroups; groupIndex++) {
    final groupIndices = <int>[
      for (var index = 0; index < expectedDataChunkCount; index++)
        if (index % totalGroups == groupIndex) index,
    ];
    final missingCount = groupIndices
        .where((index) => !recoveredByIndex.containsKey(index))
        .length;
    final parityAvailable = parityChunks.any(
      (chunk) => chunk.parityGroup == groupIndex,
    );
    if (missingCount > 0 && (!parityAvailable || missingCount > 1)) {
      failedGroups.add(groupIndex);
    }
  }

  final reconstructed = StringBuffer();
  for (var index = 0; index < expectedDataChunkCount; index++) {
    final chunk = recoveredByIndex[index];
    if (chunk == null) {
      continue;
    }
    reconstructed.write(chunk.body);
  }
  return PayloadRecoveryResult(
    rebuilt: recoveredByIndex.length >= expectedDataChunkCount,
    payload: reconstructed.toString(),
    recoveredDataChunks: recoveredByIndex.length,
    failedGroups: failedGroups.length,
    totalGroups: totalGroups,
  );
}

int _expectedParityGroups(
  int expectedDataChunkCount,
  Iterable<ProtectedChunk> availableChunks,
) {
  final highestGroup = availableChunks
      .where((chunk) => chunk.parity || chunk.parityGroup >= 0)
      .fold<int>(
        -1,
        (highest, chunk) =>
            highest > chunk.parityGroup ? highest : chunk.parityGroup,
      );
  if (highestGroup >= 0) {
    return highestGroup + 1;
  }
  return expectedDataChunkCount > 0 ? 1 : 0;
}

String _buildParityChunk(List<ProtectedChunk> dataChunks) {
  if (dataChunks.isEmpty) {
    return '';
  }

  final bytes = <int>[];
  for (final chunk in dataChunks) {
    final utf8Bytes = utf8.encode(chunk.body);
    for (var i = 0; i < utf8Bytes.length; i++) {
      if (i >= bytes.length) {
        bytes.add(utf8Bytes[i]);
      } else {
        bytes[i] ^= utf8Bytes[i];
      }
    }
  }
  return utf8.decode(bytes, allowMalformed: true);
}

String _recoverMissingChunk(
  String parityBody,
  List<ProtectedChunk> survivingChunks,
) {
  final bytes = utf8.encode(parityBody);
  var recovered = <int>[...bytes];
  for (final survivingChunk in survivingChunks) {
    final chunkBytes = utf8.encode(survivingChunk.body);
    for (var i = 0; i < chunkBytes.length; i++) {
      if (i < recovered.length) {
        recovered[i] ^= chunkBytes[i];
      }
    }
  }
  return utf8.decode(recovered, allowMalformed: true);
}

int _retrievalBit(String value, int salt) {
  return value.codeUnits.fold(salt, (sum, unit) => sum + unit) % 2;
}
