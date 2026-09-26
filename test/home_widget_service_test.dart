import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:next_ddl/models/app_snapshot.dart';
import 'package:next_ddl/models/deadline_task.dart';
import 'package:next_ddl/models/milestone.dart';
import 'package:next_ddl/services/home_widget_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('next_ddl/home_widget');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final now = DateTime.utc(2026, 9, 25);
  DeadlineTask task(String id, {bool completed = false}) => DeadlineTask(
    id: id,
    title: 'Task $id',
    note: 'Private note not needed by widget',
    timezoneId: 'UTC',
    createdAtUtc: now,
    updatedAtUtc: now,
    finalDueAtUtc: now.add(const Duration(days: 2)),
    completedAtUtc: completed ? now : null,
    milestones: [
      Milestone(
        id: 'blank',
        title: ' ',
        dueAtUtc: now,
        source: MilestoneSource.manual,
      ),
      Milestone(
        id: 'done',
        title: 'Done',
        dueAtUtc: now,
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
    reminderOffsetsSeconds: const [],
    notificationsEnabled: false,
  );

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'snapshot excludes completed tasks/nodes and private data; keeps future candidates',
    () {
      final result = HomeWidgetService.buildSnapshot(
        AppSnapshot.empty().copyWith(
          tasks: [task('open'), task('done', completed: true)],
        ),
        timezoneId: 'Asia/Tokyo',
      );
      final tasks = result['tasks'] as List;
      expect(tasks, hasLength(1));
      expect(tasks.single['milestones'], hasLength(2));
      expect(tasks.single['milestones'][0]['title'], ' ');
      expect(
        tasks.single['finalDueAtUtc'],
        now.add(const Duration(days: 2)).millisecondsSinceEpoch,
      );
      expect(tasks.single.containsKey('note'), false);
      expect(result['timezoneId'], 'Asia/Tokyo');
      expect(result['schemaVersion'], 1);
    },
  );

  for (final locale in AppLocalePreference.values) {
    test('serializes ${locale.tag} and empty state', () {
      final result = HomeWidgetService.buildSnapshot(
        AppSnapshot.empty().copyWith(preferredLocale: locale),
        timezoneId: 'UTC',
      );
      expect(result['locale'], locale.tag);
      expect(result['tasks'], isEmpty);
    });
  }

  test('writes ordered full snapshots including deletion', () async {
    final writes = <Map<String, dynamic>>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'writeSnapshot');
      writes.add(
        jsonDecode((call.arguments as Map)['snapshot'] as String)
            as Map<String, dynamic>,
      );
      return null;
    });
    final service = HomeWidgetService(enabled: true);
    await Future.wait([
      service.sync(
        AppSnapshot.empty().copyWith(tasks: [task('one')]),
        timezoneId: 'UTC',
      ),
      service.sync(AppSnapshot.empty(), timezoneId: 'Asia/Shanghai'),
    ]);
    expect(writes.first['tasks'], hasLength(1));
    expect(writes.last['tasks'], isEmpty);
    expect(writes.last['timezoneId'], 'Asia/Shanghai');
  });

  test('failed sync is reported but does not block later sync', () async {
    var count = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      if (count++ == 0) throw PlatformException(code: 'disk_full');
      return null;
    });
    final service = HomeWidgetService(enabled: true);
    await expectLater(
      service.sync(AppSnapshot.empty(), timezoneId: 'UTC'),
      throwsA(isA<PlatformException>()),
    );
    await service.sync(AppSnapshot.empty(), timezoneId: 'UTC');
    expect(count, 2);
  });

  test('non Android service never invokes platform', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => fail('unexpected platform call'),
    );
    final service = HomeWidgetService(enabled: false);
    await service.sync(AppSnapshot.empty(), timezoneId: 'UTC');
    await service.listenForTaskTaps((_) => fail('unexpected tap'));
    service.dispose();
  });

  test('cold and warm taps consumed once; disposal removes callback', () async {
    String? pending = 'cold';
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'consumePendingTaskId');
      final value = pending;
      pending = null;
      return value;
    });
    final service = HomeWidgetService(enabled: true);
    final taps = <String>[];
    await service.listenForTaskTaps(taps.add);
    Future<void> notify() async {
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('taskTapAvailable'),
        ),
        (_) {},
      );
    }

    pending = 'warm';
    await notify();
    await notify();
    expect(taps, ['cold', 'warm']);
    service.dispose();
    pending = 'after-dispose';
    await notify();
    expect(taps, ['cold', 'warm']);
  });
}
