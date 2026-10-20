import 'dart:io';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../transmission_engine/logic/image_recovery.dart';

class ImageRecoveryDemo extends StatefulWidget {
  const ImageRecoveryDemo({
    super.key,
    required this.result,
    required this.photoRef,
  });

  final ImageRecoveryResult? result;
  final String photoRef;

  @override
  State<ImageRecoveryDemo> createState() => _ImageRecoveryDemoState();
}

class _ImageRecoveryDemoState extends State<ImageRecoveryDemo> {
  bool _showRecovered = true;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (result == null || widget.photoRef.isEmpty) {
      return GlassContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                color: isDark ? Colors.white30 : Colors.black38,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No image payload to demonstrate recovery.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Image Recovery Demo',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            StatusPill.recovery(result.state),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Simulating packet loss over image tiles. Like QR codes, MedGate uses Reed-Solomon/XOR parity groups to recover missing data packets.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white54 : Colors.black54,
              ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Naive (No Recovery)'),
              icon: Icon(Icons.broken_image_rounded),
            ),
            ButtonSegment(
              value: true,
              label: Text('MedGate Recovery'),
              icon: Icon(Icons.image_rounded),
            ),
          ],
          selected: {_showRecovered},
          onSelectionChanged: (val) {
            setState(() {
              _showRecovered = val.first;
            });
          },
        ),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 16 / 9,
              ),
              itemCount: 16,
              itemBuilder: (context, index) {
                final isMissing = _showRecovered
                    ? (!result.survivingDataIndices.contains(index) &&
                        !result.recoveredDataIndices.contains(index))
                    : !result.survivingDataIndices.contains(index);

                return _ImageTile(
                  index: index,
                  photoRef: widget.photoRef,
                  isMissing: isMissing,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatsRow(
                label: 'Simulated packet loss',
                value: '${result.lossPercent.toStringAsFixed(0)}% chunks lost',
              ),
              _StatsRow(
                label: 'Error-correction recovery',
                value: '${result.recoveryPercent.toStringAsFixed(0)}% restored',
              ),
              _StatsRow(
                label: 'Result summary',
                value: result.rebuilt ? '100% Intact Image' : 'Degraded Image quality',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.index,
    required this.photoRef,
    required this.isMissing,
  });

  final int index;
  final String photoRef;
  final bool isMissing;

  @override
  Widget build(BuildContext context) {
    if (isMissing) {
      return Container(
        color: Colors.grey.shade400,
        child: const Center(
          child: Icon(Icons.blur_on_rounded, size: 16, color: Colors.white70),
        ),
      );
    }

    final File? file = photoRef.isNotEmpty && !photoRef.startsWith('placeholder://')
        ? File(photoRef)
        : null;
    final hasFile = file != null && file.existsSync();

    final row = index ~/ 4;
    final col = index % 4;

    // Alignment parameters mapped from [0, 3] to [-1.0, 1.0]
    final alignment = Alignment(
      -1.0 + (col * 2.0 / 3.0),
      -1.0 + (row * 2.0 / 3.0),
    );

    return ClipRect(
      child: Align(
        alignment: alignment,
        widthFactor: 0.25,
        heightFactor: 0.25,
        child: hasFile
            ? Image.file(file, fit: BoxFit.cover)
            : Container(
                color: kMedicalAccent.withValues(alpha: 0.15),
                child: const Center(
                  child: Icon(Icons.image_rounded, size: 14, color: kMedicalAccent),
                ),
              ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
