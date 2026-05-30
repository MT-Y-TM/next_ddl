import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_ddl/app/app.dart';
import 'package:next_ddl/features/settings/settings_page.dart';
import 'package:next_ddl/features/tasks/task_edit_page.dart';
import 'package:next_ddl/features/tasks/task_list_page.dart';
import 'package:next_ddl/features/tasks/tasks_controller.dart';
import 'package:next_ddl/features/update/app_update_controller.dart';
import 'package:next_ddl/l10n/app_localizations.dart';
import 'package:next_ddl/models/app_snapshot.dart';
import 'package:next_ddl/models/deadline_task.dart';
import 'package:next_ddl/models/milestone.dart';
import 'package:next_ddl/models/update_release.dart';
import 'package:next_ddl/services/app_info_service.dart';
import 'package:next_ddl/services/app_update_service.dart';
import 'package:next_ddl/services/deadline_repository.dart';
import 'package:next_ddl/services/file_export_service.dart';
import 'package:next_ddl/services/notification_scheduler.dart';
import 'package:next_ddl/services/timezone_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  testWidgets('home page defaults to in-progress tab and separates overdue tasks', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 1, 1, 8);
    final snapshot = AppSnapshot(
      schemaVersion: 1,
      exportedAtUtc: now,
      persistentNotificationEnabled: false,
      preferredLocale: AppLocalePreference.zh,
      persistentNotificationTimeUnit: PersistentNotificationTimeUnit.day,
      tasks: [
        DeadlineTask(
          id: 'progress',
          title: '进行中任务',
          note: '',
          timezoneId: 'Asia/Shanghai',
          createdAtUtc: now,
          updatedAtUtc: now,
          finalDueAtUtc: now.add(const Duration(days: 2)),
          milestones: const [],
          reminderOffsetsSeconds: const [],
          notificationsEnabled: false,
        ),
        DeadlineTask(
          id: 'overdue',
          title: '过期任务',
          note: '',
          timezoneId: 'Asia/Shanghai',
          createdAtUtc: now,
          updatedAtUtc: now,
          finalDueAtUtc: now.subtract(const Duration(hours: 2)),
          milestones: const [],
          reminderOffsetsSeconds: const [],
          notificationsEnabled: false,
        ),
      ],
    );

    await tester.pumpWidget(_buildApp(snapshot, now));
    await tester.pumpAndSettle();

    expect(find.text('进行中'), findsOneWidget);
    expect(find.text('已过期'), findsOneWidget);
    expect(find.text('进行中任务'), findsOneWidget);
    expect(find.text('过期任务'), findsNothing);

    await tester.tap(find.text('已过期'));
    await tester.pumpAndSettle();

    expect(find.text('过期任务'), findsOneWidget);
  });

  testWidgets('final deadline label appears once and next milestone hides without milestones', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 1, 1, 8);
    final snapshot = AppSnapshot(
      schemaVersion: 1,
      exportedAtUtc: now,
      persistentNotificationEnabled: false,
      preferredLocale: AppLocalePreference.zh,
      persistentNotificationTimeUnit: PersistentNotificationTimeUnit.day,
      tasks: [
        DeadlineTask(
          id: '1',
          title: '论文终稿',
          note: '',
          timezoneId: 'Asia/Shanghai',
          createdAtUtc: now,
          updatedAtUtc: now,
          finalDueAtUtc: now.add(const Duration(days: 2)),
          milestones: const [],
          reminderOffsetsSeconds: const [0],
          notificationsEnabled: true,
        ),
      ],
    );

    await tester.pumpWidget(_buildApp(snapshot, now));
    await tester.pumpAndSettle();

    expect(find.text('最终截止'), findsOneWidget);
    expect(find.text('下一个节点'), findsNothing);
  });

  testWidgets('task with milestones still shows next milestone', (tester) async {
    final now = DateTime.utc(2026, 1, 1, 8);
    final snapshot = AppSnapshot(
      schemaVersion: 1,
      exportedAtUtc: now,
      persistentNotificationEnabled: false,
      preferredLocale: AppLocalePreference.zh,
      persistentNotificationTimeUnit: PersistentNotificationTimeUnit.day,
      tasks: [
        DeadlineTask(
          id: '1',
          title: '有节点任务',
          note: '',
          timezoneId: 'Asia/Shanghai',
          createdAtUtc: now,
          updatedAtUtc: now,
          finalDueAtUtc: now.add(const Duration(days: 2)),
          milestones: [
            Milestone(
              id: 'm1',
              title: '阶段检查',
              dueAtUtc: now.add(const Duration(hours: 6)),
              source: MilestoneSource.manual,
            ),
          ],
          reminderOffsetsSeconds: const [0],
          notificationsEnabled: true,
        ),
      ],
    );

    await tester.pumpWidget(_buildApp(snapshot, now));
    await tester.pumpAndSettle();

    expect(find.text('下一个节点'), findsOneWidget);
    expect(find.text('阶段检查'), findsOneWidget);
  });

  testWidgets('empty milestone titles stay blank without placeholder text', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 1, 1, 8);
    final snapshot = AppSnapshot(
      schemaVersion: 1,
      exportedAtUtc: now,
      persistentNotificationEnabled: false,
      preferredLocale: AppLocalePreference.zh,
      persistentNotificationTimeUnit: PersistentNotificationTimeUnit.day,
      tasks: [
        DeadlineTask(
          id: '1',
          title: '空节点任务',
          note: '',
          timezoneId: 'Asia/Shanghai',
          createdAtUtc: now,
          updatedAtUtc: now,
          finalDueAtUtc: now.add(const Duration(days: 2)),
          milestones: [
            Milestone(
              id: 'm1',
              title: '',
              dueAtUtc: now.add(const Duration(hours: 6)),
              source: MilestoneSource.manual,
            ),
          ],
          reminderOffsetsSeconds: const [0],
          notificationsEnabled: true,
        ),
      ],
    );

    await tester.pumpWidget(_buildApp(snapshot, now));
    await tester.pumpAndSettle();

    expect(find.text('未命名节点'), findsNothing);

    await tester.tap(find.text('空节点任务'));
    await tester.pumpAndSettle();

    expect(find.text('未命名节点'), findsNothing);
  });

  testWidgets('settings page shows locale and persistent time unit controls', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 1, 1, 8);
    final snapshot = AppSnapshot(
      schemaVersion: 1,
      exportedAtUtc: now,
      persistentNotificationEnabled: true,
      preferredLocale: AppLocalePreference.en,
      persistentNotificationTimeUnit: PersistentNotificationTimeUnit.hour,
      tasks: const [],
    );

    await tester.pumpWidget(_buildApp(snapshot, now));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Notification time unit'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Notification time unit'), findsOneWidget);
    expect(find.text('Android persistent notification'), findsOneWidget);
    expect(find.text('Updates'), findsOneWidget);
  });

  testWidgets('settings page checks updates and shows up-to-date state', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 1, 1, 8);
    final snapshot = AppSnapshot.empty().copyWith(
      exportedAtUtc: now,
      preferredLocale: AppLocalePreference.en,
    );
    final updateService = _FakeAppUpdateService();

    await tester.pumpWidget(
      _buildSettingsApp(snapshot, updateService: updateService),
    );
    await tester.pumpAndSettle();

    expect(find.text('Check for updates'), findsWidgets);
    await tester.tap(
      find.widgetWithText(FilledButton, 'Check for updates').first,
    );
    await tester.pumpAndSettle();

    expect(find.text("You're on the latest version"), findsOneWidget);
  });

  testWidgets('settings page shows update available state', (tester) async {
    final now = DateTime.utc(2026, 1, 1, 8);
    final snapshot = AppSnapshot.empty().copyWith(
      exportedAtUtc: now,
      preferredLocale: AppLocalePreference.en,
    );
    final updateService = _FakeAppUpdateService(
      release: UpdateRelease(
        tagName: 'v1.1.8',
        version: '1.1.8',
        publishedAtUtc: now,
        body: 'New build available.',
        htmlUrl: 'https://github.com/MT-Y-TM/next_ddl/releases/tag/v1.1.8',
        assets: const [],
      ),
    );

    await tester.pumpWidget(
      _buildSettingsApp(snapshot, updateService: updateService),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Check for updates').first,
    );
    await tester.pumpAndSettle();

    expect(find.text('New version available: 1.1.8'), findsOneWidget);
  });

  testWidgets('settings page shows update download progress and speed', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 1, 1, 8);
    final snapshot = AppSnapshot.empty().copyWith(
      exportedAtUtc: now,
      preferredLocale: AppLocalePreference.en,
    );
    final blocker = Completer<void>();
    final updateService = _FakeAppUpdateService(
      release: UpdateRelease(
        tagName: 'v1.1.8',
        version: '1.1.8',
        publishedAtUtc: now,
        body: 'New build available.',
        htmlUrl: 'https://github.com/MT-Y-TM/next_ddl/releases/tag/v1.1.8',
        assets: const [],
      ),
      progress: const DownloadProgress(
        receivedBytes: 512,
        totalBytes: 1024,
        speedBytesPerSecond: 2048,
      ),
      downloadBlocker: blocker,
    );

    await tester.pumpWidget(
      _buildSettingsApp(snapshot, updateService: updateService),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsPage)),
    );
    await container
        .read(appUpdateControllerProvider.notifier)
        .checkForUpdate(userInitiated: true);
    await tester.pumpAndSettle();
    unawaited(
      container.read(appUpdateControllerProvider.notifier).downloadAndInstall(),
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('50%'), findsOneWidget);
    expect(find.textContaining('2.0 KB/s'), findsOneWidget);

    blocker.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('settings page can clear cached installers', (tester) async {
    final now = DateTime.utc(2026, 1, 1, 8);
    final snapshot = AppSnapshot.empty().copyWith(
      exportedAtUtc: now,
      preferredLocale: AppLocalePreference.en,
    );
    final updateService = _FakeAppUpdateService(clearCount: 2);

    await tester.pumpWidget(
      _buildSettingsApp(snapshot, updateService: updateService),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Clear cached installers'));
    await tester.pumpAndSettle();

    expect(find.text('Cleared 2 cached installer(s)'), findsOneWidget);
  });

  testWidgets('settings page shows cached installer hint when reusable apk exists', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 1, 1, 8);
    final snapshot = AppSnapshot.empty().copyWith(
      exportedAtUtc: now,
      preferredLocale: AppLocalePreference.en,
    );
    final updateService = _FakeAppUpdateService(
      release: UpdateRelease(
        tagName: 'v1.1.8',
        version: '1.1.8',
        publishedAtUtc: now,
        body: 'New build available.',
        htmlUrl: 'https://github.com/MT-Y-TM/next_ddl/releases/tag/v1.1.8',
        assets: const [],
      ),
      cachedInstaller: const CachedUpdateInstaller(
        version: '1.1.8',
        filePath: 'C:/temp/app-release-v1.1.8.apk',
      ),
    );

    await tester.pumpWidget(
      _buildSettingsApp(snapshot, updateService: updateService),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsPage)),
    );
    await container
        .read(appUpdateControllerProvider.notifier)
        .checkForUpdate(userInitiated: true);
    await tester.pumpAndSettle();

    expect(find.text('Using cached installer for 1.1.8'), findsOneWidget);
  });

  testWidgets('settings page shows friendly message when no published release exists', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 1, 1, 8);
    final snapshot = AppSnapshot.empty().copyWith(
      exportedAtUtc: now,
      preferredLocale: AppLocalePreference.en,
    );
    final updateService = _FakeAppUpdateService(
      error: const AppUpdateException(AppUpdateErrorType.noPublishedRelease),
    );

    await tester.pumpWidget(
      _buildSettingsApp(snapshot, updateService: updateService),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Check for updates').first,
    );
    await tester.pumpAndSettle();

    expect(
      find.text('There is no published release available yet.'),
      findsOneWidget,
    );
  });

  testWidgets('settings page timezone dialog shows localized names and iana ids', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 1, 1, 8);
    final snapshot = AppSnapshot(
      schemaVersion: 1,
      exportedAtUtc: now,
      persistentNotificationEnabled: false,
      preferredLocale: AppLocalePreference.en,
      persistentNotificationTimeUnit: PersistentNotificationTimeUnit.day,
      tasks: const [],
    );

    await tester.pumpWidget(_buildApp(snapshot, now));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('App timezone'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('App timezone'));
    await tester.pumpAndSettle();

    expect(find.text('Choose app timezone'), findsOneWidget);
    expect(find.text('Shanghai'), findsOneWidget);
    expect(find.text('Asia/Shanghai'), findsOneWidget);
    expect(find.text('Buenos Aires (America / Argentina)'), findsOneWidget);
    expect(find.text('America/Argentina/Buenos_Aires'), findsOneWidget);
  });

  testWidgets('timezone dialog search matches localized fallback names', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 1, 1, 8);
    final snapshot = AppSnapshot(
      schemaVersion: 1,
      exportedAtUtc: now,
      persistentNotificationEnabled: false,
      preferredLocale: AppLocalePreference.en,
      persistentNotificationTimeUnit: PersistentNotificationTimeUnit.day,
      tasks: const [],
    );

    await tester.pumpWidget(_buildApp(snapshot, now));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('App timezone'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('App timezone'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'buenos');
    await tester.pumpAndSettle();

    expect(find.text('Buenos Aires (America / Argentina)'), findsOneWidget);
    expect(find.text('America/Argentina/Buenos_Aires'), findsOneWidget);
  });

  testWidgets('settings page can switch language labels', (tester) async {
    final now = DateTime.utc(2026, 1, 1, 8);
    final snapshot = AppSnapshot(
      schemaVersion: 1,
      exportedAtUtc: now,
      persistentNotificationEnabled: false,
      preferredLocale: AppLocalePreference.zh,
      persistentNotificationTimeUnit: PersistentNotificationTimeUnit.day,
      tasks: const [],
    );

    await tester.pumpWidget(_buildApp(snapshot, now));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('语言'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<AppLocalePreference>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
  });

  testWidgets('task editor reflects japanese locale strings', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deadlineRepositoryProvider.overrideWithValue(
            _MemoryRepository(AppSnapshot.empty().copyWith(
              preferredLocale: AppLocalePreference.ja,
            )),
          ),
          notificationSchedulerProvider.overrideWithValue(_FakeNotifications()),
          timezoneServiceProvider.overrideWithValue(_FakeTimezoneService()),
          fileExportServiceProvider.overrideWithValue(_FakeFileExportService()),
          appInfoServiceProvider.overrideWithValue(_FakeAppInfoService()),
          appUpdateServiceProvider.overrideWithValue(_FakeAppUpdateService()),
        ],
        child: const MaterialApp(
          locale: Locale('ja'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: TaskEditPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('新規タスク'), findsOneWidget);
    expect(find.text('タスク名'), findsOneWidget);
    expect(find.text('中間マイルストーン'), findsOneWidget);
  });

  testWidgets('startup update dialog shows download progress', (tester) async {
    final now = DateTime.utc(2026, 1, 1, 8);
    final snapshot = AppSnapshot.empty().copyWith(
      exportedAtUtc: now,
      preferredLocale: AppLocalePreference.en,
    );
    final blocker = Completer<void>();
    final updateService = _FakeAppUpdateService(
      release: UpdateRelease(
        tagName: 'v1.1.8',
        version: '1.1.8',
        publishedAtUtc: now,
        body: 'New build available.',
        htmlUrl: 'https://github.com/MT-Y-TM/next_ddl/releases/tag/v1.1.8',
        assets: const [],
      ),
      progress: const DownloadProgress(
        receivedBytes: 512,
        totalBytes: 1024,
        speedBytesPerSecond: 2048,
      ),
      downloadBlocker: blocker,
    );

    await tester.pumpWidget(_buildApp(snapshot, now, updateService: updateService));
    await tester.pumpAndSettle();

    expect(find.text('New version available'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TaskListPage)),
    );
    unawaited(
      container.read(appUpdateControllerProvider.notifier).downloadAndInstall(),
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('50%'), findsOneWidget);

    blocker.complete();
    await tester.pumpAndSettle();
  });
}

Widget _buildApp(
  AppSnapshot snapshot,
  DateTime now, {
  AppUpdateService? updateService,
}) {
  return ProviderScope(
    overrides: [
      deadlineRepositoryProvider.overrideWithValue(_MemoryRepository(snapshot)),
      notificationSchedulerProvider.overrideWithValue(_FakeNotifications()),
      timezoneServiceProvider.overrideWithValue(_FakeTimezoneService()),
      fileExportServiceProvider.overrideWithValue(_FakeFileExportService()),
      appInfoServiceProvider.overrideWithValue(_FakeAppInfoService()),
      appUpdateServiceProvider.overrideWithValue(
        updateService ?? _FakeAppUpdateService(),
      ),
      nowProvider.overrideWith((ref) => Stream.value(now)),
    ],
    child: const NextDdlApp(),
  );
}

Widget _buildSettingsApp(
  AppSnapshot snapshot, {
  required AppUpdateService updateService,
}) {
  return ProviderScope(
    overrides: [
      deadlineRepositoryProvider.overrideWithValue(_MemoryRepository(snapshot)),
      notificationSchedulerProvider.overrideWithValue(_FakeNotifications()),
      timezoneServiceProvider.overrideWithValue(_FakeTimezoneService()),
      fileExportServiceProvider.overrideWithValue(_FakeFileExportService()),
      appInfoServiceProvider.overrideWithValue(_FakeAppInfoService()),
      appUpdateServiceProvider.overrideWithValue(updateService),
    ],
    child: MaterialApp(
      locale: switch (snapshot.preferredLocale) {
        AppLocalePreference.zh => const Locale('zh'),
        AppLocalePreference.en => const Locale('en'),
        AppLocalePreference.ja => const Locale('ja'),
        AppLocalePreference.system => const Locale('en'),
      },
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SettingsPage(),
    ),
  );
}

class _MemoryRepository implements DeadlineRepository {
  _MemoryRepository(this.snapshot);

  AppSnapshot snapshot;

  @override
  Future<String?> exportSnapshot(AppSnapshot snapshot) async => null;

  @override
  Future<AppSnapshot?> importSnapshot() async => null;

  @override
  Future<AppSnapshot> loadSnapshot() async => snapshot;

  @override
  Future<void> saveSnapshot(AppSnapshot snapshot) async {
    this.snapshot = snapshot;
  }
}

class _FakeNotifications implements NotificationScheduler {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> removeAll() async {}

  @override
  Future<void> removeTask(String taskId) async {}

  @override
  Future<void> requestPermissionIfNeeded() async {}

  @override
  Future<void> syncPersistentNotification({
    required bool enabled,
    required List<DeadlineTask> tasks,
    required DateTime nowUtc,
    required AppLocalePreference localePreference,
    required PersistentNotificationTimeUnit timeUnit,
  }) async {}

  @override
  Future<void> syncTask(
    DeadlineTask task, {
    required AppLocalePreference localePreference,
  }) async {}
}

class _FakeTimezoneService extends DeviceTimezoneService {
  String _timezoneId = 'Asia/Shanghai';

  @override
  String get currentTimezoneId => _timezoneId;

  @override
  tz.Location get location => tz.getLocation(_timezoneId);

  @override
  List<String> get timezoneIds => const [
    'Asia/Shanghai',
    'Asia/Tokyo',
    'UTC',
    'America/New_York',
    'America/Argentina/Buenos_Aires',
  ];

  @override
  Future<void> initialize() async {}

  @override
  DateTime localToUtc(DateTime value) {
    return tz.TZDateTime(
      location,
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
    ).toUtc();
  }

  @override
  DateTime utcToConfigured(DateTime value) {
    return tz.TZDateTime.from(value.toUtc(), location);
  }

  @override
  Future<bool> setTimezone(String timezoneId) async {
    if (!timezoneIds.contains(timezoneId)) {
      return false;
    }
    _timezoneId = timezoneId;
    notifyListeners();
    return true;
  }
}

class _FakeFileExportService implements FileExportService {
  @override
  Future<String?> exportJson({
    required String suggestedName,
    required String content,
    AppLocalePreference localePreference = AppLocalePreference.system,
  }) async {
    return null;
  }

  @override
  Future<String?> importJson({
    AppLocalePreference localePreference = AppLocalePreference.system,
  }) async => null;
}

class _FakeAppUpdateService implements AppUpdateService {
  _FakeAppUpdateService({
    this.release,
    this.error,
    this.cachedInstaller,
    this.clearCount = 0,
    this.progress,
    this.downloadBlocker,
  });

  final UpdateRelease? release;
  final Object? error;
  final CachedUpdateInstaller? cachedInstaller;
  final int clearCount;
  final DownloadProgress? progress;
  final Completer<void>? downloadBlocker;

  @override
  Future<UpdateRelease?> checkForUpdate({required String currentVersion}) async {
    if (error != null) {
      throw error!;
    }
    return release;
  }

  @override
  Future<CachedUpdateInstaller?> findReusableInstaller({
    required UpdateRelease release,
    required String currentVersion,
  }) async {
    return cachedInstaller;
  }

  @override
  Future<AppUpdateInstallResult> downloadAndInstall(
    UpdateRelease release, {
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    if (progress != null) {
      onProgress?.call(progress!);
    }
    if (downloadBlocker != null) {
      await downloadBlocker!.future;
    }
    return const AppUpdateInstallResult(
      status: AppUpdateInstallStatus.openedReleasePage,
    );
  }

  @override
  Future<int> clearCachedInstallers() async => clearCount;

  @override
  Future<void> openInstallPermissionSettings() async {}

  @override
  Future<void> openReleasePage(UpdateRelease release) async {}

  @override
  Future<bool> resumePendingInstall(String filePath) async => false;
}

class _FakeAppInfoService implements AppInfoService {
  @override
  Future<String> getVersionLabel() async => '1.1.7';
}
