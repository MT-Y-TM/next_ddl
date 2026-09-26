import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:next_ddl/features/tasks/task_planning_page.dart';
import 'package:next_ddl/features/tasks/task_planning_strings.dart';
import 'package:next_ddl/models/deadline_task.dart';
import 'package:next_ddl/models/task_recurrence.dart';
import 'package:next_ddl/models/task_template.dart';
import 'package:next_ddl/services/task_planning_repository.dart';
import 'package:next_ddl/services/task_planning_service.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  setUpAll(tz.initializeTimeZones);
  for (final language in ['zh', 'en', 'ja']) {
    testWidgets(
      '$language template CRUD validates input and confirms deletion',
      (tester) async {
        Map<String, dynamic> data = {};
        final service = TaskPlanningService(
          repository: CallbackTaskPlanningRepository(
            read: () async => data,
            write: (v) async => data = v,
          ),
          findTask: (_) => null,
          addOrUpdateTask: (_) async {},
          deleteTask: (_) async {},
        );
        addTearDown(service.dispose);
        await service.initialize();
        final locale = Locale(language);
        final s = TaskPlanningStrings(locale);
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: const [Locale('zh'), Locale('en'), Locale('ja')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: TaskPlanningPage(service: service),
          ),
        );
        expect(find.text(s.text('title')), findsOneWidget);
        await tester.tap(find.text(s.text('new')));
        await pumpDialog(tester);
        await tester.tap(find.text(s.text('save')));
        await pumpDialog(tester);
        expect(find.text(s.text('error')), findsOneWidget);
        await tester.enterText(find.byType(TextField).first, 'Template A');
        await tester.tap(find.text(s.text('save')));
        await tester.pumpAndSettle();
        expect(service.snapshot.templates.values.single.title, 'Template A');
        await tester.ensureVisible(find.text(s.text('edit')));
        await tester.tap(find.text(s.text('edit')));
        await pumpDialog(tester);
        await tester.enterText(find.byType(TextField).first, 'Template B');
        await tester.tap(find.text(s.text('save')));
        await tester.pumpAndSettle();
        expect(service.snapshot.templates.values.single.title, 'Template B');
        await tester.ensureVisible(find.text(s.text('delete')));
        await tester.tap(find.text(s.text('delete')));
        await pumpDialog(tester);
        await tester.tap(find.text(s.text('cancel')));
        await tester.pumpAndSettle();
        expect(service.snapshot.templates.length, 1);
        await tester.tap(find.text(s.text('delete')));
        await pumpDialog(tester);
        await tester.tap(find.text(s.text('save')));
        await tester.pumpAndSettle();
        expect(service.snapshot.templates, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'pause/resume and terminate use service and display translated policy',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic> data = {};
      final tasks = <String, DeadlineTask>{};
      final service = TaskPlanningService(
        repository: CallbackTaskPlanningRepository(
          read: () async => data,
          write: (v) async => data = v,
        ),
        clock: () => DateTime.utc(2026, 1, 1),
        findTask: (id) => tasks[id],
        addOrUpdateTask: (t) async => tasks[t.id] = t,
        deleteTask: (id) async => tasks.remove(id),
      );
      addTearDown(service.dispose);
      await service.createSeries(
        TaskRecurrence(
          id: 's',
          revisions: [
            RecurrenceRevision(
              fromDate: '2026-01-01',
              template: TaskTemplate(
                id: 't',
                title: 'Recurring',
                notificationsEnabled: true,
                alarmEnabled: true,
              ),
              rule: TaskRecurrenceRule(
                frequency: RecurrenceFrequency.daily,
                timezoneId: 'UTC',
                startDate: '2026-01-01',
              ),
            ),
          ],
        ),
      );
      await service.materialize(limit: 1);
      await tester.pumpWidget(
        MaterialApp(home: TaskPlanningPage(service: service)),
      );
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      expect(tasks.values.single.alarmEnabled, isFalse);
      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();
      expect(tasks.values.single.alarmEnabled, isTrue);
      await tester.tap(find.text('Terminate series'));
      await pumpDialog(tester);
      expect(
        find.text(TaskPlanningStrings(const Locale('en')).text('confirmTerminate')),
        findsOneWidget,
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(tasks.values.single.notificationsEnabled, isFalse);
      expect(find.text('Resume'), findsNothing);
      expect(find.text('Terminate series'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

// The page's busy indicator intentionally keeps animating below modal dialogs.
Future<void> pumpDialog(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}
