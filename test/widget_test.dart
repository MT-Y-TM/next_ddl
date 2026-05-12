import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_ddl/app/app.dart';
import 'package:next_ddl/models/app_snapshot.dart';
import 'package:next_ddl/models/deadline_task.dart';
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
          deadlineRepositoryProvider.overrideWithValue(_MemoryRepository(snapshot)),
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
    expect(find.textContaining('下一个节点'), findsOneWidget);
    expect(find.text('最终截止'), findsWidgets);
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
  Future<void> syncTask(DeadlineTask task) async {}
}

class _FakeTimezoneService implements TimezoneService {
  @override
  String get currentTimezoneId => 'Asia/Shanghai';

  @override
  tz.Location get location => tz.getLocation('UTC');

  @override
  Future<void> initialize() async {}

  @override
  DateTime localToUtc(DateTime value) => value.toUtc();
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
