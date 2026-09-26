import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/app_snapshot.dart';

/// One app-scoped instance. Register the native plugin before calling on Android.
class HomeWidgetService {
  HomeWidgetService({MethodChannel? channel, bool? enabled})
    : _channel = channel ?? const MethodChannel('next_ddl/home_widget'),
      _enabled =
          enabled ??
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  final MethodChannel _channel;
  final bool _enabled;
  Future<void> _writes = Future<void>.value();
  Future<void> _taps = Future<void>.value();

  /// Retains all unfinished candidates so native refresh can advance without Dart.
  static Map<String, Object?> buildSnapshot(
    AppSnapshot snapshot, {
    required String timezoneId,
  }) => {
    'schemaVersion': 1,
    'locale': snapshot.preferredLocale.tag,
    'timezoneId': timezoneId,
    'tasks': [
      for (final task in snapshot.tasks)
        if (task.completedAtUtc == null)
          {
            'id': task.id,
            'title': task.title,
            'finalDueAtUtc': task.finalDueAtUtc.millisecondsSinceEpoch,
            'updatedAtUtc': task.updatedAtUtc.millisecondsSinceEpoch,
            'milestones': [
              for (final node in task.milestones)
                if (node.completedAtUtc == null)
                  {
                    'title': node.title,
                    'dueAtUtc': node.dueAtUtc.millisecondsSinceEpoch,
                  },
            ],
          },
    ],
  };

  Future<void> sync(AppSnapshot snapshot, {required String timezoneId}) {
    if (!_enabled) return Future<void>.value();
    final json = jsonEncode(buildSnapshot(snapshot, timezoneId: timezoneId));
    final write = _writes.then(
      (_) => _channel.invokeMethod<void>('writeSnapshot', {'snapshot': json}),
    );
    // A failed platform write must not poison subsequent syncs.
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return write;
  }

  /// Call after repository load and the navigator's first frame. The callback
  /// must check task existence and fall back to the home page for deleted IDs.
  Future<void> listenForTaskTaps(FutureOr<void> Function(String) onTap) async {
    if (!_enabled) return;
    Future<void> drain() {
      final next = _taps.then((_) async {
        final id = await _channel.invokeMethod<String>('consumePendingTaskId');
        if (id != null && id.isNotEmpty) await onTap(id);
      });
      _taps = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
      return next;
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'taskTapAvailable') await drain();
    });
    await drain();
  }

  void dispose() {
    if (_enabled) _channel.setMethodCallHandler(null);
  }
}
