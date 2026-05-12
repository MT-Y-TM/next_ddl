import 'package:flutter_test/flutter_test.dart';
import 'package:next_ddl/features/tasks/tasks_controller.dart';
import 'package:next_ddl/models/app_snapshot.dart';
import 'package:next_ddl/models/deadline_task.dart';
import 'package:next_ddl/services/deadline_repository.dart';
import 'package:next_ddl/services/notification_scheduler.dart';
import 'package:next_ddl/services/timezone_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  test('controller persists added task and schedules notifications', () async {
    final repository = _MemoryRepository();
    final notifications = _FakeNotificationScheduler();
    final container = ProviderContainer(
      overrides: [
        deadlineRepositoryProvider.overrideWithValue(repository),
        notificationSchedulerProvider.overrideWithValue(notifications),
        timezoneServiceProvider.overrideWithValue(_FakeTimezoneService()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(tasksControllerProvider.future);

    final now = DateTime.utc(2026, 1, 1, 12);
    final task = DeadlineTask(
      id: 'task_1',
      title: '提交周报',
      note: '',
      timezoneId: 'Asia/Shanghai',
      createdAtUtc: now,
      updatedAtUtc: now,
      finalDueAtUtc: now.add(const Duration(days: 1)),
      milestones: const [],
      reminderOffsetsSeconds: const [0],
      notificationsEnabled: true,
    );

    await container.read(tasksControllerProvider.notifier).addOrUpdateTask(task);

    final snapshot = container.read(tasksControllerProvider).value!;
    expect(snapshot.tasks, hasLength(1));
    expect(repository.saved?.tasks.single.title, '提交周报');
    expect(notifications.syncedTaskIds, contains('task_1'));
  });
}

class _MemoryRepository implements DeadlineRepository {
  AppSnapshot? saved;

  @override
  Future<String?> exportSnapshot(AppSnapshot snapshot) async => null;

  @override
  Future<AppSnapshot?> importSnapshot() async => null;

  @override
  Future<AppSnapshot> loadSnapshot() async => AppSnapshot.empty();

  @override
  Future<void> saveSnapshot(AppSnapshot snapshot) async {
    saved = snapshot;
  }
}

class _FakeNotificationScheduler implements NotificationScheduler {
  final List<String> syncedTaskIds = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> removeAll() async {}

  @override
  Future<void> removeTask(String taskId) async {}

  @override
  Future<void> requestPermissionIfNeeded() async {}

  @override
  Future<void> syncTask(DeadlineTask task) async {
    syncedTaskIds.add(task.id);
  }
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
