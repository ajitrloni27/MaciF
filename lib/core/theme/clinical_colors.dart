import 'package:flutter/material.dart';

/// Semantic clinical color tokens mapped to clinical meaning.
/// Each token has light-mode and dark-mode variants with sufficient
/// contrast against glass/blur backgrounds.
class ClinicalColors {
  const ClinicalColors._();

  // ── Critical / Urgent (red-family) ──────────────────────────
  static Color critical(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFFF87171) // lighter red for dark glass
          : const Color(0xFFDC2626);

  static Color criticalSurface(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0x33DC2626)
          : const Color(0xFFFEE2E2);

  // ── Caution / Degraded (amber-family) ───────────────────────
  static Color caution(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFFFBBF24) // brighter amber for dark glass
          : const Color(0xFFD97706);

  static Color cautionSurface(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0x33D97706)
          : const Color(0xFFFEF3C7);

  // ── Success / Synced (green-family) ─────────────────────────
  static Color success(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFF4ADE80) // lighter green for dark glass
          : const Color(0xFF16A34A);

  static Color successSurface(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0x3316A34A)
          : const Color(0xFFDCFCE7);

  // ── Info / Neutral (blue-family) ────────────────────────────
  static Color info(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFF60A5FA) // lighter blue for dark glass
          : const Color(0xFF2563EB);

  static Color infoSurface(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0x332563EB)
          : const Color(0xFFDBEAFE);
}

/// Semantic severity levels used by pills and alerts.
enum ClinicalSeverity { critical, caution, success, info }

/// Resolves a [ClinicalSeverity] to its foreground color.
Color clinicalColor(ClinicalSeverity severity, Brightness brightness) {
  return switch (severity) {
    ClinicalSeverity.critical => ClinicalColors.critical(brightness),
    ClinicalSeverity.caution  => ClinicalColors.caution(brightness),
    ClinicalSeverity.success  => ClinicalColors.success(brightness),
    ClinicalSeverity.info     => ClinicalColors.info(brightness),
  };
}

/// Resolves a [ClinicalSeverity] to its surface/background color.
Color clinicalSurface(ClinicalSeverity severity, Brightness brightness) {
  return switch (severity) {
    ClinicalSeverity.critical => ClinicalColors.criticalSurface(brightness),
    ClinicalSeverity.caution  => ClinicalColors.cautionSurface(brightness),
    ClinicalSeverity.success  => ClinicalColors.successSurface(brightness),
    ClinicalSeverity.info     => ClinicalColors.infoSurface(brightness),
  };
}
