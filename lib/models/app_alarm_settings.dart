import 'alarm_audio_item.dart';

class AppAlarmSettings {
  const AppAlarmSettings({
    this.enabled = false,
    this.globalAudioItems = const [],
  });

  final bool enabled;
  final List<AlarmAudioItem> globalAudioItems;

  factory AppAlarmSettings.defaults() {
    return const AppAlarmSettings();
  }

  AppAlarmSettings copyWith({
    bool? enabled,
    List<AlarmAudioItem>? globalAudioItems,
  }) {
    return AppAlarmSettings(
      enabled: enabled ?? this.enabled,
      globalAudioItems: globalAudioItems ?? this.globalAudioItems,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'globalAudioItems': globalAudioItems.map((item) => item.toJson()).toList(),
      };

  factory AppAlarmSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return AppAlarmSettings.defaults();
    }
    return AppAlarmSettings(
      enabled: (json['enabled'] as bool?) ?? false,
      globalAudioItems: ((json['globalAudioItems'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>())
          .map(AlarmAudioItem.fromJson)
          .where((item) => item.uri.trim().isNotEmpty)
          .toList(),
    );
  }
}
