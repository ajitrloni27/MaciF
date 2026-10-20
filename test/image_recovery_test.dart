import 'package:flutter_test/flutter_test.dart';
import 'package:cih/features/transmission_engine/logic/image_recovery.dart';
import 'package:cih/features/transmission_engine/logic/recovery_strategy.dart';

void main() {
  test('simulateImageRecovery succeeds under mild loss', () {
    final result = simulateImageRecovery(
      reliability: 95,
      redundancy: 3,
      activeStrategy: 'RS',
      randomSeed: 42,
    );

    expect(result.totalDataChunks, 16);
    expect(result.totalParityChunks, 3);
    expect(result.rebuilt, isTrue);
    expect(result.state, RecoveryState.fullRecovery);
  });

  test('simulateImageRecovery fails or degrades under high loss', () {
    final result = simulateImageRecovery(
      reliability: 40,
      redundancy: 1,
      activeStrategy: 'XOR',
      randomSeed: 12345,
    );

    expect(result.rebuilt, isFalse);
    expect(result.state, isNot(RecoveryState.fullRecovery));
  });
}
