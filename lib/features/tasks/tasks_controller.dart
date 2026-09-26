import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../models/app_snapshot.dart';
import '../../models/app_theme_settings.dart';
import '../../models/deadline_task.dart';
import '../../models/milestone.dart';
import '../../models/app_alarm_settings.dart';
import '../../services/alarm_scheduler.dart';
import '../../services/backup_service.dart';
import '../../services/app_info_service.dart';
import '../../services/deadline_repository.dart';
import '../../services/notification_scheduler.dart';
import '../../services/timezone_service.dart';
import '../../utils/deadline_logic.dart';
import '../../utils/locale_utils.dart';
import '../../utils/task_actions.dart';

final nowProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now().toUtc();
  while (true) {
    await Future<void>.delayed(const Duration(seconds: 1));
    yield DateTime.now().toUtc();
  }
});

final appVersionProvider = FutureProvider<String>((ref) {
  return ref.watch(appInfoServiceProvider).getVersionLabel();
});

final tasksControllerProvider =
    AsyncNotifierProvider<TasksController, AppSnapshot>(TasksController.new);

final sortedTasksProvider = Provider<List<DeadlineTask>>((ref) {
  final snapshot = ref.watch(tasksControllerProvider).valueOrNull;
  final now = ref.watch(nowProvider).valueOrNull ?? DateTime.now().toUtc();
  if (snapshot == null) {
    return const [];
  }
  return sortTasks(snapshot.tasks, now);
});

final inProgressTasksProvider = Provider<List<DeadlineTask>>((ref) {
  final snapshot = ref.watch(tasksControllerProvider).valueOrNull;
  final now = ref.watch(nowProvider).valueOrNull ?? DateTime.now().toUtc();
  if (snapshot == null) {
    return const [];
  }
  return sortInProgressTasks(inProgressTasks(snapshot.tasks, now), now);
});

final overdueTasksProvider = Provider<List<DeadlineTask>>((ref) {
  final snapshot = ref.watch(tasksControllerProvider).valueOrNull;
  final now = ref.watch(nowProvider).valueOrNull ?? DateTime.now().toUtc();
  if (snapshot == null) {
    return const [];
  }
  return sortOverdueTasks(overdueTasks(snapshot.tasks, now));
});

final archivedTasksProvider = Provider<List<DeadlineTask>>((ref) {
  final tasks = ref.watch(tasksControllerProvider).valueOrNull?.tasks ?? const <DeadlineTask>[];
  return tasks.where((task) => task.isCompleted).toList()
    ..sort((a, b) => b.completedAtUtc!.compareTo(a.completedAtUtc!));
});

final localePreferenceProvider = Provider<AppLocalePreference>((ref) {
  return ref.watch(tasksControllerProvider).valueOrNull?.preferredLocale ??
      AppLocalePreference.system;
});

final themeSettingsProvider = Provider<AppThemeSettings>((ref) {
  return ref.watch(tasksControllerProvider).valueOrNull?.themeSettings ??
      AppThemeSettings.defaults();
});

final alarmSettingsProvider = Provider<AppAlarmSettings>((ref) {
  return ref.watch(tasksControllerProvider).valueOrNull?.alarmSettings ??
      AppAlarmSettings.defaults();
});

final persistentNotificationTimeUnitProvider =
    Provider<PersistentNotificationTimeUnit>((ref) {
      return ref
              .watch(tasksControllerProvider)
              .valueOrNull
              ?.persistentNotificationTimeUnit ??
          PersistentNotificationTimeUnit.day;
    });

final timezoneAwareLocalToUtcProvider = Provider.family<DateTime, DateTime>((
  ref,
  value,
) {
  ref.watch(timezoneRevisionProvider);
  return ref.watch(timezoneServiceProvider).localToUtc(value);
});

final configuredUtcToLocalProvider = Provider.family<DateTime, DateTime>((
  ref,
  value,
) {
  ref.watch(timezoneRevisionProvider);
  return ref.watch(timezoneServiceProvider).utcToConfigured(value);
});

final timezoneRevisionProvider = Provider<int>((ref) {
  final timezoneService = ref.watch(timezoneServiceProvider);
  void listener() => ref.invalidateSelf();
  timezoneService.addListener(listener);
  ref.onDispose(() => timezoneService.removeListener(listener));
  return DateTime.now().microsecondsSinceEpoch;
});

class TasksController extends AsyncNotifier<AppSnapshot> {
  Future<void> _pendingMutation = Future<void>.value();

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _pendingMutation.then((_) => operation());
    _pendingMutation = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  DeadlineTask _task(String id) => state.requireValue.tasks.firstWhere((task) => task.id == id);

  Future<void> savePlanningData(Map<String, dynamic> data) => _serialize(() async {
    final updated = state.requireValue.copyWith(planningData: data, exportedAtUtc: DateTime.now().toUtc());
    await _repository.saveSnapshot(updated);
    state = AsyncData(updated);
  });

  Future<void> setTaskCompleted(String id, bool completed) => _serialize(() async {
    await _saveTask(_task(id).copyWith(
      completedAtUtc: completed ? DateTime.now().toUtc() : null,
      clearCompletedAt: !completed,
      updatedAtUtc: DateTime.now().toUtc(),
    ));
  });

  Future<void> setMilestoneCompleted(String taskId, String milestoneId, bool completed) => _serialize(() async {
    final task = _task(taskId);
    final now = DateTime.now().toUtc();
    await _saveTask(task.copyWith(updatedAtUtc: now, milestones: [
      for (final node in task.milestones)
        if (node.id == milestoneId)
          node.copyWith(completedAtUtc: completed ? now : null, clearCompletedAt: !completed)
        else node,
    ]));
  });

  Future<void> postponeTask(String id, DateTime due, {bool shiftFutureMilestones = false}) => _serialize(() async {
    await _saveTask(postponeDeadlineTask(_task(id), due,
      nowUtc: DateTime.now().toUtc(), shiftFutureMilestones: shiftFutureMilestones));
  });

  Future<void> restoreTask(DeadlineTask task) => addOrUpdateTask(task.copyWith(updatedAtUtc: DateTime.now().toUtc()));

  Future<void> setTaskTags(String id, List<String> tags) => _serialize(() async {
    await _saveTask(_task(id).copyWith(
      tags: tags.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toSet().toList(),
      updatedAtUtc: DateTime.now().toUtc(),
    ));
  });

  Future<void> removeTag(String tag) => _serialize(() async {
    final snapshot = state.requireValue;
    final updated = snapshot.copyWith(tasks: [
      for (final task in snapshot.tasks)
        if (task.tags.contains(tag)) task.copyWith(tags: task.tags.where((item) => item != tag).toList(), updatedAtUtc: DateTime.now().toUtc())
        else task,
    ]);
    await _repository.saveSnapshot(updated);
    state = AsyncData(updated);
  });
  DeadlineRepository get _repository => ref.read(deadlineRepositoryProvider);
  NotificationScheduler get _notificationScheduler =>
      ref.read(notificationSchedulerProvider);
  AlarmScheduler get _alarmScheduler => ref.read(alarmSchedulerProvider);
  TimezoneService get _timezoneService => ref.read(timezoneServiceProvider);

  @override
  Future<AppSnapshot> build() async {
    final snapshot = await _repository.loadSnapshot();
    await _notificationScheduler.syncPersistentNotification(
      enabled: snapshot.persistentNotificationEnabled,
      tasks: snapshot.tasks,
      nowUtc: DateTime.now().toUtc(),
      localePreference: snapshot.preferredLocale,
      timeUnit: snapshot.persistentNotificationTimeUnit,
    );
    await _syncAlarmsSafely(
      settings: snapshot.alarmSettings,
      tasks: snapshot.tasks,
      localePreference: snapshot.preferredLocale,
    );
    return snapshot;
  }

  Future<void> addOrUpdateTask(DeadlineTask task) => _serialize(() => _saveTask(task));

  Future<void> _saveTask(DeadlineTask task) async {
    final snapshot = state.requireValue;
    final nextTasks = [...snapshot.tasks];
    final index = nextTasks.indexWhere((item) => item.id == task.id);
    if (index == -1) {
      nextTasks.add(task);
    } else {
      nextTasks[index] = task;
    }
    final nextSnapshot = snapshot.copyWith(
      exportedAtUtc: DateTime.now().toUtc(),
      tasks: nextTasks,
    );
    await _repository.saveSnapshot(nextSnapshot);
    state = AsyncData(nextSnapshot);
    await _notificationScheduler.removeAll();
    await _removeAllAlarmsSafely();
    await _syncAll(nextSnapshot);
  }

  Future<void> deleteTask(String taskId) => _serialize(() async {
    final snapshot = state.requireValue;
    final nextSnapshot = snapshot.copyWith(
      exportedAtUtc: DateTime.now().toUtc(),
      tasks: snapshot.tasks.where((item) => item.id != taskId).toList(),
    );
    await _repository.saveSnapshot(nextSnapshot);
    state = AsyncData(nextSnapshot);
    await _notificationScheduler.removeAll();
    await _removeAllAlarmsSafely();
    await _syncAll(nextSnapshot);
  });

  Future<AppSnapshot?> importSnapshot() async {
    final imported = await _repository.importSnapshot();
    if (imported == null) {
      return null;
    }
    await _repository.saveSnapshot(imported);
    state = AsyncData(imported);
    await _notificationScheduler.removeAll();
    await _removeAllAlarmsSafely();
    await _syncAll(imported);
    return imported;
  }

  Future<void> replaceWithBackup(AppSnapshot snapshot) => _serialize(() async {
    await BackupService(repository: _repository).replaceWithBackup(snapshot);
    state = AsyncData(snapshot);
    await _notificationScheduler.removeAll();
    await _removeAllAlarmsSafely();
    await _syncAll(snapshot);
  });

  Future<void> reloadPersistedSnapshot() => _serialize(() async {
    final snapshot = await _repository.loadSnapshot();
    state = AsyncData(snapshot);
    await _notificationScheduler.removeAll();
    await _removeAllAlarmsSafely();
    await _syncAll(snapshot);
  });

  Future<String?> exportSnapshot() {
    return _repository.exportSnapshot(state.requireValue);
  }

  Future<void> requestNotificationPermission() {
    return _notificationScheduler.requestPermissionIfNeeded();
  }

  Future<void> setPersistentNotificationEnabled(bool enabled) => _serialize(() async {
    final snapshot = state.requireValue;
    if (snapshot.persistentNotificationEnabled == enabled) {
      return;
    }
    if (enabled) {
      await _notificationScheduler.requestPermissionIfNeeded();
    }
    final nextSnapshot = snapshot.copyWith(
      exportedAtUtc: DateTime.now().toUtc(),
      persistentNotificationEnabled: enabled,
    );
    await _repository.saveSnapshot(nextSnapshot);
    state = AsyncData(nextSnapshot);
    await _notificationScheduler.syncPersistentNotification(
      enabled: enabled,
      tasks: nextSnapshot.tasks,
      nowUtc: DateTime.now().toUtc(),
      localePreference: nextSnapshot.preferredLocale,
      timeUnit: nextSnapshot.persistentNotificationTimeUnit,
    );
  });

  Future<void> setPreferredLocale(AppLocalePreference preferredLocale) => _serialize(() async {
    final snapshot = state.requireValue;
    if (snapshot.preferredLocale == preferredLocale) {
      return;
    }
    final nextSnapshot = snapshot.copyWith(
      exportedAtUtc: DateTime.now().toUtc(),
      preferredLocale: preferredLocale,
    );
    await _repository.saveSnapshot(nextSnapshot);
    state = AsyncData(nextSnapshot);
    await _notificationScheduler.removeAll();
    await _removeAllAlarmsSafely();
    await _syncAll(nextSnapshot);
  });

  Future<void> setPersistentNotificationTimeUnit(
    PersistentNotificationTimeUnit timeUnit,
  ) => _serialize(() async {
    final snapshot = state.requireValue;
    if (snapshot.persistentNotificationTimeUnit == timeUnit) {
      return;
    }
    final nextSnapshot = snapshot.copyWith(
      exportedAtUtc: DateTime.now().toUtc(),
      persistentNotificationTimeUnit: timeUnit,
    );
    await _repository.saveSnapshot(nextSnapshot);
    state = AsyncData(nextSnapshot);
    await _notificationScheduler.syncPersistentNotification(
      enabled: nextSnapshot.persistentNotificationEnabled,
      tasks: nextSnapshot.tasks,
      nowUtc: DateTime.now().toUtc(),
      localePreference: nextSnapshot.preferredLocale,
      timeUnit: timeUnit,
    );
  });

  Future<void> setThemeSettings(AppThemeSettings themeSettings) => _serialize(() async {
    final snapshot = state.requireValue;
    final nextSnapshot = snapshot.copyWith(
      exportedAtUtc: DateTime.now().toUtc(),
      themeSettings: themeSettings,
    );
    await _repository.saveSnapshot(nextSnapshot);
    state = AsyncData(nextSnapshot);
  });

  Future<void> setAlarmSettings(AppAlarmSettings alarmSettings) => _serialize(() async {
    final snapshot = state.requireValue;
    final nextSnapshot = snapshot.copyWith(
      exportedAtUtc: DateTime.now().toUtc(),
      alarmSettings: alarmSettings,
    );
    await _repository.saveSnapshot(nextSnapshot);
    state = AsyncData(nextSnapshot);
    await _syncAlarmsSafely(
      settings: nextSnapshot.alarmSettings,
      tasks: nextSnapshot.tasks,
      localePreference: nextSnapshot.preferredLocale,
    );
  });

  Future<bool> canScheduleExactAlarms() {
    return _alarmScheduler.canScheduleExactAlarms();
  }

  Future<void> openExactAlarmSettings() {
    return _alarmScheduler.openExactAlarmSettings();
  }

  String get timezoneId => _timezoneService.currentTimezoneId;

  List<String> get timezoneIds => _timezoneService.timezoneIds;

  Future<bool> setTimezone(String timezoneId) => _serialize(() async {
    final changed = await _timezoneService.setTimezone(timezoneId);
    if (!changed) {
      return false;
    }
    final snapshot = state.valueOrNull;
    if (snapshot != null) {
      await _notificationScheduler.removeAll();
      await _removeAllAlarmsSafely();
      await _syncAll(snapshot);
      state = AsyncData(snapshot);
    }
    return true;
  });

  List<Milestone> generateQuarterNodes(
    DateTime finalDueAtUtc,
    String taskId, {
    AppLocalePreference localePreference = AppLocalePreference.system,
  }) {
    return generateQuarterMilestones(
      nowUtc: DateTime.now().toUtc(),
      finalDueAtUtc: finalDueAtUtc,
      taskId: taskId,
      titleBuilder: (percent) {
        final l10n = resolveAppLocalizations(localePreference);
        return l10n.generatedMilestoneTitle(percent);
      },
    );
  }

  Future<void> _syncAll(AppSnapshot snapshot) async {
    for (final task in snapshot.tasks) {
      if (task.isCompleted) continue;
      await _notificationScheduler.syncTask(
        task.copyWith(milestones: task.milestones.where((node) => !node.isCompleted).toList()),
        localePreference: snapshot.preferredLocale,
      );
    }
    await _notificationScheduler.syncPersistentNotification(
      enabled: snapshot.persistentNotificationEnabled,
      tasks: snapshot.tasks,
      nowUtc: DateTime.now().toUtc(),
      localePreference: snapshot.preferredLocale,
      timeUnit: snapshot.persistentNotificationTimeUnit,
    );
    await _syncAlarmsSafely(
      settings: snapshot.alarmSettings,
      tasks: snapshot.tasks,
      localePreference: snapshot.preferredLocale,
    );
  }

  Future<void> _syncAlarmsSafely({
    required AppAlarmSettings settings,
    required List<DeadlineTask> tasks,
    required AppLocalePreference localePreference,
  }) async {
    try {
      await _alarmScheduler.syncAlarms(
        settings: settings,
        tasks: [
          for (final task in tasks)
            if (!task.isCompleted)
              task.copyWith(milestones: task.milestones.where((node) => !node.isCompleted).toList()),
        ],
        localePreference: localePreference,
      );
    } on MissingPluginException {
      return;
    }
  }

  Future<void> _removeAllAlarmsSafely() async {
    try {
      await _alarmScheduler.removeAll();
    } on MissingPluginException {
      return;
    }
  }
}
