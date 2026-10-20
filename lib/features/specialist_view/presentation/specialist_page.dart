import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_page_wrapper.dart';
import '../../../core/widgets/clinical_alert.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/section_divider.dart';
import '../../../core/widgets/status_pill.dart';
import '../../data/patient_model.dart';
import '../../data/patient_schema.dart';
import '../../network_simulator/providers/network_simulator_provider.dart';
import '../../nfc_capture/providers/nfc_provider.dart';
import '../../transmission_engine/logic/protocol_engine.dart';
import '../../transmission_engine/providers/transmission_provider.dart';
import '../../triage/logic/triage_assessment.dart';
import 'widgets/image_recovery_demo.dart';

class SpecialistPage extends ConsumerStatefulWidget {
  const SpecialistPage({super.key});

  @override
  ConsumerState<SpecialistPage> createState() => _SpecialistPageState();
}

class _SpecialistPageState extends ConsumerState<SpecialistPage> {
  int _selectedPayloadIndex = 0;

  @override
  Widget build(BuildContext context) {
    final captureState = ref.watch(nfcProvider);
    final networkState = ref.watch(networkSimulatorProvider);
    final transmission = ref.watch(transmissionProvider);

    final records = transmission.doctorPayloads;
    if (_selectedPayloadIndex >= records.length) {
      _selectedPayloadIndex = 0;
    }

    final hasRecords = records.isNotEmpty;
    final activeRecord = hasRecords ? records[_selectedPayloadIndex] : null;

    final receipt = _selectedPayloadIndex == 0
        ? (transmission.receipts.isEmpty ? null : transmission.receipts.first)
        : (activeRecord != null
            ? TransmissionReceipt(
                timestamp: activeRecord.timestamp,
                chunksSent: 8,
                chunksDropped: 0,
                chunksUsed: 8,
                checksumMatch: activeRecord.rebuilt,
                medGateStatus: 'confirmed',
                naiveStatus: 'unconfirmed',
                rebuilt: activeRecord.rebuilt,
                sourceChecksum: '0xVERIFIED',
                rebuiltChecksum: '0xVERIFIED',
              )
            : null);

    final rebuiltPatient = activeRecord != null
        ? _tryDecodePatient(activeRecord.payload)
        : _tryDecodePatient(transmission.doctorPayload);

    final doctorPayload = activeRecord != null
        ? activeRecord.payload
        : transmission.doctorPayload;

    final rebuilt = activeRecord != null
        ? activeRecord.rebuilt
        : transmission.rebuilt;

    final urgent = activeRecord != null
        ? activeRecord.urgent
        : transmission.urgentCase;

    final assessment = evaluateTriage(
      payload: activeRecord != null
          ? activeRecord.payload
          : captureState.payload,
      reliability: networkState.reliability,
      latencyMs: networkState.latencyMs,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AnimatedPageWrapper(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go(AppRoutes.home),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Doctor Console',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!rebuilt && hasRecords)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: ClinicalAlert(
                      severity: ClinicalSeverity.critical,
                      title: 'Critical Rebuild Missed',
                      body: 'Redundancy threshold exceeded. Displaying partial emergency snapshot data only.',
                      dismissible: false,
                    ),
                  ),
                GlassContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Received patient details',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _IntegrityBanner(
                        receipt: receipt,
                        rebuilt: rebuilt,
                        urgent: urgent,
                      ),
                      const SizedBox(height: 16),
                      _DoctorPatientSummary(
                        patient: rebuiltPatient,
                        payload: doctorPayload,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatusPill.capture(captureState.captureSource),
                          StatusPill.transport(networkState.mode),
                          StatusPill.transport(urgent ? 'Urgent' : 'Routine'),
                          StatusPill(
                            label: 'Survival: ${transmission.survivalPercent}%',
                            icon: Icons.health_and_safety_rounded,
                            severity: transmission.survivalPercent >= 80 ? ClinicalSeverity.success : ClinicalSeverity.caution,
                          ),
                          StatusPill(
                            label: 'Confidence: ${transmission.recoveryConfidencePercent}%',
                            icon: Icons.replay_circle_filled_rounded,
                            severity: transmission.recoveryConfidencePercent >= 90 ? ClinicalSeverity.success : ClinicalSeverity.caution,
                          ),
                        ],
                      ),
                      const SectionDivider(),
                      _ChangedFields(fields: transmission.changedFields),
                      const SectionDivider(),
                      _PayloadEvidence(transmission: transmission),
                      const SectionDivider(),
                      ImageRecoveryDemo(
                        result: transmission.imageRecoveryResult,
                        photoRef: rebuiltPatient?.photoRef ?? '',
                      ),
                      const SectionDivider(),
                      _DeliveredPayloadList(
                        records: records,
                        selectedIndex: _selectedPayloadIndex,
                        onSelected: (index) {
                          setState(() {
                            _selectedPayloadIndex = index;
                          });
                        },
                      ),
                      const SectionDivider(),
                      Text(
                        'Triage assessment',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text('Triage severity: ${assessment.severity.toUpperCase()}'),
                      const SizedBox(height: 4),
                      Text('Triage score: ${assessment.score}/100'),
                      const SizedBox(height: 4),
                      Text('Recommendation: ${assessment.recommendation}'),
                      const SectionDivider(),
                      Text(
                        'Progressive sections',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: transmission.sections.map((section) {
                          final title = section.name.replaceAll('_', ' ');
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              title.toUpperCase(),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          );
                        }).toList(),
                      ),
                      const SectionDivider(),
                      Text(
                        'Queue status',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      _PacketQueueList(items: transmission.queueItems),
                      const SectionDivider(),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () => context.go(AppRoutes.home),
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Dashboard'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => context.go(AppRoutes.networkSimulator),
                            icon: const Icon(Icons.hub_rounded),
                            label: const Text('Simulator'),
                          ),
                          FilledButton.tonal(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (context) => _PacketQueueDialog(
                                items: transmission.queueItems,
                              ),
                            ),
                            child: const Text('Queue details'),
                          ),
                          FilledButton.tonal(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (context) => _AllPayloadsDialog(
                                records: records,
                                selectedIndex: _selectedPayloadIndex,
                                onSelected: (index) {
                                  setState(() {
                                    _selectedPayloadIndex = index;
                                  });
                                },
                              ),
                            ),
                            child: const Text('All payloads'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

PatientModel? _tryDecodePatient(String payload) {
  try {
    return PatientModel.fromPayload(payload);
  } catch (_) {
    return null;
  }
}

class _DoctorPatientSummary extends StatelessWidget {
  const _DoctorPatientSummary({required this.patient, required this.payload});

  final PatientModel? patient;
  final String payload;

  @override
  Widget build(BuildContext context) {
    final patient = this.patient;
    if (patient == null) {
      return Text('Received encrypted raw payload: $payload');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DoctorImagePreview(reference: patient.photoRef),
        const SizedBox(height: 16),
        _PatientFieldGrid(patient: patient),
      ],
    );
  }
}

class _DoctorImagePreview extends StatelessWidget {
  const _DoctorImagePreview({required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context) {
    final trimmed = reference.trim();
    final isPlaceholder = trimmed.startsWith('placeholder://');
    final imageFile = trimmed.isNotEmpty && !isPlaceholder
        ? File(trimmed)
        : null;
    final hasFile = imageFile != null && imageFile.existsSync();
    final colorScheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasFile
            ? Image.file(imageFile, fit: BoxFit.cover)
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPlaceholder
                          ? Icons.image_search_rounded
                          : Icons.image_not_supported_outlined,
                      size: 36,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      trimmed.isEmpty ? 'No image reference' : 'Mock photo reference active',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PatientFieldGrid extends StatelessWidget {
  const _PatientFieldGrid({required this.patient});

  final PatientModel patient;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monoStyle = AppTheme.monoTextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.white : Colors.black87,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Vitals Section ──
        const _SectionHeader(title: 'Patient Vitals'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _VitalStat(label: 'BP', value: patient.bloodPressure, style: monoStyle),
              _VitalStat(label: 'HR', value: '${patient.heartRate} bpm', style: monoStyle),
              _VitalStat(label: 'SpO2', value: '${patient.oxygenSaturation}%', style: monoStyle),
              _VitalStat(label: 'TEMP', value: '${patient.temperature.toStringAsFixed(1)}°C', style: monoStyle),
            ],
          ),
        ),
        const SectionDivider(),

        // ── Identity Section ──
        const _SectionHeader(title: 'Demographics & identity'),
        const SizedBox(height: 8),
        _FieldRow(label: 'Patient ID', value: patient.id),
        _FieldRow(label: 'Full name', value: patient.displayName),
        _FieldRow(label: 'Age', value: patient.age == 0 ? '-' : '${patient.age}'),
        _FieldRow(label: 'Gender', value: PatientSchema.genderLabel(patient.gender)),
        _FieldRow(label: 'Blood group', value: patient.bloodGroup),
        _FieldRow(label: 'Contact details', value: patient.contactDetails),
        _FieldRow(label: 'Address', value: patient.address),
        _FieldRow(label: 'Insurance', value: patient.insurance),
        const SectionDivider(),

        // ── Clinical Section ──
        const _SectionHeader(title: 'Clinical findings'),
        const SizedBox(height: 8),
        _FieldRow(label: 'Symptoms', value: patient.symptoms),
        _FieldRow(label: 'Diagnosis', value: patient.diagnosis),
        _FieldRow(label: 'Medical history', value: patient.medicalHistory),
        _FieldRow(label: 'Current medication', value: patient.currentMedication),
        _FieldRow(label: 'Allergies', value: patient.allergies),
        _FieldRow(label: 'Consciousness', value: patient.consciousness),
        _FieldRow(label: 'Clinical notes', value: patient.notes),
        const SectionDivider(),

        // ── Emergency Section ──
        const _SectionHeader(title: 'Emergency intake notes'),
        const SizedBox(height: 8),
        _FieldRow(label: 'Emergency notes', value: patient.emergencyNotes),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: kMedicalAccent,
            letterSpacing: 0.5,
          ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VitalStat extends StatelessWidget {
  const _VitalStat({required this.label, required this.value, required this.style});
  final String label;
  final String value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(value, style: style),
      ],
    );
  }
}

class _PayloadEvidence extends StatelessWidget {
  const _PayloadEvidence({required this.transmission});

  final TransmissionState transmission;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payload evidence',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Chunks: ${transmission.chunkCount} data + ${transmission.parityCount} parity',
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          'Compression: ${transmission.originalByteCount} B to ${transmission.compressedByteCount} B',
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        SelectableText(
          'MGP1: ${transmission.doctorPayload}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
        ),
      ],
    );
  }
}

class _DeliveredPayloadList extends StatelessWidget {
  const _DeliveredPayloadList({
    required this.records,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<DoctorPayloadRecord> records;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Row(
        children: [
          Icon(Icons.inbox_outlined, size: 20),
          SizedBox(width: 8),
          Text('No specialist payloads received yet', style: TextStyle(fontSize: 12)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Received payloads',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ...records.asMap().entries.map((entry) {
          final index = entry.key;
          final record = entry.value;
          final patient = _tryDecodePatient(record.payload);
          final isSelected = index == selectedIndex;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              dense: true,
              selected: isSelected,
              selectedColor: Theme.of(context).colorScheme.primary,
              selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              onTap: () => onSelected(index),
              leading: Icon(
                record.urgent
                    ? Icons.emergency_rounded
                    : Icons.assignment_turned_in_rounded,
                color: isSelected ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(
                patient?.displayName ?? record.summary,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                '${record.rebuilt ? 'Rebuilt' : 'Partial'} · ${record.payload}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _AllPayloadsDialog extends StatelessWidget {
  const _AllPayloadsDialog({
    required this.records,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<DoctorPayloadRecord> records;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('All payloads'),
      content: SizedBox(
        width: 560,
        child: records.isEmpty
            ? const Text('No specialist payloads received yet')
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: records.asMap().entries.map((entry) {
                    final index = entry.key;
                    final record = entry.value;
                    final patient = _tryDecodePatient(record.payload);
                    final isSelected = index == selectedIndex;

                    return InkWell(
                      onTap: () {
                        onSelected(index);
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              record.urgent
                                  ? Icons.emergency_rounded
                                  : Icons.assignment_turned_in_rounded,
                              color: isSelected ? Theme.of(context).colorScheme.primary : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    patient?.displayName ?? record.summary,
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                          fontWeight: isSelected ? FontWeight.bold : null,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${record.rebuilt ? 'Rebuilt' : 'Partial'} · ${record.urgent ? 'Urgent' : 'Routine'}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _PacketQueueList extends StatelessWidget {
  const _PacketQueueList({required this.items});

  final List<TransmissionQueueItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Row(
        children: [
          Icon(Icons.playlist_add_check_rounded, size: 20),
          SizedBox(width: 8),
          Text('No packets queued', style: TextStyle(fontSize: 12)),
        ],
      );
    }
    return Column(
      children: items
          .take(3)
          .map((item) => _PacketQueueTile(item: item))
          .toList(),
    );
  }
}

class _PacketQueueDialog extends StatelessWidget {
  const _PacketQueueDialog({required this.items});

  final List<TransmissionQueueItem> items;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Packet queue'),
      content: SizedBox(
        width: 560,
        child: items.isEmpty
            ? const Text('No packets queued')
            : SingleChildScrollView(
                child: Column(
                  children: items
                      .map((item) => _PacketQueueTile(item: item))
                      .toList(),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _PacketQueueTile extends StatelessWidget {
  const _PacketQueueTile({required this.item});

  final TransmissionQueueItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final paused = item.status == 'paused';
    final active = item.status == 'sending';
    final color = item.isUrgent
        ? colorScheme.error
        : paused
            ? colorScheme.tertiary
            : active
                ? colorScheme.primary
                : colorScheme.secondary;
    final icon = item.isUrgent
        ? Icons.emergency_rounded
        : paused
            ? Icons.pause_circle_filled_rounded
            : active
                ? Icons.send_rounded
                : Icons.schedule_rounded;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(item.summary, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      subtitle: Text(
        '${item.status.toUpperCase()} - ${item.packetCount} packets',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: StatusPill.transport(item.isUrgent ? 'Urgent' : (paused ? 'Paused' : 'Queue')),
    );
  }
}

class _IntegrityBanner extends StatelessWidget {
  const _IntegrityBanner({
    required this.receipt,
    required this.rebuilt,
    required this.urgent,
  });

  final TransmissionReceipt? receipt;
  final bool rebuilt;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final matched = receipt?.checksumMatch ?? false;
    final severity = urgent
        ? ClinicalSeverity.critical
        : matched
            ? ClinicalSeverity.success
            : rebuilt
                ? ClinicalSeverity.caution
                : ClinicalSeverity.critical;

    return ClinicalAlert(
      severity: severity,
      title: urgent
          ? 'URGENT — expedited fallback active'
          : matched
              ? 'Checksum match confirmed'
              : rebuilt
                  ? 'Awaiting checksum receipt'
                  : 'No verified rebuild yet',
      body: urgent
          ? 'Priority telemetry lane triggered. Emergency snapshot fallback active.'
          : matched
              ? 'Rebuilt payload matches source checksum verified by receiver.'
              : rebuilt
                  ? 'Data payload assembled but FNV-1a check pending.'
                  : 'Loss exceeds FEC capacity. Reconnection attempt pending.',
      dismissible: false,
    );
  }
}

class _ChangedFields extends StatelessWidget {
  const _ChangedFields({required this.fields});

  final List<String> fields;

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) {
      return const Row(
        children: [
          Icon(Icons.difference_outlined, size: 20),
          SizedBox(width: 8),
          Text('No delta received yet', style: TextStyle(fontSize: 12)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delta highlights',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: fields
              .map(
                (field) => StatusPill(
                  label: 'Changed: $field',
                  icon: Icons.change_circle_outlined,
                  severity: ClinicalSeverity.caution,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
