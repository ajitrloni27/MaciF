import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../nfc_capture/providers/nfc_provider.dart';
import '../logic/triage_assessment.dart';

class TriageState {
  const TriageState({
    this.questionnaire = const TriageSymptomQuestionnaire(),
    required this.assessment,
  });

  final TriageSymptomQuestionnaire questionnaire;
  final TriageAssessment assessment;

  TriageState copyWith({
    TriageSymptomQuestionnaire? questionnaire,
    TriageAssessment? assessment,
  }) {
    return TriageState(
      questionnaire: questionnaire ?? this.questionnaire,
      assessment: assessment ?? this.assessment,
    );
  }
}

class TriageNotifier extends Notifier<TriageState> {
  @override
  TriageState build() {
    final patient = ref.watch(nfcProvider).patient;
    final initialQ = TriageSymptomQuestionnaire(
      childUnder5: (patient?.age ?? 0) > 0 && (patient?.age ?? 0) < 5,
      fever: (patient?.temperature ?? 0) >= 38.0,
    );
    final assessment = evaluateRuleBasedTriage(
      questionnaire: initialQ,
      age: patient?.age ?? 0,
      bloodPressure: patient?.bloodPressure ?? '',
      heartRate: patient?.heartRate ?? 0,
      oxygenSaturation: patient?.oxygenSaturation ?? 0,
      temperature: patient?.temperature ?? 0,
    );
    return TriageState(questionnaire: initialQ, assessment: assessment);
  }

  void updateQuestionnaire(TriageSymptomQuestionnaire updated) {
    final patient = ref.read(nfcProvider).patient;
    final assessment = evaluateRuleBasedTriage(
      questionnaire: updated,
      age: patient?.age ?? 0,
      bloodPressure: patient?.bloodPressure ?? '',
      heartRate: patient?.heartRate ?? 0,
      oxygenSaturation: patient?.oxygenSaturation ?? 0,
      temperature: patient?.temperature ?? 0,
    );
    state = TriageState(questionnaire: updated, assessment: assessment);
  }

  void toggleFever(bool v) => updateQuestionnaire(state.questionnaire.copyWith(fever: v));
  void toggleChestPain(bool v) => updateQuestionnaire(state.questionnaire.copyWith(chestPain: v));
  void toggleBreathlessness(bool v) => updateQuestionnaire(state.questionnaire.copyWith(breathlessness: v));
  void toggleBleedingInjury(bool v) => updateQuestionnaire(state.questionnaire.copyWith(bleedingInjury: v));
  void toggleAbdominalPain(bool v) => updateQuestionnaire(state.questionnaire.copyWith(abdominalPain: v));
  void toggleSkinProblem(bool v) => updateQuestionnaire(state.questionnaire.copyWith(skinProblem: v));
  void toggleChildUnder5(bool v) => updateQuestionnaire(state.questionnaire.copyWith(childUnder5: v));
  void togglePregnancy(bool v) => updateQuestionnaire(state.questionnaire.copyWith(pregnancy: v));
}

final triageProvider = NotifierProvider<TriageNotifier, TriageState>(TriageNotifier.new);
