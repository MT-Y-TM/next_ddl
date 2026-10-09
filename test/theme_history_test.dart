import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:next_ddl/models/app_theme_settings.dart';
import 'package:next_ddl/services/theme_asset_service.dart';

void main() {
  test(
    'recent backgrounds are bounded, unique and survive JSON round trips',
    () {
      var settings = const AppThemeSettings();
      for (var i = 0; i < 7; i++) {
        settings = settings
            .copyWith(
              backgroundMode: ThemeBackgroundMode.image,
              backgroundImagePath: 'image-$i.png',
              imageScale: 1 + i / 10,
              imageRotationDegrees: i * 12,
            )
            .rememberBackgroundsFrom(settings);
      }
      settings = AppThemeSettings.fromJson(
        jsonDecode(jsonEncode(settings.toJson())),
      );
      expect(settings.backgroundImageHistory.map((p) => p.path), [
        'image-6.png',
        'image-5.png',
        'image-4.png',
        'image-3.png',
        'image-2.png',
      ]);
      final restored = settings.backgroundImageHistory[2]
          .applyTo(
            settings.copyWith(cornerRadius: 29, seedColorValue: 0xFF123456),
          )
          .rememberBackgroundsFrom(settings);
      expect(restored.backgroundImagePath, 'image-4.png');
      expect(restored.imageScale, 1.4);
      expect(restored.imageRotationDegrees, 48);
      expect(restored.cornerRadius, 29);
      expect(restored.seedColorValue, 0xFF123456);
      expect(restored.backgroundImageHistory.first.path, 'image-4.png');
      expect(restored.backgroundImageHistory, hasLength(5));
    },
  );

  test(
    'old snapshots include current image without resetting its parameters',
    () {
      final settings = AppThemeSettings.fromJson({
        'backgroundMode': 'image',
        'backgroundImagePath': 'old.png',
        'imageRotationQuarterTurns': 1,
        'imageOverlayOpacity': 0.6,
        'imageBlurSigma': 3,
      });
      expect(settings.backgroundImageHistory.single.path, 'old.png');
      expect(
        settings.backgroundImageHistory.single.settings.imageRotationDegrees,
        90,
      );
      final restored = settings.backgroundImageHistory.single.applyTo(
        settings.copyWith(
          backgroundMode: ThemeBackgroundMode.solid,
          cornerRadius: 26,
        ),
      );
      expect(restored.imageOverlayOpacity, 0.6);
      expect(restored.imageBlurSigma, 3);
      expect(restored.cornerRadius, 26);
      expect(AppThemeSettings.fromJson(null).backgroundImageHistory, isEmpty);
    },
  );

  test(
    'picking a new image retains old asset; cancel only removes new draft',
    () async {
      final directory = await Directory.systemTemp.createTemp('theme-assets-');
      addTearDown(() => directory.delete(recursive: true));
      final source = await File(
        '${directory.path}/source.png',
      ).writeAsBytes([1, 2, 3]);
      final service = LocalThemeAssetService(
        supportDirectory: () async => directory,
        imagePicker: () async => source.path,
      );
      final first = (await service.pickAndCopyBackgroundImage())!;
      final second = (await service.pickAndCopyBackgroundImage(
        oldPath: first,
      ))!;
      expect(await File(first).exists(), isTrue);
      expect(await File(second).exists(), isTrue);
      await service.deleteBackgroundImage(second);
      expect(await File(first).readAsBytes(), [1, 2, 3]);
      expect(await File(second).exists(), isFalse);
      await service.deleteBackgroundImage(source.path);
      expect(await source.exists(), isTrue);
    },
  );
}
