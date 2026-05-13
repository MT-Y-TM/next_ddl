import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_ddl/app/app.dart';
import 'package:next_ddl/features/tasks/task_edit_page.dart';
import 'package:next_ddl/models/app_snapshot.dart';
import 'package:next_ddl/models/deadline_task.dart';
import 'package:next_ddl/models/milestone.dart';
import 'package:next_ddl/services/app_info_service.dart';
import 'package:next_ddl/services/deadline_repository.dart';
import 'package:next_ddl/services/file_export_service.dart';
import 'package:next_ddl/services/notification_scheduler.dart';
import 'package:next_ddl/services/timezone_service.dart';
import 'package:next_ddl/features/tasks/tasks_controller.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  testWidgets('shows saved task in home page', (tester) async {
    final now = DateTime.utc(2026, 1, 1, 8);
    final snapshot = AppSnapshot(
      schemaVersion: 1,
      exportedAtUtc: now,
      persistentNotificationEnabled: false,
      tasks: [
        DeadlineTask(
          id: '1',
          title: '论文终稿',
          note: '需要提交 PDF',
          timezoneId: 'Asia/Shanghai',
          createdAtUtc: now,
          updatedAtUtc: now,
          finalDueAtUtc: now.add(const Duration(days: 2)),
          milestones: const [],
          reminderOffsetsSeconds: const [0, 3600],
          notificationsEnabled: true,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deadlineRepositoryProvider.overrideWithValue(
            _MemoryRepository(snapshot),
          ),
          notificationSchedulerProvider.overrideWithValue(_FakeNotifications()),
          timezoneServiceProvider.overrideWithValue(_FakeTimezoneService()),
          fileExportServiceProvider.overrideWithValue(_FakeFileExportService()),
          appInfoServiceProvider.overrideWithValue(_FakeAppInfoService()),
          nowProvider.overrideWith((ref) => Stream.value(now)),
        ],
        child: const NextDdlApp(),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('论文终稿'), findsOneWidget);
    expect(find.textContaining('下一个节点'), findsNothing);
    expect(find.text('最终截止'), findsWidgets);
    expect(find.text('剩余时间'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('shows next milestone row only when task has milestones', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 1, 1, 8);
    final snapshot = AppSnapshot(
      schemaVersion: 1,
      exportedAtUtc: now,
      persistentNotificationEnabled: false,
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deadlineRepositoryProvider.overrideWithValue(
            _MemoryRepository(snapshot),
          ),
          notificationSchedulerProvider.overrideWithValue(_FakeNotifications()),
          timezoneServiceProvider.overrideWithValue(_FakeTimezoneService()),
          fileExportServiceProvider.overrideWithValue(_FakeFileExportService()),
          appInfoServiceProvider.overrideWithValue(_FakeAppInfoService()),
          nowProvider.overrideWith((ref) => Stream.value(now)),
        ],
        child: const NextDdlApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('下一个节点'), findsOneWidget);
    expect(find.text('阶段检查'), findsOneWidget);
  });

  testWidgets('shows empty state when no tasks exist', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deadlineRepositoryProvider.overrideWithValue(
            _MemoryRepository(AppSnapshot.empty()),
          ),
          notificationSchedulerProvider.overrideWithValue(_FakeNotifications()),
          timezoneServiceProvider.overrideWithValue(_FakeTimezoneService()),
          fileExportServiceProvider.overrideWithValue(_FakeFileExportService()),
          appInfoServiceProvider.overrideWithValue(_FakeAppInfoService()),
          nowProvider.overrideWith(
            (ref) => Stream.value(DateTime.utc(2026, 1, 1, 8)),
          ),
        ],
        child: const NextDdlApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('还没有任何 deadline 任务'), findsOneWidget);
    expect(find.text('立即创建'), findsOneWidget);
  });

  testWidgets('task editor keeps milestones manual only', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deadlineRepositoryProvider.overrideWithValue(
            _MemoryRepository(AppSnapshot.empty()),
          ),
          notificationSchedulerProvider.overrideWithValue(_FakeNotifications()),
          timezoneServiceProvider.overrideWithValue(_FakeTimezoneService()),
          fileExportServiceProvider.overrideWithValue(_FakeFileExportService()),
          appInfoServiceProvider.overrideWithValue(_FakeAppInfoService()),
        ],
        child: const MaterialApp(home: TaskEditPage()),
      ),
    );

    expect(find.text('新增节点'), findsOneWidget);
    expect(find.textContaining('自动生成'), findsNothing);
  });

  testWidgets('settings page shows and searches configured timezone', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deadlineRepositoryProvider.overrideWithValue(
            _MemoryRepository(AppSnapshot.empty()),
          ),
          notificationSchedulerProvider.overrideWithValue(_FakeNotifications()),
          timezoneServiceProvider.overrideWithValue(_FakeTimezoneService()),
          fileExportServiceProvider.overrideWithValue(_FakeFileExportService()),
          appInfoServiceProvider.overrideWithValue(_FakeAppInfoService()),
          nowProvider.overrideWith(
            (ref) => Stream.value(DateTime.utc(2026, 1, 1, 8)),
          ),
        ],
        child: const NextDdlApp(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('应用时区'), findsOneWidget);
    expect(find.text('Asia/Shanghai'), findsOneWidget);
    expect(find.text('Android 消息栏常驻提醒'), findsOneWidget);

    await tester.tap(find.text('应用时区'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tokyo');
    await tester.pumpAndSettle();

    expect(find.text('Asia/Tokyo'), findsOneWidget);
  });
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
  int removeAllCount = 0;
  final List<String> syncedTaskIds = [];
  bool? lastPersistentEnabled;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> removeAll() async {
    removeAllCount++;
  }

  @override
  Future<void> removeTask(String taskId) async {}

  @override
  Future<void> requestPermissionIfNeeded() async {}

  @override
  Future<void> syncPersistentNotification({
    required bool enabled,
    required List<DeadlineTask> tasks,
    required DateTime nowUtc,
  }) async {
    lastPersistentEnabled = enabled;
  }

  @override
  Future<void> syncTask(DeadlineTask task) async {
    syncedTaskIds.add(task.id);
  }
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
  }) async {
    return null;
  }

  @override
  Future<String?> importJson() async => null;
}

class _FakeAppInfoService implements AppInfoService {
  @override
  Future<String> getVersionLabel() async => '0.1.0+1';
}
