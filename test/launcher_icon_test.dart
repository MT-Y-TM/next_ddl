import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'launcher source is square and generated Android icons have no side bars',
    () async {
      final source = ByteData.sublistView(
        File('asset/launcher_icon.png').readAsBytesSync(),
      );
      expect(source.getUint32(16), source.getUint32(20));
      for (final entry in {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      }.entries) {
        final bytes = File(
          'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
        ).readAsBytesSync();
        final png = ByteData.sublistView(bytes);
        expect(png.getUint32(16), entry.value);
        expect(png.getUint32(20), entry.value);
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final pixels = (await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        for (final x in [2, entry.value - 3]) {
          final offset = ((entry.value - 3) * entry.value + x) * 4;
          expect(pixels.getUint8(offset + 3), 255);
          expect(
            [
              pixels.getUint8(offset),
              pixels.getUint8(offset + 1),
              pixels.getUint8(offset + 2),
            ],
            isNot(equals([255, 255, 255])),
            reason:
                'Artwork must fill both lower side edges, not be letterboxed.',
          );
        }
        frame.image.dispose();
        codec.dispose();
      }
    },
  );

  test('Windows icon contains all seven generated square PNG frames', () {
    final bytes = File(
      'windows/runner/resources/app_icon.ico',
    ).readAsBytesSync();
    final ico = ByteData.sublistView(bytes);
    expect(ico.getUint16(0, Endian.little), 0);
    expect(ico.getUint16(2, Endian.little), 1);
    expect(ico.getUint16(4, Endian.little), 7);
    const sizes = [16, 24, 32, 48, 64, 128, 256];
    for (var i = 0; i < sizes.length; i++) {
      final entry = 6 + i * 16;
      expect(ico.getUint8(entry), sizes[i] % 256);
      expect(ico.getUint8(entry + 1), sizes[i] % 256);
      final length = ico.getUint32(entry + 8, Endian.little);
      final offset = ico.getUint32(entry + 12, Endian.little);
      expect(offset + length, lessThanOrEqualTo(bytes.length));
      expect(bytes.sublist(offset, offset + 8), [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ]);
      final png = ByteData.sublistView(bytes, offset, offset + length);
      expect(png.getUint32(16), sizes[i]);
      expect(png.getUint32(20), sizes[i]);
    }
  });
}
