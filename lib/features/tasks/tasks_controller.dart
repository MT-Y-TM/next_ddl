import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../models/app_snapshot.dart';
import '../../models/app_theme_settings.dart';
import '../../models/deadline_task.dart';
import '../../models/milestone.dart';
import '../../models/app_alarm_settings.dart';
import '../../services/alarm_scheduler.dart';
import '../../services/app_info_service.dart';
import '../../services/deadline_repository.dart';
import '../../services/notification_scheduler.dart';
import '../../services/timezone_service.dart';
import '../../utils/deadline_logic.dart';
import '../../utils/locale_utils.dart';

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

  Future<void> addOrUpdateTask(DeadlineTask task) async {
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
    state = AsyncData(nextSnapshot);
    await _repository.saveSnapshot(nextSnapshot);
    await _notificationScheduler.removeAll();
    await _removeAllAlarmsSafely();
    await _syncAll(nextSnapshot);
  }

  Future<void> deleteTask(String taskId) async {
    final snapshot = state.requireValue;
    final nextSnapshot = snapshot.copyWith(
      exportedAtUtc: DateTime.now().toUtc(),
      tasks: snapshot.tasks.where((item) => item.id != taskId).toList(),
    );
    state = AsyncData(nextSnapshot);
    await _repository.saveSnapshot(nextSnapshot);
    await _notificationScheduler.removeAll();
    await _removeAllAlarmsSafely();
    await _syncAll(nextSnapshot);
  }

  Future<AppSnapshot?> importSnapshot() async {
    final imported = await _repository.importSnapshot();
    if (imported == null) {
      return null;
    }
    state = AsyncData(imported);
    await _repository.saveSnapshot(imported);
    await _notificationScheduler.removeAll();
    await _removeAllAlarmsSafely();
    await _syncAll(imported);
    return imported;
  }

  Future<String?> exportSnapshot() {
    return _repository.exportSnapshot(state.requireValue);
  }

  Future<void> requestNotificationPermission() {
    return _notificationScheduler.requestPermissionIfNeeded();
  }

  Future<void> setPersistentNotificationEnabled(bool enabled) async {
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
    state = AsyncData(nextSnapshot);
    await _repository.saveSnapshot(nextSnapshot);
    await _notificationScheduler.syncPersistentNotification(
      enabled: enabled,
      tasks: nextSnapshot.tasks,
      nowUtc: DateTime.now().toUtc(),
      localePreference: nextSnapshot.preferredLocale,
      timeUnit: nextSnapshot.persistentNotificationTimeUnit,
    );
  }

  Future<void> setPreferredLocale(AppLocalePreference preferredLocale) async {
    final snapshot = state.requireValue;
    if (snapshot.preferredLocale == preferredLocale) {
      return;
    }
    final nextSnapshot = snapshot.copyWith(
      exportedAtUtc: DateTime.now().toUtc(),
      preferredLocale: preferredLocale,
    );
    state = AsyncData(nextSnapshot);
    await _repository.saveSnapshot(nextSnapshot);
    await _notificationScheduler.syncPersistentNotification(
      enabled: nextSnapshot.persistentNotificationEnabled,
      tasks: nextSnapshot.tasks,
      nowUtc: DateTime.now().toUtc(),
      localePreference: preferredLocale,
      timeUnit: nextSnapshot.persistentNotificationTimeUnit,
    );
  }

  Future<void> setPersistentNotificationTimeUnit(
    PersistentNotificationTimeUnit timeUnit,
  ) async {
    final snapshot = state.requireValue;
    if (snapshot.persistentNotificationTimeUnit == timeUnit) {
      return;
    }
    final nextSnapshot = snapshot.copyWith(
      exportedAtUtc: DateTime.now().toUtc(),
      persistentNotificationTimeUnit: timeUnit,
    );
    state = AsyncData(nextSnapshot);
    await _repository.saveSnapshot(nextSnapshot);
    await _notificationScheduler.syncPersistentNotification(
      enabled: nextSnapshot.persistentNotificationEnabled,
      tasks: nextSnapshot.tasks,
      nowUtc: DateTime.now().toUtc(),
      localePreference: nextSnapshot.preferredLocale,
      timeUnit: timeUnit,
    );
  }

  Future<void> setThemeSettings(AppThemeSettings themeSettings) async {
    final snapshot = state.requireValue;
    final nextSnapshot = snapshot.copyWith(
      exportedAtUtc: DateTime.now().toUtc(),
      themeSettings: themeSettings,
    );
    state = AsyncData(nextSnapshot);
    await _repository.saveSnapshot(nextSnapshot);
  }

  Future<void> setAlarmSettings(AppAlarmSettings alarmSettings) async {
    final snapshot = state.requireValue;
    final nextSnapshot = snapshot.copyWith(
      exportedAtUtc: DateTime.now().toUtc(),
      alarmSettings: alarmSettings,
    );
    state = AsyncData(nextSnapshot);
    await _repository.saveSnapshot(nextSnapshot);
    await _syncAlarmsSafely(
      settings: nextSnapshot.alarmSettings,
      tasks: nextSnapshot.tasks,
      localePreference: nextSnapshot.preferredLocale,
    );
  }

  Future<bool> canScheduleExactAlarms() {
    return _alarmScheduler.canScheduleExactAlarms();
  }

  Future<void> openExactAlarmSettings() {
    return _alarmScheduler.openExactAlarmSettings();
  }

  String get timezoneId => _timezoneService.currentTimezoneId;

  List<String> get timezoneIds => _timezoneService.timezoneIds;

  Future<bool> setTimezone(String timezoneId) async {
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
  }

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
      await _notificationScheduler.syncTask(
        task,
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
        tasks: tasks,
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
