import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _ChunkTextC = Pointer<Utf8> Function(Pointer<Utf8>, Int32);
typedef _ChunkTextDart = Pointer<Utf8> Function(Pointer<Utf8>, int);

class RustChunkingBridge {
  RustChunkingBridge._();

  static final RustChunkingBridge instance = RustChunkingBridge._();

  DynamicLibrary? _library;
  _ChunkTextDart? _chunkText;
  bool _attempted = false;

  bool get isAvailable {
    _ensureLoaded();
    return _chunkText != null;
  }

  List<String>? tryChunkText(String input, int chunkSize) {
    final chunkTextFn = _ensureLoaded();
    if (chunkTextFn == null) {
      return null;
    }

    final inputPtr = input.toNativeUtf8();
    try {
      final resultPtr = chunkTextFn(inputPtr, chunkSize);
      if (resultPtr == nullptr) {
        return null;
      }

      final payload = resultPtr.toDartString();
      final decoded = jsonDecode(payload) as List<dynamic>;
      return decoded.map((item) => item.toString()).toList(growable: false);
    } catch (_) {
      return null;
    } finally {
      calloc.free(inputPtr);
    }
  }

  _ChunkTextDart? _ensureLoaded() {
    if (_attempted) {
      return _chunkText;
    }

    _attempted = true;

    try {
      final libraryPath = _findLibraryPath();
      if (libraryPath == null) {
        return null;
      }

      _library = DynamicLibrary.open(libraryPath);
      _chunkText = _library!.lookupFunction<_ChunkTextC, _ChunkTextDart>(
        'cih_chunk_text',
      );
      return _chunkText;
    } catch (_) {
      return null;
    }
  }

  String? _findLibraryPath() {
    final candidates = <String>{};
    final currentDir = Directory.current.path;
    candidates.addAll([
      if (Platform.isWindows)
        '$currentDir\\native\\cih_chunk_engine\\target\\release\\cih_chunk_engine.dll',
      if (Platform.isLinux)
        '$currentDir/native/cih_chunk_engine/target/release/libcih_chunk_engine.so',
      if (Platform.isMacOS)
        '$currentDir/native/cih_chunk_engine/target/release/libcih_chunk_engine.dylib',
    ]);

    final parentCandidates = <String>{};
    final parentDir = Directory.current.parent.path;
    if (parentDir.isNotEmpty) {
      parentCandidates.addAll([
        if (Platform.isWindows)
          '$parentDir\\native\\cih_chunk_engine\\target\\release\\cih_chunk_engine.dll',
        if (Platform.isLinux)
          '$parentDir/native/cih_chunk_engine/target/release/libcih_chunk_engine.so',
        if (Platform.isMacOS)
          '$parentDir/native/cih_chunk_engine/target/release/libcih_chunk_engine.dylib',
      ]);
    }

    for (final candidate in [...candidates, ...parentCandidates]) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    return null;
  }
}
