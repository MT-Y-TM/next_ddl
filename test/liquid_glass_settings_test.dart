import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyant_glass/kyant_glass.dart';
import 'package:next_ddl/app/liquid_glass_input.dart';
import 'package:next_ddl/app/theme.dart';
import 'package:next_ddl/models/app_snapshot.dart';
import 'package:next_ddl/models/app_theme_settings.dart';
import 'package:next_ddl/models/liquid_glass_settings.dart';

void main() {
  test('old themes retain the original six glass defaults', () {
    final theme = AppThemeSettings.fromJson({'liquidGlassInputsEnabled': true});
    final p = theme.liquidGlassSettings;
    expect(theme.liquidGlassInputsEnabled, isTrue);
    expect(p.blur, 6);
    expect(p.refractionHeight, 10);
    expect(p.refractionAmount, 5);
    expect(p.dispersion, 0.08);
    expect(p.highlight, 0.45);
    expect(p.opacity(dark: false), 0.58);
    expect(p.opacity(dark: true), 0.72);
  });

  test(
    'all parameters round-trip through snapshots without losing wallpaper',
    () {
      final p = const LiquidGlassSettings(
        blur: 12.5,
        refractionHeight: 25,
        refractionAmount: 18,
        dispersion: 0.61,
        tintOpacity: 0.4,
        highlight: 0.85,
      );
      final snapshot = AppSnapshot.empty().copyWith(
        themeSettings: AppThemeSettings(
          liquidGlassInputsEnabled: true,
          liquidGlassSettings: p,
          backgroundImagePath: 'my-wallpaper.png',
          cornerRadius: 28,
        ),
      );
      final stored = AppSnapshot.fromJson(
        jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>,
      );
      expect(stored.themeSettings.liquidGlassSettings.toJson(), p.toJson());
      expect(stored.themeSettings.backgroundImagePath, 'my-wallpaper.png');
      expect(
        stored.themeSettings
            .copyWith(liquidGlassInputsEnabled: false)
            .liquidGlassSettings
            .toJson(),
        p.toJson(),
      );
      final reset = stored.themeSettings.copyWith(
        liquidGlassSettings: const LiquidGlassSettings(),
      );
      expect(reset.cornerRadius, 28);
      expect(reset.backgroundImagePath, 'my-wallpaper.png');
      expect(reset.liquidGlassInputsEnabled, isTrue);
      expect(reset.liquidGlassSettings.tintOpacity, isNull);
    },
  );

  test('imports clamp all six ranges and recover non-finite values', () {
    final p = LiquidGlassSettings.fromJson({
      'blur': 999,
      'refractionHeight': -2,
      'refractionAmount': double.nan,
      'dispersion': -1,
      'tintOpacity': 3,
      'highlight': double.infinity,
    });
    expect(p.blur, 20);
    expect(p.refractionHeight, 0);
    expect(p.refractionAmount, 5);
    expect(p.dispersion, 0);
    expect(p.tintOpacity, 1);
    expect(p.highlight, 0.45);
    for (final parameter in LiquidGlassParameter.values) {
      final low = p.withValue(parameter, -100).valueFor(parameter, dark: false);
      final high = p.withValue(parameter, 100).valueFor(parameter, dark: false);
      expect(low, parameter.min);
      expect(high, parameter.max);
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('all six parameters reach the renderer ($brightness)', (
      tester,
    ) async {
      await tester.runAsync(KyantGlass.precache);
      final value = ValueNotifier(const LiquidGlassSettings());
      addTearDown(value.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder(
          valueListenable: value,
          builder: (_, p, _) => MaterialApp(
            theme: buildNextDdlTheme(
              brightness: brightness,
              settings: AppThemeSettings(
                liquidGlassInputsEnabled: true,
                liquidGlassSettings: p,
              ),
            ),
            builder: (_, child) => NextDdlAppShell(
              background: const ColoredBox(color: Colors.blue),
              child: child!,
            ),
            home: const Scaffold(body: LiquidGlassInput(child: TextField())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final source = KyantBackdropScope.maybeOf(
        tester.element(find.byType(TextField)),
      )!;
      final revision = source.revision;
      for (final p in [
        const LiquidGlassSettings(
          blur: 0,
          refractionHeight: 0,
          refractionAmount: 0,
          dispersion: 0,
          tintOpacity: 0,
          highlight: 0,
        ),
        const LiquidGlassSettings(
          blur: 20,
          refractionHeight: 40,
          refractionAmount: 30,
          dispersion: 1,
          tintOpacity: 1,
          highlight: 1,
        ),
        const LiquidGlassSettings(
          blur: 8,
          refractionHeight: 18,
          refractionAmount: 12,
          dispersion: 0.4,
          tintOpacity: 0.3,
          highlight: 0.7,
        ),
      ]) {
        value.value = p;
        await tester.pumpAndSettle();
        final glass = tester.widget<KyantGlass>(find.byType(KyantGlass));
        expect(glass.blur, p.blur);
        expect(glass.refractionHeight, p.refractionHeight);
        expect(glass.refractionAmount, p.refractionAmount);
        expect(glass.dispersion, p.dispersion);
        expect(glass.highlight, p.highlight);
        expect(glass.tint.a, closeTo(p.tintOpacity!, 0.001));
        expect(source.revision, revision);
        expect(
          tester
                  .widget<EditableText>(find.byType(EditableText))
                  .style
                  .shadows ??
              [],
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets(
    'transparent glass adapts text as a dark wallpaper changes tone',
    (tester) async {
      await tester.runAsync(KyantGlass.precache);
      final background = ValueNotifier<Color>(Colors.black);
      addTearDown(background.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder(
          valueListenable: background,
          builder: (_, color, _) => MaterialApp(
            theme: buildNextDdlTheme(
              settings: const AppThemeSettings(
                liquidGlassInputsEnabled: true,
                liquidGlassSettings: LiquidGlassSettings(tintOpacity: 0.22),
              ),
            ),
            builder: (_, child) => NextDdlAppShell(
              background: ColoredBox(color: color),
              child: child!,
            ),
            home: const Scaffold(body: LiquidGlassInput(child: TextField())),
          ),
        ),
      );
      Future<void> settleReadback() async {
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 80));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
      }

      await settleReadback();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).style.color,
        const Color(0xFFF4F7F8),
      );
      background.value = const Color(0xFF696969);
      await settleReadback();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).style.color,
        const Color(0xFF172028),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
