import 'dart:io';

class PatientImageDetails {
  const PatientImageDetails({
    required this.reference,
    required this.exists,
    required this.fileName,
    required this.fileBytes,
    required this.referenceBytes,
    required this.estimatedCompressedBytes,
    required this.compressionLabel,
  });

  final String reference;
  final bool exists;
  final String fileName;
  final int fileBytes;
  final int referenceBytes;
  final int estimatedCompressedBytes;
  final String compressionLabel;
}

Future<PatientImageDetails> loadPatientImageDetails(String reference) async {
  final trimmed = reference.trim();
  final placeholder = trimmed.startsWith('placeholder://');
  final file = placeholder || trimmed.isEmpty ? null : File(trimmed);
  final exists = file != null && await file.exists();
  final fileBytes = exists ? await file.length() : 0;
  final fileName = exists ? file.uri.pathSegments.last : 'Placeholder image';
  final estimatedCompressedBytes = exists
      ? (fileBytes * 0.45).round().clamp(1, fileBytes)
      : 0;
  return PatientImageDetails(
    reference: trimmed,
    exists: exists || placeholder,
    fileName: fileName,
    fileBytes: fileBytes,
    referenceBytes: trimmed.length,
    estimatedCompressedBytes: estimatedCompressedBytes,
    compressionLabel: exists
        ? 'Gallery image copied at quality 45, max width 1024px'
        : 'Placeholder only; no image bytes attached',
  );
}

String formatBytes(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kb = bytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  }
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
}
