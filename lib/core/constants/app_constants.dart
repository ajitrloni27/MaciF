import 'package:flutter/material.dart';

class AppConstants {
  static const double pagePadding = 24.0;
  static const double cardRadius = 24.0;
  static const Duration animationDuration = Duration(milliseconds: 250);
  static const double sectionSpacing = 16.0;

  // Pill / chip entrance animation
  static const Duration pillAnimationDuration = Duration(milliseconds: 200);
  static const Curve pillAnimationCurve = Curves.easeOutCubic;

  // Toast / alert animation
  static const Duration toastDuration = Duration(seconds: 4);
  static const Duration toastAnimationDuration = Duration(milliseconds: 300);
  static const int maxVisibleToasts = 3;
}
