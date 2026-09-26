import 'package:flutter_test/flutter_test.dart';
import 'package:next_ddl/models/deadline_task.dart';
import 'package:next_ddl/models/milestone.dart';
import 'package:next_ddl/utils/deadline_logic.dart';
import 'package:next_ddl/utils/task_actions.dart';

void main() {
  final now = DateTime.utc(2026, 9, 25, 12);
  DeadlineTask task() => DeadlineTask(
    id: 'task', title: 'Task', note: '', timezoneId: 'UTC',
    createdAtUtc: now.subtract(const Duration(days: 2)), updatedAtUtc: now,
    finalDueAtUtc: now.add(const Duration(days: 2)),
    notificationsEnabled: true, reminderOffsetsSeconds: const [0, 600],
    milestones: [
      Milestone(id: 'past', title: '', dueAtUtc: now.subtract(const Duration(hours: 1)), source: MilestoneSource.manual),
      Milestone(id: 'next', title: 'First', dueAtUtc: now.add(const Duration(hours: 1)), source: MilestoneSource.manual),
      Milestone(id: 'last', title: 'Second', dueAtUtc: now.add(const Duration(hours: 2)), source: MilestoneSource.manual),
    ],
  );

  test('completed milestones advance the active deadline; archived tasks leave both lists', () {
    final original = task();
    final advanced = original.copyWith(milestones: [
      for (final node in original.milestones)
        node.id == 'next' ? node.copyWith(completedAtUtc: now) : node,
    ]);
    expect(resolveFutureMilestone(advanced, now)?.id, 'last');
    final archived = advanced.copyWith(completedAtUtc: now);
    expect(inProgressTasks([archived], now), isEmpty);
    expect(overdueTasks([archived], now.add(const Duration(days: 5))), isEmpty);
    expect(resolveFutureMilestone(archived, now), isNull);
    expect(inProgressTasks([archived.copyWith(clearCompletedAt: true)], now), hasLength(1));
  });

  test('completed and legacy JSON round trip with tags', () {
    final original = task().copyWith(completedAtUtc: now, tags: ['Study']);
    final decoded = DeadlineTask.fromJson(original.toJson());
    expect(decoded.completedAtUtc, now);
    expect(decoded.tags, ['Study']);
    final legacy = original.toJson()..remove('completedAtUtc')..remove('tags');
    expect(DeadlineTask.fromJson(legacy).isCompleted, false);
    expect(DeadlineTask.fromJson(legacy).tags, isEmpty);
    final node = original.milestones.first.copyWith(completedAtUtc: now);
    expect(Milestone.fromJson(node.toJson()).completedAtUtc, now);
    expect(node.copyWith(clearCompletedAt: true).isCompleted, false);
  });

  test('postpone moves future uncompleted nodes only, preserving history', () {
    final base = task();
    final source = base.copyWith(milestones: [
      base.milestones[0], base.milestones[1], base.milestones[2].copyWith(completedAtUtc: now),
    ]);
    final due = source.finalDueAtUtc.add(const Duration(days: 1));
    final shifted = postponeDeadlineTask(source, due, nowUtc: now, shiftFutureMilestones: true);
    expect(shifted.finalDueAtUtc, due);
    expect(shifted.milestones.first.dueAtUtc, source.milestones.first.dueAtUtc);
    expect(shifted.milestones.firstWhere((m) => m.id == 'last').dueAtUtc, source.milestones.last.dueAtUtc);
    expect(shifted.milestones.firstWhere((m) => m.id == 'next').dueAtUtc, now.add(const Duration(hours: 25)));
    final unchanged = postponeDeadlineTask(source, due, nowUtc: now);
    expect(unchanged.milestones.map((m) => m.dueAtUtc), source.milestones.map((m) => m.dueAtUtc));
  });

  test('invalid deadline and completed task cannot be postponed', () {
    expect(() => postponeDeadlineTask(task(), now, nowUtc: now), throwsArgumentError);
    expect(() => postponeDeadlineTask(task(), now.add(const Duration(minutes: 30)), nowUtc: now), throwsArgumentError);
    expect(() => postponeDeadlineTask(task().copyWith(completedAtUtc: now), now.add(const Duration(days: 3)), nowUtc: now), throwsArgumentError);
  });
}
