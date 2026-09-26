import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:next_ddl/models/alarm_audio_item.dart';
import 'package:next_ddl/models/app_alarm_settings.dart';
import 'package:next_ddl/models/deadline_task.dart';
import 'package:next_ddl/models/milestone.dart';
import 'package:next_ddl/services/reminder_health_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const health = MethodChannel('next_ddl/reminder_health');
  const alarm = MethodChannel('next_ddl/alarm');
  const notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final now = DateTime.utc(2026, 9, 25);
  const audio = AlarmAudioItem(
    id: 'a',
    displayName: 'Audio',
    uri: 'content://a',
  );
  const settings = AppAlarmSettings(enabled: true, globalAudioItems: [audio]);

  ReminderHealthService service([
    TargetPlatform platform = TargetPlatform.windows,
  ]) => ReminderHealthService(platform: platform, now: () => now);
  DeadlineTask task() => DeadlineTask(
    id: 'open',
    title: 'Open',
    note: '',
    timezoneId: 'UTC',
    createdAtUtc: now,
    updatedAtUtc: now,
    finalDueAtUtc: now.add(const Duration(days: 2)),
    milestones: [
      Milestone(
        id: 'done',
        title: 'Done',
        dueAtUtc: now.add(const Duration(hours: 1)),
        source: MilestoneSource.manual,
        completedAtUtc: now,
      ),
      Milestone(
        id: 'future',
        title: 'Future',
        dueAtUtc: now.add(const Duration(days: 1)),
        source: MilestoneSource.manual,
      ),
    ],
    reminderOffsetsSeconds: const [0, 0, 3600],
    notificationsEnabled: true,
    alarmEnabled: true,
  );

  tearDown(() {
    for (final channel in [health, alarm, notifications]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  for (final kind in ReminderKind.values) {
    test('${kind.name} ignores completed tasks and milestones', () {
      final next = ReminderHealthService.nextExpected(
        [
          task().copyWith(
            id: 'done-task',
            completedAtUtc: now,
            finalDueAtUtc: now.add(const Duration(minutes: 1)),
          ),
          task(),
        ],
        settings,
        now,
        kind,
      );
      expect(next?.taskId, 'open');
      expect(next?.nodeTitle, 'Future');
      expect(next?.atUtc, now.add(const Duration(hours: 23)));
      expect(
        ReminderHealthService.nextExpected(
          [task().copyWith(completedAtUtc: now)],
          settings,
          now,
          kind,
        ),
        isNull,
      );
    });
  }

  test('next reminder excludes elapsed offsets and honors switches/audio', () {
    final due = task().copyWith(
      milestones: [],
      finalDueAtUtc: now,
      reminderOffsetsSeconds: [0, 3600],
    );
    expect(
      ReminderHealthService.nextExpected(
        [due],
        settings,
        now,
        ReminderKind.notification,
      ),
      isNull,
    );
    expect(
      ReminderHealthService.nextExpected(
        [task().copyWith(notificationsEnabled: false)],
        settings,
        now,
        ReminderKind.notification,
      ),
      isNull,
    );
    for (final disabled in [
      const AppAlarmSettings(),
      const AppAlarmSettings(enabled: true),
    ]) {
      expect(
        ReminderHealthService.nextExpected(
          [task()],
          disabled,
          now,
          ReminderKind.alarm,
        ),
        isNull,
      );
    }
    expect(
      ReminderHealthService.nextExpected(
        [task().copyWith(alarmEnabled: false)],
        settings,
        now,
        ReminderKind.alarm,
      ),
      isNull,
    );
    expect(
      ReminderHealthService.nextExpected(
        [
          task().copyWith(alarmAudioItemsOverride: [audio]),
        ],
        const AppAlarmSettings(enabled: true),
        now,
        ReminderKind.alarm,
      ),
      isNotNull,
    );
  });

  test(
    'native audio statuses retain order and unknown is not readable',
    () async {
      messenger.setMockMethodCallHandler(health, (call) async {
        expect(call.method, 'checkAudioUris');
        expect((call.arguments as Map)['uris'], ['content://a', 'b', 'c', 'd']);
        return ['readable', 'unavailable', 'unknown', 'future-status'];
      });
      final checks = await service().checkAudioItems([
        audio,
        audio.copyWith(uri: 'b'),
        audio.copyWith(uri: 'c'),
        audio.copyWith(uri: 'd'),
      ]);
      expect(checks.map((check) => check.state), [
        ReminderAudioState.readable,
        ReminderAudioState.unavailable,
        ReminderAudioState.unknown,
        ReminderAudioState.unknown,
      ]);
    },
  );

  test(
    'missing/malformed native audio checks fall back to actual file reads',
    () async {
      final dir = await Directory.systemTemp.createTemp('reminder-health-');
      addTearDown(() => dir.delete(recursive: true));
      final readable = await File('${dir.path}/audio.bin').writeAsBytes([1]);
      final empty = await File('${dir.path}/empty.bin').writeAsBytes([]);
      final items = [
        audio.copyWith(uri: readable.path),
        audio.copyWith(uri: readable.uri.toString()),
        audio.copyWith(uri: empty.path),
        audio.copyWith(uri: '${dir.path}/missing'),
        audio,
        audio.copyWith(uri: ''),
      ];
      for (final malformed in [false, true]) {
        messenger.setMockMethodCallHandler(health, (_) async {
          if (malformed) return ['readable'];
          throw MissingPluginException();
        });
        expect((await service().checkAudioItems(items)).map((e) => e.state), [
          ReminderAudioState.readable,
          ReminderAudioState.readable,
          ReminderAudioState.unavailable,
          ReminderAudioState.unavailable,
          ReminderAudioState.unknown,
          ReminderAudioState.unavailable,
        ]);
      }
    },
  );

  test(
    'Windows permissions stay unknown/not applicable without guessing',
    () async {
      messenger.setMockMethodCallHandler(
        alarm,
        (_) async => fail('Unexpected query'),
      );
      expect(
        await service().notificationPermission(),
        ReminderPermission.unknown,
      );
      expect(
        await service().exactAlarmPermission(),
        ReminderPermission.notApplicable,
      );
      expect(
        await service().requestNotificationPermission(),
        ReminderActionResult.unsupported,
      );
    },
  );

  test(
    'Android permissions map true/false/null and plugin failures safely',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      final android = service(TargetPlatform.android);
      for (final value in [true, false, null, 'missing', 'error']) {
        Future<Object?> handler(MethodCall call) async {
          if (value == 'missing') throw MissingPluginException();
          if (value == 'error') throw PlatformException(code: 'unavailable');
          return value;
        }

        messenger.setMockMethodCallHandler(alarm, handler);
        messenger.setMockMethodCallHandler(notifications, handler);
        final expected = value == true
            ? ReminderPermission.allowed
            : value == false
            ? ReminderPermission.denied
            : ReminderPermission.unknown;
        expect(await android.notificationPermission(), expected);
        expect(await android.exactAlarmPermission(), expected);
      }
    },
  );

  test(
    'inspect uses native pending count and filters/deduplicates audio',
    () async {
      messenger.setMockMethodCallHandler(health, (call) async {
        if (call.method == 'pendingAlarmCount') return 3;
        expect(call.method, 'checkAudioUris');
        expect((call.arguments as Map)['uris'], [
          'content://a',
          'content://override',
        ]);
        return ['readable', 'unavailable'];
      });
      final report = await service().inspect(
        tasks: [
          task().copyWith(
            alarmAudioItemsOverride: [
              audio,
              audio.copyWith(uri: 'content://override'),
            ],
          ),
          task().copyWith(
            completedAtUtc: now,
            alarmAudioItemsOverride: [
              audio.copyWith(uri: 'content://completed'),
            ],
          ),
          task().copyWith(
            alarmEnabled: false,
            alarmAudioItemsOverride: [
              audio.copyWith(uri: 'content://disabled'),
            ],
          ),
        ],
        settings: settings,
      );
      expect(report.pendingAlarmCount, 3);
      expect(report.audio, hasLength(2));
    },
  );

  test('unavailable pending queries remain unknown rather than zero', () async {
    for (final value in [null, -1, 'missing', 'error', 0]) {
      messenger.setMockMethodCallHandler(health, (_) async {
        if (value == 'missing') throw MissingPluginException();
        if (value == 'error') throw PlatformException(code: 'unavailable');
        return value;
      });
      final report = await service().inspect(
        tasks: [],
        settings: const AppAlarmSettings(),
      );
      expect(report.pendingAlarmCount, value == 0 ? 0 : null);
      expect(report.pendingNotificationCount, isNull);
    }
  });

  test(
    'test alarm is capped at ten seconds and never syncs/cancels schedules',
    () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(alarm, (call) async {
        calls.add(call.method);
        expect(call.method, 'stopCurrentAlarm');
        return null;
      });
      messenger.setMockMethodCallHandler(health, (call) async {
        calls.add(call.method);
        if (call.method == 'testAlarm') {
          expect(call.arguments, {
            'audioUris': ['content://a'],
            'title': 'Test',
            'maxDurationSeconds': 10,
          });
          return true;
        }
        expect(call.method, 'openNotificationSettings');
        return null;
      });
      final healthService = service();
      expect(
        await healthService.testAlarm(audio: [], title: 'Test'),
        ReminderActionResult.noAudio,
      );
      expect(calls, isEmpty);
      expect(
        await healthService.testAlarm(audio: [audio], title: 'Test'),
        ReminderActionResult.requested,
      );
      expect(await healthService.stopAlarm(), ReminderActionResult.requested);
      expect(
        await healthService.openNotificationSettings(),
        ReminderActionResult.requested,
      );
      expect(calls, [
        'testAlarm',
        'stopCurrentAlarm',
        'openNotificationSettings',
      ]);
    },
  );

  test(
    'native refusal, missing plugin and errors produce safe action results',
    () async {
      for (final value in [false, null, 'missing', 'error']) {
        messenger.setMockMethodCallHandler(health, (_) async {
          if (value == 'missing') throw MissingPluginException();
          if (value == 'error') throw PlatformException(code: 'unavailable');
          return value;
        });
        expect(
          await service().testAlarm(audio: [audio], title: 'Test'),
          value == 'missing'
              ? ReminderActionResult.unsupported
              : ReminderActionResult.failed,
        );
      }
      messenger.setMockMethodCallHandler(
        health,
        (_) async => throw MissingPluginException(),
      );
      expect(
        await service().openNotificationSettings(),
        ReminderActionResult.unsupported,
      );
    },
  );
}
