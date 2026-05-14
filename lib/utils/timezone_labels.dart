import 'package:next_ddl/l10n/app_localizations.dart';

String localizedTimezoneDisplayName(AppLocalizations l10n, String timezoneId) {
  return switch (timezoneId) {
    'Asia/Shanghai' => l10n.timezoneAsiaShanghai,
    'Asia/Hong_Kong' => l10n.timezoneAsiaHongKong,
    'Asia/Taipei' => l10n.timezoneAsiaTaipei,
    'Asia/Tokyo' => l10n.timezoneAsiaTokyo,
    'Asia/Seoul' => l10n.timezoneAsiaSeoul,
    'UTC' => l10n.timezoneUtc,
    'Europe/London' => l10n.timezoneEuropeLondon,
    'America/New_York' => l10n.timezoneAmericaNewYork,
    'America/Los_Angeles' => l10n.timezoneAmericaLosAngeles,
    _ => timezoneId.split('/').last.replaceAll('_', ' '),
  };
}

String localizedTimezoneLabel(AppLocalizations l10n, String timezoneId) {
  final display = localizedTimezoneDisplayName(l10n, timezoneId);
  return '$display ($timezoneId)';
}
