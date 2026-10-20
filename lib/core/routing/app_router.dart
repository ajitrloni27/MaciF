import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/debug/presentation/component_gallery_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/network_simulator/presentation/network_simulator_page.dart';
import '../../features/nfc_capture/presentation/nfc_capture_page.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/specialist_view/presentation/specialist_page.dart';

class AppRoutes {
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const nfcCapture = '/nfc-capture';
  static const networkSimulator = '/network-simulator';
  static const specialist = '/specialist';
  static const settings = '/settings';
  static const componentGallery = '/component-gallery';
}

CustomTransitionPage<void> _fadeTransitionPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 150),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: child,
      );
    },
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (context, state) => _fadeTransitionPage(state, const OnboardingPage()),
      ),
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (context, state) => _fadeTransitionPage(state, const HomePage()),
      ),
      GoRoute(
        path: AppRoutes.nfcCapture,
        pageBuilder: (context, state) => _fadeTransitionPage(state, const NfcCapturePage()),
      ),
      GoRoute(
        path: AppRoutes.networkSimulator,
        pageBuilder: (context, state) => _fadeTransitionPage(state, const NetworkSimulatorPage()),
      ),
      GoRoute(
        path: AppRoutes.specialist,
        pageBuilder: (context, state) => _fadeTransitionPage(state, const SpecialistPage()),
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (context, state) => _fadeTransitionPage(state, const SettingsPage()),
      ),
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.componentGallery,
          pageBuilder: (context, state) => _fadeTransitionPage(state, const ComponentGalleryPage()),
        ),
    ],
  );
});
