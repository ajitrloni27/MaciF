import '../../data/patient_model.dart';
import '../../data/patient_schema.dart';

/// Clinical priority levels used to sort and protect the most important
/// patient information before lower-value fields are transmitted.
enum ClinicalPriority { critical, high, medium, low }

/// The specialist view unlocks sections progressively as data becomes available.
enum TransmissionSection {
  vitals,
  symptoms,
  medicalHistory,
  attachments,
  completeRecord,
}

class ClinicalField {
  const ClinicalField({
    required this.key,
    required this.label,
    required this.value,
    required this.priority,
  });

  final String key;
  final String label;
  final String value;
  final ClinicalPriority priority;
}

class ValidationIssue {
  const ValidationIssue({required this.field, required this.message});

  final String field;
  final String message;
}

class ClinicalTransmissionPlan {
  const ClinicalTransmissionPlan({
    required this.priorityFields,
    required this.sections,
    required this.estimatedDeliveryMs,
  });

  final List<ClinicalField> priorityFields;
  final List<TransmissionSection> sections;
  final int estimatedDeliveryMs;
}

ClinicalTransmissionPlan buildClinicalTransmissionPlan(PatientModel patient) {
  final fields = <ClinicalField>[
    if (patient.heartRate > 0)
      ClinicalField(
        key: 'heartRate',
        label: 'Heart Rate',
        value: '${patient.heartRate} bpm',
        priority: ClinicalPriority.critical,
      ),
    if (patient.bloodPressure.trim().isNotEmpty)
      ClinicalField(
        key: 'bloodPressure',
        label: 'Blood Pressure',
        value: patient.bloodPressure,
        priority: ClinicalPriority.critical,
      ),
    if (patient.oxygenSaturation > 0)
      ClinicalField(
        key: 'oxygenSaturation',
        label: 'SpO₂',
        value: '${patient.oxygenSaturation}%',
        priority: ClinicalPriority.critical,
      ),
    if (patient.temperature > 0)
      ClinicalField(
        key: 'temperature',
        label: 'Temperature',
        value: '${patient.temperature.toStringAsFixed(1)}°C',
        priority: ClinicalPriority.critical,
      ),
    if (patient.allergies.trim().isNotEmpty)
      ClinicalField(
        key: 'allergies',
        label: 'Allergies',
        value: patient.allergies,
        priority: ClinicalPriority.critical,
      ),
    if (patient.consciousness.trim().isNotEmpty)
      ClinicalField(
        key: 'consciousness',
        label: 'Consciousness',
        value: patient.consciousness,
        priority: ClinicalPriority.critical,
      ),
    if (patient.emergencyNotes.trim().isNotEmpty)
      ClinicalField(
        key: 'emergencyNotes',
        label: 'Emergency Notes',
        value: patient.emergencyNotes,
        priority: ClinicalPriority.critical,
      ),
    if (patient.symptoms.trim().isNotEmpty)
      ClinicalField(
        key: 'symptoms',
        label: 'Symptoms',
        value: patient.symptoms,
        priority: ClinicalPriority.high,
      ),
    if (patient.diagnosis.trim().isNotEmpty)
      ClinicalField(
        key: 'diagnosis',
        label: 'Diagnosis',
        value: patient.diagnosis,
        priority: ClinicalPriority.high,
      ),
    if (patient.currentMedication.trim().isNotEmpty)
      ClinicalField(
        key: 'currentMedication',
        label: 'Current Medication',
        value: patient.currentMedication,
        priority: ClinicalPriority.high,
      ),
    if (patient.medicalHistory.trim().isNotEmpty)
      ClinicalField(
        key: 'medicalHistory',
        label: 'Medical History',
        value: patient.medicalHistory,
        priority: ClinicalPriority.medium,
      ),
    if (patient.age > 0)
      ClinicalField(
        key: 'age',
        label: 'Age',
        value: '${patient.age}',
        priority: ClinicalPriority.medium,
      ),
    if (patient.gender.trim().isNotEmpty)
      ClinicalField(
        key: 'gender',
        label: 'Gender',
        value: PatientSchema.genderLabel(patient.gender),
        priority: ClinicalPriority.medium,
      ),
    if (patient.address.trim().isNotEmpty)
      ClinicalField(
        key: 'address',
        label: 'Address',
        value: patient.address,
        priority: ClinicalPriority.low,
      ),
    if (patient.contactDetails.trim().isNotEmpty)
      ClinicalField(
        key: 'contactDetails',
        label: 'Contact Details',
        value: patient.contactDetails,
        priority: ClinicalPriority.low,
      ),
    if (patient.insurance.trim().isNotEmpty)
      ClinicalField(
        key: 'insurance',
        label: 'Insurance',
        value: patient.insurance,
        priority: ClinicalPriority.low,
      ),
  ];

  final sections = <TransmissionSection>[];
  if (patient.heartRate > 0 ||
      patient.bloodPressure.trim().isNotEmpty ||
      patient.oxygenSaturation > 0 ||
      patient.temperature > 0) {
    sections.add(TransmissionSection.vitals);
  }
  if (patient.symptoms.trim().isNotEmpty ||
      patient.diagnosis.trim().isNotEmpty) {
    sections.add(TransmissionSection.symptoms);
  }
  if (patient.medicalHistory.trim().isNotEmpty || patient.age > 0) {
    sections.add(TransmissionSection.medicalHistory);
  }
  if (patient.photoRef.trim().isNotEmpty) {
    sections.add(TransmissionSection.attachments);
  }
  sections.add(TransmissionSection.completeRecord);

  final estimatedDeliveryMs = 260 + (fields.length * 40);
  fields.sort((a, b) => a.priority.index.compareTo(b.priority.index));

  return ClinicalTransmissionPlan(
    priorityFields: fields,
    sections: sections,
    estimatedDeliveryMs: estimatedDeliveryMs,
  );
}

List<ValidationIssue> validateClinicalValues(PatientModel patient) {
  final issues = <ValidationIssue>[];

  if (patient.heartRate > 250) {
    issues.add(
      const ValidationIssue(
        field: 'heartRate',
        message: 'Heart Rate exceeds the local safety threshold (>250).',
      ),
    );
  }
  if (patient.temperature < 30) {
    issues.add(
      const ValidationIssue(
        field: 'temperature',
        message: 'Temperature is below the plausible clinical range (<30°C).',
      ),
    );
  }
  if (patient.oxygenSaturation > 100) {
    issues.add(
      const ValidationIssue(
        field: 'oxygenSaturation',
        message: 'SpO₂ exceeds the plausible physiological range (>100%).',
      ),
    );
  }

  final bloodPressureParts = patient.bloodPressure.split('/');
  if (bloodPressureParts.length == 2) {
    final systolic = int.tryParse(bloodPressureParts[0].trim());
    final diastolic = int.tryParse(bloodPressureParts[1].trim());
    if (systolic != null && diastolic != null) {
      if (systolic <= 0 || diastolic <= 0 || diastolic >= systolic) {
        issues.add(
          const ValidationIssue(
            field: 'bloodPressure',
            message: 'Blood Pressure values appear implausible.',
          ),
        );
      }
    }
  }

  return issues;
}

String buildEmergencySnapshot(PatientModel patient) {
  final parts = <String>[
    'emergency=true',
    'timestamp=${DateTime.now().toIso8601String()}',
    'vitals=${patient.heartRate}/${patient.bloodPressure}/${patient.oxygenSaturation}/${patient.temperature.toStringAsFixed(1)}',
    'allergies=${patient.allergies}',
    'emergencyNotes=${patient.emergencyNotes}',
    'bloodGroup=${patient.bloodGroup}',
  ];
  return parts.join('|');
}
