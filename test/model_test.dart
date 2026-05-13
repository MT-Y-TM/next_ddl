import 'package:flutter_test/flutter_test.dart';
import 'package:next_ddl/models/app_snapshot.dart';
import 'package:next_ddl/models/deadline_task.dart';
import 'package:next_ddl/models/milestone.dart';
import 'package:next_ddl/services/timezone_service.dart';
import 'package:next_ddl/utils/deadline_logic.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  test('snapshot json round trip keeps task data', () {
    final snapshot = AppSnapshot(
      schemaVersion: 1,
      exportedAtUtc: DateTime.parse('2026-01-02T00:00:00.000Z'),
      persistentNotificationEnabled: true,
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
    expect(decoded.persistentNotificationEnabled, isTrue);
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

  test('remaining progress counts down from creation to final deadline', () {
    final createdAt = DateTime.utc(2026, 1, 1);
    final task = DeadlineTask(
      id: 'task_1',
      title: '毕业设计',
      note: '',
      timezoneId: 'Asia/Shanghai',
      createdAtUtc: createdAt,
      updatedAtUtc: createdAt,
      finalDueAtUtc: DateTime.utc(2026, 1, 11),
      milestones: const [],
      reminderOffsetsSeconds: const [],
      notificationsEnabled: false,
    );

    expect(resolveRemainingProgress(task, createdAt), 1);
    expect(resolveRemainingProgress(task, DateTime.utc(2026, 1, 6)), 0.5);
    expect(resolveRemainingProgress(task, DateTime.utc(2026, 1, 11)), 0);
    expect(resolveRemainingProgress(task, DateTime.utc(2026, 1, 12)), 0);
  });

  test('remaining progress handles invalid task time range', () {
    final now = DateTime.utc(2026, 1, 1);
    final futureTask = DeadlineTask(
      id: 'task_1',
      title: '未来任务',
      note: '',
      timezoneId: 'Asia/Shanghai',
      createdAtUtc: DateTime.utc(2026, 1, 2),
      updatedAtUtc: now,
      finalDueAtUtc: DateTime.utc(2026, 1, 1, 12),
      milestones: const [],
      reminderOffsetsSeconds: const [],
      notificationsEnabled: false,
    );
    final overdueTask = futureTask.copyWith(
      finalDueAtUtc: DateTime.utc(2025, 12, 31),
    );

    expect(resolveRemainingProgress(futureTask, now), 1);
    expect(resolveRemainingProgress(overdueTask, now), 0);
  });

  test('configured timezone converts selected wall time to utc', () async {
    SharedPreferences.setMockInitialValues({
      DeviceTimezoneService.storageKey: 'Asia/Shanghai',
    });
    final service = DeviceTimezoneService();
    await service.initialize();

    final utc = service.localToUtc(DateTime(2026, 1, 1, 20));

    expect(utc, DateTime.utc(2026, 1, 1, 12));
  });

  test('configured timezone converts utc to selected wall time', () async {
    SharedPreferences.setMockInitialValues({
      DeviceTimezoneService.storageKey: 'Asia/Shanghai',
    });
    final service = DeviceTimezoneService();
    await service.initialize();

    final local = service.utcToConfigured(DateTime.utc(2026, 1, 1, 12));

    expect(local.year, 2026);
    expect(local.month, 1);
    expect(local.day, 1);
    expect(local.hour, 20);
  });

  test('invalid configured timezone is ignored', () async {
    SharedPreferences.setMockInitialValues({
      DeviceTimezoneService.storageKey: 'Asia/Shanghai',
    });
    final service = DeviceTimezoneService();
    await service.initialize();

    final changed = await service.setTimezone('Not/A_Timezone');

    expect(changed, isFalse);
    expect(service.currentTimezoneId, 'Asia/Shanghai');
  });
}
