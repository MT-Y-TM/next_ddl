import 'package:flutter_test/flutter_test.dart';
import 'package:next_ddl/models/deadline_task.dart';
import 'package:next_ddl/models/task_recurrence.dart';
import 'package:next_ddl/models/task_template.dart';
import 'package:next_ddl/services/task_planning_repository.dart';
import 'package:next_ddl/services/task_planning_service.dart';
import 'package:timezone/data/latest.dart' as tz;

class MemoryPlanningRepository implements TaskPlanningRepository {
  TaskPlanningSnapshot value = TaskPlanningSnapshot();
  bool failNextSave = false;
  @override
  Future<TaskPlanningSnapshot> load() async =>
      TaskPlanningSnapshot.fromJson(value.toJson());
  @override
  Future<void> save(TaskPlanningSnapshot snapshot) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('storage unavailable');
    }
    value = TaskPlanningSnapshot.fromJson(snapshot.toJson());
  }
}

void main() {
  setUpAll(tz.initializeTimeZones);
  final now = DateTime.utc(2026, 1, 1);
  late MemoryPlanningRepository repository;
  late Map<String, DeadlineTask> tasks;
  late TaskPlanningService service;
  var failWrite = false;
  var failDelete = false;
  TaskTemplate template() => TaskTemplate(
    id: 't',
    title: 'Original',
    notificationsEnabled: true,
    alarmEnabled: true,
    reminderOffsetsSeconds: [3600],
    milestones: [const TemplateMilestone(title: 'Draft', offsetSeconds: -7200)],
  );
  TaskRecurrence series({String id = 's/a'}) => TaskRecurrence(
    id: id,
    revisions: [
      RecurrenceRevision(
        fromDate: '2026-01-01',
        template: template(),
        rule: TaskRecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          timezoneId: 'UTC',
          startDate: '2026-01-01',
        ),
      ),
    ],
  );
  TaskPlanningService newService() => TaskPlanningService(
    repository: repository,
    clock: () => now,
    findTask: (id) => tasks[id],
    addOrUpdateTask: (task) async {
      if (failWrite) {
        failWrite = false;
        throw StateError('scheduler unavailable');
      }
      tasks[task.id] = task;
    },
    deleteTask: (id) async {
      if (failDelete) {
        failDelete = false;
        throw StateError('delete unavailable');
      }
      tasks.remove(id);
    },
  );
  setUp(() {
    repository = MemoryPlanningRepository();
    tasks = {};
    failWrite = false;
    failDelete = false;
    service = newService();
  });
  tearDown(() => service.dispose());

  test('template CRUD and instantiated milestone offsets round trip', () async {
    await service.saveTemplate(template());
    await service.saveTemplate(template().copyWith(title: 'Changed'));
    expect(service.snapshot.templates.length, 1);
    final preview = service.previewTemplate(
      service.snapshot.templates['t']!,
      now.add(const Duration(days: 1)),
      'UTC',
    );
    expect(preview.title, 'Changed');
    expect(
      preview.milestones.single.dueAtUtc,
      preview.finalDueAtUtc.subtract(const Duration(hours: 2)),
    );
    await service.createFromPreview(preview);
    await service.createFromPreview(preview);
    await service.createSeries(series());
    await service.deleteTemplate('t');
    expect(tasks.length, 1);
    expect(service.snapshot.templates, isEmpty);
    expect(
      service.snapshot.series.values.single.revisions.single.template.title,
      'Original',
    );
    expect(
      () => template().copyWith(
        milestones: [const TemplateMilestone(title: ' ', offsetSeconds: -1)],
      ),
      throwsFormatException,
    );
  });

  test(
    'concurrent materialization, reload, deletion and clock rollback do not duplicate',
    () async {
      await service.createSeries(series());
      await Future.wait([
        service.materialize(limit: 2),
        service.materialize(limit: 2),
      ]);
      expect(tasks.length, 4);
      expect(
        tasks.keys.every((id) => id.startsWith('planning/s%2Fa/')),
        isTrue,
      );
      final deleted = tasks.keys.first;
      tasks.remove(deleted);
      await service.reload();
      await service.materialize(
        nowUtc: now.subtract(const Duration(days: 1)),
        limit: 2,
      );
      expect(tasks.containsKey(deleted), isFalse);
      expect(service.snapshot.issued.length, 6);
    },
  );

  test(
    'ledger failure never overwrites a successfully created and edited task',
    () async {
      await service.createSeries(series());
      repository.failNextSave = true;
      await expectLater(service.materialize(limit: 1), throwsStateError);
      final task = tasks.values.single;
      tasks[task.id] = task.copyWith(title: 'User edit', completedAtUtc: now);
      await service.materialize(limit: 1);
      expect(tasks.values.single.title, 'User edit');
      expect(tasks.values.single.isCompleted, isTrue);
      expect(service.snapshot.issued, contains(task.id));
    },
  );

  test(
    'pause disables both reminders; resume preserves modified task content',
    () async {
      await service.createSeries(series());
      await service.materialize(limit: 2);
      final ids = tasks.keys.toList();
      tasks[ids.first] = tasks[ids.first]!.copyWith(
        title: 'Personal title',
        tags: ['tag'],
      );
      await service.setStatus('s/a', RecurrenceStatus.paused);
      expect(
        tasks.values.every((t) => !t.notificationsEnabled && !t.alarmEnabled),
        isTrue,
      );
      expect(service.preview(nowUtc: now), isEmpty);
      final second = tasks[ids.last]!;
      tasks[second.id] = second.copyWith(
        note: 'Edited while paused',
        updatedAtUtc: now.add(const Duration(minutes: 1)),
      );
      service.dispose();
      service = newService();
      await service.setStatus('s/a', RecurrenceStatus.active);
      expect(tasks[ids.first]!.title, 'Personal title');
      expect(tasks[ids.first]!.tags, ['tag']);
      expect(tasks[ids.first]!.notificationsEnabled, isTrue);
      expect(tasks[ids.first]!.alarmEnabled, isTrue);
      expect(tasks[ids.last]!.note, 'Edited while paused');
      expect(tasks[ids.last]!.notificationsEnabled, isFalse);
      expect(service.snapshot.suspendedReminders, isEmpty);
    },
  );

  test(
    'termination persists and materialize retries interrupted cancellation',
    () async {
      await service.createSeries(series());
      await service.materialize(limit: 1);
      failWrite = true;
      await expectLater(
        service.setStatus('s/a', RecurrenceStatus.terminated),
        throwsStateError,
      );
      await service.reload();
      await service.materialize();
      expect(tasks.values.single.notificationsEnabled, isFalse);
      expect(tasks.values.single.alarmEnabled, isFalse);
      await expectLater(
        service.setStatus('s/a', RecurrenceStatus.active),
        throwsStateError,
      );
    },
  );

  test(
    'resume does not resurrect deleted, skipped or completed tasks',
    () async {
      await service.createSeries(series());
      await service.materialize(limit: 3);
      final ids = tasks.keys.toList();
      await service.setStatus('s/a', RecurrenceStatus.paused);
      tasks.remove(ids[0]);
      tasks[ids[1]] = tasks[ids[1]]!.copyWith(completedAtUtc: now);
      await service.skip('s/a', ids[2].split('/').last);
      await service.setStatus('s/a', RecurrenceStatus.active);
      expect(tasks.length, 1);
      expect(tasks.values.single.isCompleted, isTrue);
      expect(tasks.values.single.notificationsEnabled, isFalse);
    },
  );

  test('skip survives failed delete and is replayed at startup', () async {
    await service.createSeries(series());
    await service.materialize(limit: 1);
    failDelete = true;
    await expectLater(service.skip('s/a', '2026-01-01'), throwsStateError);
    await service.reload();
    await service.materialize(limit: 1);
    expect(tasks.containsKey(series().instanceId('2026-01-01')), isFalse);
    expect(
      service.snapshot.skipped,
      contains(series().instanceId('2026-01-01')),
    );
    await service.skip('s/a', '2026-01-03');
    expect(
      service.preview(nowUtc: now).any((p) => p.date == '2026-01-03'),
      isFalse,
    );
  });

  test(
    'single-instance and following edit boundaries preserve issued tasks',
    () async {
      await service.createSeries(series());
      await service.materialize(limit: 1);
      final original = tasks.values.single;
      await service.editOnlyThis(
        's/a',
        '2026-01-01',
        original.copyWith(title: 'Only this'),
      );
      RecurrenceRevision revision(String from) => RecurrenceRevision(
        fromDate: from,
        template: template().copyWith(title: 'Following'),
        rule: TaskRecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          timezoneId: 'UTC',
          startDate: from,
        ),
      );
      await expectLater(
        service.editFollowing('s/a', revision('2026-01-01')),
        throwsStateError,
      );
      await service.editFollowing('s/a', revision('2026-01-02'));
      await service.materialize(limit: 1);
      expect(tasks[original.id]!.title, 'Only this');
      expect(tasks[series().instanceId('2026-01-02')]!.title, 'Following');
    },
  );

  test(
    'snapshot is immutable, backward compatible and rejects duplicate IDs',
    () {
      expect(TaskPlanningSnapshot.fromJson({}).suspendedReminders, isEmpty);
      expect(() => service.snapshot.issued.add('bad'), throwsUnsupportedError);
      expect(
        () => TaskPlanningSnapshot.fromJson({'schemaVersion': 999}),
        throwsFormatException,
      );
      expect(
        () => TaskPlanningSnapshot.fromJson({
          'templates': [template().toJson(), template().toJson()],
        }),
        throwsFormatException,
      );
    },
  );

  test('daily/weekly use calendar days with inclusive start and end', () {
    final rule = TaskRecurrenceRule(
      frequency: RecurrenceFrequency.weekly,
      timezoneId: 'Asia/Shanghai',
      startDate: '2026-01-01',
      endDate: '2026-01-08',
      weekdays: {4},
    );
    expect(rule.dueOn(DateTime.utc(2026, 1, 1)), DateTime.utc(2026, 1, 1, 1));
    expect(rule.dueOn(DateTime.utc(2026, 1, 2)), isNull);
    expect(rule.dueOn(DateTime.utc(2026, 1, 8)), isNotNull);
    expect(rule.dueOn(DateTime.utc(2026, 1, 15)), isNull);
  });

  test(
    'DST gaps skip and folds choose earliest instant, including half-hour shifts',
    () {
      TaskRecurrenceRule rule(String zone, int hour, int minute) =>
          TaskRecurrenceRule(
            frequency: RecurrenceFrequency.daily,
            timezoneId: zone,
            startDate: '2026-01-01',
            hour: hour,
            minute: minute,
          );
      expect(
        rule('America/New_York', 2, 30).dueOn(DateTime.utc(2026, 3, 8)),
        isNull,
      );
      expect(
        rule('America/New_York', 1, 30).dueOn(DateTime.utc(2026, 11, 1)),
        DateTime.utc(2026, 11, 1, 5, 30),
      );
      expect(
        rule('Australia/Lord_Howe', 2, 15).dueOn(DateTime.utc(2026, 10, 4)),
        isNull,
      );
      expect(
        rule('Australia/Lord_Howe', 1, 45).dueOn(DateTime.utc(2026, 4, 5)),
        DateTime.utc(2026, 4, 4, 14, 45),
      );
    },
  );

  test(
    'monthly skip/clamp handles leap years and never drifts from day 31',
    () {
      TaskRecurrenceRule rule(MonthEndPolicy policy) => TaskRecurrenceRule(
        frequency: RecurrenceFrequency.monthly,
        timezoneId: 'UTC',
        startDate: '2024-01-01',
        monthDay: 31,
        monthEndPolicy: policy,
      );
      expect(
        rule(MonthEndPolicy.skip).dueOn(DateTime.utc(2024, 2, 29)),
        isNull,
      );
      final clamp = TaskRecurrenceRule.fromJson(
        rule(MonthEndPolicy.lastDay).toJson(),
      );
      for (final date in [
        DateTime.utc(2024, 2, 29),
        DateTime.utc(2025, 2, 28),
        DateTime.utc(2026, 4, 30),
        DateTime.utc(2026, 5, 31),
      ]) {
        expect(clamp.dueOn(date), date.add(const Duration(hours: 9)));
      }
      expect(clamp.dueOn(DateTime.utc(2026, 5, 30)), isNull);
      expect(() => parsePlanningDate('2026-02-30'), throwsFormatException);
    },
  );
}
