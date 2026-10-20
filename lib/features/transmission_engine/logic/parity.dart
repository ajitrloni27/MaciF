List<int> generateParity(List<String> chunks) {
  final parity = <int>[];
  for (final chunk in chunks) {
    var checksum = 0;
    for (final codeUnit in chunk.codeUnits) {
      checksum += codeUnit;
    }
    parity.add(checksum % 97);
  }
  return parity;
}
