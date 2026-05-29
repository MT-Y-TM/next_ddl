import '../models/deadline_task.dart';
import '../models/milestone.dart';

Milestone? resolveFutureMilestone(DeadlineTask task, DateTime nowUtc) {
  final milestones = [...task.milestones]
    ..sort((left, right) => left.dueAtUtc.compareTo(right.dueAtUtc));
  for (final milestone in milestones) {
    if (!milestone.dueAtUtc.isBefore(nowUtc)) {
      return milestone;
    }
  }
  return null;
}

Milestone? resolveNextMilestone(DeadlineTask task, DateTime nowUtc) {
  final futureMilestone = resolveFutureMilestone(task, nowUtc);
  if (futureMilestone != null) {
    return futureMilestone;
  }
  return null;
}

DateTime resolveActiveDeadlinePoint(DeadlineTask task, DateTime nowUtc) {
  return resolveFutureMilestone(task, nowUtc)?.dueAtUtc ?? task.finalDueAtUtc;
}

String resolvePersistentNotificationTargetTitle(
  DeadlineTask task,
  DateTime nowUtc,
) {
  final milestoneTitle = resolveFutureMilestone(task, nowUtc)?.title.trim();
  if (milestoneTitle != null) {
    return milestoneTitle;
  }
  return task.title.trim();
}

List<DeadlineTask> inProgressTasks(List<DeadlineTask> tasks, DateTime nowUtc) {
  return [
    for (final task in tasks)
      if (!task.finalDueAtUtc.isBefore(nowUtc)) task,
  ];
}

List<DeadlineTask> overdueTasks(List<DeadlineTask> tasks, DateTime nowUtc) {
  return [
    for (final task in tasks)
      if (task.finalDueAtUtc.isBefore(nowUtc)) task,
  ];
}

List<DeadlineTask> sortInProgressTasks(
  List<DeadlineTask> tasks,
  DateTime nowUtc,
) {
  final sorted = [...tasks];
  sorted.sort((left, right) {
    final byActivePoint = resolveActiveDeadlinePoint(
      left,
      nowUtc,
    ).compareTo(resolveActiveDeadlinePoint(right, nowUtc));
    if (byActivePoint != 0) {
      return byActivePoint;
    }
    return right.updatedAtUtc.compareTo(left.updatedAtUtc);
  });
  return sorted;
}

DeadlineTask? resolveMostUrgentInProgressTask(
  List<DeadlineTask> tasks,
  DateTime nowUtc,
) {
  final sorted = sortInProgressTasks(inProgressTasks(tasks, nowUtc), nowUtc);
  return sorted.isEmpty ? null : sorted.first;
}

List<DeadlineTask> sortOverdueTasks(List<DeadlineTask> tasks) {
  final sorted = [...tasks];
  sorted.sort((left, right) {
    final byFinalDue = left.finalDueAtUtc.compareTo(right.finalDueAtUtc);
    if (byFinalDue != 0) {
      return byFinalDue;
    }
    return right.updatedAtUtc.compareTo(left.updatedAtUtc);
  });
  return sorted;
}

List<DeadlineTask> sortTasks(List<DeadlineTask> tasks, DateTime nowUtc) {
  return [
    ...sortInProgressTasks(inProgressTasks(tasks, nowUtc), nowUtc),
    ...sortOverdueTasks(overdueTasks(tasks, nowUtc)),
  ];
}

List<Milestone> generateQuarterMilestones({
  required DateTime nowUtc,
  required DateTime finalDueAtUtc,
  required String taskId,
  required String Function(int percent) titleBuilder,
}) {
  final total = finalDueAtUtc.difference(nowUtc);
  if (total.inSeconds <= 0) {
    return const [];
  }
  const percents = [0.25, 0.5, 0.75];
  return List<Milestone>.generate(percents.length, (index) {
    final percent = percents[index];
    final dueAtUtc = nowUtc.add(
      Duration(milliseconds: (total.inMilliseconds * percent).round()),
    );
    return Milestone(
      id: '${taskId}_generated_$index',
      title: titleBuilder((percent * 100).round()),
      dueAtUtc: dueAtUtc,
      source: MilestoneSource.generated,
    );
  });
}

TaskUrgency resolveTaskUrgency(DeadlineTask task, DateTime nowUtc) {
  if (task.finalDueAtUtc.isBefore(nowUtc)) {
    return TaskUrgency.overdue;
  }
  if (resolveActiveDeadlinePoint(task, nowUtc).difference(nowUtc) <=
      const Duration(hours: 24)) {
    return TaskUrgency.urgent;
  }
  return TaskUrgency.normal;
}

double resolveRemainingProgress(DeadlineTask task, DateTime nowUtc) {
  final total = task.finalDueAtUtc.difference(task.createdAtUtc).inMilliseconds;
  if (total <= 0) {
    return task.finalDueAtUtc.isAfter(nowUtc) ? 1 : 0;
  }
  final remaining = task.finalDueAtUtc.difference(nowUtc).inMilliseconds;
  return (remaining / total).clamp(0, 1).toDouble();
}

enum TaskUrgency { normal, urgent, overdue }
