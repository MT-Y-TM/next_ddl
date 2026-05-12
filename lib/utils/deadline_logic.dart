import '../models/deadline_task.dart';
import '../models/milestone.dart';

Milestone? resolveNextMilestone(DeadlineTask task, DateTime nowUtc) {
  final milestones = [...task.milestones]
    ..sort((left, right) => left.dueAtUtc.compareTo(right.dueAtUtc));
  for (final milestone in milestones) {
    if (!milestone.dueAtUtc.isBefore(nowUtc)) {
      return milestone;
    }
  }
  if (!task.finalDueAtUtc.isBefore(nowUtc)) {
    return Milestone(
      id: '${task.id}_final',
      title: '最终截止',
      dueAtUtc: task.finalDueAtUtc,
      source: MilestoneSource.manual,
    );
  }
  return null;
}

List<DeadlineTask> sortTasks(List<DeadlineTask> tasks, DateTime nowUtc) {
  final sorted = [...tasks];
  sorted.sort((left, right) {
    final leftExpired = left.finalDueAtUtc.isBefore(nowUtc);
    final rightExpired = right.finalDueAtUtc.isBefore(nowUtc);
    if (leftExpired != rightExpired) {
      return leftExpired ? -1 : 1;
    }
    if (leftExpired && rightExpired) {
      final byFinal = left.finalDueAtUtc.compareTo(right.finalDueAtUtc);
      if (byFinal != 0) {
        return byFinal;
      }
    }

    final leftNext = resolveNextMilestone(left, nowUtc)?.dueAtUtc ??
        left.finalDueAtUtc;
    final rightNext = resolveNextMilestone(right, nowUtc)?.dueAtUtc ??
        right.finalDueAtUtc;
    final byNext = leftNext.compareTo(rightNext);
    if (byNext != 0) {
      return byNext;
    }
    return right.updatedAtUtc.compareTo(left.updatedAtUtc);
  });
  return sorted;
}

List<Milestone> generateQuarterMilestones({
  required DateTime nowUtc,
  required DateTime finalDueAtUtc,
  required String taskId,
}) {
  final total = finalDueAtUtc.difference(nowUtc);
  if (total.inSeconds <= 0) {
    return const [];
  }
  const percents = [0.25, 0.5, 0.75];
  return List<Milestone>.generate(percents.length, (index) {
    final percent = percents[index];
    final dueAtUtc = nowUtc.add(
      Duration(
        milliseconds: (total.inMilliseconds * percent).round(),
      ),
    );
    return Milestone(
      id: '${taskId}_generated_$index',
      title: '${(percent * 100).round()}% 节点',
      dueAtUtc: dueAtUtc,
      source: MilestoneSource.generated,
    );
  });
}

TaskUrgency resolveTaskUrgency(DeadlineTask task, DateTime nowUtc) {
  if (task.finalDueAtUtc.isBefore(nowUtc)) {
    return TaskUrgency.overdue;
  }
  if (task.finalDueAtUtc.difference(nowUtc) <= const Duration(hours: 24)) {
    return TaskUrgency.urgent;
  }
  return TaskUrgency.normal;
}

enum TaskUrgency {
  normal,
  urgent,
  overdue,
}
