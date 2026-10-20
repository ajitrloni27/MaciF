import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/clinical_alert.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/status_pill.dart';
import '../../patient_storage/logic/patient_record_store.dart';
import '../../transmission_engine/logic/protocol_engine.dart';
import '../../transmission_engine/logic/recovery_strategy.dart';

class ComponentGalleryPage extends StatelessWidget {
  const ComponentGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinical Component Gallery'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/settings'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Color System',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ColorSwatch(
                  label: 'Critical',
                  color: ClinicalColors.critical(Brightness.light),
                  darkColor: ClinicalColors.critical(Brightness.dark),
                ),
                _ColorSwatch(
                  label: 'Caution',
                  color: ClinicalColors.caution(Brightness.light),
                  darkColor: ClinicalColors.caution(Brightness.dark),
                ),
                _ColorSwatch(
                  label: 'Success',
                  color: ClinicalColors.success(Brightness.light),
                  darkColor: ClinicalColors.success(Brightness.dark),
                ),
                _ColorSwatch(
                  label: 'Info',
                  color: ClinicalColors.info(Brightness.light),
                  darkColor: ClinicalColors.info(Brightness.dark),
                ),
              ],
            ),
            const SectionDivider(),

            Text(
              'Status Pills',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusPill.priority(ClinicalPriority.critical),
                StatusPill.priority(ClinicalPriority.high),
                StatusPill.priority(ClinicalPriority.medium),
                StatusPill.priority(ClinicalPriority.low),
                StatusPill.syncStatus(PatientSyncStatus.newRecord),
                StatusPill.syncStatus(PatientSyncStatus.updated),
                StatusPill.syncStatus(PatientSyncStatus.synced),
                StatusPill.recovery(RecoveryState.fullRecovery),
                StatusPill.recovery(RecoveryState.recovered),
                StatusPill.recovery(RecoveryState.degraded),
                StatusPill.recovery(RecoveryState.failed),
                StatusPill.transport('Urgent Fallback'),
                StatusPill.transport('Primary Channel'),
                StatusPill.capture('nfc'),
                StatusPill.capture('manual'),
              ],
            ),
            const SectionDivider(),

            Text(
              'Clinical Banners',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const ClinicalAlert(
              severity: ClinicalSeverity.critical,
              title: 'Critical FEC Recovery Failure',
              body: 'Packet loss has exceeded parity redundancy threshold. High clinical risk.',
              dismissible: false,
            ),
            const SizedBox(height: 12),
            ClinicalAlert(
              severity: ClinicalSeverity.caution,
              title: 'Telemetry Stream Degraded',
              body: 'Severe jitter detected. Fallback route activated to maintain intake flow.',
              onDismiss: () {},
            ),
            const SizedBox(height: 12),
            ClinicalAlert(
              severity: ClinicalSeverity.success,
              title: 'Primary Route Restored',
              body: 'Network reliability exceeds 90%. Shifted back to standard positional schema.',
              onDismiss: () {},
            ),
            const SizedBox(height: 12),
            ClinicalAlert(
              severity: ClinicalSeverity.info,
              title: 'NFC Controller Ready',
              body: 'Contactless hardware successfully initialized. Bring cards close.',
              onDismiss: () {},
            ),
            const SectionDivider(),

            Text(
              'Interactive Toasts',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton(
                  onPressed: () => ClinicalAlert.showToast(
                    context,
                    severity: ClinicalSeverity.critical,
                    title: 'Urgent Alert',
                    body: 'Clinically implausible heart rate detected.',
                  ),
                  child: const Text('Show Critical Toast'),
                ),
                ElevatedButton(
                  onPressed: () => ClinicalAlert.showToast(
                    context,
                    severity: ClinicalSeverity.caution,
                    title: 'Transport Fallback',
                    body: 'Primary cellular link lost. Switched to satellite.',
                  ),
                  child: const Text('Show Caution Toast'),
                ),
                ElevatedButton(
                  onPressed: () => ClinicalAlert.showToast(
                    context,
                    severity: ClinicalSeverity.success,
                    title: 'Record Synced',
                    body: 'Local patient file successfully overwritten by base station.',
                  ),
                  child: const Text('Show Success Toast'),
                ),
              ],
            ),
            const SectionDivider(),

            Text(
              'Tabular Numerals Vitals',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Standard font figures: 11111 vs 88888 (Notice misalignment)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Tabular figures (AppTheme): 11111 vs 88888 (Aligned columns)',
              style: AppTheme.monoTextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.label,
    required this.color,
    required this.darkColor,
  });

  final String label;
  final Color color;
  final Color darkColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 50,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: Colors.black12),
          ),
          child: const Center(
            child: Text('LGT', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        Container(
          width: 70,
          height: 50,
          decoration: BoxDecoration(
            color: darkColor,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
            border: Border.all(color: Colors.white12),
          ),
          child: const Center(
            child: Text('DRK', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
