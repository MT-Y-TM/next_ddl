import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:next_ddl/app/background_readability.dart';
import 'package:next_ddl/app/theme.dart';
import 'package:next_ddl/features/tasks/task_detail_page.dart';
import 'package:next_ddl/features/tasks/task_edit_page.dart';
import 'package:next_ddl/features/tasks/tasks_controller.dart';
import 'package:next_ddl/l10n/app_localizations.dart';
import 'package:next_ddl/models/app_snapshot.dart';
import 'package:next_ddl/models/app_theme_settings.dart';
import 'package:next_ddl/models/deadline_task.dart';
import 'package:next_ddl/models/milestone.dart';
import 'package:next_ddl/services/timezone_service.dart';
import 'package:next_ddl/utils/background_readability.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all gray shades select the greater WCAG contrast', () {
    for (var gray = 0; gray <= 255; gray++) {
      final color = Color.fromARGB(255, gray, gray, gray);
      final result = BackgroundReadability.forColor(color);
      final contrast = backgroundContrastRatio(color, result.foreground);
      expect(contrast, greaterThanOrEqualTo(4.5));
      expect(
        contrast,
        greaterThanOrEqualTo(
          backgroundContrastRatio(
            color,
            result.foreground == Colors.white ? Colors.black : Colors.white,
          ),
        ),
      );
    }
  });

  test('luminance respects color channels rather than RGB average', () {
    expect(
      BackgroundReadability.forColor(const Color(0xFF0000FF)).foreground,
      Colors.white,
    );
    expect(
      BackgroundReadability.forColor(Colors.yellow).foreground,
      Colors.black,
    );
    expect(BackgroundReadability.forColor(Colors.red).foreground, Colors.black);
  });

  test(
    'dominant area wins over a bright highlight without text decoration',
    () {
      final pixels = Uint8List.fromList([
        for (var i = 0; i < 70; i++) ...[16, 16, 16, 255],
        for (var i = 0; i < 30; i++) ...[255, 255, 255, 255],
      ]);
      final result = analyzeBackgroundPixels(pixels);
      expect(result.foreground, Colors.white);
      expect(result.dominantColor, const Color(0xFF101010));
      expect(result.readableFraction, 0.7);
    },
  );

  test('empty and transparent samples have a stable composited fallback', () {
    expect(analyzeBackgroundPixels(Uint8List(0)).foreground, Colors.black);
    expect(
      analyzeBackgroundPixels(Uint8List.fromList([0, 0, 0, 0])).foreground,
      Colors.black,
    );
    expect(
      analyzeBackgroundPixels(
        Uint8List.fromList([255, 255, 255, 0]),
        fallback: Colors.black,
      ).foreground,
      Colors.white,
    );
    expect(
      analyzeBackgroundPixels(
        Uint8List.fromList([0, 0, 0, 128]),
        fallback: Colors.white,
      ).dominantColor,
      const Color(0xFF7F7F7F),
    );
  });

  for (final brightness in Brightness.values) {
    for (final background in [Colors.black, Colors.white]) {
      testWidgets(
        'samples only wallpaper, keeping card and toolbar colors ($brightness, $background)',
        (tester) async {
          final base = buildNextDdlTheme(brightness: brightness);
          await tester.pumpWidget(
            MaterialApp(
              theme: base,
              builder: (_, child) => NextDdlAppShell(
                background: ColoredBox(color: background),
                child: child!,
              ),
              home: Scaffold(
                appBar: AppBar(title: const Text('toolbar')),
                body: const Column(
                  children: [
                    Card(
                      child: SizedBox(
                        height: 220,
                        width: double.infinity,
                        child: Text('card'),
                      ),
                    ),
                    WallpaperText('canvas'),
                    WallpaperRegion(
                      child: ListTile(
                        title: Text('timeline'),
                        subtitle: Text('date'),
                        leading: Icon(Icons.event),
                      ),
                    ),
                    WallpaperRegion(
                      child: TextField(
                        decoration: InputDecoration(labelText: 'input'),
                      ),
                    ),
                    Chip(label: Text('chip')),
                  ],
                ),
              ),
            ),
          );
          await _readback(tester);
          final expected = background == Colors.black
              ? Colors.white
              : Colors.black;
          expect(_style(tester, 'canvas').color, expected);
          expect(_style(tester, 'timeline').color, expected);
          expect(_style(tester, 'date').color, expected);
          expect(_style(tester, 'card').color, base.colorScheme.onSurface);
          expect(_style(tester, 'toolbar').color, base.colorScheme.onSurface);
          final input = tester.widget<EditableText>(find.byType(EditableText));
          expect(input.style.color, expected);
          final cardContext = tester.element(find.text('card'));
          expect(Theme.of(cardContext).colorScheme, base.colorScheme);
          expect(
            Theme.of(tester.element(find.text('chip'))).colorScheme,
            base.colorScheme,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('pure and gradient backgrounds are analyzed after painting', (
    tester,
  ) async {
    final settings = ValueNotifier(
      const AppThemeSettings(solidBackgroundColorValue: 0xFF050505),
    );
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder(
        valueListenable: settings,
        builder: (_, value, _) => ProviderScope(
          overrides: [themeSettingsProvider.overrideWithValue(value)],
          child: MaterialApp(
            theme: buildNextDdlTheme(),
            builder: (_, child) => NextDdlAppShell(child: child!),
            home: const Scaffold(body: WallpaperText('label')),
          ),
        ),
      ),
    );
    await _readback(tester);
    expect(_style(tester, 'label').color, Colors.white);
    settings.value = settings.value.copyWith(
      backgroundMode: ThemeBackgroundMode.gradient,
      gradientStartColorValue: 0xFFFFFFFF,
      gradientEndColorValue: 0xFFF8FFFF,
    );
    await tester.pump();
    await _readback(tester);
    expect(_style(tester, 'label').color, Colors.black);
  });

  testWidgets(
    'image crop, zoom, rotation and overlay drive final visible contrast',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(200, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final file = await tester.runAsync(_wallpaper);
      await tester.runAsync(() => _preload(file!));
      addTearDown(() async {
        await FileImage(file!).evict();
        await file.delete();
        await file.parent.delete();
      });
      final settings = ValueNotifier(
        AppThemeSettings(
          backgroundMode: ThemeBackgroundMode.image,
          backgroundImagePath: file!.path,
          imageScale: 2,
          imageOffsetX: 1,
          imageOverlayOpacity: 0,
        ),
      );
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder(
          valueListenable: settings,
          builder: (_, value, _) => ProviderScope(
            overrides: [themeSettingsProvider.overrideWithValue(value)],
            child: MaterialApp(
              theme: buildNextDdlTheme(),
              builder: (_, child) => NextDdlAppShell(child: child!),
              home: const Scaffold(body: WallpaperText('cropped')),
            ),
          ),
        ),
      );
      await _readback(tester);
      expect(_style(tester, 'cropped').color, Colors.white);
      final originalImage = tester.element(find.byType(Image));
      settings.value = settings.value.copyWith(imageOffsetX: -1);
      await tester.pump();
      await _readback(tester);
      expect(_style(tester, 'cropped').color, Colors.black);
      expect(tester.element(find.byType(Image)), same(originalImage));
      settings.value = settings.value.copyWith(
        imageRotationDegrees: 180,
        imageBlurSigma: 4,
      );
      await tester.pump();
      await _readback(tester);
      expect(_style(tester, 'cropped').color, Colors.white);
      settings.value = settings.value.copyWith(imageOffsetX: 1);
      await tester.pump();
      await _readback(tester);
      expect(_style(tester, 'cropped').color, Colors.black);
      settings.value = settings.value.copyWith(imageOverlayOpacity: 0.85);
      await tester.pump();
      await _readback(tester);
      expect(_style(tester, 'cropped').color, Colors.white);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('mixed painted wallpaper keeps text free of outlines and halos', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildNextDdlTheme(),
        builder: (_, child) => NextDdlAppShell(
          background: CustomPaint(painter: _MixedPainter()),
          child: child!,
        ),
        home: const Scaffold(
          body: Column(
            children: [
              WallpaperText('mixed'),
              Card(child: Text('surface')),
            ],
          ),
        ),
      ),
    );
    await _readback(tester);
    expect(_style(tester, 'mixed').shadows, isEmpty);
    expect(_style(tester, 'surface').shadows, isNull);
  });

  testWidgets(
    'navigation and foreground updates do not repaint/reanalyze the background',
    (tester) async {
      var paints = 0;
      final navigator = GlobalKey<NavigatorState>();
      final updates = ValueNotifier(0);
      addTearDown(updates.dispose);
      final background = CustomPaint(
        painter: _MixedPainter(onPaint: () => paints++),
      );
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: buildNextDdlTheme().copyWith(platform: TargetPlatform.android),
          builder: (_, child) =>
              NextDdlAppShell(background: background, child: child!),
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: updates,
              builder: (_, value, _) => WallpaperText('tick $value'),
            ),
          ),
        ),
      );
      await _readback(tester);
      final baseline = paints;
      for (var i = 1; i <= 3; i++) {
        updates.value = i;
        await tester.pump();
      }
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: WallpaperText('page')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(paints, baseline);
      expect(find.text('tick 3'), findsOneWidget);
    },
  );

  testWidgets(
    'editor fields and section headings adapt while chips and cards retain surface colors',
    (tester) async {
      final now = DateTime.utc(2040);
      final task = DeadlineTask(
        id: 'edit',
        title: 'editable title',
        note: '',
        timezoneId: 'UTC',
        tags: const ['tag'],
        createdAtUtc: now,
        updatedAtUtc: now,
        finalDueAtUtc: now.add(const Duration(days: 3)),
        milestones: const [],
        reminderOffsetsSeconds: const [0],
        notificationsEnabled: false,
      );
      final base = buildNextDdlTheme();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tasksControllerProvider.overrideWith(() => _Tasks(task)),
            timezoneServiceProvider.overrideWithValue(_Utc()),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: base,
            builder: (_, child) => NextDdlAppShell(
              background: const ColoredBox(color: Colors.black),
              child: child!,
            ),
            home: TaskEditPage(existingTask: task),
          ),
        ),
      );
      await _readback(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(TaskEditPage)),
      )!;
      for (final field in tester.widgetList<EditableText>(
        find.byType(EditableText),
      )) {
        expect(field.style.color, Colors.white);
        expect(field.cursorColor, Colors.white);
      }
      expect(_style(tester, 'tag').color, isNot(Colors.white));
      await tester.scrollUntilVisible(
        find.text(l10n.milestones),
        180,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(_style(tester, l10n.milestones).color, Colors.white);
      expect(
        _style(tester, l10n.noMilestones).color,
        base.colorScheme.onSurface,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in ['zh', 'en', 'ja']) {
    testWidgets('real task details adapt timeline, not the card ($locale)', (
      tester,
    ) async {
      final now = DateTime.utc(2040);
      final task = DeadlineTask(
        id: 'readable',
        title: 'card title',
        note: '',
        timezoneId: 'UTC',
        createdAtUtc: now,
        updatedAtUtc: now,
        finalDueAtUtc: now.add(const Duration(days: 3)),
        milestones: [
          Milestone(
            id: 'node',
            title: 'node',
            dueAtUtc: now.add(const Duration(days: 1)),
            source: MilestoneSource.manual,
          ),
        ],
        reminderOffsetsSeconds: const [0],
        notificationsEnabled: false,
      );
      final base = buildNextDdlTheme();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tasksControllerProvider.overrideWith(() => _Tasks(task)),
            timezoneServiceProvider.overrideWithValue(_Utc()),
            nowProvider.overrideWith((_) => Stream.value(now)),
          ],
          child: MaterialApp(
            locale: Locale(locale),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: base,
            builder: (_, child) => NextDdlAppShell(
              background: const ColoredBox(color: Colors.black),
              child: child!,
            ),
            home: const TaskDetailPage(taskId: 'readable'),
          ),
        ),
      );
      await _readback(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(TaskDetailPage)),
      )!;
      expect(_style(tester, l10n.timeline).color, Colors.white);
      expect(_style(tester, 'node').color, Colors.white);
      expect(_style(tester, 'card title').color, base.colorScheme.onSurface);
      await tester.scrollUntilVisible(find.text(l10n.reminderRules), 180);
      expect(_style(tester, l10n.reminderRules).color, Colors.white);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _readback(WidgetTester tester) async {
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 80));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
  }
  await tester.pump();
}

TextStyle _style(WidgetTester tester, String text) => tester
    .widgetList<RichText>(find.byType(RichText))
    .firstWhere((widget) => widget.text.toPlainText() == text)
    .text
    .style!;

class _MixedPainter extends CustomPainter {
  _MixedPainter({this.onPaint});
  final VoidCallback? onPaint;
  @override
  void paint(Canvas canvas, Size size) {
    onPaint?.call();
    canvas.drawColor(Colors.black, BlendMode.src);
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_MixedPainter oldDelegate) => false;
}

Future<File> _wallpaper() async {
  final directory = await Directory.systemTemp.createTemp(
    'next_ddl_readability_',
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(Colors.black, BlendMode.src);
  canvas.drawRect(
    const Rect.fromLTWH(100, 0, 100, 100),
    Paint()..color = Colors.white,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(200, 100);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return await File(
      '${directory.path}/source.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Future<void> _preload(File file) async {
  final ready = Completer<void>();
  final stream = FileImage(file).resolve(ImageConfiguration.empty);
  final listener = ImageStreamListener((image, _) {
    image.dispose();
    ready.complete();
  }, onError: ready.completeError);
  stream.addListener(listener);
  try {
    await ready.future;
  } finally {
    stream.removeListener(listener);
  }
}

class _Tasks extends TasksController {
  _Tasks(this.task);
  final DeadlineTask task;
  @override
  Future<AppSnapshot> build() async =>
      AppSnapshot.empty().copyWith(tasks: [task]);
  @override
  String get timezoneId => 'UTC';
}

class _Utc extends DeviceTimezoneService {
  @override
  String get currentTimezoneId => 'UTC';
  @override
  tz.Location get location => tz.UTC;
  @override
  DateTime utcToConfigured(DateTime value) => value.toUtc();
}
