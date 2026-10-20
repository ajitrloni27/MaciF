import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/clinical_colors.dart';
import '../../../core/widgets/animated_page_wrapper.dart';
import '../../../core/widgets/clinical_alert.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/status_pill.dart';
import '../../nfc_capture/providers/nfc_provider.dart';
import '../../transmission_engine/providers/transmission_provider.dart';
import '../logic/triage_models.dart';
import '../providers/triage_provider.dart';
import 'widgets/triage_questionnaire_card.dart';

class TriagePage extends ConsumerWidget {
  const TriagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final triageState = ref.watch(triageProvider);
    final triageNotifier = ref.read(triageProvider.notifier);
    final nfcState = ref.watch(nfcProvider);
    final patient = nfcState.patient;
    final assessment = triageState.assessment;
    final sending = ref.watch(transmissionProvider).status == 'transmitting';

    return Scaffold(
      body: AnimatedPageWrapper(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pre-Consultation Triage',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (patient != null)
                  GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _vitalBadge('Age', '${patient.age}y'),
                        _vitalBadge('BP', patient.bloodPressure.isEmpty ? '--' : patient.bloodPressure),
                        _vitalBadge('HR', '${patient.heartRate}'),
                        _vitalBadge('SpO2', '${patient.oxygenSaturation}%'),
                        _vitalBadge('Temp', '${patient.temperature.toStringAsFixed(1)}°C'),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                TriageQuestionnaireCard(
                  questionnaire: triageState.questionnaire,
                  onToggleFever: triageNotifier.toggleFever,
                  onToggleChestPain: triageNotifier.toggleChestPain,
                  onToggleBreathlessness: triageNotifier.toggleBreathlessness,
                  onToggleBleedingInjury: triageNotifier.toggleBleedingInjury,
                  onToggleAbdominalPain: triageNotifier.toggleAbdominalPain,
                  onToggleSkinProblem: triageNotifier.toggleSkinProblem,
                  onToggleChildUnder5: triageNotifier.toggleChildUnder5,
                  onTogglePregnancy: triageNotifier.togglePregnancy,
                ),
                const SizedBox(height: 14),
                GlassContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.route_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text('Routing Recommendation', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          StatusPill(
                            label: assessment.urgency.displayName,
                            icon: assessment.isUrgent ? Icons.emergency_rounded : Icons.info_outline_rounded,
                            severity: assessment.isUrgent
                                ? ClinicalSeverity.critical
                                : (assessment.urgency == TriageUrgency.priority ? ClinicalSeverity.caution : ClinicalSeverity.success),
                          ),
                          const SizedBox(width: 8),
                          StatusPill(
                            label: assessment.specialty.displayName,
                            icon: Icons.local_hospital_rounded,
                            severity: assessment.specialty == TriageSpecialty.emergency ? ClinicalSeverity.critical : ClinicalSeverity.info,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(assessment.reason, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const ClinicalAlert(
                  severity: ClinicalSeverity.info,
                  title: 'Notice',
                  body: 'Decision-support aid, not a diagnosis.',
                  dismissible: false,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: Icon(sending ? Icons.sync_rounded : Icons.send_rounded),
                    label: Text(sending ? 'Transmitting...' : 'Confirm Triage & Transmit'),
                    onPressed: (patient == null || sending)
                        ? null
                        : () async {
                            final isUrgent = assessment.isUrgent;
                            final updated = patient.copyWith(
                              urgent: isUrgent,
                              symptoms: triageState.questionnaire.summary,
                              diagnosis: 'Specialty: ${assessment.specialty.displayName} | Urgency: ${assessment.urgency.displayName}',
                              emergencyNotes: assessment.reason,
                            );
                            ref.read(nfcProvider.notifier).updateVitals(
                                  urgent: isUrgent,
                                  symptoms: updated.symptoms,
                                  diagnosis: updated.diagnosis,
                                  emergencyNotes: updated.emergencyNotes,
                                );
                            await ref.read(transmissionProvider.notifier).sendPatientRecord(patient: updated);
                            if (context.mounted) {
                              ClinicalAlert.showToast(
                                context,
                                severity: isUrgent ? ClinicalSeverity.critical : ClinicalSeverity.success,
                                title: isUrgent ? 'Urgent Record Queued' : 'Record Transmitted',
                                body: 'Routed to ${assessment.specialty.displayName} (${assessment.urgency.displayName})',
                              );
                              context.go(AppRoutes.home);
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _vitalBadge(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
