import 'dart:typed_data';

import 'patient_schema.dart';

class PatientModel {
  const PatientModel({
    required this.id,
    required this.displayName,
    required this.age,
    required this.bloodPressure,
    required this.heartRate,
    required this.oxygenSaturation,
    required this.temperature,
    required this.notes,
    required this.photoRef,
    this.urgent = false,
    this.symptoms = '',
    this.diagnosis = '',
    this.medicalHistory = '',
    this.currentMedication = '',
    this.allergies = '',
    this.consciousness = '',
    this.emergencyNotes = '',
    this.address = '',
    this.contactDetails = '',
    this.insurance = '',
    this.gender = '',
    this.bloodGroup = '',
  });

  final String id;
  final String displayName;
  final int age;
  final String bloodPressure;
  final int heartRate;
  final int oxygenSaturation;
  final double temperature;
  final String notes;
  final String photoRef;
  final bool urgent;
  final String symptoms;
  final String diagnosis;
  final String medicalHistory;
  final String currentMedication;
  final String allergies;
  final String consciousness;
  final String emergencyNotes;
  final String address;
  final String contactDetails;
  final String insurance;
  final String gender;
  final String bloodGroup;

  static const empty = PatientModel(
    id: '',
    displayName: '',
    age: 0,
    bloodPressure: '',
    heartRate: 0,
    oxygenSaturation: 0,
    temperature: 0,
    notes: '',
    photoRef: '',
  );

  factory PatientModel.fromWireMap(Map<String, String> data) {
    return PatientModel(
      id: data['id']?.trim() ?? '',
      displayName: data['name']?.trim() ?? '',
      age: int.tryParse(data['age'] ?? '') ?? 0,
      bloodPressure: data['bloodPressure']?.trim() ?? data['bp']?.trim() ?? '',
      heartRate: int.tryParse(data['heartRate'] ?? data['hr'] ?? '') ?? 0,
      oxygenSaturation:
          int.tryParse(data['oxygenSaturation'] ?? data['spo2'] ?? '') ?? 0,
      temperature:
          double.tryParse(data['temperature'] ?? data['temp'] ?? '') ?? 0,
      notes: data['notes']?.trim() ?? '',
      photoRef: data['photoRef']?.trim() ?? data['photo']?.trim() ?? '',
      urgent: data['urgent']?.toLowerCase() == 'true' || data['urgent'] == '1',
      symptoms: data['symptoms']?.trim() ?? '',
      diagnosis: data['diagnosis']?.trim() ?? '',
      medicalHistory: data['medicalHistory']?.trim() ?? '',
      currentMedication: data['currentMedication']?.trim() ?? '',
      allergies: data['allergies']?.trim() ?? '',
      consciousness: data['consciousness']?.trim() ?? '',
      emergencyNotes: data['emergencyNotes']?.trim() ?? '',
      address: data['address']?.trim() ?? '',
      contactDetails: data['contactDetails']?.trim() ?? '',
      insurance: data['insurance']?.trim() ?? '',
      gender: PatientSchema.normalizeGenderCode(data['gender'] ?? ''),
      bloodGroup: data['bloodGroup']?.trim() ?? '',
    );
  }

  Map<String, String> toWireMap() => {
    'id': id,
    'name': displayName,
    'age': '$age',
    'bloodPressure': bloodPressure,
    'heartRate': '$heartRate',
    'oxygenSaturation': '$oxygenSaturation',
    'temperature': temperature.toStringAsFixed(1),
    'notes': notes,
    'photoRef': photoRef,
    'urgent': urgent.toString(),
    'symptoms': symptoms,
    'diagnosis': diagnosis,
    'medicalHistory': medicalHistory,
    'currentMedication': currentMedication,
    'allergies': allergies,
    'consciousness': consciousness,
    'emergencyNotes': emergencyNotes,
    'address': address,
    'contactDetails': contactDetails,
    'insurance': insurance,
    'gender': PatientSchema.normalizeGenderCode(gender),
    'bloodGroup': bloodGroup,
  };

  String toPayload() => PatientSchema.encodeValues(toWireMap());

  Uint8List toRecordBytes() => encodePatientRecord(this);

  factory PatientModel.fromPayload(String payload) {
    if (payload.startsWith(PatientSchema.binaryPayloadPrefix) ||
        payload.startsWith(PatientSchema.versionPrefix)) {
      final values = PatientSchema.decodeValues(payload);
      return PatientModel.fromWireMap(values);
    }
    final data = <String, String>{};
    for (final part in payload.split('|')) {
      final separator = part.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      data[part.substring(0, separator)] = part.substring(separator + 1);
    }
    return PatientModel.fromWireMap(data);
  }

  factory PatientModel.fromRecordBytes(Uint8List bytes) {
    return decodePatientRecord(bytes);
  }

  bool get isValidForSend {
    return id.trim().isNotEmpty &&
        displayName.trim().isNotEmpty &&
        bloodPressure.trim().isNotEmpty &&
        heartRate > 0 &&
        oxygenSaturation > 0 &&
        temperature > 0;
  }

  PatientModel copyWith({
    String? id,
    String? displayName,
    int? age,
    String? bloodPressure,
    int? heartRate,
    int? oxygenSaturation,
    double? temperature,
    String? notes,
    String? photoRef,
    bool? urgent,
    String? symptoms,
    String? diagnosis,
    String? medicalHistory,
    String? currentMedication,
    String? allergies,
    String? consciousness,
    String? emergencyNotes,
    String? address,
    String? contactDetails,
    String? insurance,
    String? gender,
    String? bloodGroup,
  }) {
    return PatientModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      age: age ?? this.age,
      bloodPressure: bloodPressure ?? this.bloodPressure,
      heartRate: heartRate ?? this.heartRate,
      oxygenSaturation: oxygenSaturation ?? this.oxygenSaturation,
      temperature: temperature ?? this.temperature,
      notes: notes ?? this.notes,
      photoRef: photoRef ?? this.photoRef,
      urgent: urgent ?? this.urgent,
      symptoms: symptoms ?? this.symptoms,
      diagnosis: diagnosis ?? this.diagnosis,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      currentMedication: currentMedication ?? this.currentMedication,
      allergies: allergies ?? this.allergies,
      consciousness: consciousness ?? this.consciousness,
      emergencyNotes: emergencyNotes ?? this.emergencyNotes,
      address: address ?? this.address,
      contactDetails: contactDetails ?? this.contactDetails,
      insurance: insurance ?? this.insurance,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
    );
  }
}

Uint8List encodePatientRecord(PatientModel record) {
  return PatientSchema.encodeValueBytes(record.toWireMap());
}

PatientModel decodePatientRecord(Uint8List bytes) {
  return PatientModel.fromWireMap(PatientSchema.decodeValueBytes(bytes));
}
