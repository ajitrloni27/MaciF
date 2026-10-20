import 'package:flutter/material.dart';

/// A soft, glass-consistent divider with horizontal fades on the edges,
/// matching the overall glass UI language.
class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key, this.verticalMargin = 16.0});

  final double verticalMargin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.symmetric(vertical: verticalMargin),
      height: 1,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isDark ? Colors.white.withValues(alpha: 0.0) : Colors.black.withValues(alpha: 0.0),
            isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
            isDark ? Colors.white.withValues(alpha: 0.0) : Colors.black.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}
