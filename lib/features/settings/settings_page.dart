import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_ddl/l10n/app_localizations.dart';

import '../../models/app_alarm_settings.dart';
import '../../models/app_snapshot.dart';
import '../../models/app_theme_settings.dart';
import '../../services/timezone_service.dart';
import '../../utils/timezone_labels.dart';
import '../tasks/tasks_controller.dart';
import '../update/app_update_controller.dart';
import 'settings_formatters.dart';
import 'widgets/alarm_settings_card.dart';
import 'widgets/theme_settings_card.dart';
import 'widgets/timezone_picker_dialog.dart';
import 'widgets/update_settings_card.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(tasksControllerProvider).valueOrNull;
    final versionAsync = ref.watch(appVersionProvider);
    ref.watch(timezoneRevisionProvider);
    final timezoneId = ref.watch(timezoneServiceProvider).currentTimezoneId;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsEntryCard(
            icon: Icons.storage_outlined,
            title: l10n.settingsTasksAndData,
            subtitle: l10n.taskCountValue(snapshot?.tasks.length ?? 0),
            onTap: () => _push(context, const _TaskDataSettingsPage()),
          ),
          _SettingsEntryCard(
            icon: Icons.palette_outlined,
            title: l10n.themeSettings,
            subtitle: _themeSubtitle(l10n, snapshot?.themeSettings),
            onTap: () => _push(context, const _ThemeSettingsPage()),
          ),
          _SettingsEntryCard(
            icon: Icons.notifications_active_outlined,
            title: l10n.settingsNotificationsAndAlarms,
            subtitle: _notificationsSubtitle(l10n, snapshot),
            onTap: () => _push(context, const _NotificationAlarmSettingsPage()),
          ),
          _SettingsEntryCard(
            icon: Icons.translate_outlined,
            title: l10n.settingsLanguageAndTimezone,
            subtitle:
                '${settingsLocaleLabel(l10n, snapshot?.preferredLocale)} · ${localizedTimezoneLabel(l10n, timezoneId)}',
            onTap: () => _push(context, const _LanguageTimezoneSettingsPage()),
          ),
          _SettingsEntryCard(
            icon: Icons.info_outline,
            title: l10n.settingsAboutApp,
            subtitle: versionAsync.valueOrNull ?? l10n.loading,
            onTap: () => _push(context, const _AboutAppSettingsPage()),
          ),
        ],
      ),
    );
  }

  String _themeSubtitle(AppLocalizations l10n, AppThemeSettings? settings) {
    final current = settings ?? AppThemeSettings.defaults();
    return switch (current.backgroundMode) {
      ThemeBackgroundMode.solid => l10n.themeBackgroundSolid,
      ThemeBackgroundMode.gradient => l10n.themeBackgroundGradient,
      ThemeBackgroundMode.image => l10n.themeBackgroundImage,
    };
  }

  String _notificationsSubtitle(AppLocalizations l10n, AppSnapshot? snapshot) {
    if (snapshot == null) {
      return l10n.loading;
    }
    final persistent = snapshot.persistentNotificationEnabled
        ? l10n.persistentEnabled
        : l10n.persistentDisabled;
    final alarm = snapshot.alarmSettings.enabled
        ? l10n.enableAlarmFeature
        : l10n.alarmSettings;
    return '$persistent · $alarm';
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _SettingsEntryCard extends StatelessWidget {
  const _SettingsEntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _TaskDataSettingsPage extends ConsumerWidget {
  const _TaskDataSettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(tasksControllerProvider).valueOrNull;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTasksAndData)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.storage_outlined),
              title: Text(l10n.taskCount),
              subtitle: Text(l10n.taskCountValue(snapshot?.tasks.length ?? 0)),
            ),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title: Text(l10n.exportJson),
                  subtitle: Text(l10n.exportJsonHint),
                  onTap: () async {
                    final path = await ref
                        .read(tasksControllerProvider.notifier)
                        .exportSnapshot();
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          path == null
                              ? l10n.exportCancelled
                              : l10n.exportSuccess(path),
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: Text(l10n.importJson),
                  subtitle: Text(l10n.importJsonHint),
                  onTap: () async {
                    final imported = await ref
                        .read(tasksControllerProvider.notifier)
                        .importSnapshot();
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          imported == null
                              ? l10n.importCancelled
                              : l10n.importSuccess(imported.tasks.length),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeSettingsPage extends ConsumerWidget {
  const _ThemeSettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(tasksControllerProvider).valueOrNull;
    final themeSettings =
        snapshot?.themeSettings ?? AppThemeSettings.defaults();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.themeSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ThemeSettingsCard(settings: themeSettings, enabled: snapshot != null),
        ],
      ),
    );
  }
}

class _NotificationAlarmSettingsPage extends ConsumerWidget {
  const _NotificationAlarmSettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(tasksControllerProvider).valueOrNull;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsNotificationsAndAlarms)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: Text(l10n.persistentNotification),
              subtitle: Text(
                Platform.isAndroid
                    ? l10n.persistentNotificationAndroidHint
                    : l10n.persistentNotificationOtherHint,
              ),
              value: snapshot?.persistentNotificationEnabled ?? false,
              onChanged: snapshot == null
                  ? null
                  : (value) async {
                      await ref
                          .read(tasksControllerProvider.notifier)
                          .setPersistentNotificationEnabled(value);
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? l10n.persistentEnabled
                                : l10n.persistentDisabled,
                          ),
                        ),
                      );
                    },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.straighten_outlined),
              title: Text(l10n.messageBarUnit),
              subtitle: Text(
                (snapshot?.persistentNotificationTimeUnit ??
                            PersistentNotificationTimeUnit.day) ==
                        PersistentNotificationTimeUnit.day
                    ? l10n.unitByDay
                    : l10n.unitByHour,
              ),
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<PersistentNotificationTimeUnit>(
                  value:
                      snapshot?.persistentNotificationTimeUnit ??
                      PersistentNotificationTimeUnit.day,
                  onChanged: snapshot == null
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          ref
                              .read(tasksControllerProvider.notifier)
                              .setPersistentNotificationTimeUnit(value);
                        },
                  items: [
                    DropdownMenuItem(
                      value: PersistentNotificationTimeUnit.day,
                      child: Text(l10n.unitByDay),
                    ),
                    DropdownMenuItem(
                      value: PersistentNotificationTimeUnit.hour,
                      child: Text(l10n.unitByHour),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AlarmSettingsCard(
            settings: snapshot?.alarmSettings ?? AppAlarmSettings.defaults(),
            enabled: snapshot != null,
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(l10n.notificationNotice),
              subtitle: Text(
                Platform.isWindows
                    ? l10n.windowsNotificationNotice
                    : l10n.androidNotificationNotice,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageTimezoneSettingsPage extends ConsumerWidget {
  const _LanguageTimezoneSettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(tasksControllerProvider).valueOrNull;
    ref.watch(timezoneRevisionProvider);
    final timezoneId = ref.watch(timezoneServiceProvider).currentTimezoneId;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsLanguageAndTimezone)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.translate_outlined),
              title: Text(l10n.language),
              subtitle: Text(
                settingsLocaleLabel(l10n, snapshot?.preferredLocale),
              ),
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<AppLocalePreference>(
                  value:
                      snapshot?.preferredLocale ?? AppLocalePreference.system,
                  onChanged: snapshot == null
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          ref
                              .read(tasksControllerProvider.notifier)
                              .setPreferredLocale(value);
                        },
                  items: [
                    for (final item in AppLocalePreference.values)
                      DropdownMenuItem<AppLocalePreference>(
                        value: item,
                        child: Text(settingsLocaleLabel(l10n, item)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.public_outlined),
              title: Text(l10n.appTimezone),
              subtitle: Text(localizedTimezoneLabel(l10n, timezoneId)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickTimezone(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTimezone(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(tasksControllerProvider.notifier);
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => TimezonePickerDialog(
        currentTimezoneId: controller.timezoneId,
        timezoneIds: controller.timezoneIds,
      ),
    );
    if (selected == null || selected == controller.timezoneId) {
      return;
    }
    final changed = await controller.setTimezone(selected);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          changed ? l10n.timezoneUpdated(selected) : l10n.timezoneInvalid,
        ),
      ),
    );
  }
}

class _AboutAppSettingsPage extends ConsumerWidget {
  const _AboutAppSettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(appVersionProvider);
    final updateState = ref.watch(appUpdateControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAboutApp)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.currentVersion),
              subtitle: Text(versionAsync.valueOrNull ?? l10n.loading),
            ),
          ),
          UpdateSettingsCard(state: updateState),
        ],
      ),
    );
  }
}
