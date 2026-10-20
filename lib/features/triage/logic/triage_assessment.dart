export 'triage_models.dart';

import 'triage_models.dart';

TriageAssessment evaluateRuleBasedTriage({
  required TriageSymptomQuestionnaire questionnaire,
  int age = 0,
  String bloodPressure = '',
  int heartRate = 0,
  int oxygenSaturation = 0,
  double temperature = 0,
  String notesText = '',
  int reliability = 100,
  int latencyMs = 0,
}) {
  final parts = bloodPressure.split('/');
  final sys = parts.isNotEmpty ? int.tryParse(parts[0].trim()) ?? 0 : 0;
  final dia = parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 0 : 0;
  final isChildUnder5 = questionnaire.childUnder5 || (age > 0 && age < 5);

  final reasons = <String>[];
  var urgency = TriageUrgency.routine;

  // 1. Critical red flags
  final hasHypoxia = oxygenSaturation > 0 && oxygenSaturation < 92;
  final hasExtremeHr = heartRate > 130 || (heartRate > 0 && heartRate < 45);
  final hasExtremeBp = (sys >= 180 || (sys > 0 && sys <= 85)) || (dia >= 120 || (dia > 0 && dia <= 50));
  final hasSeverePreeclampsiaRisk = questionnaire.pregnancy && (sys >= 160 || dia >= 110);

  if (questionnaire.chestPain) reasons.add('acute chest pain');
  if (questionnaire.breathlessness) reasons.add('respiratory distress / breathlessness');
  if (questionnaire.bleedingInjury) reasons.add('active bleeding or acute trauma');
  if (hasHypoxia) reasons.add('hypoxia (SpO2 $oxygenSaturation%)');
  if (hasExtremeHr) reasons.add('abnormal heart rate ($heartRate bpm)');
  if (hasExtremeBp) reasons.add('critical blood pressure ($bloodPressure)');
  if (hasSeverePreeclampsiaRisk) reasons.add('pregnancy with high BP risk');
  if (isChildUnder5 && temperature >= 38.5) reasons.add('child under 5 with high fever (${temperature.toStringAsFixed(1)}°C)');

  if (reasons.isNotEmpty) {
    urgency = TriageUrgency.urgent;
  } else if (questionnaire.abdominalPain ||
      questionnaire.fever ||
      (oxygenSaturation >= 92 && oxygenSaturation < 95) ||
      (heartRate >= 100 && heartRate <= 130) ||
      temperature >= 38.0 ||
      isChildUnder5 ||
      questionnaire.pregnancy) {
    urgency = TriageUrgency.priority;
    if (questionnaire.abdominalPain) reasons.add('abdominal pain');
    if (questionnaire.fever) reasons.add('fever (${temperature > 0 ? "${temperature.toStringAsFixed(1)}°C" : "reported"})');
    if (questionnaire.pregnancy) reasons.add('pregnancy antenatal review');
    if (isChildUnder5) reasons.add('paediatric evaluation');
    if (oxygenSaturation >= 92 && oxygenSaturation < 95) reasons.add('borderline SpO2 ($oxygenSaturation%)');
    if (heartRate >= 100 && heartRate <= 130) reasons.add('tachycardia ($heartRate bpm)');
  } else if (questionnaire.skinProblem) {
    urgency = TriageUrgency.routine;
    reasons.add('isolated dermatological presentation');
  } else {
    urgency = TriageUrgency.routine;
    reasons.add('stable vitals without red-flag symptoms');
  }

  // 2. Specialty routing
  final TriageSpecialty specialty;
  if (urgency == TriageUrgency.urgent &&
      (questionnaire.chestPain || questionnaire.breathlessness || questionnaire.bleedingInjury || hasHypoxia || hasExtremeBp || hasExtremeHr)) {
    specialty = TriageSpecialty.emergency;
  } else if (questionnaire.pregnancy) {
    specialty = TriageSpecialty.obstetrics;
  } else if (isChildUnder5) {
    specialty = TriageSpecialty.paediatrics;
  } else if (questionnaire.skinProblem && !questionnaire.fever && !questionnaire.abdominalPain) {
    specialty = TriageSpecialty.dermatology;
  } else {
    specialty = TriageSpecialty.generalPhysician;
  }

  final score = urgency == TriageUrgency.urgent ? 85 : (urgency == TriageUrgency.priority ? 55 : 20);
  final severity = urgency == TriageUrgency.urgent ? 'critical' : (urgency == TriageUrgency.priority ? 'monitor' : 'stable');
  final reasonText = 'Routed to ${specialty.displayName} [${urgency.displayName}] due to: ${reasons.join(", ")}.';

  return TriageAssessment(
    severity: severity,
    score: score,
    recommendation: urgency == TriageUrgency.urgent
        ? 'Escalate immediately to ${specialty.displayName}'
        : (urgency == TriageUrgency.priority ? 'Prioritize review by ${specialty.displayName}' : 'Routine review by ${specialty.displayName}'),
    flaggedTerms: reasons,
    specialty: specialty,
    urgency: urgency,
    reason: reasonText,
    questionnaire: questionnaire,
  );
}

TriageAssessment evaluateTriage({
  required String payload,
  required int reliability,
  required int latencyMs,
}) {
  final normalized = payload.toLowerCase();
  final q = TriageSymptomQuestionnaire(
    chestPain: normalized.contains('chest') || normalized.contains('stroke'),
    breathlessness: normalized.contains('breath') || normalized.contains('dyspnea'),
    bleedingInjury: normalized.contains('bleed') || normalized.contains('trauma') || normalized.contains('wound'),
    fever: normalized.contains('fever') || normalized.contains('pyrexia'),
    abdominalPain: normalized.contains('abdom') || normalized.contains('stomach'),
    skinProblem: normalized.contains('rash') || normalized.contains('skin') || normalized.contains('lesion'),
    childUnder5: normalized.contains('child') || normalized.contains('infant'),
    pregnancy: normalized.contains('pregnant') || normalized.contains('pregnancy') || normalized.contains('maternal'),
  );

  var bp = '';
  final bpMatch = RegExp(r'(\d{2,3}/\d{2,3})').firstMatch(payload);
  if (bpMatch != null) bp = bpMatch.group(1)!;

  var hr = 0;
  final hrMatch = RegExp(r'(?:hr|heart rate)[:=\s]+(\d{2,3})', caseSensitive: false).firstMatch(payload);
  if (hrMatch != null) hr = int.tryParse(hrMatch.group(1)!) ?? 0;

  var spo2 = 0;
  final spo2Match = RegExp(r'(?:spo2|o2)[:=\s]+(\d{2,3})', caseSensitive: false).firstMatch(payload);
  if (spo2Match != null) spo2 = int.tryParse(spo2Match.group(1)!) ?? 0;

  if (normalized.contains('critical') || normalized.contains('severe') || normalized.contains('shock')) {
    final forced = evaluateRuleBasedTriage(
      questionnaire: q.copyWith(chestPain: true),
      bloodPressure: bp.isNotEmpty ? bp : '80/50',
      heartRate: hr > 0 ? hr : 135,
      oxygenSaturation: spo2 > 0 ? spo2 : 88,
      reliability: reliability,
      latencyMs: latencyMs,
    );
    return forced;
  }

  return evaluateRuleBasedTriage(
    questionnaire: q,
    bloodPressure: bp,
    heartRate: hr,
    oxygenSaturation: spo2,
    reliability: reliability,
    latencyMs: latencyMs,
  );
}
