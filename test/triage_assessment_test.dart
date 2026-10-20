import 'package:cih/features/triage/logic/triage_assessment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Legacy payload evaluation', () {
    test('flags urgent payloads during degraded network', () {
      final assessment = evaluateTriage(
        payload: 'Critical vitals: 85/53',
        reliability: 64,
        latencyMs: 320,
      );

      expect(assessment.severity, 'critical');
      expect(assessment.score, greaterThan(70));
      expect(assessment.recommendation, contains('immediate'));
    });

    test('keeps stable payloads low risk on healthy networks', () {
      final assessment = evaluateTriage(
        payload: 'Routine follow-up',
        reliability: 98,
        latencyMs: 80,
      );

      expect(assessment.severity, 'stable');
      expect(assessment.score, lessThan(40));
    });
  });

  group('Rule-based symptom & vitals triage', () {
    test('routes acute chest pain and hypoxia to Emergency with Urgent priority', () {
      final result = evaluateRuleBasedTriage(
        questionnaire: const TriageSymptomQuestionnaire(chestPain: true),
        oxygenSaturation: 89,
        heartRate: 112,
        bloodPressure: '130/85',
      );

      expect(result.specialty, TriageSpecialty.emergency);
      expect(result.urgency, TriageUrgency.urgent);
      expect(result.isUrgent, isTrue);
      expect(result.reason, contains('acute chest pain'));
      expect(result.reason, contains('hypoxia'));
      expect(result.disclaimer, 'Decision-support aid, not a diagnosis.');
    });

    test('routes child under 5 with fever to Paediatrics', () {
      final result = evaluateRuleBasedTriage(
        questionnaire: const TriageSymptomQuestionnaire(
          fever: true,
          childUnder5: true,
        ),
        age: 3,
        temperature: 39.0,
      );

      expect(result.specialty, TriageSpecialty.paediatrics);
      expect(result.urgency, TriageUrgency.urgent);
      expect(result.isUrgent, isTrue);
      expect(result.reason, contains('child under 5 with high fever'));
    });

    test('routes pregnancy with abdominal pain to Obstetrics with Priority', () {
      final result = evaluateRuleBasedTriage(
        questionnaire: const TriageSymptomQuestionnaire(
          pregnancy: true,
          abdominalPain: true,
        ),
        bloodPressure: '120/78',
      );

      expect(result.specialty, TriageSpecialty.obstetrics);
      expect(result.urgency, TriageUrgency.priority);
      expect(result.isUrgent, isFalse);
      expect(result.reason, contains('pregnancy'));
    });

    test('routes isolated rash with normal vitals to Dermatology with Routine', () {
      final result = evaluateRuleBasedTriage(
        questionnaire: const TriageSymptomQuestionnaire(skinProblem: true),
        oxygenSaturation: 98,
        heartRate: 72,
        bloodPressure: '120/80',
      );

      expect(result.specialty, TriageSpecialty.dermatology);
      expect(result.urgency, TriageUrgency.routine);
      expect(result.isUrgent, isFalse);
      expect(result.reason, contains('isolated dermatological presentation'));
    });

    test('routes general adult fever to General Physician', () {
      final result = evaluateRuleBasedTriage(
        questionnaire: const TriageSymptomQuestionnaire(fever: true),
        age: 35,
        temperature: 38.2,
        oxygenSaturation: 97,
        heartRate: 85,
      );

      expect(result.specialty, TriageSpecialty.generalPhysician);
      expect(result.urgency, TriageUrgency.priority);
      expect(result.reason, contains('fever'));
    });

    test('critical blood pressure triggers Urgent regardless of symptoms', () {
      final result = evaluateRuleBasedTriage(
        questionnaire: const TriageSymptomQuestionnaire(),
        bloodPressure: '190/125',
      );

      expect(result.urgency, TriageUrgency.urgent);
      expect(result.specialty, TriageSpecialty.emergency);
      expect(result.isUrgent, isTrue);
    });
  });
}
