import '../models/deadline_task.dart';

DeadlineTask postponeDeadlineTask(
  DeadlineTask task,
  DateTime finalDueAtUtc, {
  required DateTime nowUtc,
  bool shiftFutureMilestones = false,
}) {
  final due = finalDueAtUtc.toUtc();
  if (task.isCompleted || !due.isAfter(nowUtc)) {
    throw ArgumentError('The new deadline must be in the future for an active task.');
  }
  final delta = due.difference(task.finalDueAtUtc);
  final milestones = [
    for (final node in task.milestones)
      if (shiftFutureMilestones && !node.isCompleted && node.dueAtUtc.isAfter(nowUtc))
        node.copyWith(dueAtUtc: node.dueAtUtc.add(delta))
      else
        node,
  ];
  if (milestones.any((node) => !node.dueAtUtc.isBefore(due))) {
    throw ArgumentError('Milestones must be before the final deadline.');
  }
  milestones.sort((a, b) => a.dueAtUtc.compareTo(b.dueAtUtc));
  return task.copyWith(finalDueAtUtc: due, milestones: milestones, updatedAtUtc: nowUtc);
}
