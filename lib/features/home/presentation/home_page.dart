import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_page_wrapper.dart';
import '../../../core/widgets/clinical_alert.dart';
import '../../../core/widgets/floating_nav_bar.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/status_pill.dart';
import '../../network_simulator/providers/network_simulator_provider.dart';
import '../../nfc_capture/providers/nfc_provider.dart';
import '../../patient_storage/logic/patient_record_store.dart';
import '../../patient_storage/providers/patient_storage_provider.dart';
import '../../transmission_engine/logic/adaptive_transmission.dart';
import '../../transmission_engine/logic/chunking.dart';
import '../../transmission_engine/logic/protocol_engine.dart';
import '../../transmission_engine/providers/transmission_provider.dart';
import '../../triage/logic/triage_assessment.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final captureState = ref.watch(nfcProvider);
    final transmissionState = ref.watch(transmissionProvider);
    final networkState = ref.watch(networkSimulatorProvider);
    final storageState = ref.watch(patientStorageProvider);
    final patient = captureState.patient;
    final storedRecord =
        patient == null ? null : storageState.recordFor(patient.id);
    final chunks = chunkText(captureState.payload, 8);
    final clinicalPlan =
        patient == null ? null : buildClinicalTransmissionPlan(patient);
    final validationIssues =
        patient == null ? const <ValidationIssue>[] : validateClinicalValues(patient);
    final assessment = evaluateTriage(
      payload: captureState.payload,
      reliability: networkState.reliability,
      latencyMs: networkState.latencyMs,
    );
    final adaptiveResult = simulateAdaptiveTransmission(
      captureState.payload,
      lossCount: 1,
      parityPieces: 2,
    );
    final sending = transmissionState.status == 'transmitting';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isDark ? Colors.white38 : Colors.black38,
          fontWeight: FontWeight.bold,
        );
    final valueStyle = AppTheme.monoTextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.white : Colors.black87,
    );

    return Scaffold(
      body: AnimatedPageWrapper(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Care dashboard',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Intake, transmission health, and specialist readiness.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                ),
                const SizedBox(height: 20),
                GlassContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (patient == null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Patient overview',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            StatusPill.ready(false),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_search_rounded,
                                  size: 48,
                                  color: isDark ? Colors.white24 : Colors.black26,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No patient in queue',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: isDark ? Colors.white30 : Colors.black38,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: kMedicalAccent.withValues(alpha: 0.12),
                              child: const Icon(Icons.person_rounded, color: kMedicalAccent),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    patient.displayName,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'ID: ${patient.id}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: isDark ? Colors.white30 : Colors.black38,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            StatusPill.ready(true),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            StatusPill.priority(
                                patient.urgent ? ClinicalPriority.critical : ClinicalPriority.low),
                            if (storedRecord != null)
                              StatusPill.syncStatus(storedRecord.status),
                            StatusPill.capture(captureState.captureSource),
                            StatusPill.transport(patient.urgent ? 'Urgent' : 'Routine'),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _VitalBox(label: 'BP', value: patient.bloodPressure, labelStyle: labelStyle, valueStyle: valueStyle),
                              _VitalBox(label: 'HR', value: '${patient.heartRate}', labelStyle: labelStyle, valueStyle: valueStyle),
                              _VitalBox(label: 'SPO2', value: '${patient.oxygenSaturation}%', labelStyle: labelStyle, valueStyle: valueStyle),
                              _VitalBox(label: 'TEMP', value: '${patient.temperature}°C', labelStyle: labelStyle, valueStyle: valueStyle),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'Transmission status: ${transmissionState.status.toUpperCase()}',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        transmissionState.proofSummary,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                      ),
                      if (clinicalPlan != null && clinicalPlan.priorityFields.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Priority stream',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: clinicalPlan.priorityFields.take(4).map((field) {
                            return StatusPill(
                              label: '${field.label}: ${field.priority.name.toUpperCase()}',
                              icon: Icons.priority_high_rounded,
                              severity: switch (field.priority) {
                                ClinicalPriority.critical => ClinicalSeverity.critical,
                                ClinicalPriority.high => ClinicalSeverity.caution,
                                ClinicalPriority.medium => ClinicalSeverity.info,
                                ClinicalPriority.low => ClinicalSeverity.success,
                              },
                            );
                          }).toList(),
                        ),
                      ],
                      if (validationIssues.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ...validationIssues.map(
                          (issue) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: ClinicalAlert(
                              severity: ClinicalSeverity.caution,
                              title: 'Clinical validation warning',
                              body: issue.message,
                              dismissible: false,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x1F000000) : const Color(0x99FFFFFF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transmission stats',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            _StatLine(label: 'Triage assessment', value: '${assessment.severity.toUpperCase()} (${assessment.score}/100)'),
                            _StatLine(label: 'Adaptive rebuild', value: '${adaptiveResult.summary} (${adaptiveResult.survivalPercent}%)'),
                            _StatLine(
                              label: 'Compression savings',
                              value: '${transmissionState.originalByteCount > 0 ? ((transmissionState.originalByteCount - transmissionState.compressedByteCount) / transmissionState.originalByteCount * 100).toStringAsFixed(1) : 0}% saved',
                            ),
                            _StatLine(label: 'Delta payload', value: transmissionState.deltaPayload.isEmpty ? '-' : transmissionState.deltaPayload),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: transmissionState.progress / 100,
                          minHeight: 6,
                          backgroundColor: isDark ? Colors.white10 : Colors.black12,
                          valueColor: const AlwaysStoppedAnimation<Color>(kMedicalAccent),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        transmissionState.message,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                      ),
                      const SizedBox(height: 20),
                      // Primary send row
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: FilledButton.icon(
                              onPressed: patient == null ||
                                      !patient.isValidForSend ||
                                      sending
                                  ? null
                                  : () => ref
                                      .read(transmissionProvider.notifier)
                                      .sendPatientRecord(patient: patient),
                              icon: sending
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded),
                              label: Text(sending ? 'Sending…' : 'Send'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: OutlinedButton.icon(
                              onPressed: () => context.go('/specialist'),
                              icon: const Icon(
                                Icons.medical_services_rounded,
                                size: 16,
                              ),
                              label: const Text('Console'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Auto-reconnect + fallback send
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark
                                ? const Color(0xFFFFB74D)
                                : const Color(0xFFE65100),
                            side: BorderSide(
                              color: isDark
                                  ? const Color(0x66FFB74D)
                                  : const Color(0x66E65100),
                            ),
                          ),
                          onPressed: patient == null ||
                                  !patient.isValidForSend ||
                                  sending
                              ? null
                              : () => ref
                                  .read(transmissionProvider.notifier)
                                  .sendWithAutoFallback(patient: patient),
                          icon: const Icon(Icons.satellite_alt_rounded,
                              size: 16),
                          label: const Text('Send + Auto-Retry & Fallback'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const FloatingNavBar(),
    );
  }
}

class _VitalBox extends StatelessWidget {
  const _VitalBox({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 2),
        Text(value, style: valueStyle),
      ],
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
