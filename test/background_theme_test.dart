import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:next_ddl/app/theme.dart';
import 'package:next_ddl/features/tasks/tasks_controller.dart';
import 'package:next_ddl/models/app_theme_settings.dart';

void main() {
  test(
    'background image provider cache reuses providers for the same path',
    () {
      final cache = BackgroundImageProviderCache();

      final first = cache.providerFor('C:/next_ddl/backgrounds/bg.png');
      final second = cache.providerFor('C:/next_ddl/backgrounds/bg.png');
      final third = cache.providerFor('C:/next_ddl/backgrounds/other.png');

      expect(identical(second, first), isTrue);
      expect(identical(third, first), isFalse);
    },
  );

  testWidgets('app shell keeps background layer stable while child changes', (
    tester,
  ) async {
    var initCount = 0;
    var buildCount = 0;
    final background = _ProbeBackground(
      onInit: () => initCount++,
      onBuild: () => buildCount++,
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: NextDdlAppShell(
          background: background,
          child: const Text('first page'),
        ),
      ),
    );

    expect(initCount, 1);
    expect(buildCount, 1);
    expect(find.text('first page'), findsOneWidget);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: NextDdlAppShell(
          background: background,
          child: const Text('second page'),
        ),
      ),
    );

    expect(initCount, 1);
    expect(buildCount, 1);
    expect(find.text('first page'), findsNothing);
    expect(find.text('second page'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'Android wallpaper pixels remain unchanged throughout push and system pop ($brightness)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(240, 400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final directory = await tester.runAsync(_createWallpaper);
        addTearDown(() => directory!.delete(recursive: true));
        final wallpaper = File('${directory!.path}/wallpaper.png');
        await tester.runAsync(() async {
          final loaded = Completer<void>();
          final stream = FileImage(wallpaper).resolve(ImageConfiguration.empty);
          final listener = ImageStreamListener((image, _) {
            image.dispose();
            loaded.complete();
          }, onError: loaded.completeError);
          stream.addListener(listener);
          try {
            await loaded.future;
          } finally {
            stream.removeListener(listener);
          }
        });
        final settings = AppThemeSettings(
          backgroundMode: ThemeBackgroundMode.image,
          backgroundImagePath: wallpaper.path,
          imageBlurSigma: 2,
          imageOverlayOpacity: 0.25,
        );
        final navigatorKey = GlobalKey<NavigatorState>();
        final captureKey = GlobalKey();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [themeSettingsProvider.overrideWithValue(settings)],
            child: MaterialApp(
              navigatorKey: navigatorKey,
              theme: buildNextDdlTheme(
                brightness: brightness,
                settings: settings,
              ).copyWith(platform: TargetPlatform.android),
              builder: (context, child) => RepaintBoundary(
                key: captureKey,
                child: NextDdlAppShell(child: child!),
              ),
              home: const _TransparentPage(title: 'Home'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final originalElement = tester.element(find.byType(Image));
        final originalImage = tester
            .widget<RawImage>(find.byType(RawImage))
            .image;
        expect(originalImage, isNotNull);
        final baseline = await _wallpaperPixels(tester, captureKey);
        expect(baseline.toSet().length, greaterThan(1));
        expect(find.byType(Navigator), findsOneWidget);

        Future<void> verifyTransition(String action) async {
          await tester.pump();
          // Inspect intermediate frames: settle-only checks miss the opaque
          // transition surface that disappears when the animation completes.
          for (var frame = 0; frame < 30; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(
              await _wallpaperPixels(tester, captureKey),
              baseline,
              reason: '$action frame $frame must not cover or move wallpaper',
            );
            expect(tester.element(find.byType(Image)), same(originalElement));
            expect(
              tester.widget<RawImage>(find.byType(RawImage)).image,
              same(originalImage),
            );
          }
          await tester.pumpAndSettle();
        }

        for (final title in ['Settings', 'Theme']) {
          navigatorKey.currentState!.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => _TransparentPage(title: title),
            ),
          );
          await verifyTransition('push $title');
          expect(find.text(title), findsOneWidget);
        }
        for (final title in ['Settings', 'Home']) {
          await tester.binding.handlePopRoute();
          await verifyTransition('system back to $title');
          expect(find.text(title), findsOneWidget);
        }
        expect(navigatorKey.currentState!.canPop(), isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await FileImage(wallpaper).evict();
      },
    );
  }
}

Future<Directory> _createWallpaper() async {
  final directory = await Directory.systemTemp.createTemp(
    'next_ddl_wallpaper_',
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  for (var x = 0; x < 24; x++) {
    for (var y = 0; y < 40; y++) {
      canvas.drawRect(
        Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
        Paint()..color = Color.fromARGB(255, 30 + x * 8, 20 + y * 5, 180),
      );
    }
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(24, 40);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '${directory.path}/wallpaper.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
  } finally {
    image.dispose();
    picture.dispose();
  }
  return directory;
}

Future<List<int>> _wallpaperPixels(WidgetTester tester, GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData();
      return [
        for (final y in [180, 280, 360])
          for (final x in [20, 120, 220])
            bytes!.getUint32((y * image.width + x) * 4),
      ];
    } finally {
      image.dispose();
    }
  }))!;
}

class _TransparentPage extends StatelessWidget {
  const _TransparentPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const SizedBox.expand(),
    );
  }
}

class _ProbeBackground extends StatefulWidget {
  const _ProbeBackground({required this.onInit, required this.onBuild});

  final VoidCallback onInit;
  final VoidCallback onBuild;

  @override
  State<_ProbeBackground> createState() => _ProbeBackgroundState();
}

class _ProbeBackgroundState extends State<_ProbeBackground> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    return const SizedBox.expand();
  }
}
