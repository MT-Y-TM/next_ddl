import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/alarm_audio_item.dart';
import '../models/app_alarm_settings.dart';
import '../models/deadline_task.dart';

enum ReminderPermission { allowed, denied, unknown, notApplicable }

enum ReminderKind { notification, alarm }

enum ReminderAudioState { readable, unavailable, unknown }

enum ReminderAction { notification, alarm, stop, permission, settings }

enum ReminderActionResult { requested, unsupported, failed, noAudio }

class ExpectedReminder {
  const ExpectedReminder({
    required this.taskId,
    required this.taskTitle,
    required this.nodeTitle,
    required this.atUtc,
    required this.kind,
  });

  final String taskId;
  final String taskTitle;
  // Null identifies the final deadline, localized by the card.
  final String? nodeTitle;
  final DateTime atUtc;
  final ReminderKind kind;
}

class ReminderAudioCheck {
  const ReminderAudioCheck(this.item, this.state);
  final AlarmAudioItem item;
  final ReminderAudioState state;
}

class ReminderHealthReport {
  const ReminderHealthReport({
    required this.checkedAtUtc,
    required this.notificationPermission,
    required this.exactAlarmPermission,
    required this.nextNotification,
    required this.nextAlarm,
    required this.pendingNotificationCount,
    required this.audio,
    this.pendingAlarmCount,
  });

  final DateTime checkedAtUtc;
  final ReminderPermission notificationPermission;
  final ReminderPermission exactAlarmPermission;
  final ExpectedReminder? nextNotification;
  final ExpectedReminder? nextAlarm;
  // Plugin metadata only: null means unavailable, not zero registered alarms.
  final int? pendingNotificationCount;
  final int? pendingAlarmCount;
  final List<ReminderAudioCheck> audio;
}

class ReminderHealthEvent {
  const ReminderHealthEvent(this.atUtc, this.action, this.result);
  final DateTime atUtc;
  final ReminderAction action;
  final ReminderActionResult result;
}

/// Separate from scheduler contracts so existing `implements` fakes stay valid.
/// The host must initialize LocalNotificationScheduler before testing a toast.
class ReminderHealthService {
  ReminderHealthService({
    FlutterLocalNotificationsPlugin? plugin,
    MethodChannel? alarmChannel,
    MethodChannel? healthChannel,
    TargetPlatform? platform,
    DateTime Function()? now,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _channel = alarmChannel ?? const MethodChannel('next_ddl/alarm'),
       _healthChannel =
           healthChannel ?? const MethodChannel('next_ddl/reminder_health'),
       platform = platform ?? defaultTargetPlatform,
       _now = now ?? DateTime.now;

  final FlutterLocalNotificationsPlugin _plugin;
  final MethodChannel _channel;
  final MethodChannel _healthChannel;
  final TargetPlatform platform;
  final DateTime Function() _now;
  final List<ReminderHealthEvent> _events = [];
  static const testNotificationId = -19001;
  static const _timeout = Duration(seconds: 8);

  List<ReminderHealthEvent> get events => List.unmodifiable(_events);
  bool get supported =>
      !kIsWeb &&
      (platform == TargetPlatform.android ||
          platform == TargetPlatform.windows);

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<ReminderPermission> notificationPermission() async {
    if (!supported || platform != TargetPlatform.android) {
      return ReminderPermission.unknown;
    }
    return _permission(() async => _android?.areNotificationsEnabled());
  }

  Future<ReminderPermission> exactAlarmPermission() async {
    if (platform == TargetPlatform.windows && supported) {
      return ReminderPermission.notApplicable;
    }
    if (!supported) return ReminderPermission.unknown;
    return _permission(
      () => _channel.invokeMethod<bool>('canScheduleExactAlarms'),
    );
  }

  Future<ReminderPermission> _permission(Future<bool?> Function() read) async {
    try {
      return switch (await read().timeout(_timeout)) {
        true => ReminderPermission.allowed,
        false => ReminderPermission.denied,
        null => ReminderPermission.unknown,
      };
    } catch (_) {
      return ReminderPermission.unknown;
    }
  }

  Future<ReminderHealthReport> inspect({
    required List<DeadlineTask> tasks,
    required AppAlarmSettings settings,
  }) async {
    final now = _now().toUtc();
    final notification = await notificationPermission();
    final exact = await exactAlarmPermission();
    int? count;
    if (supported) {
      try {
        final pending = await _plugin.pendingNotificationRequests().timeout(
          _timeout,
        );
        count = pending.where((item) => item.id != testNotificationId).length;
      } catch (_) {
        // Unsupported queries must not look like an empty system schedule.
      }
    }
    final items = <String, AlarmAudioItem>{
      for (final item in settings.globalAudioItems) item.uri: item,
      for (final task in tasks.where(
        (task) => !task.isCompleted && task.alarmEnabled,
      ))
        for (final item in task.alarmAudioItemsOverride) item.uri: item,
    };
    int? alarmCount;
    if (supported) {
      try {
        final value = await _healthChannel
            .invokeMethod<int>('pendingAlarmCount')
            .timeout(_timeout);
        if (value != null && value >= 0) alarmCount = value;
      } catch (_) {
        /* No native registration query on older builds. */
      }
    }
    final audio = await checkAudioItems(items.values.toList());
    return ReminderHealthReport(
      checkedAtUtc: now,
      notificationPermission: notification,
      exactAlarmPermission: exact,
      nextNotification: nextExpected(
        tasks,
        settings,
        now,
        ReminderKind.notification,
      ),
      nextAlarm: nextExpected(tasks, settings, now, ReminderKind.alarm),
      pendingNotificationCount: count,
      pendingAlarmCount: alarmCount,
      audio: List.unmodifiable(audio),
    );
  }

  static ExpectedReminder? nextExpected(
    List<DeadlineTask> tasks,
    AppAlarmSettings settings,
    DateTime nowUtc,
    ReminderKind kind,
  ) {
    ExpectedReminder? next;
    for (final task in tasks) {
      if (task.isCompleted) continue;
      if (kind == ReminderKind.notification && !task.notificationsEnabled) {
        continue;
      }
      if (kind == ReminderKind.alarm &&
          (!settings.enabled ||
              !task.alarmEnabled ||
              effectiveAudio(task, settings).isEmpty)) {
        continue;
      }
      final targets = <({String? title, DateTime due})>[
        (title: null, due: task.finalDueAtUtc),
        for (final node in task.milestones)
          if (!node.isCompleted) (title: node.title, due: node.dueAtUtc),
      ];
      for (final target in targets) {
        for (final offset in task.reminderOffsetsSeconds.toSet()) {
          final at = target.due.subtract(Duration(seconds: offset)).toUtc();
          if (!at.isAfter(nowUtc) || (next != null && !at.isBefore(next.atUtc))) {
            continue;
          }
          next = ExpectedReminder(
            taskId: task.id,
            taskTitle: task.title,
            nodeTitle: target.title,
            atUtc: at,
            kind: kind,
          );
        }
      }
    }
    return next;
  }

  static List<AlarmAudioItem> effectiveAudio(
    DeadlineTask task,
    AppAlarmSettings settings,
  ) => task.alarmAudioItemsOverride.isNotEmpty
      ? task.alarmAudioItemsOverride
      : settings.globalAudioItems;

  Future<List<ReminderAudioCheck>> checkAudioItems(
    List<AlarmAudioItem> items,
  ) async {
    if (items.isEmpty) return const [];
    if (supported) {
      try {
        final states = await _healthChannel
            .invokeListMethod<String>('checkAudioUris', {
              'uris': items.map((item) => item.uri).toList(),
            })
            .timeout(_timeout);
        if (states != null && states.length == items.length) {
          return [
            for (var i = 0; i < items.length; i++)
              ReminderAudioCheck(items[i], switch (states[i]) {
                'readable' => ReminderAudioState.readable,
                'unavailable' => ReminderAudioState.unavailable,
                _ => ReminderAudioState.unknown,
              }),
          ];
        }
      } catch (_) {
        /* Fall back to local readability checks, never URI guesses. */
      }
    }
    return [
      for (final item in items)
        ReminderAudioCheck(item, await checkAudio(item)),
    ];
  }

  /// Readability is not a decoder/playback test. Content URI grants need native code.
  Future<ReminderAudioState> checkAudio(AlarmAudioItem item) async {
    final raw = item.uri.trim();
    if (raw.isEmpty) return ReminderAudioState.unavailable;
    final uri = Uri.tryParse(raw);
    final windowsPath = RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(raw);
    if (uri == null ||
        (!windowsPath && uri.hasScheme && uri.scheme != 'file')) {
      return ReminderAudioState.unknown;
    }
    try {
      final file = uri.scheme == 'file' ? File.fromUri(uri) : File(raw);
      final bytes = await file.openRead(0, 1).first.timeout(_timeout);
      return bytes.isEmpty
          ? ReminderAudioState.unavailable
          : ReminderAudioState.readable;
    } on FileSystemException {
      return ReminderAudioState.unavailable;
    } on StateError {
      return ReminderAudioState.unavailable;
    } catch (_) {
      return ReminderAudioState.unknown;
    }
  }

  Future<ReminderActionResult> testNotification({
    required String title,
    required String body,
  }) => _act(ReminderAction.notification, () async {
    await _plugin.show(
      testNotificationId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'next_ddl_messages',
          'Next DDL Messages',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        windows: WindowsNotificationDetails(),
      ),
    );
  });

  /// Optional native contract: testAlarm({audioUris, title, maxDurationSeconds: 10})
  /// returns true only when accepted. It must not sync/cancel real task alarms.
  Future<ReminderActionResult> testAlarm({
    required List<AlarmAudioItem> audio,
    required String title,
  }) async {
    if (audio.isEmpty) {
      return _record(ReminderAction.alarm, ReminderActionResult.noAudio);
    }
    return _act(ReminderAction.alarm, () async {
      final accepted = await _healthChannel.invokeMethod<bool>('testAlarm', {
        'audioUris': audio.map((item) => item.uri).toList(),
        'title': title,
        'maxDurationSeconds': 10,
      });
      if (accepted != true) throw StateError('test_not_accepted');
    });
  }

  Future<ReminderActionResult> stopAlarm() => _act(
    ReminderAction.stop,
    () => _channel.invokeMethod<void>('stopCurrentAlarm'),
  );

  Future<ReminderActionResult> requestNotificationPermission() =>
      _act(ReminderAction.permission, () async {
        if (platform != TargetPlatform.android || _android == null) {
          throw MissingPluginException();
        }
        await _android!.requestNotificationsPermission();
      });

  Future<ReminderActionResult> openExactAlarmSettings() =>
      _act(ReminderAction.settings, () async {
        if (platform != TargetPlatform.android) throw MissingPluginException();
        await _channel.invokeMethod<void>('openExactAlarmSettings');
      });

  // Optional native entry point; never substitute an unverified OEM deep link.
  Future<ReminderActionResult> openNotificationSettings() => _act(
    ReminderAction.settings,
    () => _healthChannel.invokeMethod<void>('openNotificationSettings'),
  );

  Future<ReminderActionResult> _act(
    ReminderAction action,
    Future<void> Function() run,
  ) async {
    if (!supported) return _record(action, ReminderActionResult.unsupported);
    try {
      await run().timeout(_timeout);
      return _record(action, ReminderActionResult.requested);
    } on MissingPluginException {
      return _record(action, ReminderActionResult.unsupported);
    } catch (_) {
      return _record(action, ReminderActionResult.failed);
    }
  }

  ReminderActionResult _record(
    ReminderAction action,
    ReminderActionResult result,
  ) {
    // Bounded, memory-only diagnostics deliberately omit titles, paths and errors.
    _events.add(ReminderHealthEvent(_now().toUtc(), action, result));
    if (_events.length > 20) _events.removeAt(0);
    return result;
  }
}

final reminderHealthServiceProvider = Provider<ReminderHealthService>(
  (ref) => ReminderHealthService(),
);
