import 'package:flutter/material.dart';

const double kGlassBlurSigma = 24.0;
const double kGlassBackgroundOpacity = 0.16;
const Color kGlassBorderColor = Color(0x66FFFFFF);
const double kGlassBorderWidth = 1.2;
const double kGlassBorderRadius = 24.0;
const double kGlassShadowBlur = 24.0;

BoxDecoration glassDecoration({
  Color? color,
  double radius = kGlassBorderRadius,
}) {
  return BoxDecoration(
    color: color ?? const Color(0x33FFFFFF),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: kGlassBorderColor, width: kGlassBorderWidth),
    boxShadow: const [
      BoxShadow(color: Color(0x11000000), blurRadius: kGlassShadowBlur),
    ],
  );
}
