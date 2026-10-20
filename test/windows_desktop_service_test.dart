import 'package:flutter_test/flutter_test.dart';
import 'package:next_ddl/l10n/app_localizations_en.dart';
import 'package:next_ddl/models/app_snapshot.dart';
import 'package:next_ddl/models/deadline_task.dart';
import 'package:next_ddl/models/milestone.dart';
import 'package:next_ddl/services/windows_desktop_service.dart';

void main() {
  final l10n = AppLocalizationsEn();
  final now = DateTime.utc(2026, 10, 20, 12);

  DeadlineTask task({String title = 'Study'}) => DeadlineTask(
    id: title,
    title: title,
    note: '',
    timezoneId: 'UTC',
    createdAtUtc: now,
    updatedAtUtc: now,
    finalDueAtUtc: now.add(const Duration(days: 5)),
    milestones: [
      Milestone(
        id: 'next',
        title: 'Review',
        dueAtUtc: now.add(const Duration(hours: 30)),
        source: MilestoneSource.manual,
      ),
    ],
    reminderOffsetsSeconds: const [],
    notificationsEnabled: false,
  );

  test('uses the nearest milestone and compact remaining time', () {
    final summary = WindowsDesktopService.buildSummary(
      AppSnapshot.empty().copyWith(tasks: [task()]),
      now,
      l10n,
    );
    expect(summary['title'], 'Review');
    expect(summary['remaining'], '1.3 days');
    expect(summary['openLabel'], 'Open Next DDL');
  });

  test('falls back to the task title when the milestone title is blank', () {
    final current = task().copyWith(
      milestones: [
        Milestone(
          id: 'blank',
          title: ' ',
          dueAtUtc: now.add(const Duration(hours: 2)),
          source: MilestoneSource.manual,
        ),
      ],
    );
    final summary = WindowsDesktopService.buildSummary(
      AppSnapshot.empty().copyWith(tasks: [current]),
      now,
      l10n,
    );
    expect(summary['title'], 'Study');
  });

  test('uses the localized empty state when no task is active', () {
    final summary = WindowsDesktopService.buildSummary(
      AppSnapshot.empty(),
      now,
      l10n,
    );
    expect(summary['title'], 'No in-progress tasks right now');
    expect(summary['remaining'], '');
  });
}
