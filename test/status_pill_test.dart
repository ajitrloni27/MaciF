import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cih/core/widgets/status_pill.dart';
import 'package:cih/features/patient_storage/logic/patient_record_store.dart';
import 'package:cih/features/transmission_engine/logic/protocol_engine.dart';
import 'package:cih/features/transmission_engine/logic/recovery_strategy.dart';

void main() {
  testWidgets('StatusPill renders priority variants correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatusPill.priority(ClinicalPriority.critical),
        ),
      ),
    );

    expect(find.text('Critical'), findsOneWidget);
    expect(find.byIcon(Icons.error_rounded), findsOneWidget);
  });

  testWidgets('StatusPill renders sync status variants correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatusPill.syncStatus(PatientSyncStatus.synced),
        ),
      ),
    );

    expect(find.text('Synced'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
  });

  testWidgets('StatusPill renders recovery variants correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatusPill.recovery(RecoveryState.degraded),
        ),
      ),
    );

    expect(find.text('Degraded'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });
}
