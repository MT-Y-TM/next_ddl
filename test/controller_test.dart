import 'package:flutter_test/flutter_test.dart';
import 'package:next_ddl/features/tasks/tasks_controller.dart';
import 'package:next_ddl/models/app_alarm_settings.dart';
import 'package:next_ddl/services/alarm_scheduler.dart';
import 'package:next_ddl/models/app_snapshot.dart';
import 'package:next_ddl/models/deadline_task.dart';
import 'package:next_ddl/models/milestone.dart';
import 'package:next_ddl/services/deadline_repository.dart';
import 'package:next_ddl/services/notification_scheduler.dart';
import 'package:next_ddl/services/timezone_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  test('controller syncs persistent summary on build with saved preferences', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    final repository = _MemoryRepository(
      initial: AppSnapshot(
        schemaVersion: 1,
        exportedAtUtc: now,
        persistentNotificationEnabled: true,
        preferredLocale: AppLocalePreference.en,
        persistentNotificationTimeUnit: PersistentNotificationTimeUnit.hour,
        tasks: [
          DeadlineTask(
            id: 'task_1',
            title: 'Submit report',
            note: '',
            timezoneId: 'Asia/Shanghai',
            createdAtUtc: now,
            updatedAtUtc: now,
            finalDueAtUtc: now.add(const Duration(days: 1)),
            milestones: const [],
            reminderOffsetsSeconds: const [],
            notificationsEnabled: false,
          ),
        ],
      ),
    );
    final notifications = _FakeNotificationScheduler();
    final container = ProviderContainer(
      overrides: [
        deadlineRepositoryProvider.overrideWithValue(repository),
        alarmSchedulerProvider.overrideWithValue(_FakeAlarmScheduler()),
        notificationSchedulerProvider.overrideWithValue(notifications),
        timezoneServiceProvider.overrideWithValue(_FakeTimezoneService()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(tasksControllerProvider.future);

    expect(notifications.persistentSyncCount, 1);
    expect(notifications.lastLocalePreference, AppLocalePreference.en);
    expect(
      notifications.lastTimeUnit,
      PersistentNotificationTimeUnit.hour,
    );
    expect(notifications.lastPersistentTaskIds, ['task_1']);
  });

  test('controller persists added task and schedules notifications', () async {
    final repository = _MemoryRepository();
    final notifications = _FakeNotificationScheduler();
    final container = ProviderContainer(
      overrides: [
        deadlineRepositoryProvider.overrideWithValue(repository),
        alarmSchedulerProvider.overrideWithValue(_FakeAlarmScheduler()),
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
    expect(notifications.lastLocalePreference, AppLocalePreference.system);
    expect(notifications.lastTimeUnit, PersistentNotificationTimeUnit.day);
  });

  test('controller persists persistent notification toggle', () async {
    final repository = _MemoryRepository();
    final notifications = _FakeNotificationScheduler();
    final container = ProviderContainer(
      overrides: [
        deadlineRepositoryProvider.overrideWithValue(repository),
        alarmSchedulerProvider.overrideWithValue(_FakeAlarmScheduler()),
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

  test('controller persists locale change and refreshes persistent summary', () async {
    final repository = _MemoryRepository(
      initial: AppSnapshot(
        schemaVersion: 1,
        exportedAtUtc: DateTime.utc(2026, 1, 1, 12),
        persistentNotificationEnabled: true,
        preferredLocale: AppLocalePreference.system,
        persistentNotificationTimeUnit: PersistentNotificationTimeUnit.day,
        tasks: const [],
      ),
    );
    final notifications = _FakeNotificationScheduler();
    final container = ProviderContainer(
      overrides: [
        deadlineRepositoryProvider.overrideWithValue(repository),
        alarmSchedulerProvider.overrideWithValue(_FakeAlarmScheduler()),
        notificationSchedulerProvider.overrideWithValue(notifications),
        timezoneServiceProvider.overrideWithValue(_FakeTimezoneService()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(tasksControllerProvider.future);
    await container
        .read(tasksControllerProvider.notifier)
        .setPreferredLocale(AppLocalePreference.ja);

    final snapshot = container.read(tasksControllerProvider).value!;
    expect(snapshot.preferredLocale, AppLocalePreference.ja);
    expect(repository.saved?.preferredLocale, AppLocalePreference.ja);
    expect(notifications.lastLocalePreference, AppLocalePreference.ja);
    expect(notifications.persistentSyncCount, greaterThan(1));
  });

  test('controller persists time unit change and refreshes persistent summary', () async {
    final repository = _MemoryRepository(
      initial: AppSnapshot(
        schemaVersion: 1,
        exportedAtUtc: DateTime.utc(2026, 1, 1, 12),
        persistentNotificationEnabled: true,
        preferredLocale: AppLocalePreference.system,
        persistentNotificationTimeUnit: PersistentNotificationTimeUnit.day,
        tasks: const [],
      ),
    );
    final notifications = _FakeNotificationScheduler();
    final container = ProviderContainer(
      overrides: [
        deadlineRepositoryProvider.overrideWithValue(repository),
        alarmSchedulerProvider.overrideWithValue(_FakeAlarmScheduler()),
        notificationSchedulerProvider.overrideWithValue(notifications),
        timezoneServiceProvider.overrideWithValue(_FakeTimezoneService()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(tasksControllerProvider.future);
    await container
        .read(tasksControllerProvider.notifier)
        .setPersistentNotificationTimeUnit(
          PersistentNotificationTimeUnit.hour,
        );

    final snapshot = container.read(tasksControllerProvider).value!;
    expect(
      snapshot.persistentNotificationTimeUnit,
      PersistentNotificationTimeUnit.hour,
    );
    expect(
      repository.saved?.persistentNotificationTimeUnit,
      PersistentNotificationTimeUnit.hour,
    );
    expect(
      notifications.lastTimeUnit,
      PersistentNotificationTimeUnit.hour,
    );
    expect(notifications.persistentSyncCount, greaterThan(1));
  });

  test('controller import replaces state and refreshes persistent summary', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    final imported = AppSnapshot(
      schemaVersion: 1,
      exportedAtUtc: now,
      persistentNotificationEnabled: true,
      preferredLocale: AppLocalePreference.en,
      persistentNotificationTimeUnit: PersistentNotificationTimeUnit.hour,
      tasks: [
        DeadlineTask(
          id: 'task_imported',
          title: 'Imported task',
          note: '',
          timezoneId: 'Asia/Shanghai',
          createdAtUtc: now,
          updatedAtUtc: now,
          finalDueAtUtc: now.add(const Duration(days: 2)),
          milestones: [
            Milestone(
              id: 'm1',
              title: 'checkpoint',
              dueAtUtc: now.add(const Duration(hours: 3)),
              source: MilestoneSource.manual,
            ),
          ],
          reminderOffsetsSeconds: const [0],
          notificationsEnabled: true,
        ),
      ],
    );
    final repository = _MemoryRepository(imported: imported);
    final notifications = _FakeNotificationScheduler();
    final container = ProviderContainer(
      overrides: [
        deadlineRepositoryProvider.overrideWithValue(repository),
        alarmSchedulerProvider.overrideWithValue(_FakeAlarmScheduler()),
        notificationSchedulerProvider.overrideWithValue(notifications),
        timezoneServiceProvider.overrideWithValue(_FakeTimezoneService()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(tasksControllerProvider.future);
    final result = await container
        .read(tasksControllerProvider.notifier)
        .importSnapshot();

    expect(result?.tasks.single.id, 'task_imported');
    expect(notifications.removeAllCount, 1);
    expect(notifications.syncedTaskIds, contains('task_imported'));
    expect(notifications.lastLocalePreference, AppLocalePreference.en);
    expect(
      notifications.lastTimeUnit,
      PersistentNotificationTimeUnit.hour,
    );
    expect(notifications.lastPersistentTaskIds, ['task_imported']);
  });

  test('controller timezone change resyncs tasks and persistent summary', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    final repository = _MemoryRepository(
      initial: AppSnapshot(
        schemaVersion: 1,
        exportedAtUtc: now,
        persistentNotificationEnabled: true,
        preferredLocale: AppLocalePreference.system,
        persistentNotificationTimeUnit: PersistentNotificationTimeUnit.day,
        tasks: [
          DeadlineTask(
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
          ),
        ],
      ),
    );
    final notifications = _FakeNotificationScheduler();
    final container = ProviderContainer(
      overrides: [
        deadlineRepositoryProvider.overrideWithValue(repository),
        alarmSchedulerProvider.overrideWithValue(_FakeAlarmScheduler()),
        notificationSchedulerProvider.overrideWithValue(notifications),
        timezoneServiceProvider.overrideWithValue(_FakeTimezoneService()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(tasksControllerProvider.future);
    final changed = await container
        .read(tasksControllerProvider.notifier)
        .setTimezone('UTC');

    expect(changed, isTrue);
    expect(notifications.removeAllCount, 1);
    expect(notifications.syncedTaskIds, contains('task_1'));
    expect(notifications.persistentSyncCount, greaterThan(1));
  });
}

class _MemoryRepository implements DeadlineRepository {
  _MemoryRepository({AppSnapshot? initial, this.imported})
    : _loaded = initial ?? AppSnapshot.empty();

  final AppSnapshot _loaded;
  final AppSnapshot? imported;
  AppSnapshot? saved;

  @override
  Future<String?> exportSnapshot(AppSnapshot snapshot) async => null;

  @override
  Future<AppSnapshot?> importSnapshot() async => imported;

  @override
  Future<AppSnapshot> loadSnapshot() async => _loaded;

  @override
  Future<void> saveSnapshot(AppSnapshot snapshot) async {
    saved = snapshot;
  }
}

class _FakeNotificationScheduler implements NotificationScheduler {
  final List<String> syncedTaskIds = [];
  int permissionRequestCount = 0;
  int persistentSyncCount = 0;
  int removeAllCount = 0;
  bool? lastPersistentEnabled;
  AppLocalePreference? lastLocalePreference;
  PersistentNotificationTimeUnit? lastTimeUnit;
  List<String> lastPersistentTaskIds = const [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> removeAll() async {
    removeAllCount++;
  }

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
    required AppLocalePreference localePreference,
    required PersistentNotificationTimeUnit timeUnit,
  }) async {
    persistentSyncCount++;
    lastPersistentEnabled = enabled;
    lastLocalePreference = localePreference;
    lastTimeUnit = timeUnit;
    lastPersistentTaskIds = tasks.map((task) => task.id).toList();
  }

  @override
  Future<void> syncTask(
    DeadlineTask task, {
    required AppLocalePreference localePreference,
  }) async {
    syncedTaskIds.add(task.id);
  }
}

class _FakeAlarmScheduler implements AlarmScheduler {
  int syncCount = 0;
  int removeAllCount = 0;

  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> openExactAlarmSettings() async {}

  @override
  Future<void> removeAll() async {
    removeAllCount++;
  }

  @override
  Future<void> removeTask(String taskId) async {}

  @override
  Future<void> stopCurrentAlarm() async {}

  @override
  Future<void> syncAlarms({
    required AppAlarmSettings settings,
    required List<DeadlineTask> tasks,
    required AppLocalePreference localePreference,
  }) async {
    syncCount++;
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



