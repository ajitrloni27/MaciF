import 'package:flutter/material.dart';

class AnimatedPageWrapper extends StatelessWidget {
  const AnimatedPageWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
