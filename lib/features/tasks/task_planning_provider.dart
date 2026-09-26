import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/task_planning_repository.dart';
import '../../services/task_planning_service.dart';
import 'tasks_controller.dart';

final taskPlanningProvider = Provider<TaskPlanningService>((ref) {
  final service = TaskPlanningService(
    repository: CallbackTaskPlanningRepository(
      read: () async => (await ref.read(tasksControllerProvider.future)).planningData,
      write: (data) => ref.read(tasksControllerProvider.notifier).savePlanningData(data),
    ),
    addOrUpdateTask: (task) => ref.read(tasksControllerProvider.notifier).addOrUpdateTask(task),
    findTask: (id) {
      final tasks = ref.read(tasksControllerProvider).valueOrNull?.tasks;
      if (tasks == null) return null;
      for (final task in tasks) {
        if (task.id == id) return task;
      }
      return null;
    },
    deleteTask: (id) => ref.read(tasksControllerProvider.notifier).deleteTask(id),
  );
  ref.onDispose(service.dispose);
  return service;
});
