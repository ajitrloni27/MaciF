import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/clinical_colors.dart';
import '../theme/glass_style.dart';
import '../../features/patient_storage/logic/patient_record_store.dart';
import '../../features/transmission_engine/logic/recovery_strategy.dart';
import '../../features/transmission_engine/logic/protocol_engine.dart';

/// A single reusable pill/chip widget for status, priority, or category
/// indicators throughout the app. Uses the semantic clinical color system
/// and a glass-frosted background consistent with the app's visual language.
class StatusPill extends StatefulWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.icon,
    required this.severity,
    this.animate = true,
  });

  final String label;
  final IconData icon;
  final ClinicalSeverity severity;
  final bool animate;

  // ── Priority pills ───────────────────────────────────────────
  factory StatusPill.priority(ClinicalPriority priority) {
    return StatusPill(
      label: priority.name[0].toUpperCase() + priority.name.substring(1),
      icon: switch (priority) {
        ClinicalPriority.critical => Icons.error_rounded,
        ClinicalPriority.high    => Icons.warning_amber_rounded,
        ClinicalPriority.medium  => Icons.info_rounded,
        ClinicalPriority.low     => Icons.check_circle_outline_rounded,
      },
      severity: switch (priority) {
        ClinicalPriority.critical => ClinicalSeverity.critical,
        ClinicalPriority.high    => ClinicalSeverity.caution,
        ClinicalPriority.medium  => ClinicalSeverity.info,
        ClinicalPriority.low     => ClinicalSeverity.success,
      },
    );
  }

  // ── Sync status pills ────────────────────────────────────────
  factory StatusPill.syncStatus(PatientSyncStatus status) {
    return StatusPill(
      label: switch (status) {
        PatientSyncStatus.newRecord => 'New',
        PatientSyncStatus.updated  => 'Updated',
        PatientSyncStatus.synced   => 'Synced',
      },
      icon: switch (status) {
        PatientSyncStatus.newRecord => Icons.add_circle_outline_rounded,
        PatientSyncStatus.updated  => Icons.sync_rounded,
        PatientSyncStatus.synced   => Icons.verified_rounded,
      },
      severity: switch (status) {
        PatientSyncStatus.newRecord => ClinicalSeverity.info,
        PatientSyncStatus.updated  => ClinicalSeverity.caution,
        PatientSyncStatus.synced   => ClinicalSeverity.success,
      },
    );
  }

  // ── Recovery status pills ────────────────────────────────────
  factory StatusPill.recovery(RecoveryState state) {
    return StatusPill(
      label: switch (state) {
        RecoveryState.fullRecovery => 'Full Recovery',
        RecoveryState.recovered   => 'Recovered',
        RecoveryState.degraded    => 'Degraded',
        RecoveryState.failed      => 'Failed',
      },
      icon: switch (state) {
        RecoveryState.fullRecovery => Icons.verified_rounded,
        RecoveryState.recovered   => Icons.healing_rounded,
        RecoveryState.degraded    => Icons.warning_amber_rounded,
        RecoveryState.failed      => Icons.error_rounded,
      },
      severity: switch (state) {
        RecoveryState.fullRecovery => ClinicalSeverity.success,
        RecoveryState.recovered   => ClinicalSeverity.success,
        RecoveryState.degraded    => ClinicalSeverity.caution,
        RecoveryState.failed      => ClinicalSeverity.critical,
      },
    );
  }

  // ── Transport pills ──────────────────────────────────────────
  factory StatusPill.transport(String mode) {
    final normalized = mode.toLowerCase();
    return StatusPill(
      label: mode,
      icon: normalized.contains('urgent')
          ? Icons.emergency_rounded
          : normalized.contains('fallback')
              ? Icons.alt_route_rounded
              : Icons.cell_tower_rounded,
      severity: normalized.contains('urgent')
          ? ClinicalSeverity.critical
          : normalized.contains('fallback')
              ? ClinicalSeverity.caution
              : ClinicalSeverity.info,
    );
  }

  // ── Capture method pills ─────────────────────────────────────
  factory StatusPill.capture(String source) {
    final isNfc = source.toLowerCase() == 'nfc';
    return StatusPill(
      label: isNfc ? 'NFC' : 'Manual Entry',
      icon: isNfc ? Icons.nfc_rounded : Icons.edit_note_rounded,
      severity: isNfc ? ClinicalSeverity.success : ClinicalSeverity.info,
    );
  }

  // ── Generic ready/empty status ───────────────────────────────
  factory StatusPill.ready(bool isReady) {
    return StatusPill(
      label: isReady ? 'Ready' : 'Empty',
      icon: isReady
          ? Icons.check_circle_rounded
          : Icons.radio_button_unchecked_rounded,
      severity: isReady ? ClinicalSeverity.success : ClinicalSeverity.info,
    );
  }

  @override
  State<StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<StatusPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppConstants.pillAnimationDuration,
    );
    _fadeScale = CurvedAnimation(
      parent: _controller,
      curve: AppConstants.pillAnimationCurve,
    );
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant StatusPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label != widget.label ||
        oldWidget.severity != widget.severity) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final fg = clinicalColor(widget.severity, brightness);
    final bg = clinicalSurface(widget.severity, brightness);

    return FadeTransition(
      opacity: _fadeScale,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1.0).animate(_fadeScale),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: glassDecoration(
            color: bg.withValues(alpha: brightness == Brightness.dark ? 0.25 : 0.7),
            radius: 999,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: fg),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  color: fg,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
