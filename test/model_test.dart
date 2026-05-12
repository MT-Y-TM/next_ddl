import 'package:flutter_test/flutter_test.dart';
import 'package:next_ddl/models/app_snapshot.dart';
import 'package:next_ddl/models/deadline_task.dart';
import 'package:next_ddl/models/milestone.dart';
import 'package:next_ddl/utils/deadline_logic.dart';

void main() {
  test('snapshot json round trip keeps task data', () {
    final snapshot = AppSnapshot(
      schemaVersion: 1,
      exportedAtUtc: DateTime.parse('2026-01-02T00:00:00.000Z'),
      tasks: [
        DeadlineTask(
          id: 'task_1',
          title: '毕业设计',
          note: '最终答辩',
          timezoneId: 'Asia/Shanghai',
          createdAtUtc: DateTime.parse('2026-01-01T00:00:00.000Z'),
          updatedAtUtc: DateTime.parse('2026-01-02T00:00:00.000Z'),
          finalDueAtUtc: DateTime.parse('2026-02-01T12:00:00.000Z'),
          milestones: [
            Milestone(
              id: 'm1',
              title: '开题',
              dueAtUtc: DateTime.parse('2026-01-10T12:00:00.000Z'),
              source: MilestoneSource.manual,
            ),
          ],
          reminderOffsetsSeconds: const [0, 3600, 86400],
          notificationsEnabled: true,
        ),
      ],
    );

    final decoded = AppSnapshot.fromJson(snapshot.toJson());

    expect(decoded.schemaVersion, 1);
    expect(decoded.tasks.single.title, '毕业设计');
    expect(decoded.tasks.single.reminderOffsetsSeconds, [0, 3600, 86400]);
    expect(decoded.tasks.single.milestones.single.title, '开题');
  });

  test('generate default milestones creates 25 50 75 markers', () {
    final now = DateTime.utc(2026, 1, 1);
    final milestones = generateQuarterMilestones(
      nowUtc: now,
      finalDueAtUtc: DateTime.utc(2026, 1, 9),
      taskId: 'task_1',
    );

    expect(milestones.length, 3);
    expect(milestones[0].title, '25% 节点');
    expect(milestones[1].title, '50% 节点');
    expect(milestones[2].title, '75% 节点');
    expect(
      milestones.every((item) => item.source == MilestoneSource.generated),
      isTrue,
    );
  });
}
