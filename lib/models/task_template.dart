import 'alarm_audio_item.dart';
import 'deadline_task.dart';
import 'milestone.dart';

/// Offsets are elapsed UTC seconds relative to the final deadline, not wall time.
class TemplateMilestone {
  const TemplateMilestone({required this.title, required this.offsetSeconds});
  final String title;
  final int offsetSeconds;
  Map<String, dynamic> toJson() => {
    'title': title,
    'offsetSeconds': offsetSeconds,
  };
  factory TemplateMilestone.fromJson(Map<String, dynamic> json) =>
      TemplateMilestone(
        title: json['title'] as String,
        offsetSeconds: json['offsetSeconds'] as int,
      );
}

class TaskTemplate {
  TaskTemplate({
    required this.id,
    required this.title,
    this.note = '',
    List<TemplateMilestone> milestones = const [],
    List<int> reminderOffsetsSeconds = const [],
    this.notificationsEnabled = false,
    this.alarmEnabled = false,
    List<AlarmAudioItem> alarmAudioItems = const [],
  }) : milestones = List.unmodifiable(milestones),
       reminderOffsetsSeconds = List.unmodifiable(reminderOffsetsSeconds),
       alarmAudioItems = List.unmodifiable(alarmAudioItems) {
    if (id.isEmpty ||
        title.trim().isEmpty ||
        milestones.length > 64 ||
        reminderOffsetsSeconds.length > 16 ||
        milestones.any((m) => m.offsetSeconds >= 0 || m.title.trim().isEmpty) ||
        reminderOffsetsSeconds.any((s) => s < 0)) {
      throw const FormatException('Invalid task template');
    }
  }
  final String id;
  final String title;
  final String note;
  final List<TemplateMilestone> milestones;
  final List<int> reminderOffsetsSeconds;
  final bool notificationsEnabled;
  final bool alarmEnabled;
  final List<AlarmAudioItem> alarmAudioItems;

  factory TaskTemplate.fromTask(DeadlineTask task, {required String id}) =>
      TaskTemplate(
        id: id,
        title: task.title,
        note: task.note,
        milestones: task.milestones
            .map(
              (m) => TemplateMilestone(
                title: m.title,
                offsetSeconds: m.dueAtUtc
                    .difference(task.finalDueAtUtc)
                    .inSeconds,
              ),
            )
            .toList(),
        reminderOffsetsSeconds: task.reminderOffsetsSeconds,
        notificationsEnabled: task.notificationsEnabled,
        alarmEnabled: task.alarmEnabled,
        alarmAudioItems: task.alarmAudioItemsOverride,
      );

  TaskTemplate copyWith({
    String? title,
    String? note,
    List<TemplateMilestone>? milestones,
    List<int>? reminderOffsetsSeconds,
    bool? notificationsEnabled,
    bool? alarmEnabled,
    List<AlarmAudioItem>? alarmAudioItems,
  }) => TaskTemplate(
    id: id,
    title: title ?? this.title,
    note: note ?? this.note,
    milestones: milestones ?? this.milestones,
    reminderOffsetsSeconds:
        reminderOffsetsSeconds ?? this.reminderOffsetsSeconds,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    alarmEnabled: alarmEnabled ?? this.alarmEnabled,
    alarmAudioItems: alarmAudioItems ?? this.alarmAudioItems,
  );

  DeadlineTask instantiate({
    required String taskId,
    required DateTime baseUtc,
    required String timezoneId,
    required DateTime nowUtc,
  }) => DeadlineTask(
    id: taskId,
    title: title,
    note: note,
    timezoneId: timezoneId,
    createdAtUtc: nowUtc.toUtc(),
    updatedAtUtc: nowUtc.toUtc(),
    finalDueAtUtc: baseUtc.toUtc(),
    milestones: [
      for (var i = 0; i < milestones.length; i++)
        Milestone(
          id: '$taskId/node/$i',
          title: milestones[i].title,
          dueAtUtc: baseUtc.toUtc().add(
            Duration(seconds: milestones[i].offsetSeconds),
          ),
          source: MilestoneSource.manual,
        ),
    ],
    reminderOffsetsSeconds: reminderOffsetsSeconds,
    notificationsEnabled: notificationsEnabled,
    alarmEnabled: alarmEnabled,
    alarmAudioItemsOverride: alarmAudioItems,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'note': note,
    'milestones': milestones.map((m) => m.toJson()).toList(),
    'reminderOffsetsSeconds': reminderOffsetsSeconds,
    'notificationsEnabled': notificationsEnabled,
    'alarmEnabled': alarmEnabled,
    'alarmAudioItems': alarmAudioItems.map((a) => a.toJson()).toList(),
  };
  factory TaskTemplate.fromJson(Map<String, dynamic> j) => TaskTemplate(
    id: j['id'] as String,
    title: j['title'] as String,
    note: j['note'] as String? ?? '',
    milestones: (j['milestones'] as List? ?? [])
        .map(
          (m) =>
              TemplateMilestone.fromJson(Map<String, dynamic>.from(m as Map)),
        )
        .toList(),
    reminderOffsetsSeconds: (j['reminderOffsetsSeconds'] as List? ?? [])
        .cast<int>(),
    notificationsEnabled: j['notificationsEnabled'] as bool? ?? false,
    alarmEnabled: j['alarmEnabled'] as bool? ?? false,
    alarmAudioItems: (j['alarmAudioItems'] as List? ?? [])
        .map(
          (a) => AlarmAudioItem.fromJson(Map<String, dynamic>.from(a as Map)),
        )
        .toList(),
  );
}
