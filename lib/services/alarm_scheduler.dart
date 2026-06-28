import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_alarm_settings.dart';
import '../models/app_snapshot.dart';
import '../models/deadline_task.dart';

abstract class AlarmScheduler {
  Future<void> initialize();

  Future<bool> canScheduleExactAlarms();

  Future<void> openExactAlarmSettings();

  Future<void> syncAlarms({
    required AppAlarmSettings settings,
    required List<DeadlineTask> tasks,
    required AppLocalePreference localePreference,
  });

  Future<void> removeTask(String taskId);

  Future<void> removeAll();

  Future<void> stopCurrentAlarm();
}

class MethodChannelAlarmScheduler implements AlarmScheduler {
  MethodChannelAlarmScheduler({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('next_ddl/alarm');

  final MethodChannel _channel;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> canScheduleExactAlarms() async {
    try {
      return await _channel.invokeMethod<bool>('canScheduleExactAlarms') ??
          true;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> openExactAlarmSettings() async {
    await _ignoreMissingPlugin(
      () => _channel.invokeMethod<void>('openExactAlarmSettings'),
    );
  }

  @override
  Future<void> syncAlarms({
    required AppAlarmSettings settings,
    required List<DeadlineTask> tasks,
    required AppLocalePreference localePreference,
  }) async {
    await _ignoreMissingPlugin(
      () => _channel.invokeMethod<void>('syncAlarms', {
        'settings': settings.toJson(),
        'tasks': tasks.map((task) => task.toJson()).toList(),
        'localeTag': localePreference.tag,
      }),
    );
  }

  @override
  Future<void> removeTask(String taskId) async {
    await _ignoreMissingPlugin(
      () => _channel.invokeMethod<void>('removeTaskAlarms', {'taskId': taskId}),
    );
  }

  @override
  Future<void> removeAll() async {
    await _ignoreMissingPlugin(
      () => _channel.invokeMethod<void>('removeAllAlarms'),
    );
  }

  @override
  Future<void> stopCurrentAlarm() async {
    await _ignoreMissingPlugin(
      () => _channel.invokeMethod<void>('stopCurrentAlarm'),
    );
  }

  Future<void> _ignoreMissingPlugin(Future<void> Function() action) async {
    try {
      await action();
    } on MissingPluginException {
      return;
    }
  }
}

final alarmSchedulerProvider = Provider<AlarmScheduler>((ref) {
  throw UnimplementedError('alarmSchedulerProvider must be overridden');
});
