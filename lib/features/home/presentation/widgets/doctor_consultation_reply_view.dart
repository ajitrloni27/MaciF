import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/clinical_colors.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../transmission_engine/providers/transmission_provider.dart';

class DoctorConsultationReplyView extends ConsumerWidget {
  const DoctorConsultationReplyView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transmission = ref.watch(transmissionProvider);
    final reply = transmission.latestReceivedReply;

    if (reply == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mark_email_read_rounded, color: Colors.tealAccent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Doctor Consultation Reply',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                StatusPill(
                  label: reply.followUp ? 'Follow-Up Needed' : 'Completed',
                  icon: reply.followUp ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                  severity: reply.followUp ? ClinicalSeverity.caution : ClinicalSeverity.success,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Specialist: ${reply.doctorName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Advice:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey.shade400)),
                  const SizedBox(height: 2),
                  Text(reply.advice, style: Theme.of(context).textTheme.bodyMedium),
                  if (reply.prescriptionNote.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Prescription (Rx):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey.shade400)),
                    const SizedBox(height: 2),
                    Text(reply.prescriptionNote, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Case: ${reply.caseId} • ${_formatTime(reply.timestamp)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.done_all_rounded, size: 16),
                  label: const Text('Acknowledge'),
                  onPressed: () => ref.read(transmissionProvider.notifier).clearReceivedReply(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }
}
