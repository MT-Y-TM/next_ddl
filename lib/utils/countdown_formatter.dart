String formatCountdown(Duration duration) {
  final isNegative = duration.isNegative;
  final absolute = duration.abs();
  final days = absolute.inDays;
  final hours = absolute.inHours.remainder(24).toString().padLeft(2, '0');
  final minutes =
      absolute.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds =
      absolute.inSeconds.remainder(60).toString().padLeft(2, '0');
  final value = '$days天 $hours:$minutes:$seconds';
  return isNegative ? '已超时 $value' : value;
}

String formatCountdownFromDates({
  required DateTime now,
  required DateTime target,
}) {
  return formatCountdown(target.difference(now));
}
