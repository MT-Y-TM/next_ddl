import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/deadline_task.dart';
import '../models/task_recurrence.dart';
import '../models/task_template.dart';
import 'task_planning_repository.dart';

class PlannedOccurrence {
  const PlannedOccurrence(this.seriesId, this.date, this.task);
  final String seriesId;
  final String date;
  final DeadlineTask task;
}

/// One service per repository. All mutations are serialized, including writes
/// through the injected task controller. No timers or work in Widget.build.
class TaskPlanningService extends ChangeNotifier {
  TaskPlanningService({
    required this.repository,
    required this.addOrUpdateTask,
    required this.findTask,
    required this.deleteTask,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final TaskPlanningRepository repository;
  final Future<void> Function(DeadlineTask) addOrUpdateTask;
  final DeadlineTask? Function(String) findTask;
  final Future<void> Function(String) deleteTask;
  final DateTime Function() clock;
  TaskPlanningSnapshot _snapshot = TaskPlanningSnapshot();
  TaskPlanningSnapshot get snapshot => _snapshot;
  Future<void> _tail = Future.value();
  bool _loaded = false;
  static String newId() => List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _tail.then((_) async {
      if (!_loaded) {
        _snapshot = await repository.load();
        _loaded = true;
      }
      return action();
    });
    _tail = next.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return next;
  }

  Future<void> initialize() => _serial(() async {
    notifyListeners();
  });
  Future<void> reload() => _serial(() async {
    _snapshot = await repository.load();
    notifyListeners();
  });
  Future<void> _save(TaskPlanningSnapshot next) async {
    await repository.save(next);
    _snapshot = next;
    notifyListeners();
  }

  Map<String, dynamic> toJson() => _snapshot.toJson();
  Future<void> importJson(Map<String, dynamic> json) => _serial(() async {
    await _save(TaskPlanningSnapshot.fromJson(json));
  });
  Future<void> saveTemplate(TaskTemplate template) => _serial(
    () => _save(
      _snapshot.copyWith(
        templates: {..._snapshot.templates, template.id: template},
      ),
    ),
  );

  /// Existing series retain their own immutable template revision.
  Future<void> deleteTemplate(String id) => _serial(
    () => _save(
      _snapshot.copyWith(templates: {..._snapshot.templates}..remove(id)),
    ),
  );
  Future<void> createSeries(TaskRecurrence series) => _serial(() async {
    if (_snapshot.series.containsKey(series.id)) {
      throw StateError('Series ID already used');
    }
    await _save(
      _snapshot.copyWith(series: {..._snapshot.series, series.id: series}),
    );
  });
  Future<void> setStatus(String id, RecurrenceStatus status) =>
      _serial(() async {
        final s = _snapshot.series[id]!;
        if (s.status == RecurrenceStatus.terminated && status != s.status) {
          throw StateError('Terminated series cannot resume');
        }
        await _save(
          _snapshot.copyWith(
            series: {
              ..._snapshot.series,
              id: s.copyWith(status: status),
            },
          ),
        );
        await _reconcileReminders();
      });

  /// Replayed on materialization after an interrupted status change. Controller
  /// upserts must cancel and reschedule reminders from the current task flags.
  Future<void> _reconcileReminders() async {
    final now = clock().toUtc();
    for (final series in _snapshot.series.values) {
      final prefix = 'planning/${Uri.encodeComponent(series.id)}/';
      final ids = {
        ..._snapshot.issued,
        ..._snapshot.suspendedReminders.keys,
      }.where((id) => id.startsWith(prefix)).toList();
      for (final id in ids) {
        final task = findTask(id);
        final saved = _snapshot.suspendedReminders[id];
        if (series.status == RecurrenceStatus.active) {
          if (saved == null) continue;
          if (task != null &&
              !task.isCompleted &&
              !task.finalDueAtUtc.isBefore(now) &&
              !_snapshot.skipped.contains(id) &&
              task.updatedAtUtc.isAtSameMomentAs(saved.updatedAtUtc) &&
              ((!task.notificationsEnabled && !task.alarmEnabled) ||
                (task.notificationsEnabled == saved.notificationsEnabled &&
                 task.alarmEnabled == saved.alarmEnabled))) {
            await addOrUpdateTask(
              task.copyWith(
                notificationsEnabled: saved.notificationsEnabled,
                alarmEnabled: saved.alarmEnabled,
              ),
            );
          }
          await _save(
            _snapshot.copyWith(
              suspendedReminders: {..._snapshot.suspendedReminders}..remove(id),
            ),
          );
        } else if (task != null &&
            !task.isCompleted &&
            !task.finalDueAtUtc.isBefore(now) &&
            (task.notificationsEnabled || task.alarmEnabled || saved != null)) {
          if (saved == null) {
            await _save(
              _snapshot.copyWith(
                suspendedReminders: {
                  ..._snapshot.suspendedReminders,
                  id: SuspendedTaskReminders(
                    notificationsEnabled: task.notificationsEnabled,
                    alarmEnabled: task.alarmEnabled,
                    updatedAtUtc: task.updatedAtUtc,
                  ),
                },
              ),
            );
          }
          // Repeat the upsert even when flags are already off: the preceding
          // scheduler call may have failed after the task itself was persisted.
          await addOrUpdateTask(
            task.copyWith(notificationsEnabled: false, alarmEnabled: false),
          );
        }
      }
    }
  }

  DeadlineTask previewTemplate(
    TaskTemplate template,
    DateTime baseUtc,
    String timezoneId, {
    String? taskId,
  }) => template.instantiate(
    taskId: taskId ?? 'template/${newId()}',
    baseUtc: baseUtc,
    timezoneId: timezoneId,
    nowUtc: clock().toUtc(),
  );

  Future<void> createFromPreview(DeadlineTask preview) => _serial(() async {
    if (findTask(preview.id) == null) await addOrUpdateTask(preview);
  });

  /// Globally limited, chronologically sorted; scans at most 366 civil days
  /// per revision. Past periods are deliberately not backfilled on resume.
  List<PlannedOccurrence> preview({
    required DateTime nowUtc,
    int horizonDays = 30,
    int limit = 20,
  }) {
    if (horizonDays < 1 || horizonDays > 366 || limit < 1 || limit > 100) {
      throw ArgumentError('Planning bounds exceeded');
    }
    final now = nowUtc.toUtc();
    final until = now.add(Duration(days: horizonDays));
    final occurrences = <PlannedOccurrence>[];
    for (final s in _snapshot.series.values) {
      if (s.status != RecurrenceStatus.active) continue;
      for (final revision in s.revisions) {
        final localNow = tz.TZDateTime.from(
          now,
          tz.getLocation(revision.rule.timezoneId),
        );
        final first = DateTime.utc(localNow.year, localNow.month, localNow.day);
        for (var i = 0; i <= horizonDays; i++) {
          final date = first.add(Duration(days: i));
          final key = planningDateKey(date);
          if (s.revisionOn(key) != revision) continue;
          final id = s.instanceId(key);
          if (_snapshot.issued.contains(id) || _snapshot.skipped.contains(id)) {
            continue;
          }
          final due = revision.rule.dueOn(date);
          if (due == null || due.isBefore(now) || due.isAfter(until)) continue;
          occurrences.add(
            PlannedOccurrence(
              s.id,
              key,
              revision.template.instantiate(
                taskId: id,
                baseUtc: due,
                timezoneId: revision.rule.timezoneId,
                nowUtc: now,
              ),
            ),
          );
        }
      }
    }
    occurrences.sort((a, b) {
      final time = a.task.finalDueAtUtc.compareTo(b.task.finalDueAtUtc);
      return time == 0 ? a.task.id.compareTo(b.task.id) : time;
    });
    return occurrences.take(limit).toList();
  }

  Future<List<DeadlineTask>> materialize({
    DateTime? nowUtc,
    int horizonDays = 30,
    int limit = 20,
  }) => _serial(() async {
    await _reconcileReminders();
    // A skip persisted before a failed controller delete remains retryable.
    for (final id in _snapshot.skipped) {
      if (findTask(id) != null) await deleteTask(id);
    }
    final result = <DeadlineTask>[];
    for (final occurrence in preview(
      nowUtc: nowUtc ?? clock(),
      horizonDays: horizonDays,
      limit: limit,
    )) {
      final task = occurrence.task;
      // A prior controller write may have succeeded before the ledger write
      // failed. Never overwrite that task (including completion or postponement).
      if (findTask(task.id) == null) {
        await addOrUpdateTask(task);
        result.add(task);
      }
      await _save(_snapshot.copyWith(issued: {..._snapshot.issued, task.id}));
    }
    return result;
  });

  /// Skipping an emitted instance removes it through the controller, cancelling
  /// reminders. A repeated call also retries a failed delete.
  Future<void> skip(String seriesId, String date) => _serial(() async {
    parsePlanningDate(date);
    final id = _snapshot.series[seriesId]!.instanceId(date);
    await _save(_snapshot.copyWith(skipped: {..._snapshot.skipped, id}));
    if (findTask(id) != null) await deleteTask(id);
  });

  Future<void> editOnlyThis(
    String seriesId,
    String date,
    DeadlineTask edited,
  ) => _serial(() async {
    parsePlanningDate(date);
    final id = _snapshot.series[seriesId]!.instanceId(date);
    if (edited.id != id ||
        findTask(id) == null ||
        _snapshot.skipped.contains(id)) {
      throw ArgumentError('Invalid occurrence edit');
    }
    await addOrUpdateTask(edited.copyWith(updatedAtUtc: clock().toUtc()));
    await _save(_snapshot.copyWith(issued: {..._snapshot.issued, id}));
    await _reconcileReminders();
  });

  /// Following edits affect unissued dates only. Already materialized tasks are
  /// independent, preserving completion and individual edits. UI states this.
  /// Pass a date after the last issued occurrence to avoid ambiguous scope.
  Future<void> editFollowing(String seriesId, RecurrenceRevision revision) =>
      _serial(() async {
        final s = _snapshot.series[seriesId]!;
        if (s.status == RecurrenceStatus.terminated) {
          throw StateError('Series terminated');
        }
        final prefix = 'planning/${Uri.encodeComponent(seriesId)}/';
        if (_snapshot.issued.any(
          (id) =>
              id.startsWith(prefix) &&
              id.substring(prefix.length).compareTo(revision.fromDate) >= 0,
        )) {
          throw StateError('Following edits must start after issued instances');
        }
        final revisions =
            s.revisions
                .where((r) => r.fromDate.compareTo(revision.fromDate) < 0)
                .toList()
              ..add(revision);
        await _save(
          _snapshot.copyWith(
            series: {
              ..._snapshot.series,
              seriesId: s.copyWith(revisions: revisions),
            },
          ),
        );
      });
}
