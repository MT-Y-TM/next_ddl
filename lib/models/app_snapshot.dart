import 'app_alarm_settings.dart';
import 'app_theme_settings.dart';
import 'deadline_task.dart';

enum AppLocalePreference {
  system('system'),
  zh('zh'),
  en('en'),
  ja('ja');

  const AppLocalePreference(this.tag);

  final String tag;

  static AppLocalePreference fromTag(String? value) {
    return AppLocalePreference.values.firstWhere(
      (item) => item.tag == value,
      orElse: () => AppLocalePreference.system,
    );
  }
}

enum PersistentNotificationTimeUnit {
  day('day'),
  hour('hour');

  const PersistentNotificationTimeUnit(this.value);

  final String value;

  static PersistentNotificationTimeUnit fromValue(String? value) {
    return PersistentNotificationTimeUnit.values.firstWhere(
      (item) => item.value == value,
      orElse: () => PersistentNotificationTimeUnit.day,
    );
  }
}

class AppSnapshot {
  const AppSnapshot({
    required this.schemaVersion,
    required this.exportedAtUtc,
    required this.tasks,
    this.persistentNotificationEnabled = false,
    this.preferredLocale = AppLocalePreference.system,
    this.persistentNotificationTimeUnit = PersistentNotificationTimeUnit.day,
    this.themeSettings = const AppThemeSettings(),
    this.alarmSettings = const AppAlarmSettings(),
  });

  final int schemaVersion;
  final DateTime exportedAtUtc;
  final List<DeadlineTask> tasks;
  final bool persistentNotificationEnabled;
  final AppLocalePreference preferredLocale;
  final PersistentNotificationTimeUnit persistentNotificationTimeUnit;
  final AppThemeSettings themeSettings;
  final AppAlarmSettings alarmSettings;

  factory AppSnapshot.empty() {
    return AppSnapshot(
      schemaVersion: 1,
      exportedAtUtc: DateTime.now().toUtc(),
      tasks: const [],
      persistentNotificationEnabled: false,
      preferredLocale: AppLocalePreference.system,
      persistentNotificationTimeUnit: PersistentNotificationTimeUnit.day,
      themeSettings: AppThemeSettings.defaults(),
      alarmSettings: AppAlarmSettings.defaults(),
    );
  }

  AppSnapshot copyWith({
    int? schemaVersion,
    DateTime? exportedAtUtc,
    List<DeadlineTask>? tasks,
    bool? persistentNotificationEnabled,
    AppLocalePreference? preferredLocale,
    PersistentNotificationTimeUnit? persistentNotificationTimeUnit,
    AppThemeSettings? themeSettings,
    AppAlarmSettings? alarmSettings,
  }) {
    return AppSnapshot(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      exportedAtUtc: exportedAtUtc ?? this.exportedAtUtc,
      tasks: tasks ?? this.tasks,
      persistentNotificationEnabled:
          persistentNotificationEnabled ?? this.persistentNotificationEnabled,
      preferredLocale: preferredLocale ?? this.preferredLocale,
      persistentNotificationTimeUnit:
          persistentNotificationTimeUnit ?? this.persistentNotificationTimeUnit,
      themeSettings: themeSettings ?? this.themeSettings,
      alarmSettings: alarmSettings ?? this.alarmSettings,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'exportedAtUtc': exportedAtUtc.toIso8601String(),
        'tasks': tasks.map((item) => item.toJson()).toList(),
        'persistentNotificationEnabled': persistentNotificationEnabled,
        'preferredLocaleTag': preferredLocale.tag,
        'persistentNotificationTimeUnit': persistentNotificationTimeUnit.value,
        'themeSettings': themeSettings.toJson(),
        'alarmSettings': alarmSettings.toJson(),
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
      persistentNotificationEnabled:
          (json['persistentNotificationEnabled'] as bool?) ?? false,
      preferredLocale: AppLocalePreference.fromTag(
        json['preferredLocaleTag'] as String?,
      ),
      persistentNotificationTimeUnit:
          PersistentNotificationTimeUnit.fromValue(
            json['persistentNotificationTimeUnit'] as String?,
          ),
      themeSettings: AppThemeSettings.fromJson(
        json['themeSettings'] as Map<String, dynamic>?,
      ),
      alarmSettings: AppAlarmSettings.fromJson(
        json['alarmSettings'] as Map<String, dynamic>?,
      ),
    );
  }
}
