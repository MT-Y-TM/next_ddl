import 'alarm_audio_item.dart';
import 'milestone.dart';

class DeadlineTask {
  const DeadlineTask({
    required this.id,
    required this.title,
    required this.note,
    required this.timezoneId,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.finalDueAtUtc,
    required this.milestones,
    required this.reminderOffsetsSeconds,
    required this.notificationsEnabled,
    this.alarmEnabled = false,
    this.alarmAudioItemsOverride = const [],
  });

  final String id;
  final String title;
  final String note;
  final String timezoneId;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime finalDueAtUtc;
  final List<Milestone> milestones;
  final List<int> reminderOffsetsSeconds;
  final bool notificationsEnabled;
  final bool alarmEnabled;
  final List<AlarmAudioItem> alarmAudioItemsOverride;

  DeadlineTask copyWith({
    String? id,
    String? title,
    String? note,
    String? timezoneId,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
    DateTime? finalDueAtUtc,
    List<Milestone>? milestones,
    List<int>? reminderOffsetsSeconds,
    bool? notificationsEnabled,
    bool? alarmEnabled,
    List<AlarmAudioItem>? alarmAudioItemsOverride,
  }) {
    return DeadlineTask(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      timezoneId: timezoneId ?? this.timezoneId,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      finalDueAtUtc: finalDueAtUtc ?? this.finalDueAtUtc,
      milestones: milestones ?? this.milestones,
      reminderOffsetsSeconds:
          reminderOffsetsSeconds ?? this.reminderOffsetsSeconds,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
      alarmAudioItemsOverride:
          alarmAudioItemsOverride ?? this.alarmAudioItemsOverride,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'timezoneId': timezoneId,
        'createdAtUtc': createdAtUtc.toIso8601String(),
        'updatedAtUtc': updatedAtUtc.toIso8601String(),
        'finalDueAtUtc': finalDueAtUtc.toIso8601String(),
        'milestones': milestones.map((item) => item.toJson()).toList(),
        'reminderOffsetsSeconds': reminderOffsetsSeconds,
        'notificationsEnabled': notificationsEnabled,
        'alarmEnabled': alarmEnabled,
        'alarmAudioItemsOverride':
            alarmAudioItemsOverride.map((item) => item.toJson()).toList(),
      };

  factory DeadlineTask.fromJson(Map<String, dynamic> json) {
    return DeadlineTask(
      id: json['id'] as String,
      title: json['title'] as String,
      note: (json['note'] as String?) ?? '',
      timezoneId: (json['timezoneId'] as String?) ?? 'UTC',
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String).toUtc(),
      updatedAtUtc: DateTime.parse(json['updatedAtUtc'] as String).toUtc(),
      finalDueAtUtc: DateTime.parse(json['finalDueAtUtc'] as String).toUtc(),
      milestones: ((json['milestones'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>())
          .map(Milestone.fromJson)
          .toList(),
      reminderOffsetsSeconds:
          (json['reminderOffsetsSeconds'] as List<dynamic>? ?? const [])
              .map((item) => item as int)
              .toList(),
      notificationsEnabled:
          (json['notificationsEnabled'] as bool?) ?? false,
      alarmEnabled: (json['alarmEnabled'] as bool?) ?? false,
      alarmAudioItemsOverride:
          ((json['alarmAudioItemsOverride'] as List<dynamic>? ?? const [])
                  .whereType<Map<String, dynamic>>())
              .map(AlarmAudioItem.fromJson)
              .where((item) => item.uri.trim().isNotEmpty)
              .toList(),
    );
  }
}
