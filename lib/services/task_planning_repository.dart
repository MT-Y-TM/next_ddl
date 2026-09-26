import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_recurrence.dart';
import '../models/task_template.dart';

/// Only reminder preferences are journaled, never a task copy that could
/// overwrite later edits. The timestamp detects edits outside this service.
class SuspendedTaskReminders {
  const SuspendedTaskReminders({
    required this.notificationsEnabled,
    required this.alarmEnabled,
    required this.updatedAtUtc,
  });
  final bool notificationsEnabled;
  final bool alarmEnabled;
  final DateTime updatedAtUtc;
  Map<String, dynamic> toJson() => {
    'notificationsEnabled': notificationsEnabled,
    'alarmEnabled': alarmEnabled,
    'updatedAtUtc': updatedAtUtc.toUtc().toIso8601String(),
  };
  factory SuspendedTaskReminders.fromJson(Map<String, dynamic> j) =>
      SuspendedTaskReminders(
        notificationsEnabled: j['notificationsEnabled'] as bool,
        alarmEnabled: j['alarmEnabled'] as bool,
        updatedAtUtc: DateTime.parse(j['updatedAtUtc'] as String).toUtc(),
      );
}

class TaskPlanningSnapshot {
  TaskPlanningSnapshot({
    Map<String, TaskTemplate> templates = const {},
    Map<String, TaskRecurrence> series = const {},
    Set<String> issued = const {},
    Set<String> skipped = const {},
    Map<String, SuspendedTaskReminders> suspendedReminders = const {},
  }) : templates = Map.unmodifiable(templates),
       series = Map.unmodifiable(series),
       suspendedReminders = Map.unmodifiable(suspendedReminders),
       issued = Set.unmodifiable(issued),
       skipped = Set.unmodifiable(skipped);
  final Map<String, TaskTemplate> templates;
  final Map<String, TaskRecurrence> series;

  /// Tombstones survive task deletion, clock rollback and backups.
  final Set<String> issued;
  final Set<String> skipped;
  final Map<String, SuspendedTaskReminders> suspendedReminders;
  TaskPlanningSnapshot copyWith({
    Map<String, TaskTemplate>? templates,
    Map<String, TaskRecurrence>? series,
    Set<String>? issued,
    Set<String>? skipped,
    Map<String, SuspendedTaskReminders>? suspendedReminders,
  }) => TaskPlanningSnapshot(
    templates: templates ?? this.templates,
    series: series ?? this.series,
    issued: issued ?? this.issued,
    skipped: skipped ?? this.skipped,
    suspendedReminders: suspendedReminders ?? this.suspendedReminders,
  );
  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'templates': templates.values.map((t) => t.toJson()).toList(),
    'series': series.values.map((s) => s.toJson()).toList(),
    'suspendedReminders': suspendedReminders.map(
      (id, value) => MapEntry(id, value.toJson()),
    ),
    'issued': issued.toList()..sort(),
    'skipped': skipped.toList()..sort(),
  };
  factory TaskPlanningSnapshot.fromJson(Map<String, dynamic> j) {
    if (j.isNotEmpty && (j['schemaVersion'] ?? 1) != 1) {
      throw const FormatException('Unsupported planning schema');
    }
    final templates = <String, TaskTemplate>{};
    final series = <String, TaskRecurrence>{};
    for (final raw in j['templates'] as List? ?? []) {
      final t = TaskTemplate.fromJson(Map<String, dynamic>.from(raw as Map));
      if (templates.containsKey(t.id)) {
        throw const FormatException('Duplicate template');
      }
      templates[t.id] = t;
    }
    for (final raw in j['series'] as List? ?? []) {
      final s = TaskRecurrence.fromJson(Map<String, dynamic>.from(raw as Map));
      if (series.containsKey(s.id)) {
        throw const FormatException('Duplicate series');
      }
      series[s.id] = s;
    }
    return TaskPlanningSnapshot(
      templates: templates,
      series: series,
      suspendedReminders: (j['suspendedReminders'] as Map? ?? {}).map(
        (id, value) => MapEntry(
          id as String,
          SuspendedTaskReminders.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        ),
      ),
      issued: (j['issued'] as List? ?? []).cast<String>().toSet(),
      skipped: (j['skipped'] as List? ?? []).cast<String>().toSet(),
    );
  }
}

abstract interface class TaskPlanningRepository {
  Future<TaskPlanningSnapshot> load();
  Future<void> save(TaskPlanningSnapshot snapshot);
}

/// Adapter for AppSnapshot.planningData + TasksController.savePlanningData.
/// Callbacks must read the latest controller state, not a captured snapshot.
class CallbackTaskPlanningRepository implements TaskPlanningRepository {
  CallbackTaskPlanningRepository({required this.read, required this.write});
  final Future<Map<String, dynamic>> Function() read;
  final Future<void> Function(Map<String, dynamic>) write;
  @override
  Future<TaskPlanningSnapshot> load() async =>
      TaskPlanningSnapshot.fromJson(await read());
  @override
  Future<void> save(TaskPlanningSnapshot snapshot) => write(snapshot.toJson());
}

class SharedPrefsTaskPlanningRepository implements TaskPlanningRepository {
  SharedPrefsTaskPlanningRepository(this.preferences);
  static const storageKey = 'task_planning_v1';
  final SharedPreferences preferences;
  @override
  Future<TaskPlanningSnapshot> load() async {
    final raw = preferences.getString(storageKey);
    return TaskPlanningSnapshot.fromJson(
      raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  @override
  Future<void> save(TaskPlanningSnapshot snapshot) async {
    if (!await preferences.setString(
      storageKey,
      jsonEncode(snapshot.toJson()),
    )) {
      throw StateError('Planning persistence failed');
    }
  }
}
