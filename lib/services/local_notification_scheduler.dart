import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart';
import 'package:next_ddl/l10n/app_localizations.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/app_snapshot.dart';
import '../models/deadline_task.dart';
import '../utils/countdown_formatter.dart';
import '../utils/deadline_logic.dart';
import '../utils/locale_utils.dart';
import '../utils/milestone_utils.dart';
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
    required AppLocalePreference localePreference,
    required PersistentNotificationTimeUnit timeUnit,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }
    if (!enabled) {
      await _plugin.cancel(_persistentNotificationId);
      return;
    }

    final targetTask = resolveMostUrgentInProgressTask(tasks, nowUtc);
    final l10n = resolveAppLocalizations(localePreference);
    final title = l10n.persistentNotificationTitle;
    final body = targetTask == null
        ? l10n.ongoingNoTask
        : _buildPersistentBody(
            targetTask,
            nowUtc,
            localePreference: localePreference,
            timeUnit: timeUnit,
          );

    await _plugin.show(
      _persistentNotificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'next_ddl_persistent',
          'Next DDL Persistent',
          channelDescription: l10n.notificationPersistentChannelDescription,
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
  Future<void> syncTask(
    DeadlineTask task, {
    required AppLocalePreference localePreference,
  }) async {
    if (!task.notificationsEnabled) {
      return;
    }

    await removeTask(task.id);
    final l10n = resolveAppLocalizations(
      localePreference,
      systemLocale: WidgetsBinding.instance.platformDispatcher.locale,
    );
    final targets = <_NotificationTarget>[
      for (final milestone in task.milestones)
        _NotificationTarget(
          idSeed: '${task.id}:${milestone.id}',
          title: resolveMilestoneDisplayTitle(milestone.title, l10n),
          dueAtUtc: milestone.dueAtUtc,
        ),
      _NotificationTarget(
        idSeed: '${task.id}:final',
        title: l10n.finalDeadline,
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
            ? l10n.notificationNowDue(target.title)
            : l10n.notificationAdvanceDue(
                _formatOffset(offset, l10n),
                target.title,
              );
        await _plugin.zonedSchedule(
          notificationId,
          task.title,
          message,
          scheduleTime,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'next_ddl_messages',
              'Next DDL Messages',
              channelDescription: l10n.notificationMessageChannelDescription,
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

  String _formatOffset(int seconds, AppLocalizations l10n) {
    final duration = Duration(seconds: seconds);
    if (duration.inDays >= 1 && duration.inHours.remainder(24) == 0) {
      return l10n.advanceDays(duration.inDays);
    }
    if (duration.inHours >= 1 && duration.inMinutes.remainder(60) == 0) {
      return l10n.advanceHours(duration.inHours);
    }
    if (duration.inMinutes >= 1) {
      return l10n.advanceMinutes(duration.inMinutes);
    }
    return l10n.advanceSeconds(duration.inSeconds);
  }

  String _buildPersistentBody(
    DeadlineTask task,
    DateTime nowUtc, {
    required AppLocalePreference localePreference,
    required PersistentNotificationTimeUnit timeUnit,
  }) {
    final remaining = resolveActiveDeadlinePoint(task, nowUtc).difference(nowUtc);
    final l10n = resolveAppLocalizations(localePreference);
    final countdown = formatCompactCountdown(
      remaining,
      timeUnit: timeUnit,
      daySuffix: l10n.compactDaySuffix,
      hourSuffix: l10n.compactHourSuffix,
    );
    return '${task.title} · $countdown';
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
