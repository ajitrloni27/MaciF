enum TriageSpecialty {
  generalPhysician('General Physician'),
  paediatrics('Paediatrics'),
  dermatology('Dermatology'),
  obstetrics('Obstetrics'),
  emergency('Emergency');

  const TriageSpecialty(this.displayName);
  final String displayName;
}

enum TriageUrgency {
  routine('Routine'),
  priority('Priority'),
  urgent('Urgent');

  const TriageUrgency(this.displayName);
  final String displayName;
}

class TriageSymptomQuestionnaire {
  const TriageSymptomQuestionnaire({
    this.fever = false,
    this.chestPain = false,
    this.breathlessness = false,
    this.bleedingInjury = false,
    this.abdominalPain = false,
    this.skinProblem = false,
    this.childUnder5 = false,
    this.pregnancy = false,
  });

  final bool fever;
  final bool chestPain;
  final bool breathlessness;
  final bool bleedingInjury;
  final bool abdominalPain;
  final bool skinProblem;
  final bool childUnder5;
  final bool pregnancy;

  TriageSymptomQuestionnaire copyWith({
    bool? fever,
    bool? chestPain,
    bool? breathlessness,
    bool? bleedingInjury,
    bool? abdominalPain,
    bool? skinProblem,
    bool? childUnder5,
    bool? pregnancy,
  }) {
    return TriageSymptomQuestionnaire(
      fever: fever ?? this.fever,
      chestPain: chestPain ?? this.chestPain,
      breathlessness: breathlessness ?? this.breathlessness,
      bleedingInjury: bleedingInjury ?? this.bleedingInjury,
      abdominalPain: abdominalPain ?? this.abdominalPain,
      skinProblem: skinProblem ?? this.skinProblem,
      childUnder5: childUnder5 ?? this.childUnder5,
      pregnancy: pregnancy ?? this.pregnancy,
    );
  }

  List<String> get activeSymptoms {
    final list = <String>[];
    if (fever) list.add('Fever');
    if (chestPain) list.add('Chest pain');
    if (breathlessness) list.add('Breathlessness');
    if (bleedingInjury) list.add('Bleeding / injury');
    if (abdominalPain) list.add('Abdominal pain');
    if (skinProblem) list.add('Skin problem');
    if (childUnder5) list.add('Child under 5');
    if (pregnancy) list.add('Pregnancy');
    return list;
  }

  String get summary => activeSymptoms.isEmpty ? 'None reported' : activeSymptoms.join(', ');
}

class TriageAssessment {
  const TriageAssessment({
    required this.severity,
    required this.score,
    required this.recommendation,
    required this.flaggedTerms,
    this.specialty = TriageSpecialty.generalPhysician,
    this.urgency = TriageUrgency.routine,
    this.reason = 'Routine follow-up; vitals and symptoms within standard thresholds.',
    this.disclaimer = 'Decision-support aid, not a diagnosis.',
    this.questionnaire = const TriageSymptomQuestionnaire(),
  });

  final String severity;
  final int score;
  final String recommendation;
  final List<String> flaggedTerms;
  final TriageSpecialty specialty;
  final TriageUrgency urgency;
  final String reason;
  final String disclaimer;
  final TriageSymptomQuestionnaire questionnaire;

  bool get isUrgent => urgency == TriageUrgency.urgent || severity == 'critical';
}
