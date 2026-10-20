import 'package:cih/features/triage/logic/triage_assessment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
