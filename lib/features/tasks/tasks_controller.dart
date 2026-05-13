import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_snapshot.dart';
import '../../models/deadline_task.dart';
import '../../models/milestone.dart';
import '../../services/app_info_service.dart';
import '../../services/deadline_repository.dart';
import '../../services/notification_scheduler.dart';
import '../../services/timezone_service.dart';
import '../../utils/deadline_logic.dart';

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
  TimezoneService get _timezoneService => ref.read(timezoneServiceProvider);

  @override
  Future<AppSnapshot> build() async {
    final snapshot = await _repository.loadSnapshot();
    await _notificationScheduler.syncPersistentNotification(
      enabled: snapshot.persistentNotificationEnabled,
      tasks: snapshot.tasks,
      nowUtc: DateTime.now().toUtc(),
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
    await _syncAll(nextSnapshot.tasks);
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
    await _syncAll(nextSnapshot.tasks);
  }

  Future<AppSnapshot?> importSnapshot() async {
    final imported = await _repository.importSnapshot();
    if (imported == null) {
      return null;
    }
    state = AsyncData(imported);
    await _repository.saveSnapshot(imported);
    await _notificationScheduler.removeAll();
    await _syncAll(imported.tasks);
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
    );
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
      await _syncAll(snapshot.tasks);
      state = AsyncData(snapshot);
    }
    return true;
  }

  List<Milestone> generateQuarterNodes(DateTime finalDueAtUtc, String taskId) {
    return generateQuarterMilestones(
      nowUtc: DateTime.now().toUtc(),
      finalDueAtUtc: finalDueAtUtc,
      taskId: taskId,
    );
  }

  Future<void> _syncAll(List<DeadlineTask> tasks) async {
    for (final task in tasks) {
      await _notificationScheduler.syncTask(task);
    }
    final snapshot = state.valueOrNull;
    await _notificationScheduler.syncPersistentNotification(
      enabled: snapshot?.persistentNotificationEnabled ?? false,
      tasks: tasks,
      nowUtc: DateTime.now().toUtc(),
    );
  }
}
