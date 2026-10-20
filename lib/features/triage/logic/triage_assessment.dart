class TriageAssessment {
  const TriageAssessment({
    required this.severity,
    required this.score,
    required this.recommendation,
    required this.flaggedTerms,
  });

  final String severity;
  final int score;
  final String recommendation;
  final List<String> flaggedTerms;
}

TriageAssessment evaluateTriage({
  required String payload,
  required int reliability,
  required int latencyMs,
}) {
  final normalized = payload.toLowerCase();
  final flaggedTerms = <String>[];

  if (normalized.contains('critical') || normalized.contains('severe')) {
    flaggedTerms.add('critical');
  }
  if (normalized.contains('vitals') || normalized.contains('shock')) {
    flaggedTerms.add('vitals');
  }
  if (normalized.contains('stroke') || normalized.contains('bleeding')) {
    flaggedTerms.add('acute');
  }

  var score = 20;
  if (flaggedTerms.isNotEmpty) score += flaggedTerms.length * 18;
  if (reliability < 80) score += 20;
  if (latencyMs > 200) score += 15;
  if (reliability < 70) score += 10;

  String severity;
  String recommendation;

  if (score >= 75) {
    severity = 'critical';
    recommendation = 'Escalate immediately and notify specialist';
  } else if (score >= 45) {
    severity = 'monitor';
    recommendation = 'Prioritize review and keep a close watch';
  } else {
    severity = 'stable';
    recommendation = 'Routine follow-up is appropriate';
  }

  return TriageAssessment(
    severity: severity,
    score: score.clamp(0, 100),
    recommendation: recommendation,
    flaggedTerms: flaggedTerms,
  );
}
