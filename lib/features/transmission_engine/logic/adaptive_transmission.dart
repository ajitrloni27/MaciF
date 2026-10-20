class PayloadBundle {
  const PayloadBundle({
    required this.name,
    required this.sizeBytes,
    required this.urgent,
  });

  final String name;
  final int sizeBytes;
  final bool urgent;
}

class AdaptiveTransmissionResult {
  const AdaptiveTransmissionResult({
    required this.rebuilt,
    required this.survivalPercent,
    required this.summary,
    required this.receivedPieces,
    required this.totalPieces,
  });

  final bool rebuilt;
  final int survivalPercent;
  final String summary;
  final int receivedPieces;
  final int totalPieces;
}

AdaptiveTransmissionResult simulateAdaptiveTransmission(
  String payload, {
  required int lossCount,
  required int parityPieces,
}) {
  final totalPieces = payload.length.clamp(4, 20);
  final receivedPieces = totalPieces - lossCount + parityPieces;
  final survivalPercent = ((receivedPieces / totalPieces) * 100).round();
  final rebuilt = receivedPieces >= totalPieces;

  return AdaptiveTransmissionResult(
    rebuilt: rebuilt,
    survivalPercent: survivalPercent,
    summary: rebuilt
        ? 'Message rebuilt successfully from surviving pieces'
        : 'Message partially rebuilt; some data was lost',
    receivedPieces: receivedPieces,
    totalPieces: totalPieces,
  );
}

List<PayloadBundle> prioritizePayloads(List<PayloadBundle> bundles) {
  final sorted = [...bundles];
  sorted.sort((a, b) {
    if (a.urgent != b.urgent) {
      return a.urgent ? -1 : 1;
    }
    return a.sizeBytes.compareTo(b.sizeBytes);
  });
  return sorted;
}
