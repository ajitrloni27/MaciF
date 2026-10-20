import 'package:flutter_test/flutter_test.dart';
import 'package:cih/features/transmission_engine/logic/chunking.dart';

void main() {
  group('chunkText', () {
    test('splits text into equally sized chunks', () {
      expect(chunkText('abcdefghij', 3), ['abc', 'def', 'ghi', 'j']);
    });

    test('returns the full string when chunk size is larger', () {
      expect(chunkText('hello', 10), ['hello']);
    });

    test('supports the optimized chunking path', () {
      expect(chunkTextOptimized('abcdefghij', 3), ['abc', 'def', 'ghi', 'j']);
    });
  });

  group('protected chunking', () {
    test('builds parity chunks through the optimized path', () {
      final chunks = buildProtectedChunksOptimized(
        'abcdefghijklmno',
        chunkSize: 5,
        sparePieces: 2,
      );

      expect(chunks.where((chunk) => !chunk.parity).length, 3);
      expect(chunks.where((chunk) => chunk.parity).length, 2);
      expect(chunks.first.body, 'abcde');
    });
  });
}
