import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:next_ddl/app/background_readability.dart';
import 'package:next_ddl/app/theme.dart';
import 'package:next_ddl/features/tasks/tasks_controller.dart';
import 'package:next_ddl/models/app_theme_settings.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('device renderer adapts canvas text without recoloring surfaces', (
    tester,
  ) async {
    final settings = ValueNotifier(
      const AppThemeSettings(solidBackgroundColorValue: 0xFF050505),
    );
    addTearDown(settings.dispose);
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/readability-smoke-${DateTime.now().microsecondsSinceEpoch}.png',
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.white, BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(64, 64);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
      picture.dispose();
    }
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });
    await tester.pumpWidget(
      ValueListenableBuilder(
        valueListenable: settings,
        builder: (_, value, _) => ProviderScope(
          overrides: [themeSettingsProvider.overrideWithValue(value)],
          child: MaterialApp(
            theme: buildNextDdlTheme(),
            builder: (_, child) => NextDdlAppShell(child: child!),
            home: const Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('surface'),
                      ),
                    ),
                    WallpaperText('Adaptive background text'),
                    WallpaperRegion(
                      child: ListTile(
                        title: Text('Timeline'),
                        subtitle: Text('Deadline time'),
                        leading: Icon(Icons.event),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    TextStyle style(String text) => tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere((widget) => widget.text.toPlainText() == text)
        .text
        .style!;
    Future<void> verify(Color foreground) async {
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        if (style('Adaptive background text').color == foreground &&
            style('Timeline').color == foreground) {
          break;
        }
      }
      expect(style('Adaptive background text').color, foreground);
      expect(style('Timeline').color, foreground);
      expect(style('Deadline time').color, foreground);
      expect(style('surface').color, buildNextDdlTheme().colorScheme.onSurface);
      expect(tester.takeException(), isNull);
    }

    await verify(Colors.white);
    settings.value = settings.value.copyWith(
      solidBackgroundColorValue: 0xFFFFFFFF,
    );
    await verify(Colors.black);
    settings.value = settings.value.copyWith(
      backgroundMode: ThemeBackgroundMode.gradient,
      gradientStartColorValue: 0xFF111122,
      gradientEndColorValue: 0xFF222244,
    );
    await verify(Colors.white);
    settings.value = settings.value.copyWith(
      backgroundMode: ThemeBackgroundMode.image,
      backgroundImagePath: file.path,
      imageOverlayOpacity: 0,
      imageBlurSigma: 3,
    );
    await verify(Colors.black);
    settings.value = settings.value.copyWith(imageOverlayOpacity: 0.85);
    await verify(Colors.white);
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('background-readability-device');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await FileImage(file).evict();
  });
}
