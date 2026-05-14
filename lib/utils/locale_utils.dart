import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:next_ddl/l10n/app_localizations.dart';

import '../models/app_snapshot.dart';

Locale? resolvePreferredLocale(AppLocalePreference preference) {
  return switch (preference) {
    AppLocalePreference.system => null,
    AppLocalePreference.zh => const Locale('zh'),
    AppLocalePreference.en => const Locale('en'),
    AppLocalePreference.ja => const Locale('ja'),
  };
}

Locale resolveEffectiveLocale(
  AppLocalePreference preference, {
  Locale? systemLocale,
}) {
  final preferred = resolvePreferredLocale(preference);
  if (preferred != null) {
    return preferred;
  }
  final candidate =
      systemLocale ?? WidgetsBinding.instance.platformDispatcher.locale;
  return switch (candidate.languageCode) {
    'zh' => const Locale('zh'),
    'ja' => const Locale('ja'),
    'en' => const Locale('en'),
    _ => const Locale('en'),
  };
}

AppLocalizations resolveAppLocalizations(
  AppLocalePreference preference, {
  Locale? systemLocale,
}) {
  return lookupAppLocalizations(
    resolveEffectiveLocale(preference, systemLocale: systemLocale),
  );
}
