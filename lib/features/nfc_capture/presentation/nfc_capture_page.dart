import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_page_wrapper.dart';
import '../../../core/widgets/clinical_alert.dart';
import '../../../core/widgets/floating_nav_bar.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/status_pill.dart';
import '../../data/patient_schema.dart';
import '../../patient_storage/providers/patient_storage_provider.dart';
import '../../transmission_engine/logic/chunking.dart';
import '../../transmission_engine/logic/protocol_engine.dart';
import '../../transmission_engine/providers/transmission_provider.dart';
import '../providers/nfc_provider.dart';
import 'nfc_scan_dialog.dart';

class NfcCapturePage extends ConsumerStatefulWidget {
  const NfcCapturePage({super.key});

  @override
  ConsumerState<NfcCapturePage> createState() => _NfcCapturePageState();
}

class _NfcCapturePageState extends ConsumerState<NfcCapturePage> {
  bool _scanDialogVisible = false;
  final ImagePicker _imagePicker = ImagePicker();

  void _presentScanDialog() {
    if (!mounted || _scanDialogVisible) {
      return;
    }

    _scanDialogVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scanDialogVisible) {
        return;
      }

      showNfcScanDialog(context).then((_) {
        if (mounted) {
          setState(() => _scanDialogVisible = false);
        }
      });
    });
  }

  Future<void> _selectPatientImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 45,
        maxWidth: 1024,
      );
      if (image == null) {
        return;
      }
      ref.read(nfcProvider.notifier).updateVitals(photoRef: image.path);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Image selection failed: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<NfcState>(nfcProvider, (previous, next) {
      final guideActive =
          next.showGuide &&
          (next.status == 'scanning' || next.status == 'writing');
      if (guideActive && !_scanDialogVisible) {
        _presentScanDialog();
      } else if (_scanDialogVisible && !guideActive) {
        if (Navigator.canPop(context)) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        if (mounted) {
          setState(() => _scanDialogVisible = false);
        }
      }

      if (previous?.message != next.message && !guideActive) {
        ClinicalAlert.showToast(
          context,
          severity: next.requiresPermission ? ClinicalSeverity.caution : ClinicalSeverity.info,
          title: next.requiresPermission ? 'NFC Capture Guide' : 'Contactless Capture',
          body: next.message,
        );
      }
    });
    final captureState = ref.watch(nfcProvider);
    final transmission = ref.watch(transmissionProvider);
    final storage = ref.watch(patientStorageProvider);
    final patient = captureState.patient;
    final storedRecord = patient == null ? null : storage.recordFor(patient.id);
    final diffLines = patient == null || storage.latestPatient?.id != patient.id
        ? const <String>[]
        : storage.latestDiff.summaries(patient, storedRecord?.confirmedPatient);
    final chunks = buildProtectedChunks(captureState.payload);
    final sending = transmission.status == 'transmitting';
    final canSend =
        patient != null &&
        captureState.valid &&
        patient.isValidForSend &&
        !sending;

    return Scaffold(
      body: AnimatedPageWrapper(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contactless intake',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Capture, edit, write, and send a patient record.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                GlassContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Capture session',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          StatusPill(
                            label: captureState.status.toUpperCase(),
                            icon: Icons.sensors_rounded,
                            severity: captureState.requiresPermission
                                ? ClinicalSeverity.critical
                                : ClinicalSeverity.info,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(captureState.message),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          StatusPill(
                            label: 'Validation: ${captureState.valid ? 'Ready' : 'Pending'}',
                            icon: Icons.fact_check_rounded,
                            severity: captureState.valid ? ClinicalSeverity.success : ClinicalSeverity.caution,
                          ),
                          const SizedBox(width: 8),
                          StatusPill(
                            label: 'Confidence: ${captureState.confidence}%',
                            icon: Icons.replay_circle_filled_rounded,
                            severity: captureState.confidence >= 90 ? ClinicalSeverity.success : ClinicalSeverity.caution,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: () =>
                                ref.read(nfcProvider.notifier).scanTag(),
                            icon: const Icon(Icons.nfc_outlined),
                            label: const Text('Scan NFC'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                ref.read(nfcProvider.notifier).loadFallback(),
                            icon: const Icon(Icons.edit_note_outlined),
                            label: const Text('Type instead'),
                          ),
                          OutlinedButton.icon(
                            onPressed: canSend
                                ? () => ref
                                      .read(nfcProvider.notifier)
                                      .writePatientCard()
                                : null,
                            icon: const Icon(Icons.tap_and_play_outlined),
                            label: const Text('Write card'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                ref.read(nfcProvider.notifier).clear(),
                            icon: const Icon(Icons.refresh_outlined),
                            label: const Text('Reset'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (patient != null) ...[
                  GlassContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Patient details',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            StatusPill.capture(captureState.captureSource),
                            if (patient.urgent) ...[
                              const SizedBox(width: 8),
                              StatusPill.priority(ClinicalPriority.critical),
                            ],
                          ],
                        ),
                        if (diffLines.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _DiffSummary(lines: diffLines),
                        ],
                        const SizedBox(height: 12),
                        _VitalField(
                          label: 'Patient ID',
                          value: patient.id,
                          onChanged: (value) => ref
                              .read(nfcProvider.notifier)
                              .updateVitals(id: value),
                        ),
                        _VitalField(
                          label: 'Full name',
                          value: patient.displayName,
                          onChanged: (value) => ref
                              .read(nfcProvider.notifier)
                              .updateVitals(displayName: value),
                        ),
                        _VitalField(
                          label: 'Age',
                          value: patient.age == 0 ? '' : '${patient.age}',
                          keyboardType: TextInputType.number,
                          onChanged: (value) => ref
                              .read(nfcProvider.notifier)
                              .updateVitals(age: int.tryParse(value)),
                        ),
                        _GenderRadioGroup(
                          value: PatientSchema.normalizeGenderCode(
                            patient.gender,
                          ),
                          onChanged: (value) => ref
                              .read(nfcProvider.notifier)
                              .updateVitals(gender: value),
                        ),
                        _VitalField(
                          label: 'Blood group',
                          value: patient.bloodGroup,
                          onChanged: (value) => ref
                              .read(nfcProvider.notifier)
                              .updateVitals(bloodGroup: value),
                        ),
                        _VitalField(
                          label: 'Blood pressure',
                          value: patient.bloodPressure,
                          onChanged: (value) => ref
                              .read(nfcProvider.notifier)
                              .updateVitals(bloodPressure: value),
                        ),
                        _VitalField(
                          label: 'Heart rate',
                          value: '${patient.heartRate}',
                          keyboardType: TextInputType.number,
                          onChanged: (value) => ref
                              .read(nfcProvider.notifier)
                              .updateVitals(heartRate: int.tryParse(value)),
                        ),
                        _VitalField(
                          label: 'Oxygen saturation',
                          value: '${patient.oxygenSaturation}',
                          keyboardType: TextInputType.number,
                          onChanged: (value) => ref
                              .read(nfcProvider.notifier)
                              .updateVitals(
                                oxygenSaturation: int.tryParse(value),
                              ),
                        ),
                        _VitalField(
                          label: 'Temperature',
                          value: patient.temperature.toStringAsFixed(1),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => ref
                              .read(nfcProvider.notifier)
                              .updateVitals(
                                temperature: double.tryParse(value),
                              ),
                        ),
                        _VitalField(
                          label: 'Symptoms',
                          value: patient.symptoms,
                          maxLines: 2,
                          onChanged: (value) => ref
                              .read(nfcProvider.notifier)
                              .updateVitals(symptoms: value),
                        ),
                        _VitalField(
                          label: 'Diagnosis',
                          value: patient.diagnosis,
                          maxLines: 2,
                          onChanged: (value) => ref
                              .read(nfcProvider.notifier)
                              .updateVitals(diagnosis: value),
                        ),
                        _VitalField(
                          label: 'Medical history',
                          value: patient.medicalHistory,
                          maxLines: 2,
                          onChanged: (value) => ref
                              .read(nfcProvider.notifier)
                              .updateVitals(medicalHistory: value),
                        ),
                        _VitalField(
                          label: 'Current medication',
                          value: patient.currentMedication,
                          maxLines: 2,
                          onChanged: (value) => ref
                              .read(nfcProvider.notifier)
                              .updateVitals(currentMedication: value),
                        ),
                        _VitalField(
                          label: 'Allergies',
                          value: patient.allergies,
                          onChanged: (value) => ref
                              .read(nfcProvider.notifier)
                              .updateVitals(allergies: value),
                        ),
                        _VitalField(
                          label: 'Consciousness',
                          value: patient.consciousness,
                          onChanged: (value) => ref
                              .read(nfcProvider.notifier)
                              .updateVitals(consciousness: value),
                        ),
                        _VitalField(
                          label: 'Emergency notes',
                          value: patient.emergencyNotes,
                          maxLines: 2,
                          onChanged: (value) => ref
                              .read(nfcProvider.notifier)
                              .updateVitals(emergencyNotes: value),
                        ),
                        _VitalField(
                          label: 'Address',
                          value: patient.address,
                          maxLines: 2,
                          onChanged: (value) => ref
                              .read(nfcProvider.notifier)
                              .updateVitals(address: value),
                        ),
                        _VitalField(
                          label: 'Contact details',
                          value: patient.contactDetails,
                          keyboardType: TextInputType.phone,
                          onChanged: (value) => ref
                              .read(nfcProvider.notifier)
                              .updateVitals(contactDetails: value),
                        ),
                        _VitalField(
                          label: 'Insurance',
                          value: patient.insurance,
                          onChanged: (value) => ref
                              .read(nfcProvider.notifier)
                              .updateVitals(insurance: value),
                        ),
                        _VitalField(
                          label: 'Clinical notes',
                          value: patient.notes,
                          maxLines: 2,
                          onChanged: (value) => ref
                              .read(nfcProvider.notifier)
                              .updateVitals(notes: value),
                        ),
                        _PhotoReferenceField(
                          value: patient.photoRef,
                          onSelectImage: _selectPatientImage,
                          onUsePlaceholder: () => ref
                              .read(nfcProvider.notifier)
                              .updateVitals(
                                photoRef: 'placeholder://patient-photo',
                              ),
                          onClear: patient.photoRef.isEmpty
                              ? null
                              : () => ref
                                    .read(nfcProvider.notifier)
                                    .updateVitals(photoRef: ''),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Mark as urgent'),
                          subtitle: const Text(
                            'Expedites fallback and preserves a tiny thumbnail in fallback mode.',
                          ),
                          value: patient.urgent,
                          onChanged: (value) => ref
                              .read(nfcProvider.notifier)
                              .updateVitals(urgent: value),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: canSend
                              ? () => ref
                                    .read(transmissionProvider.notifier)
                                    .sendPatientRecord(patient: patient)
                              : null,
                          child: Text(
                            sending ? 'Sending...' : 'Send protected update',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                GlassContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MGP1 payload captured',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      _PayloadPreview(payload: captureState.payload),
                      const SizedBox(height: 12),
                      Text(
                        'Protected chunks: ${chunks.where((c) => !c.parity).length}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Spare retrieval pieces: ${chunks.where((c) => c.parity).length}',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: chunks
                            .take(8)
                            .map(
                              (chunk) => StatusPill(
                                label: '${chunk.parity ? 'P' : 'D'}${chunk.index}:${chunk.retrievalBit}',
                                icon: chunk.parity
                                    ? Icons.add_link_rounded
                                    : Icons.view_module_rounded,
                                severity: chunk.parity ? ClinicalSeverity.caution : ClinicalSeverity.success,
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      Text(transmission.message),
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



class _DiffSummary extends StatelessWidget {
  const _DiffSummary({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delta preview', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          ...lines.take(5).map((line) => Text(line)),
        ],
      ),
    );
  }
}

class _PayloadPreview extends StatelessWidget {
  const _PayloadPreview({required this.payload});

  final String payload;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        payload,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _PhotoReferenceField extends StatelessWidget {
  const _PhotoReferenceField({
    required this.value,
    required this.onSelectImage,
    required this.onUsePlaceholder,
    required this.onClear,
  });

  final String value;
  final VoidCallback onSelectImage;
  final VoidCallback onUsePlaceholder;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final reference = value.trim();
    final hasImage = reference.isNotEmpty;
    final isPlaceholder = reference.startsWith('placeholder://');
    final imageFile = hasImage && !isPlaceholder ? File(reference) : null;
    final hasFile = imageFile != null && imageFile.existsSync();
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Patient image', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Material(
              color: hasImage
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onUsePlaceholder,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasFile)
                      Image.file(imageFile, fit: BoxFit.cover)
                    else
                      Center(
                        child: Icon(
                          hasImage
                              ? Icons.image_rounded
                              : Icons.add_photo_alternate_outlined,
                          size: 56,
                          color: hasImage
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (hasImage)
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isPlaceholder ? 'Placeholder image' : reference,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Row(
                        children: [
                          IconButton.filledTonal(
                            tooltip: 'Select patient image',
                            onPressed: onSelectImage,
                            icon: const Icon(Icons.photo_library_rounded),
                          ),
                          const SizedBox(width: 6),
                          IconButton.filledTonal(
                            tooltip: 'Use placeholder image',
                            onPressed: onUsePlaceholder,
                            icon: const Icon(Icons.image_search_rounded),
                          ),
                          const SizedBox(width: 6),
                          IconButton.filledTonal(
                            tooltip: 'Clear patient image',
                            onPressed: onClear,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VitalField extends StatefulWidget {
  const _VitalField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.keyboardType,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  State<_VitalField> createState() => _VitalFieldState();
}

class _GenderRadioGroup extends StatelessWidget {
  const _GenderRadioGroup({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == '1' ? '1' : '0';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gender', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Row(
            key: const Key('gender-radio-group'),
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: RadioListTile<String>(
                    key: const Key('gender-male-radio'),
                    contentPadding: EdgeInsets.zero,
                    value: '0',
                    groupValue: selected,
                    onChanged: (value) {
                      if (value != null) {
                        onChanged(value);
                      }
                    },
                    title: const Text('Male'),
                    secondary: const Icon(Icons.male_rounded),
                  ),
                ),
              ),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: RadioListTile<String>(
                    key: const Key('gender-female-radio'),
                    contentPadding: EdgeInsets.zero,
                    value: '1',
                    groupValue: selected,
                    onChanged: (value) {
                      if (value != null) {
                        onChanged(value);
                      }
                    },
                    title: const Text('Female'),
                    secondary: const Icon(Icons.female_rounded),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VitalFieldState extends State<_VitalField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _VitalField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: _controller,
        keyboardType: widget.keyboardType,
        maxLines: widget.maxLines,
        textInputAction: widget.maxLines > 1
            ? TextInputAction.newline
            : TextInputAction.next,
        decoration: InputDecoration(labelText: widget.label),
        onChanged: widget.onChanged,
      ),
    );
  }
}
