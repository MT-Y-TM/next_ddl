import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/deadline_task.dart';
import '../utils/countdown_formatter.dart';
import '../utils/deadline_logic.dart';
import 'notification_scheduler.dart';
import 'timezone_service.dart';

class LocalNotificationScheduler implements NotificationScheduler {
  LocalNotificationScheduler({
    required TimezoneService timezoneService,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _timezoneService = timezoneService,
       _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final TimezoneService _timezoneService;
  final FlutterLocalNotificationsPlugin _plugin;
  static const int _persistentNotificationId = 10001;

  static final StreamController<String> _tapController =
      StreamController<String>.broadcast();

  static Stream<String> get notificationTapStream => _tapController.stream;

  @override
  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const windows = WindowsInitializationSettings(
      appName: 'Next DDL',
      appUserModelId: 'com.mtytm.nextddl',
      guid: '2f3f753f-5c7b-4339-8695-0f310b8f79a0',
    );
    const settings = InitializationSettings(android: android, windows: windows);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _tapController.add(payload);
        }
      },
    );
  }

  @override
  Future<void> removeAll() async {
    await _plugin.cancel(_persistentNotificationId);
    await _plugin.cancelAll();
  }

  @override
  Future<void> removeTask(String taskId) async {
    final requests = await _plugin.pendingNotificationRequests();
    for (final request in requests) {
      if (request.payload == taskId) {
        await _plugin.cancel(request.id);
      }
    }
  }

  @override
  Future<void> requestPermissionIfNeeded() async {
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
    }
  }

  @override
  Future<void> syncPersistentNotification({
    required bool enabled,
    required List<DeadlineTask> tasks,
    required DateTime nowUtc,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }
    if (!enabled) {
      await _plugin.cancel(_persistentNotificationId);
      return;
    }

    final sortedTasks = sortTasks(tasks, nowUtc);
    final title = 'Next DDL';
    final body = sortedTasks.isEmpty
        ? '当前没有进行中的任务'
        : _buildPersistentBody(sortedTasks.first, nowUtc);

    await _plugin.show(
      _persistentNotificationId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'next_ddl_persistent',
          'Next DDL Persistent',
          channelDescription: 'Next DDL 常驻状态通知',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          showWhen: false,
        ),
      ),
    );
  }

  @override
  Future<void> syncTask(DeadlineTask task) async {
    if (!task.notificationsEnabled) {
      return;
    }

    await removeTask(task.id);
    final targets = <_NotificationTarget>[
      for (final milestone in task.milestones)
        _NotificationTarget(
          idSeed: '${task.id}:${milestone.id}',
          title: milestone.title,
          dueAtUtc: milestone.dueAtUtc,
        ),
      _NotificationTarget(
        idSeed: '${task.id}:final',
        title: '最终截止',
        dueAtUtc: task.finalDueAtUtc,
      ),
    ];

    for (final target in targets) {
      for (final offset in task.reminderOffsetsSeconds.toSet()) {
        final scheduledAtUtc = target.dueAtUtc.subtract(
          Duration(seconds: offset),
        );
        if (!scheduledAtUtc.isAfter(DateTime.now().toUtc())) {
          continue;
        }
        final scheduleTime = tz.TZDateTime.from(
          scheduledAtUtc,
          _timezoneService.location,
        );
        final notificationId = '${target.idSeed}:$offset'.hashCode & 0x7fffffff;
        final message = offset == 0
            ? '现在到点 · ${target.title}'
            : '提前${_formatOffset(offset)} · ${target.title}';
        await _plugin.zonedSchedule(
          notificationId,
          task.title,
          message,
          scheduleTime,
          NotificationDetails(
            android: const AndroidNotificationDetails(
              'next_ddl_messages',
              'Next DDL Messages',
              channelDescription: '任务节点与最终截止消息通知',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            windows: const WindowsNotificationDetails(),
          ),
          payload: task.id,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  }

  String _formatOffset(int seconds) {
    final duration = Duration(seconds: seconds);
    if (duration.inDays >= 1 && duration.inHours.remainder(24) == 0) {
      return '${duration.inDays}天';
    }
    if (duration.inHours >= 1 && duration.inMinutes.remainder(60) == 0) {
      return '${duration.inHours}小时';
    }
    if (duration.inMinutes >= 1) {
      return '${duration.inMinutes}分钟';
    }
    return '${duration.inSeconds}秒';
  }

  String _buildPersistentBody(DeadlineTask task, DateTime nowUtc) {
    final nextMilestone = resolveNextMilestone(task, nowUtc);
    final parts = <String>[task.title];
    if (task.milestones.isNotEmpty && nextMilestone != null) {
      parts.add(
        '下一个：${nextMilestone.title} ${formatCountdownFromDates(now: nowUtc, target: nextMilestone.dueAtUtc)}',
      );
    }
    parts.add(
      '最终：${formatCountdownFromDates(now: nowUtc, target: task.finalDueAtUtc)}',
    );
    return parts.join(' · ');
  }
}

class _NotificationTarget {
  const _NotificationTarget({
    required this.idSeed,
    required this.title,
    required this.dueAtUtc,
  });

  final String idSeed;
  final String title;
  final DateTime dueAtUtc;
}
