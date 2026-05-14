import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_snapshot.dart';
import '../models/deadline_task.dart';

abstract class NotificationScheduler {
  Future<void> initialize();

  Future<void> requestPermissionIfNeeded();

  Future<void> syncPersistentNotification({
    required bool enabled,
    required List<DeadlineTask> tasks,
    required DateTime nowUtc,
    required AppLocalePreference localePreference,
    required PersistentNotificationTimeUnit timeUnit,
  });

  Future<void> syncTask(
    DeadlineTask task, {
    required AppLocalePreference localePreference,
  });

  Future<void> removeTask(String taskId);

  Future<void> removeAll();
}

final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  throw UnimplementedError('notificationSchedulerProvider must be overridden');
});
