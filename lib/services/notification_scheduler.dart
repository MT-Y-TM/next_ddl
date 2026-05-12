import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/deadline_task.dart';

abstract class NotificationScheduler {
  Future<void> initialize();

  Future<void> requestPermissionIfNeeded();

  Future<void> syncTask(DeadlineTask task);

  Future<void> removeTask(String taskId);

  Future<void> removeAll();
}

final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  throw UnimplementedError('notificationSchedulerProvider must be overridden');
});
