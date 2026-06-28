import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_ddl/features/tasks/task_list_page.dart';
import 'package:next_ddl/features/tasks/tasks_controller.dart';
import 'package:next_ddl/app/theme.dart';
import 'package:next_ddl/l10n/app_localizations.dart';
import 'package:next_ddl/models/app_snapshot.dart';
import 'package:next_ddl/services/deadline_repository.dart';
import 'package:next_ddl/services/timezone_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

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

  testWidgets('app shell keeps background layer stable while pages change', (
    tester,
  ) async {
    var initCount = 0;
    var buildCount = 0;
    final navigatorKey = GlobalKey<NavigatorState>();
    final background = _ProbeBackground(
      onInit: () => initCount++,
      onBuild: () => buildCount++,
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: NextDdlAppShell(
          background: background,
          pageNavigatorKey: navigatorKey,
          initialPageBuilder: (_) => const Text('first page'),
        ),
      ),
    );

    expect(initCount, 1);
    expect(buildCount, 1);
    expect(find.text('first page'), findsOneWidget);

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Text('second page'),
      ),
    );
    await tester.pumpAndSettle();

    expect(initCount, 1);
    expect(buildCount, 1);
    expect(find.text('first page'), findsNothing);
    expect(find.text('second page'), findsOneWidget);
  });

  testWidgets('app shell owns a nested navigator above the background', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deadlineRepositoryProvider.overrideWithValue(
            _MemoryRepository(AppSnapshot.empty()),
          ),
          timezoneServiceProvider.overrideWithValue(_FakeTimezoneService()),
          nowProvider.overrideWith((ref) => Stream.value(DateTime.utc(2026))),
        ],
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: NextDdlAppShell(
            background: const SizedBox.expand(),
            pageNavigatorKey: GlobalKey<NavigatorState>(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TaskListPage), findsOneWidget);
    expect(find.byType(Navigator), findsNWidgets(2));
  });
}

class _FakeTimezoneService extends DeviceTimezoneService {
  @override
  String get currentTimezoneId => 'Asia/Shanghai';

  @override
  tz.Location get location => tz.getLocation(currentTimezoneId);

  @override
  List<String> get timezoneIds => const ['Asia/Shanghai'];

  @override
  Future<void> initialize() async {}

  @override
  DateTime localToUtc(DateTime value) => value.toUtc();

  @override
  DateTime utcToConfigured(DateTime value) => value.toUtc();

  @override
  Future<bool> setTimezone(String timezoneId) async => timezoneIds.contains(timezoneId);
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

class _MemoryRepository implements DeadlineRepository {
  _MemoryRepository(this.snapshot);

  final AppSnapshot snapshot;

  @override
  Future<String?> exportSnapshot(AppSnapshot snapshot) async => null;

  @override
  Future<AppSnapshot?> importSnapshot() async => null;

  @override
  Future<AppSnapshot> loadSnapshot() async => snapshot;

  @override
  Future<void> saveSnapshot(AppSnapshot snapshot) async {}
}
