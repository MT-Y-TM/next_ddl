import 'package:next_ddl/l10n/app_localizations.dart';

String resolveMilestoneDisplayTitle(String title, AppLocalizations l10n) {
  return title.trim().isEmpty ? l10n.unnamedMilestone : title;
}
