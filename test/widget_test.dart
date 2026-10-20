import 'package:cih/app.dart';
import 'package:cih/features/nfc_capture/presentation/nfc_capture_page.dart';
import 'package:cih/features/nfc_capture/providers/nfc_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('app boots to the home dashboard', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MedGateApp()));
    await tester.pumpAndSettle();
    expect(find.text('Care dashboard'), findsOneWidget);
  });

  testWidgets('gender radio writes schema codes', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(nfcProvider.notifier).loadFallback();

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const NfcCapturePage(),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll the form until the female radio is visible, then tap it.
    await tester.ensureVisible(find.byKey(const Key('gender-female-radio')));
    await tester.tap(find.byKey(const Key('gender-female-radio')));
    await tester.pumpAndSettle();
    expect(container.read(nfcProvider).patient?.gender, '1');

    // Scroll the form until the male radio is visible, then tap it.
    await tester.ensureVisible(find.byKey(const Key('gender-male-radio')));
    await tester.tap(find.byKey(const Key('gender-male-radio')));
    await tester.pumpAndSettle();
    expect(container.read(nfcProvider).patient?.gender, '0');
  });
}
