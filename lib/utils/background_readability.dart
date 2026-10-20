import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/painting.dart';

class BackgroundReadability {
  const BackgroundReadability({
    required this.dominantColor,
    required this.meanLuminance,
    required this.foreground,
    required this.readableFraction,
  });

  final Color dominantColor;
  final double meanLuminance;
  final Color foreground;
  final double readableFraction;

  factory BackgroundReadability.forColor(Color color) =>
      analyzeBackgroundPixels(
        Uint8List.fromList([
          color.r.mul255,
          color.g.mul255,
          color.b.mul255,
          color.a.mul255,
        ]),
      );
}

extension on double {
  int get mul255 => (this * 255).round().clamp(0, 255);
}

double backgroundContrastRatio(Color a, Color b) {
  final left = a.computeLuminance();
  final right = b.computeLuminance();
  return (math.max(left, right) + 0.05) / (math.min(left, right) + 0.05);
}

/// Analyze the final painted pixels, not the uncropped source photograph.
/// Coverage avoids treating a few bright highlights as a bright wallpaper.
BackgroundReadability analyzeBackgroundPixels(
  Uint8List rgba, {
  Color fallback = const Color(0xFFF4F7F8),
}) {
  final histogram = <int, List<int>>{};
  var whiteReadable = 0;
  var blackReadable = 0;
  var luminanceSum = 0.0;
  var count = 0;
  final fallbackR = fallback.r * 255;
  final fallbackG = fallback.g * 255;
  final fallbackB = fallback.b * 255;
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    final alpha = rgba[i + 3] / 255;
    final r = (rgba[i] * alpha + fallbackR * (1 - alpha)).round();
    final g = (rgba[i + 1] * alpha + fallbackG * (1 - alpha)).round();
    final b = (rgba[i + 2] * alpha + fallbackB * (1 - alpha)).round();
    final luminance =
        0.2126 * _linearRgb[r] +
        0.7152 * _linearRgb[g] +
        0.0722 * _linearRgb[b];
    if (1.05 / (luminance + 0.05) >= 4.5) whiteReadable++;
    if ((luminance + 0.05) / 0.05 >= 4.5) blackReadable++;
    luminanceSum += luminance;
    final bucket = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
    final bin = histogram.putIfAbsent(bucket, () => [0, 0, 0, 0]);
    bin[0]++;
    bin[1] += r;
    bin[2] += g;
    bin[3] += b;
    count++;
  }
  if (count == 0) return BackgroundReadability.forColor(fallback);
  final dominant = histogram.values.reduce((a, b) => a[0] >= b[0] ? a : b);
  final mean = luminanceSum / count;
  final white = whiteReadable == blackReadable
      ? 1.05 / (mean + 0.05) >= (mean + 0.05) / 0.05
      : whiteReadable > blackReadable;
  return BackgroundReadability(
    dominantColor: Color.fromARGB(
      255,
      dominant[1] ~/ dominant[0],
      dominant[2] ~/ dominant[0],
      dominant[3] ~/ dominant[0],
    ),
    meanLuminance: mean,
    foreground: white ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
    readableFraction: (white ? whiteReadable : blackReadable) / count,
  );
}

final _linearRgb = List<double>.generate(256, (byte) {
  final channel = byte / 255;
  return channel <= 0.04045
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}, growable: false);
