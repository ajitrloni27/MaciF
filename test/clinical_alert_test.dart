import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cih/core/theme/clinical_colors.dart';
import 'package:cih/core/widgets/clinical_alert.dart';

void main() {
  testWidgets('ClinicalAlert inline banner renders correctly', (WidgetTester tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClinicalAlert(
            severity: ClinicalSeverity.critical,
            title: 'Test Danger Title',
            body: 'This is a test warning body message.',
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Test Danger Title'), findsOneWidget);
    expect(find.text('This is a test warning body message.'), findsOneWidget);
    expect(find.byIcon(Icons.error_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(dismissed, isTrue);
  });
}
