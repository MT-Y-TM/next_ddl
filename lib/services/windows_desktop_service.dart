import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:next_ddl/l10n/app_localizations.dart';
import '../models/app_snapshot.dart';
import '../utils/countdown_formatter.dart';
import '../utils/deadline_logic.dart';
import '../utils/locale_utils.dart';

class WindowsDesktopService {
  WindowsDesktopService({MethodChannel? channel, bool? enabled})
    : _channel = channel ?? const MethodChannel('next_ddl/desktop'),
      _enabled = enabled ?? Platform.isWindows;
  final MethodChannel _channel;
  final bool _enabled;
  String? _lastSummary;
  Future<void> _pending = Future.value();

  static Map<String, Object> buildSummary(
    AppSnapshot snapshot,
    DateTime now,
    AppLocalizations l,
  ) {
    final task = resolveMostUrgentInProgressTask(snapshot.tasks, now);
    return {
      'enabled': snapshot.persistentNotificationEnabled,
      'title': task == null ? l.ongoingNoTask : resolvePersistentNotificationTargetTitle(task, now),
      'remaining': task == null ? '' : formatCompactCountdown(
        resolveActiveDeadlinePoint(task, now).difference(now),
        timeUnit: snapshot.persistentNotificationTimeUnit,
        daySuffix: l.compactDaySuffix, hourSuffix: l.compactHourSuffix),
      'openLabel': l.desktopOpenApp,
      'exitLabel': l.desktopExitApp,
    };
  }
  Future<void> sync(AppSnapshot snapshot, DateTime now) {
    if (!_enabled) return Future.value();
    final summary = buildSummary(snapshot, now, resolveAppLocalizations(snapshot.preferredLocale));
    final encoded = jsonEncode(summary);
    final next = _pending.then((_) async {
      if (_lastSummary == encoded) return;
      await _channel.invokeMethod<void>('syncSummary', summary);
      _lastSummary = encoded;
    });
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}
