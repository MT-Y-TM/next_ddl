import 'deadline_task.dart';

class AppSnapshot {
  const AppSnapshot({
    required this.schemaVersion,
    required this.exportedAtUtc,
    required this.tasks,
  });

  final int schemaVersion;
  final DateTime exportedAtUtc;
  final List<DeadlineTask> tasks;

  factory AppSnapshot.empty() {
    return AppSnapshot(
      schemaVersion: 1,
      exportedAtUtc: DateTime.now().toUtc(),
      tasks: const [],
    );
  }

  AppSnapshot copyWith({
    int? schemaVersion,
    DateTime? exportedAtUtc,
    List<DeadlineTask>? tasks,
  }) {
    return AppSnapshot(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      exportedAtUtc: exportedAtUtc ?? this.exportedAtUtc,
      tasks: tasks ?? this.tasks,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'exportedAtUtc': exportedAtUtc.toIso8601String(),
        'tasks': tasks.map((item) => item.toJson()).toList(),
      };

  factory AppSnapshot.fromJson(Map<String, dynamic> json) {
    return AppSnapshot(
      schemaVersion: (json['schemaVersion'] as int?) ?? 1,
      exportedAtUtc: DateTime.parse(
        (json['exportedAtUtc'] as String?) ??
            DateTime.now().toUtc().toIso8601String(),
      ).toUtc(),
      tasks: ((json['tasks'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>())
          .map(DeadlineTask.fromJson)
          .toList(),
    );
  }
}
