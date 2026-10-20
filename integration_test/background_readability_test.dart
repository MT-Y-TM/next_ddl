import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kyant_glass/kyant_glass.dart';
import 'package:next_ddl/app/background_readability.dart';
import 'package:next_ddl/app/liquid_glass_input.dart';
import 'package:next_ddl/app/theme.dart';
import 'package:next_ddl/features/tasks/tasks_controller.dart';
import 'package:next_ddl/features/settings/widgets/liquid_glass_controls.dart';
import 'package:next_ddl/l10n/app_localizations.dart';
import 'package:next_ddl/models/app_theme_settings.dart';
import 'package:next_ddl/models/liquid_glass_settings.dart';
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
    await tester.pumpWidget(const SizedBox.shrink());
    await FileImage(file).evict();
  });

  testWidgets(
    'device renders glass inputs, typing and native back navigation',
    (tester) async {
      await KyantGlass.precache();
      final settings = ValueNotifier(const AppThemeSettings(cornerRadius: 24));
      final scroll = ScrollController();
      var saves = 0;
      final controller = TextEditingController(text: 'Next DDL');
      final navigator = GlobalKey<NavigatorState>();
      addTearDown(settings.dispose);
      addTearDown(scroll.dispose);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder(
          valueListenable: settings,
          builder: (_, value, _) => MaterialApp(
            navigatorKey: navigator,
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: buildNextDdlTheme(settings: value),
            builder: (_, child) => NextDdlAppShell(
              background: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF182D58),
                      Color(0xFF76B8BD),
                      Color(0xFFD3B780),
                    ],
                  ),
                ),
              ),
              child: child!,
            ),
            home: Scaffold(
              appBar: AppBar(title: const Text('Next DDL')),
              body: ListView(
                controller: scroll,
                padding: const EdgeInsets.all(24),
                children: [
                  const WallpaperText('Liquid glass inputs'),
                  const SizedBox(height: 24),
                  LiquidGlassInput(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'Task title',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const LiquidGlassInput(
                    child: TextField(
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Plan the next milestone',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Cards keep their original colors'),
                    ),
                  ),
                  if (value.liquidGlassInputsEnabled)
                    LiquidGlassControls(
                      settings: value,
                      enabled: true,
                      onSave: (parameter, amount) async {
                        saves++;
                        settings.value = settings.value.copyWith(
                          liquidGlassSettings: settings
                              .value
                              .liquidGlassSettings
                              .withValue(parameter, amount),
                        );
                      },
                      onReset: () async {
                        settings.value = settings.value.copyWith(
                          liquidGlassSettings: const LiquidGlassSettings(),
                        );
                      },
                    ),
                  const SizedBox(height: 200),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(KyantGlass), findsNothing);
      settings.value = settings.value.copyWith(liquidGlassInputsEnabled: true);
      await tester.pumpAndSettle();
      expect(find.byType(KyantGlass), findsNWidgets(3));
      await tester.enterText(find.byType(TextField).first, 'Task planning 日本語');
      await tester.pumpAndSettle();
      expect(controller.text, 'Task planning 日本語');
      expect(KyantDiagnostics.explicitPaints, greaterThan(0));
      final source = KyantBackdropScope.maybeOf(
        tester.element(find.byType(TextField).first),
      )!;
      final revision = source.revision;
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const Scaffold(body: Center(child: WallpaperText('Second page'))),
        ),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(controller.text, 'Task planning 日本語');
      expect(source.revision, revision);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      for (final parameter in LiquidGlassParameter.values) {
        final slider = find.byKey(ValueKey('theme-glass-${parameter.name}'));
        await tester.ensureVisible(slider);
        await tester.pumpAndSettle();
        final before = settings.value.liquidGlassSettings.valueFor(
          parameter,
          dark: false,
        );
        await tester.drag(slider, const Offset(80, 0));
        await tester.pumpAndSettle();
        expect(
          settings.value.liquidGlassSettings.valueFor(parameter, dark: false),
          isNot(before),
        );
      }
      expect(saves, 6);
      final reset = find.byKey(const ValueKey('theme-glass-reset'));
      await tester.ensureVisible(reset);
      await tester.pumpAndSettle();
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(
        settings.value.liquidGlassSettings.toJson(),
        const LiquidGlassSettings().toJson(),
      );
      expect(source.revision, revision);
      await tester.ensureVisible(
        find.byKey(const ValueKey('theme-glass-preview')),
      );
      await tester.pumpAndSettle();
      for (final editable in tester.widgetList<EditableText>(
        find.byType(EditableText),
      )) {
        expect(editable.style.shadows ?? [], isEmpty);
      }
      expect(tester.takeException(), isNull);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      if (Platform.isAndroid) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('liquid-glass-controls');
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
