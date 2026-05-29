import 'package:next_ddl/l10n/app_localizations.dart';

String localizedTimezoneDisplayName(AppLocalizations l10n, String timezoneId) {
  final localized = switch (timezoneId) {
    'Asia/Shanghai' => l10n.timezoneAsiaShanghai,
    'Asia/Hong_Kong' => l10n.timezoneAsiaHongKong,
    'Asia/Taipei' => l10n.timezoneAsiaTaipei,
    'Asia/Tokyo' => l10n.timezoneAsiaTokyo,
    'Asia/Seoul' => l10n.timezoneAsiaSeoul,
    'UTC' => l10n.timezoneUtc,
    'Europe/London' => l10n.timezoneEuropeLondon,
    'America/New_York' => l10n.timezoneAmericaNewYork,
    'America/Los_Angeles' => l10n.timezoneAmericaLosAngeles,
    _ => null,
  };
  if (localized != null) {
    return localized;
  }

  final parts = timezoneId.split('/');
  if (parts.isEmpty) {
    return timezoneId;
  }
  if (parts.length == 1) {
    return _formatTimezoneToken(l10n, parts.single);
  }

  final city = _formatTimezoneToken(l10n, parts.last);
  final qualifiers = [
    for (final part in parts.take(parts.length - 1)) _formatTimezoneToken(l10n, part),
  ].where((part) => part.isNotEmpty).toList();

  if (city.isEmpty) {
    return qualifiers.join(' / ');
  }
  if (qualifiers.isEmpty) {
    return city;
  }
  return switch (_languageCode(l10n)) {
    'zh' => '$city（${qualifiers.join(' / ')}）',
    'ja' => '$city（${qualifiers.join(' / ')}）',
    _ => '$city (${qualifiers.join(' / ')})',
  };
}

String localizedTimezoneLabel(AppLocalizations l10n, String timezoneId) {
  final display = localizedTimezoneDisplayName(l10n, timezoneId);
  return '$display ($timezoneId)';
}

String _formatTimezoneToken(AppLocalizations l10n, String token) {
  final localized = switch (token) {
    'Africa' => l10n.timezoneRegionAfrica,
    'America' => l10n.timezoneRegionAmerica,
    'Antarctica' => l10n.timezoneRegionAntarctica,
    'Arctic' => l10n.timezoneRegionArctic,
    'Asia' => l10n.timezoneRegionAsia,
    'Atlantic' => l10n.timezoneRegionAtlantic,
    'Australia' => l10n.timezoneRegionAustralia,
    'Brazil' => l10n.timezoneRegionBrazil,
    'Canada' => l10n.timezoneRegionCanada,
    'Chile' => l10n.timezoneRegionChile,
    'Etc' => l10n.timezoneRegionEtc,
    'Europe' => l10n.timezoneRegionEurope,
    'Indian' => l10n.timezoneRegionIndian,
    'Mexico' => l10n.timezoneRegionMexico,
    'Pacific' => l10n.timezoneRegionPacific,
    'US' => l10n.timezoneRegionUs,
    _ => null,
  };
  if (localized != null) {
    return localized;
  }

  final normalized = token
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      )
      .replaceAll('_', ' ')
      .trim();
  if (normalized.isEmpty) {
    return normalized;
  }
  if (_looksLikeCode(normalized)) {
    return normalized;
  }

  final words = normalized.split(RegExp(r'\s+'));
  return words.map(_capitalizeWord).join(' ');
}

String _capitalizeWord(String word) {
  if (word.isEmpty) {
    return word;
  }
  if (_looksLikeCode(word)) {
    return word;
  }
  return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
}

bool _looksLikeCode(String value) {
  return RegExp(r'^[A-Z0-9+\-]+$').hasMatch(value);
}

String _languageCode(AppLocalizations l10n) {
  final localeName = l10n.localeName;
  final separator = localeName.indexOf('_');
  return separator == -1 ? localeName : localeName.substring(0, separator);
}
