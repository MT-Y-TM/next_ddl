import '../models/app_snapshot.dart';

String formatCountdown(
  Duration duration, {
  String overduePrefix = '已超时',
  String daySuffix = '天',
}) {
  final isNegative = duration.isNegative;
  final absolute = duration.abs();
  final days = absolute.inDays;
  final hours = absolute.inHours.remainder(24).toString().padLeft(2, '0');
  final minutes =
      absolute.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds =
      absolute.inSeconds.remainder(60).toString().padLeft(2, '0');
  final value = '$days$daySuffix $hours:$minutes:$seconds';
  return isNegative ? '$overduePrefix $value' : value;
}

String formatCompactCountdown(
  Duration duration, {
  required PersistentNotificationTimeUnit timeUnit,
  String daySuffix = '天',
  String hourSuffix = '小时',
}) {
  final absoluteMinutes = duration.abs().inMilliseconds /
      Duration.millisecondsPerMinute;
  if (timeUnit == PersistentNotificationTimeUnit.day) {
    final days = absoluteMinutes / 60 / 24;
    final display = duration == Duration.zero ? 0 : days.clamp(0.1, days);
    return '${display.toStringAsFixed(1)}$daySuffix';
  }
  final hours = absoluteMinutes / 60;
  final displayHours = duration == Duration.zero ? 0 : hours.ceil();
  return '$displayHours$hourSuffix';
}

String formatCountdownFromDates({
  required DateTime now,
  required DateTime target,
  String overduePrefix = '已超时',
  String daySuffix = '天',
}) {
  return formatCountdown(
    target.difference(now),
    overduePrefix: overduePrefix,
    daySuffix: daySuffix,
  );
}
