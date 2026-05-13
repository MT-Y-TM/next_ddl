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

    await container
        .read(tasksControllerProvider.notifier)
        .addOrUpdateTask(task);

    final snapshot = container.read(tasksControllerProvider).value!;
    expect(snapshot.tasks, hasLength(1));
    expect(repository.saved?.tasks.single.title, '提交周报');
    expect(notifications.syncedTaskIds, contains('task_1'));
    expect(notifications.persistentSyncCount, greaterThan(0));
  });

  test('controller persists persistent notification toggle', () async {
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

    await container
        .read(tasksControllerProvider.notifier)
        .setPersistentNotificationEnabled(true);

    final snapshot = container.read(tasksControllerProvider).value!;
    expect(snapshot.persistentNotificationEnabled, isTrue);
    expect(repository.saved?.persistentNotificationEnabled, isTrue);
    expect(notifications.permissionRequestCount, 1);
    expect(notifications.lastPersistentEnabled, isTrue);
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
  int permissionRequestCount = 0;
  int persistentSyncCount = 0;
  bool? lastPersistentEnabled;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> removeAll() async {}

  @override
  Future<void> removeTask(String taskId) async {}

  @override
  Future<void> requestPermissionIfNeeded() async {
    permissionRequestCount++;
  }

  @override
  Future<void> syncPersistentNotification({
    required bool enabled,
    required List<DeadlineTask> tasks,
    required DateTime nowUtc,
  }) async {
    persistentSyncCount++;
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
  List<String> get timezoneIds => const ['Asia/Shanghai', 'UTC'];

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
