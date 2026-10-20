import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/clinical_colors.dart';
import '../theme/glass_style.dart';

/// A reusable clinical alert widget built on the glass aesthetic and
/// semantic color tokens. Supports inline banners and transient toasts.
class ClinicalAlert extends StatelessWidget {
  const ClinicalAlert({
    super.key,
    required this.severity,
    required this.title,
    this.body,
    this.action,
    this.dismissible = true,
    this.onDismiss,
  });

  final ClinicalSeverity severity;
  final String title;
  final String? body;
  final Widget? action;
  final bool dismissible;
  final VoidCallback? onDismiss;

  /// Displays a transient, glass-frosted clinical toast using [ScaffoldMessenger].
  static void showToast(
    BuildContext context, {
    required ClinicalSeverity severity,
    required String title,
    String? body,
    Duration duration = const Duration(seconds: 4),
  }) {
    final brightness = Theme.of(context).brightness;
    final fgColor = clinicalColor(severity, brightness);
    final bgColor = clinicalSurface(severity, brightness);
    final isDark = brightness == Brightness.dark;

    final icon = switch (severity) {
      ClinicalSeverity.critical => Icons.error_rounded,
      ClinicalSeverity.caution  => Icons.warning_amber_rounded,
      ClinicalSeverity.success  => Icons.check_circle_rounded,
      ClinicalSeverity.info     => Icons.info_rounded,
    };

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 90), // float just above nav bar
        duration: duration,
        content: Container(
          decoration: glassDecoration(
            color: bgColor.withValues(alpha: isDark ? 0.35 : 0.85),
            radius: 16,
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: fgColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: fgColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                    ),
                    if (body != null && body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontSize: 12,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 220.ms, curve: Curves.easeOut)
            .slideY(begin: 0.12, end: 0, duration: 280.ms, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final fgColor = clinicalColor(severity, brightness);
    final bgColor = clinicalSurface(severity, brightness);
    final isDark = brightness == Brightness.dark;

    final icon = switch (severity) {
      ClinicalSeverity.critical => Icons.error_rounded,
      ClinicalSeverity.caution  => Icons.warning_amber_rounded,
      ClinicalSeverity.success  => Icons.check_circle_rounded,
      ClinicalSeverity.info     => Icons.info_rounded,
    };

    return Container(
      width: double.infinity,
      decoration: glassDecoration(
        color: bgColor.withValues(alpha: isDark ? 0.2 : 0.6),
        radius: 16,
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fgColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: fgColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                ),
                if (body != null && body!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    body!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 12,
                        ),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: 10),
                  action!,
                ],
              ],
            ),
          ),
          if (dismissible && onDismiss != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(
                Icons.close_rounded,
                color: fgColor.withValues(alpha: 0.6),
                size: 20,
              ),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 200.ms, curve: Curves.easeOut)
        .slideY(begin: 0.08, end: 0, duration: 260.ms, curve: Curves.easeOutCubic);
  }
}
