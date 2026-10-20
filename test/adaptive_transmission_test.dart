import 'package:cih/features/transmission_engine/logic/adaptive_transmission.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rebuilds payload when enough parity pieces survive', () {
    final result = simulateAdaptiveTransmission(
      'HR 128 BP 90/60',
      lossCount: 1,
      parityPieces: 2,
    );

    expect(result.rebuilt, isTrue);
    expect(result.survivalPercent, greaterThan(0));
    expect(result.summary, contains('rebuilt'));
  });

  test('prioritizes urgent payloads ahead of large files', () {
    final order = prioritizePayloads([
      const PayloadBundle(name: 'image', sizeBytes: 900, urgent: false),
      const PayloadBundle(name: 'vitals', sizeBytes: 40, urgent: true),
    ]);

    expect(order.first.name, 'vitals');
  });
}
