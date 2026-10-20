import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

Future<void> showNfcScanDialog(BuildContext context) {
  return showDialog(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.nfc_rounded, size: 44)
                    .animate(onPlay: (controller) => controller.repeat())
                    .scale(
                      begin: const Offset(0.95, 0.95),
                      end: const Offset(1.04, 1.04),
                      duration: 900.ms,
                    )
                    .then()
                    .fadeIn(duration: 220.ms),
              ),
              const SizedBox(height: 18),
              Text(
                'Bring the card close',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Hold the device near the patient tag until the record is captured.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
