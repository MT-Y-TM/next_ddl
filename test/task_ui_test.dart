import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:next_ddl/features/tasks/task_detail_page.dart';
import 'package:next_ddl/features/tasks/task_edit_page.dart';
import 'package:next_ddl/features/tasks/task_list_page.dart';
import 'package:next_ddl/features/tasks/task_postpone_dialog.dart';
import 'package:next_ddl/features/tasks/task_ui_helpers.dart';
import 'package:next_ddl/features/tasks/task_ui_strings.dart';
import 'package:next_ddl/features/tasks/tasks_controller.dart';
import 'package:next_ddl/l10n/app_localizations.dart';
import 'package:next_ddl/models/app_snapshot.dart';
import 'package:next_ddl/models/deadline_task.dart';
import 'package:next_ddl/models/milestone.dart';
import 'package:next_ddl/services/timezone_service.dart';
import 'package:next_ddl/utils/task_actions.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

final _now = DateTime.utc(2040, 1, 31, 12);

DeadlineTask _task(
  String id, {
  List<String> tags = const [],
  String note = '',
  DateTime? completed,
  List<Milestone> nodes = const [],
  DateTime? due,
}) => DeadlineTask(
  id: id,
  title: id,
  note: note,
  timezoneId: 'UTC',
  createdAtUtc: _now,
  updatedAtUtc: _now,
  finalDueAtUtc: due ?? _now.add(const Duration(days: 2)),
  milestones: nodes,
  reminderOffsetsSeconds: const [],
  notificationsEnabled: false,
  tags: tags,
  completedAtUtc: completed,
);

Milestone _node(String id, DateTime due, {bool completed = false}) => Milestone(
  id: id,
  title: id,
  dueAtUtc: due,
  source: MilestoneSource.manual,
  completedAtUtc: completed ? _now : null,
);

// Keep platform scheduling out of widget tests; controller scheduling is tested separately.
class _UiController extends TasksController {
  _UiController(this.initial);
  final List<DeadlineTask> initial;
  bool fail = false;
  int writes = 0;
  List<DeadlineTask> get tasks => state.requireValue.tasks;
  @override
  Future<AppSnapshot> build() async =>
      AppSnapshot.empty().copyWith(tasks: initial);
  @override
  String get timezoneId => 'UTC';
  @override
  Future<void> addOrUpdateTask(DeadlineTask task) async {
    if (fail) throw StateError('private scheduling detail');
    writes++;
    state = AsyncData(
      state.requireValue.copyWith(
        tasks: [
          for (final old in tasks)
            if (old.id != task.id) old,
          task,
        ],
      ),
    );
  }

  @override
  Future<void> restoreTask(DeadlineTask task) => addOrUpdateTask(task);
  @override
  Future<void> setTaskCompleted(String id, bool completed) => addOrUpdateTask(
    tasks
        .firstWhere((t) => t.id == id)
        .copyWith(
          completedAtUtc: completed ? _now : null,
          clearCompletedAt: !completed,
        ),
  );
  @override
  Future<void> setMilestoneCompleted(
    String taskId,
    String milestoneId,
    bool completed,
  ) {
    final task = tasks.firstWhere((t) => t.id == taskId);
    return addOrUpdateTask(
      task.copyWith(
        milestones: [
          for (final node in task.milestones)
            if (node.id == milestoneId)
              node.copyWith(
                completedAtUtc: completed ? _now : null,
                clearCompletedAt: !completed,
              )
            else
              node,
        ],
      ),
    );
  }

  @override
  Future<void> postponeTask(
    String id,
    DateTime due, {
    bool shiftFutureMilestones = false,
  }) => addOrUpdateTask(
    postponeDeadlineTask(
      tasks.firstWhere((t) => t.id == id),
      due,
      nowUtc: DateTime.now().toUtc(),
      shiftFutureMilestones: shiftFutureMilestones,
    ),
  );
  @override
  Future<void> removeTag(String tag) async {
    writes++;
    state = AsyncData(
      state.requireValue.copyWith(
        tasks: [
          for (final task in tasks)
            task.copyWith(tags: task.tags.where((t) => t != tag).toList()),
        ],
      ),
    );
  }
}

class _Timezone extends DeviceTimezoneService {
  _Timezone([this.zone = 'UTC']);
  final String zone;
  @override
  String get currentTimezoneId => zone;
  @override
  tz.Location get location => tz.getLocation(zone);
  @override
  DateTime utcToConfigured(DateTime value) =>
      tz.TZDateTime.from(value, location);
  @override
  DateTime localToUtc(DateTime value) => tz.TZDateTime(
    location,
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
  ).toUtc();
}

Future<_UiController> _pump(
  WidgetTester tester,
  Widget page, {
  List<DeadlineTask> tasks = const [],
  String locale = 'en',
  _Timezone? timezone,
}) async {
  final controller = _UiController(tasks);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tasksControllerProvider.overrideWith(() => controller),
        timezoneServiceProvider.overrideWithValue(timezone ?? _Timezone()),
        nowProvider.overrideWith((ref) => Stream.value(_now)),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await ProviderScope.containerOf(tester.element(find.byWidget(page))).read(tasksControllerProvider.future);
  await tester.pumpAndSettle();
  return controller;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(tz_data.initializeTimeZones);

  test('tags normalize separators; multilingual filtering preserves order', () {
    expect(parseTaskTags(' work，学习\nwork, , 日本語 '), ['work', '学习', '日本語']);
    final tasks = [
      _task('First', note: '日本語 学习', tags: ['work']),
      _task('Second'),
    ];
    expect(filterTaskUi(tasks, ' 日本語 ', tag: 'work'), [tasks.first]);
    expect(filterTaskUi(tasks, ' FIRST '), [tasks.first]);
    expect(filterTaskUi(tasks, '  '), tasks);
    expect(filterTaskUi(tasks, '', untagged: true), [tasks.last]);
  });

  testWidgets(
    'search notes, combine tags, clear and search archive separately',
    (tester) async {
      final controller = await _pump(
        tester,
        const TaskListPage(),
        tasks: [
          _task('Active', note: '日本語', tags: ['work']),
          _task('Other'),
          _task('Archived match', note: '日本語', tags: ['work'], completed: _now),
        ],
      );
      await tester.enterText(find.byType(TextField), ' 日本語 ');
      await tester.pumpAndSettle();
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Other'), findsNothing);
      expect(find.text('Archived match'), findsNothing);
      await _tap(tester, find.widgetWithText(ChoiceChip, 'Untagged'));
      expect(find.text('No matching tasks'), findsOneWidget);
      await _tap(tester, find.byTooltip('Clear filters'));
      expect(find.text('Other'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '日本語');
      await _tap(tester, find.widgetWithText(ChoiceChip, 'work'));
      await _tap(tester, find.text('Archived'));
      expect(find.text('Archived match'), findsOneWidget);
      expect(find.text('Active'), findsNothing);
      expect(controller.writes, 0);
    },
  );

  testWidgets('tag deletion keeps tasks and clears selected tag', (
    tester,
  ) async {
    final controller = await _pump(
      tester,
      const TaskListPage(),
      tasks: [
        _task('Tagged', tags: ['work']),
      ],
    );
    await _tap(tester, find.widgetWithText(ChoiceChip, 'work'));
    await _tap(tester, find.byTooltip('Manage tags'));
    await _tap(tester, find.byTooltip('Delete'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Delete'));
    expect(controller.tasks.single.tags, isEmpty);
    expect(find.text('No tags yet'), findsOneWidget);
    await _tap(tester, find.widgetWithText(TextButton, 'Confirm'));
    expect(find.text('Tagged'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All tags'))
          .selected,
      isTrue,
    );
  });

  testWidgets('task completion, undo and archive reopen update the page', (
    tester,
  ) async {
    final controller = await _pump(
      tester,
      const TaskDetailPage(taskId: 'Task'),
      tasks: [_task('Task')],
    );
    await _tap(tester, find.text('Complete task'));
    expect(controller.tasks.single.isCompleted, isTrue);
    expect(find.text('Reopen'), findsOneWidget);
    expect(find.text('Postpone'), findsNothing);
    await _tap(tester, find.text('Undo'));
    expect(controller.tasks.single.isCompleted, isFalse);
    await _tap(tester, find.text('Complete task'));
    await _tap(tester, find.text('Reopen'));
    expect(controller.tasks.single.isCompleted, isFalse);
  });

  testWidgets(
    'past nodes stay visible; completion falls back to final deadline and can undo',
    (tester) async {
      final controller = await _pump(
        tester,
        const TaskDetailPage(taskId: 'Task'),
        tasks: [
          _task(
            'Task',
            nodes: [
              _node('Past', _now.subtract(const Duration(days: 1))),
              _node('Future', _now.add(const Duration(hours: 1))),
            ],
          ),
        ],
      );
      await _tap(
        tester,
        find.descendant(
          of: find.widgetWithText(ListTile, 'Future'),
          matching: find.byType(Checkbox),
        ),
      );
      expect(controller.tasks.single.milestones.last.isCompleted, isTrue);
      expect(find.text('Past'), findsOneWidget);
      final context = tester.element(find.byType(TaskDetailPage));
      final l = AppLocalizations.of(context)!;
      expect(find.text(l.nextNodeValue(l.finalDeadline)), findsOneWidget);
      await _tap(tester, find.text('Undo'));
      expect(controller.tasks.single.milestones.last.isCompleted, isFalse);
    },
  );

  testWidgets(
    'postpone preview shifts only future incomplete nodes; cancel, save and undo',
    (tester) async {
      // Use real-time-relative nodes because the dialog validates at submission time.
      final now = DateTime.now().toUtc();
      final task = _task(
        'Task',
        due: now.add(const Duration(days: 2)),
        nodes: [
          _node('Past', now.subtract(const Duration(days: 1))),
          _node('Done', now.add(const Duration(hours: 1)), completed: true),
          _node('Future', now.add(const Duration(hours: 2))),
        ],
      );
      final controller = await _pump(
        tester,
        const TaskDetailPage(taskId: 'Task'),
        tasks: [task],
      );
      await _tap(tester, find.text('Postpone'));
      await _tap(tester, find.text('+1 day'));
      await _tap(tester, find.byType(SwitchListTile));
      final preview = find.byType(TaskPostponeDialog);
      for (final node in task.milestones) {
        final expected = node.id == 'Future'
            ? node.dueAtUtc.add(const Duration(days: 1))
            : node.dueAtUtc;
        expect(
          find.descendant(
            of: preview,
            matching: find.text(taskUiDate(expected)),
          ),
          findsOneWidget,
        );
      }
      await _tap(tester, find.text('Cancel'));
      expect(controller.writes, 0);
      await _tap(tester, find.text('Postpone'));
      await _tap(tester, find.text('Confirm'));
      expect(
        controller.tasks.single.finalDueAtUtc,
        task.finalDueAtUtc.add(const Duration(hours: 1)),
      );
      await _tap(tester, find.text('Undo'));
      expect(controller.tasks.single.finalDueAtUtc, task.finalDueAtUtc);
    },
  );

  testWidgets(
    'invalid deadline disables submit and custom picker cancellation preserves preview',
    (tester) async {
      final task = _task('Old', due: DateTime.utc(2001));
      await _pump(
        tester,
        Scaffold(
          body: TaskPostponeDialog(task: task, timezone: _Timezone()),
        ),
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm'))
            .onPressed,
        isNull,
      );
      await _tap(tester, find.text('Custom time'));
      await _tap(tester, find.descendant(of: find.byType(DatePickerDialog), matching: find.text('Cancel')));
      expect(find.text('2001-01-01 00:00 → 2001-01-01 01:00'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm'))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('mutation failure is localized and does not report success', (
    tester,
  ) async {
    final controller = await _pump(
      tester,
      const TaskDetailPage(taskId: 'Task'),
      tasks: [_task('Task')],
    );
    controller.fail = true;
    await _tap(tester, find.text('Complete task'));
    expect(controller.tasks.single.isCompleted, isFalse);
    expect(
      find.textContaining('Operation or reminder scheduling failed'),
      findsOneWidget,
    );
    expect(find.text('Updated'), findsNothing);
    expect(find.textContaining('private scheduling detail'), findsNothing);
  });

  testWidgets('custom date and time confirm uses configured timezone', (tester) async {
    final timezone = _Timezone('Asia/Tokyo');
    final due = DateTime.utc(2040, 1, 31, 16, 30);
    TaskPostponeChoice? choice;
    await _pump(tester, Scaffold(body: Builder(builder: (context) => TextButton(
      onPressed: () async {
        choice = await showDialog<TaskPostponeChoice>(context: context,
          builder: (_) => TaskPostponeDialog(task: _task('Custom', due: due), timezone: timezone));
      }, child: const Text('Open'),
    ))));
    await _tap(tester, find.text('Open'));
    expect(find.text('2040-02-01 01:30 → 2040-02-01 02:30'), findsOneWidget);
    await _tap(tester, find.text('Custom time'));
    await _tap(tester, find.descendant(of: find.byType(DatePickerDialog), matching: find.text('OK')));
    await _tap(tester, find.descendant(of: find.byType(TimePickerDialog), matching: find.text('OK')));
    await _tap(tester, find.text('Confirm'));
    expect(choice!.dueUtc, due.add(const Duration(hours: 1)));
    expect(choice!.shift, isFalse);
  });

  testWidgets('one day means 24 UTC hours across daylight saving', (tester) async {
    final timezone = _Timezone('America/New_York');
    final due = DateTime.utc(2027, 3, 13, 17);
    await _pump(tester, Scaffold(body: TaskPostponeDialog(
      task: _task('DST', due: due), timezone: timezone)));
    await _tap(tester, find.text('+1 day'));
    expect(find.text('2027-03-13 12:00 → 2027-03-14 13:00'), findsOneWidget);
  });

  testWidgets('editing tags preserves task and milestone completion', (tester) async {
    final task = _task('Archived', completed: _now, tags: ['old'], nodes: [
      _node('Done', _now.add(const Duration(hours: 1)), completed: true),
    ]);
    final controller = await _pump(tester, TaskEditPage(existingTask: task), tasks: [task]);
    await tester.enterText(find.byType(TextField).at(2), 'work，学习,work');
    final l = AppLocalizations.of(tester.element(find.byType(TaskEditPage)))!;
    await tester.scrollUntilVisible(find.text(l.saveChanges), 250,
      scrollable: find.byType(Scrollable).first);
    await _tap(tester, find.text(l.saveChanges));
    expect(controller.tasks.single.tags, ['work', '学习']);
    expect(controller.tasks.single.completedAtUtc, task.completedAtUtc);
    expect(controller.tasks.single.milestones.single.completedAtUtc, task.milestones.single.completedAtUtc);
    expect(controller.writes, 1);
  });

  testWidgets('large lists are lazy and searching does not mutate tasks', (tester) async {
    final controller = await _pump(tester, const TaskListPage(), tasks: [
      for (var i = 0; i < 500; i++) _task('Task $i'),
    ]);
    expect(find.text('Task 499'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Task 499');
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((widget) => widget is Text && widget.data == 'Task 499'), findsOneWidget);
    expect(controller.tasks, hasLength(500));
    expect(controller.writes, 0);
  });

  for (final locale in ['zh', 'en', 'ja']) {
    testWidgets('$locale archive empty state and tag editor are localized', (
      tester,
    ) async {
      await _pump(tester, const TaskListPage(), locale: locale);
      var strings = TaskUiStrings(tester.element(find.byType(TaskListPage)));
      await _tap(tester, find.text(strings.archived));
      expect(find.text(strings.emptyArchive), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, const TaskEditPage(), locale: locale);
      strings = TaskUiStrings(tester.element(find.byType(TaskEditPage)));
      expect(find.text(strings.tags), findsOneWidget);
      expect(find.text(strings.tagsHint), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
