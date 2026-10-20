class RecoveryResult {
  const RecoveryResult({
    required this.state,
    required this.confidencePercent,
    required this.expectedChunks,
    required this.receivedChunks,
    required this.usedForRecovery,
    required this.recoveredFields,
    required this.message,
  });

  final RecoveryState state;
  final int confidencePercent;
  final int expectedChunks;
  final int receivedChunks;
  final int usedForRecovery;
  final List<String> recoveredFields;
  final String message;
}

enum RecoveryState { fullRecovery, recovered, degraded, failed }

abstract class RecoveryStrategy {
  const RecoveryStrategy();

  RecoveryResult evaluate({
    required int expectedChunks,
    required int receivedChunks,
    required int recoveryChunks,
    required List<String> recoveredFields,
    required bool checksumMatched,
  });
}

class XorParityRecoveryStrategy extends RecoveryStrategy {
  const XorParityRecoveryStrategy();

  @override
  RecoveryResult evaluate({
    required int expectedChunks,
    required int receivedChunks,
    required int recoveryChunks,
    required List<String> recoveredFields,
    required bool checksumMatched,
  }) {
    final missingChunks = expectedChunks - receivedChunks;
    final canRecover = missingChunks <= recoveryChunks && missingChunks > 0;
    final state = checksumMatched
        ? RecoveryState.fullRecovery
        : missingChunks == 0
        ? RecoveryState.fullRecovery
        : canRecover
        ? RecoveryState.recovered
        : missingChunks > recoveryChunks
        ? RecoveryState.degraded
        : RecoveryState.failed;
    final confidence = _boundedConfidence(
      expectedChunks: expectedChunks,
      receivedChunks: receivedChunks,
      recovered: checksumMatched || canRecover,
    );
    return RecoveryResult(
      state: state,
      confidencePercent: confidence,
      expectedChunks: expectedChunks,
      receivedChunks: receivedChunks,
      usedForRecovery: canRecover ? missingChunks : 0,
      recoveredFields: recoveredFields,
      message: switch (state) {
        RecoveryState.fullRecovery => 'Full recovery',
        RecoveryState.recovered => 'Recovered with parity correction',
        RecoveryState.degraded =>
          'Partial recovery; loss exceeded parity capacity',
        RecoveryState.failed => 'Failed to recover record',
      },
    );
  }
}

class ReedSolomonRecoveryStrategy extends RecoveryStrategy {
  const ReedSolomonRecoveryStrategy();

  @override
  RecoveryResult evaluate({
    required int expectedChunks,
    required int receivedChunks,
    required int recoveryChunks,
    required List<String> recoveredFields,
    required bool checksumMatched,
  }) {
    final missingChunks = expectedChunks - receivedChunks;
    final canRecover = missingChunks <= recoveryChunks;
    final state = checksumMatched
        ? RecoveryState.fullRecovery
        : missingChunks == 0
        ? RecoveryState.fullRecovery
        : canRecover
        ? RecoveryState.recovered
        : missingChunks > recoveryChunks
        ? RecoveryState.degraded
        : RecoveryState.failed;
    final confidence = _boundedConfidence(
      expectedChunks: expectedChunks,
      receivedChunks: receivedChunks,
      recovered: checksumMatched || canRecover,
    );
    return RecoveryResult(
      state: state,
      confidencePercent: confidence,
      expectedChunks: expectedChunks,
      receivedChunks: receivedChunks,
      usedForRecovery: canRecover ? missingChunks : 0,
      recoveredFields: recoveredFields,
      message: switch (state) {
        RecoveryState.fullRecovery => 'Full recovery',
        RecoveryState.recovered => 'Recovered using Reed-Solomon correction',
        RecoveryState.degraded =>
          'Partial recovery; loss exceeded correction capacity',
        RecoveryState.failed => 'Failed to recover record',
      },
    );
  }
}

int _boundedConfidence({
  required int expectedChunks,
  required int receivedChunks,
  required bool recovered,
}) {
  if (recovered) {
    return 100;
  }
  if (expectedChunks <= 0) {
    return 0;
  }
  return ((receivedChunks.clamp(0, expectedChunks) / expectedChunks) * 100)
      .round();
}
