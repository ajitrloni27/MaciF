import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/clinical_colors.dart';
import '../../../../core/widgets/clinical_alert.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../transmission_engine/providers/transmission_provider.dart';
import '../../models/consultation_reply.dart';

class DoctorReplyCard extends ConsumerStatefulWidget {
  const DoctorReplyCard({
    super.key,
    required this.caseId,
    required this.patientName,
  });

  final String caseId;
  final String patientName;

  @override
  ConsumerState<DoctorReplyCard> createState() => _DoctorReplyCardState();
}

class _DoctorReplyCardState extends ConsumerState<DoctorReplyCard> {
  final _doctorNameController = TextEditingController(text: 'Dr. Ramesh Rao, MD');
  final _adviceController = TextEditingController();
  final _prescriptionController = TextEditingController();
  bool _followUpRequired = false;
  bool _sending = false;

  @override
  void dispose() {
    _doctorNameController.dispose();
    _adviceController.dispose();
    _prescriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReply() async {
    final advice = _adviceController.text.trim();
    if (advice.isEmpty) {
      ClinicalAlert.showToast(
        context,
        severity: ClinicalSeverity.caution,
        title: 'Advice required',
        body: 'Please provide consultation advice for the health worker.',
      );
      return;
    }

    setState(() => _sending = true);
    final reply = ConsultationReply(
      caseId: widget.caseId.isEmpty ? 'CASE-101' : widget.caseId,
      doctorName: _doctorNameController.text.trim(),
      advice: advice,
      prescriptionNote: _prescriptionController.text.trim(),
      followUp: _followUpRequired,
      timestamp: DateTime.now(),
    );

    try {
      final result = await ref.read(transmissionProvider.notifier).sendConsultationReply(reply: reply);
      if (mounted) {
        if (result.rebuilt) {
          ClinicalAlert.showToast(
            context,
            severity: ClinicalSeverity.success,
            title: 'Reply Delivered',
            body: 'Advice sent back to field worker via protected pipeline.',
          );
          _adviceController.clear();
          _prescriptionController.clear();
        } else {
          ClinicalAlert.showToast(
            context,
            severity: ClinicalSeverity.caution,
            title: 'Queued for Retry',
            body: 'Network degraded; reply staged in store-and-forward queue.',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transmission = ref.watch(transmissionProvider);
    final replies = transmission.confirmedReplies.where((r) => r.caseId == widget.caseId).toList();

    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.reply_all_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                'Two-Way Specialist Reply',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              StatusPill(
                label: 'Pipeline Priority: HIGH',
                icon: Icons.bolt_rounded,
                severity: ClinicalSeverity.info,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _doctorNameController,
            decoration: const InputDecoration(labelText: 'Specialist Name / Signature', isDense: true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _adviceController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Clinical Advice & Instructions', isDense: true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _prescriptionController,
            decoration: const InputDecoration(labelText: 'Prescription / Medications (Rx)', isDense: true),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('Require urgent follow-up visit', style: Theme.of(context).textTheme.bodySmall),
              ),
              Switch.adaptive(
                value: _followUpRequired,
                onChanged: (val) => setState(() => _followUpRequired = val),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: Icon(_sending ? Icons.sync_rounded : Icons.send_rounded),
              label: Text(_sending ? 'Compressing & Transmitting...' : 'Send Protected Doctor Reply'),
              onPressed: _sending ? null : _submitReply,
            ),
          ),
          if (replies.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Sent Replies Baseline (${replies.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 6),
            ...replies.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• ${r.doctorName}: ${r.advice}', style: Theme.of(context).textTheme.bodySmall),
                )),
          ],
        ],
      ),
    );
  }
}
