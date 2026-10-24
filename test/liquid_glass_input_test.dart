import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyant_glass/kyant_glass.dart';
import 'package:next_ddl/app/liquid_glass_input.dart';
import 'package:next_ddl/app/theme.dart';
import 'package:next_ddl/models/app_theme_settings.dart';

void main() {
  test(
    'glass preference defaults off, round-trips, and survives other edits',
    () {
      expect(AppThemeSettings.fromJson({}).liquidGlassInputsEnabled, isFalse);
      final theme = AppThemeSettings.fromJson(
        const AppThemeSettings(
          liquidGlassInputsEnabled: true,
          backgroundImagePath: 'wallpaper.png',
        ).toJson(),
      ).copyWith(cornerRadius: 28);
      expect(theme.liquidGlassInputsEnabled, isTrue);
      expect(theme.backgroundImagePath, 'wallpaper.png');
      expect(theme.cornerRadius, 28);
      expect(
        theme
            .copyWith(liquidGlassInputsEnabled: false)
            .liquidGlassInputsEnabled,
        isFalse,
      );
    },
  );

  testWidgets('disabled inputs remain ordinary text fields', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildNextDdlTheme(),
        home: const Scaffold(body: LiquidGlassInput(child: TextField())),
      ),
    );
    expect(find.byType(KyantGlass), findsNothing);
    await tester.enterText(find.byType(TextField), 'Paste 普通入力');
    expect(find.text('Paste 普通入力'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'enabled glass renders shaders and keeps input and back navigation intact',
    (tester) async {
      await tester.runAsync(KyantGlass.precache);
      final enabled = ValueNotifier(false);
      final text = TextEditingController(text: 'Original');
      final navigator = GlobalKey<NavigatorState>();
      addTearDown(enabled.dispose);
      addTearDown(text.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder(
          valueListenable: enabled,
          builder: (_, value, _) => MaterialApp(
            navigatorKey: navigator,
            theme: buildNextDdlTheme(
              settings: AppThemeSettings(
                liquidGlassInputsEnabled: value,
                cornerRadius: 24,
              ),
            ),
            builder: (_, child) => NextDdlAppShell(
              background: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.orange],
                  ),
                ),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: LiquidGlassInput(
                child: TextField(
                  controller: text,
                  decoration: const InputDecoration(labelText: 'Task title'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final backdrop = KyantBackdropScope.maybeOf(
        tester.element(find.byType(TextField)),
      )!;
      expect(backdrop.image, isNull);
      enabled.value = true;
      await tester.pumpAndSettle();
      expect(find.byType(KyantGlass), findsOneWidget);
      final glassRect = tester.getRect(find.byType(KyantGlass));
      final labelRect = tester.getRect(find.text('Task title').last);
      expect(labelRect.top, greaterThanOrEqualTo(glassRect.top + 2));
      expect(labelRect.bottom, lessThan(glassRect.bottom));
      expect(backdrop.image, isNotNull);
      expect(tester.widget<KyantGlass>(find.byType(KyantGlass)).radius, 24);
      final revision = backdrop.revision;
      await tester.enterText(find.byType(TextField), 'Updated 日本語');
      await tester.pumpAndSettle();
      expect(text.text, 'Updated 日本語');
      expect(backdrop.revision, greaterThanOrEqualTo(revision));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      final beforeRefocus = backdrop.revision;
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(backdrop.revision, greaterThan(beforeRefocus));
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            body: LiquidGlassInput(
              child: TextField(
                decoration: InputDecoration(labelText: 'Next page'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Next page'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Updated 日本語'), findsOneWidget);
      enabled.value = false;
      await tester.pumpAndSettle();
      expect(find.byType(KyantGlass), findsNothing);
      expect(text.text, 'Updated 日本語');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'scrolling updates glass geometry without recapturing the wallpaper',
    (tester) async {
      await tester.runAsync(KyantGlass.precache);
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildNextDdlTheme(
            settings: const AppThemeSettings(liquidGlassInputsEnabled: true),
          ),
          builder: (_, child) => NextDdlAppShell(
            background: const ColoredBox(color: Colors.blue),
            child: child!,
          ),
          home: Scaffold(
            body: ListView(
              controller: scrollController,
              children: [
                const SizedBox(height: 120),
                LiquidGlassInput(child: const TextField()),
                const SizedBox(height: 500),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final backdrop = KyantBackdropScope.maybeOf(
        tester.element(find.byType(TextField)),
      )!;
      expect(backdrop.image, isNotNull);
      final revision = backdrop.revision;

      scrollController.jumpTo(40);
      await tester.pumpAndSettle();

      expect(backdrop.revision, revision);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
