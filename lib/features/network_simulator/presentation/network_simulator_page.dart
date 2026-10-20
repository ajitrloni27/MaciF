import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_page_wrapper.dart';
import '../../../core/widgets/floating_nav_bar.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../core/widgets/section_divider.dart';
import '../../nfc_capture/providers/nfc_provider.dart';
import '../../transmission_engine/logic/recovery_strategy.dart';
import '../../transmission_engine/providers/transmission_provider.dart';
import '../providers/network_simulator_provider.dart';

class NetworkSimulatorPage extends ConsumerWidget {
  const NetworkSimulatorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(networkSimulatorProvider);
    final captureState = ref.watch(nfcProvider);
    final transmission = ref.watch(transmissionProvider);
    final patient = captureState.patient;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Future<void> runTransmission() async {
      if (patient == null || !patient.isValidForSend) {
        return;
      }
      await ref
          .read(transmissionProvider.notifier)
          .sendPatientRecord(patient: patient, sparePieces: 2);
    }

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
                  'Network Simulator',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                GlassContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transport Settings',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Reliability', style: Theme.of(context).textTheme.bodyMedium),
                          Text('${state.reliability}%', style: valueStyle),
                        ],
                      ),
                      Slider(
                        value: state.reliability.toDouble(),
                        min: 35,
                        max: 100,
                        divisions: 13,
                        label: '${state.reliability}%',
                        onChanged: (value) {
                          ref
                              .read(networkSimulatorProvider.notifier)
                              .setReliability(value);
                          runTransmission();
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Latency', style: Theme.of(context).textTheme.bodyMedium),
                          Text('${state.latencyMs} ms', style: valueStyle),
                        ],
                      ),
                      Slider(
                        value: state.latencyMs.toDouble(),
                        min: 60,
                        max: 650,
                        divisions: 59,
                        label: '${state.latencyMs}ms',
                        onChanged: (value) {
                          ref
                              .read(networkSimulatorProvider.notifier)
                              .setLatency(value);
                          runTransmission();
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Redundancy', style: Theme.of(context).textTheme.bodyMedium),
                          Text('${state.redundancy} groups', style: valueStyle),
                        ],
                      ),
                      Slider(
                        value: state.redundancy.toDouble(),
                        min: 0,
                        max: 6,
                        divisions: 6,
                        label: '${state.redundancy}',
                        onChanged: (value) {
                          ref
                              .read(networkSimulatorProvider.notifier)
                              .setRedundancy(value);
                          runTransmission();
                        },
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoPill(label: 'Mode', value: state.mode),
                          _InfoPill(label: 'Risk', value: state.deliveryImpact),
                          _InfoPill(label: 'Signal', value: state.qualityLabel),
                          _InfoPill(label: 'Strategy', value: state.activeStrategy),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Profile Presets',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ProfileChip(label: 'Ultra Low', value: 'Ultra Low'),
                          _ProfileChip(label: 'Low', value: 'Low'),
                          _ProfileChip(label: 'Medium', value: 'Medium'),
                          _ProfileChip(label: 'High', value: 'High'),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: state.compareMode,
                        onChanged: (value) => ref
                            .read(networkSimulatorProvider.notifier)
                            .setCompareMode(value),
                        title: const Text('Compare mode'),
                        subtitle: const TextStyle(fontSize: 11, color: Colors.grey) != null
                            ? const Text('Simulate MedGate vs Naive (Standard) app side-by-side')
                            : null,
                        secondary: const Icon(Icons.compare_arrows_rounded),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                ref.read(networkSimulatorProvider.notifier).setMode('stable');
                                runTransmission();
                              },
                              icon: const Icon(Icons.check_circle_rounded),
                              label: const Text('Preset Stable'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                ref.read(networkSimulatorProvider.notifier).setMode('degraded');
                                runTransmission();
                              },
                              icon: const Icon(Icons.gpp_maybe_rounded),
                              label: const Text('Preset Degraded'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GlassContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transmission Audit & Proof',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _ResilienceGauge(score: transmission.resilienceScore),
                      const SizedBox(height: 16),
                      if (state.compareMode) ...[
                        _CompareStrip(
                          medGate: '${transmission.survivalPercent}% rebuilt',
                          naive: transmission.normalAppStatus,
                          medGateOk: transmission.rebuilt,
                          naiveOk: transmission.normalAppStatus == 'Delivered',
                        ),
                        const SizedBox(height: 16),
                      ],
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _LogStat(label: 'Bandwidth Budget', value: '${transmission.bandwidthBudget} kbps', style: valueStyle),
                            _LogStat(label: 'Current Usage', value: '${transmission.currentUsage} kbps', style: valueStyle),
                            _LogStat(label: 'Remaining Budget', value: '${transmission.remainingBudget} kbps', style: valueStyle),
                            _LogStat(label: 'Compression Ratio', value: '${transmission.compressionRatio.toStringAsFixed(2)}x', style: valueStyle),
                            _LogStat(label: 'Packet Loss Roll', value: '${transmission.packetLoss}%', style: valueStyle),
                            _LogStat(label: 'Delivery Latency', value: '${transmission.latency} ms', style: valueStyle),
                            _LogStat(label: 'Recovery Ratio', value: '${transmission.recoveryPercent}%', style: valueStyle),
                            _LogStat(label: 'Est. Delivery Time', value: '${transmission.estimatedDeliveryTime} ms', style: valueStyle),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        transmission.proofSummary,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                      ),
                      const SectionDivider(),
                      Text(
                        'Integrity Log',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (transmission.receipts.isEmpty)
                        const Row(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 20),
                            SizedBox(width: 8),
                            Text('No transmissions logged yet', style: TextStyle(fontSize: 12)),
                          ],
                        )
                      else
                        ...transmission.receipts.take(4).map((r) => _ReceiptRow(r)),
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

class _ResilienceGauge extends StatelessWidget {
  const _ResilienceGauge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final danger = score < 70;
    final color = danger
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: danger ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: score / 100),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, _) => SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 6,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FEC Resilience Score',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: score.toDouble()),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, value, _) => Text(
                    '${value.round()}%',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareStrip extends StatelessWidget {
  const _CompareStrip({
    required this.medGate,
    required this.naive,
    required this.medGateOk,
    required this.naiveOk,
  });

  final String medGate;
  final String naive;
  final bool medGateOk;
  final bool naiveOk;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CompareTile(label: 'MedGate (FEC)', value: medGate, ok: medGateOk),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CompareTile(label: 'Naive (TCP-like)', value: naive, ok: naiveOk),
        ),
      ],
    );
  }
}

class _CompareTile extends StatelessWidget {
  const _CompareTile({
    required this.label,
    required this.value,
    required this.ok,
  });

  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle_rounded : Icons.error_rounded,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow(this.receipt);

  final TransmissionReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = "${receipt.timestamp.hour.toString().padLeft(2, '0')}:${receipt.timestamp.minute.toString().padLeft(2, '0')}:${receipt.timestamp.second.toString().padLeft(2, '0')}";

    final recoveryState = receipt.checksumMatch
        ? RecoveryState.fullRecovery
        : receipt.chunksDropped == 0
            ? RecoveryState.fullRecovery
            : receipt.chunksUsed > 0
                ? RecoveryState.recovered
                : RecoveryState.failed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            receipt.checksumMatch ? Icons.gpp_good_rounded : Icons.gpp_maybe_rounded,
            color: receipt.checksumMatch ? Colors.green : Colors.amber,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receipt.checksumMatch ? 'Checksum Matched' : ' FEC Partial Rebuild',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '${receipt.chunksSent} sent · ${receipt.chunksDropped} lost · ${receipt.chunksUsed} reconstructed',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusPill.recovery(recoveryState),
          const SizedBox(width: 8),
          Text(
            timeStr,
            style: AppTheme.monoTextStyle(
              fontSize: 10,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final severity = label.toLowerCase().contains('risk')
        ? (value.toLowerCase().contains('low') ? ClinicalSeverity.success : ClinicalSeverity.caution)
        : ClinicalSeverity.info;
    return StatusPill(
      label: '$label: $value',
      icon: Icons.network_check_rounded,
      severity: severity,
    );
  }
}

class _ProfileChip extends ConsumerWidget {
  const _ProfileChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = ref.watch(networkSimulatorProvider).profileLabel == value;
    return ChoiceChip(
      label: Text(label),
      selected: isActive,
      onSelected: (_) {
        ref.read(networkSimulatorProvider.notifier).setProfile(value);
      },
    );
  }
}

class _LogStat extends StatelessWidget {
  const _LogStat({required this.label, required this.value, required this.style});

  final String label;
  final String value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          Text(
            value,
            style: style.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
