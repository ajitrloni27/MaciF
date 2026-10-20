import 'dart:convert';
import 'dart:typed_data';

const String patientSchemaPrefix = 'MGP1';
const String patientSchemaDelimiter = '|';
const String patientBinaryPayloadPrefix = 'MGPB:';

enum PatientFieldEncoding { utf8Length8, utf8Length16, uint8, uint16, bool8 }

class PatientFieldSpec {
  const PatientFieldSpec({
    required this.name,
    required this.encoding,
    this.scale = 1,
    this.description = '',
  });

  final String name;
  final PatientFieldEncoding encoding;
  final int scale;
  final String description;
}

class PatientSchema {
  static const String versionPrefix = patientSchemaPrefix;
  static const String delimiter = patientSchemaDelimiter;
  static const String binaryPayloadPrefix = patientBinaryPayloadPrefix;
  static const List<int> binaryVersionPrefix = <int>[0x4d, 0x47, 0x02];

  static const List<PatientFieldSpec> fields = <PatientFieldSpec>[
    PatientFieldSpec(name: 'id', encoding: PatientFieldEncoding.utf8Length8),
    PatientFieldSpec(name: 'name', encoding: PatientFieldEncoding.utf8Length8),
    PatientFieldSpec(name: 'age', encoding: PatientFieldEncoding.uint8),
    PatientFieldSpec(
      name: 'bloodPressure',
      encoding: PatientFieldEncoding.utf8Length8,
    ),
    PatientFieldSpec(name: 'heartRate', encoding: PatientFieldEncoding.uint8),
    PatientFieldSpec(
      name: 'oxygenSaturation',
      encoding: PatientFieldEncoding.uint8,
    ),
    PatientFieldSpec(
      name: 'temperature',
      encoding: PatientFieldEncoding.uint16,
      scale: 10,
      description: 'Celsius stored as value x 10.',
    ),
    PatientFieldSpec(
      name: 'notes',
      encoding: PatientFieldEncoding.utf8Length16,
    ),
    PatientFieldSpec(
      name: 'photoRef',
      encoding: PatientFieldEncoding.utf8Length16,
    ),
    PatientFieldSpec(name: 'urgent', encoding: PatientFieldEncoding.bool8),
    PatientFieldSpec(
      name: 'symptoms',
      encoding: PatientFieldEncoding.utf8Length16,
    ),
    PatientFieldSpec(
      name: 'diagnosis',
      encoding: PatientFieldEncoding.utf8Length16,
    ),
    PatientFieldSpec(
      name: 'medicalHistory',
      encoding: PatientFieldEncoding.utf8Length16,
    ),
    PatientFieldSpec(
      name: 'currentMedication',
      encoding: PatientFieldEncoding.utf8Length16,
    ),
    PatientFieldSpec(
      name: 'allergies',
      encoding: PatientFieldEncoding.utf8Length16,
    ),
    PatientFieldSpec(
      name: 'consciousness',
      encoding: PatientFieldEncoding.utf8Length8,
    ),
    PatientFieldSpec(
      name: 'emergencyNotes',
      encoding: PatientFieldEncoding.utf8Length16,
    ),
    PatientFieldSpec(
      name: 'address',
      encoding: PatientFieldEncoding.utf8Length16,
    ),
    PatientFieldSpec(
      name: 'contactDetails',
      encoding: PatientFieldEncoding.utf8Length16,
    ),
    PatientFieldSpec(
      name: 'insurance',
      encoding: PatientFieldEncoding.utf8Length16,
    ),
    PatientFieldSpec(
      name: 'gender',
      encoding: PatientFieldEncoding.bool8,
      description: 'Fixed for MGP binary v2: 0 = Male, 1 = Female.',
    ),
    PatientFieldSpec(
      name: 'bloodGroup',
      encoding: PatientFieldEncoding.utf8Length8,
    ),
  ];

  static List<String> get fieldOrder =>
      fields.map((field) => field.name).toList(growable: false);

  static const Map<String, String> legacyAliases = <String, String>{
    'id': 'id',
    'name': 'name',
    'displayName': 'name',
    'age': 'age',
    'bloodPressure': 'bloodPressure',
    'bp': 'bloodPressure',
    'heartRate': 'heartRate',
    'hr': 'heartRate',
    'oxygenSaturation': 'oxygenSaturation',
    'spo2': 'oxygenSaturation',
    'temperature': 'temperature',
    'temp': 'temperature',
    'notes': 'notes',
    'photoRef': 'photoRef',
    'photo': 'photoRef',
    'urgent': 'urgent',
    'symptoms': 'symptoms',
    'diagnosis': 'diagnosis',
    'medicalHistory': 'medicalHistory',
    'currentMedication': 'currentMedication',
    'allergies': 'allergies',
    'consciousness': 'consciousness',
    'emergencyNotes': 'emergencyNotes',
    'address': 'address',
    'contactDetails': 'contactDetails',
    'insurance': 'insurance',
    'gender': 'gender',
    'bloodGroup': 'bloodGroup',
  };

  static String encodeValues(Map<String, String> values) {
    return '$binaryPayloadPrefix${base64Url.encode(encodeValueBytes(values))}';
  }

  static Uint8List encodeValueBytes(Map<String, String> values) {
    final builder = BytesBuilder(copy: false)..add(binaryVersionPrefix);
    final normalized = _normalized(values);
    for (final field in fields) {
      _writeField(builder, field, normalized[field.name] ?? '');
    }
    return builder.takeBytes();
  }

  static Map<String, String> decodeValues(String payload) {
    final trimmed = payload.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Empty patient record');
    }
    if (trimmed.startsWith(binaryPayloadPrefix)) {
      return decodeValueBytes(
        base64Url.decode(trimmed.substring(binaryPayloadPrefix.length)),
      );
    }
    return decodeDelimitedValues(trimmed);
  }

  static Map<String, String> decodeValueBytes(List<int> bytes) {
    if (bytes.length < binaryVersionPrefix.length) {
      throw const FormatException('Missing binary schema prefix');
    }
    for (var index = 0; index < binaryVersionPrefix.length; index++) {
      if (bytes[index] != binaryVersionPrefix[index]) {
        throw const FormatException('Missing binary schema prefix');
      }
    }
    final reader = _ByteReader(bytes, binaryVersionPrefix.length);
    final normalized = <String, String>{};
    for (final field in fields) {
      normalized[field.name] = _readField(reader, field);
    }
    if (!reader.isDone) {
      throw const FormatException('Unexpected bytes after patient record');
    }
    return normalized;
  }

  static String encodeDelimitedValues(Map<String, String> values) {
    final normalized = _normalized(values);
    final serialized = fields
        .map((field) => _escapeValue(normalized[field.name] ?? ''))
        .join(delimiter);
    return '$versionPrefix$delimiter$serialized';
  }

  static Map<String, String> decodeDelimitedValues(String payload) {
    if (!payload.startsWith(versionPrefix)) {
      throw const FormatException('Missing schema prefix');
    }
    final parts = payload.split(delimiter);
    if (parts.isEmpty || parts.first != versionPrefix) {
      throw const FormatException('Missing schema prefix');
    }
    final rawValues = parts.skip(1).toList();
    final normalized = <String, String>{};
    for (var index = 0; index < fields.length; index++) {
      final field = fields[index].name;
      normalized[field] = index < rawValues.length
          ? _unescapeValue(rawValues[index])
          : '';
    }
    return normalized;
  }

  static Map<String, String> _normalized(Map<String, String> values) {
    final normalized = <String, String>{};
    for (final field in fields) {
      final legacyKey = legacyAliases.entries
          .firstWhere(
            (entry) => entry.value == field.name,
            orElse: () => const MapEntry<String, String>('', ''),
          )
          .key;
      normalized[field.name] = values[field.name] ?? values[legacyKey] ?? '';
    }
    normalized['gender'] = normalizeGenderCode(normalized['gender'] ?? '');
    return normalized;
  }

  static String normalizeGenderCode(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == '1' || normalized == 'female') {
      return '1';
    }
    if (normalized == '0' || normalized == 'male') {
      return '0';
    }
    return '';
  }

  static String genderLabel(String value) {
    return switch (normalizeGenderCode(value)) {
      '0' => 'Male',
      '1' => 'Female',
      _ => '',
    };
  }

  static void _writeField(
    BytesBuilder builder,
    PatientFieldSpec field,
    String value,
  ) {
    switch (field.encoding) {
      case PatientFieldEncoding.utf8Length8:
        _writeString(builder, value, 1);
      case PatientFieldEncoding.utf8Length16:
        _writeString(builder, value, 2);
      case PatientFieldEncoding.uint8:
        builder.addByte(_parseScaled(value, field.scale).clamp(0, 255).toInt());
      case PatientFieldEncoding.uint16:
        final parsed = _parseScaled(value, field.scale).clamp(0, 65535).toInt();
        builder.addByte((parsed >> 8) & 0xff);
        builder.addByte(parsed & 0xff);
      case PatientFieldEncoding.bool8:
        builder.addByte(_parseBool(value));
    }
  }

  static String _readField(_ByteReader reader, PatientFieldSpec field) {
    switch (field.encoding) {
      case PatientFieldEncoding.utf8Length8:
        return reader.readString(1);
      case PatientFieldEncoding.utf8Length16:
        return reader.readString(2);
      case PatientFieldEncoding.uint8:
        return '${reader.readUint8()}';
      case PatientFieldEncoding.uint16:
        final value = reader.readUint16();
        if (field.scale == 1) {
          return '$value';
        }
        return (value / field.scale).toStringAsFixed(1);
      case PatientFieldEncoding.bool8:
        return '${reader.readUint8().clamp(0, 1)}';
    }
  }

  static void _writeString(
    BytesBuilder builder,
    String value,
    int lengthBytes,
  ) {
    final encoded = utf8.encode(value.replaceAll('\n', ' '));
    final maxLength = lengthBytes == 1 ? 255 : 65535;
    if (encoded.length > maxLength) {
      throw FormatException('Field exceeds $maxLength byte binary limit');
    }
    if (lengthBytes == 1) {
      builder.addByte(encoded.length);
    } else {
      builder.addByte((encoded.length >> 8) & 0xff);
      builder.addByte(encoded.length & 0xff);
    }
    builder.add(encoded);
  }

  static int _parseScaled(String value, int scale) {
    final parsed = double.tryParse(value.trim()) ?? 0;
    return (parsed * scale).round();
  }

  static int _parseBool(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == '1' || normalized == 'true' || normalized == 'female') {
      return 1;
    }
    return 0;
  }

  static String _escapeValue(String value) {
    return value.replaceAll(delimiter, '\\$delimiter').replaceAll('\n', ' ');
  }

  static String _unescapeValue(String value) {
    return value.replaceAll('\\$delimiter', delimiter);
  }
}

class _ByteReader {
  _ByteReader(this.bytes, this.offset);

  final List<int> bytes;
  int offset;

  bool get isDone => offset >= bytes.length;

  int readUint8() {
    if (offset >= bytes.length) {
      throw const FormatException('Unexpected end of patient record');
    }
    return bytes[offset++];
  }

  int readUint16() {
    final high = readUint8();
    final low = readUint8();
    return (high << 8) | low;
  }

  String readString(int lengthBytes) {
    final length = lengthBytes == 1 ? readUint8() : readUint16();
    final start = offset;
    final end = start + length;
    if (end > bytes.length) {
      throw const FormatException('Unexpected end of patient string field');
    }
    offset = end;
    return utf8.decode(bytes.sublist(start, end));
  }
}
