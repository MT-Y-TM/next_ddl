import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_ddl/l10n/app_localizations.dart';

import '../update/app_update_controller.dart';
import '../update/app_update_state.dart';
import '../../models/app_snapshot.dart';
import '../../services/timezone_service.dart';
import '../../utils/timezone_labels.dart';
import '../tasks/tasks_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(tasksControllerProvider).valueOrNull;
    final versionAsync = ref.watch(appVersionProvider);
    ref.watch(timezoneRevisionProvider);
    final timezoneId = ref.watch(timezoneServiceProvider).currentTimezoneId;
    final updateState = ref.watch(appUpdateControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.system_update_alt_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.updates,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _updateStatusText(l10n, updateState),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (updateState.release case final release?) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.publishedAtLabel(
                        _formatDateTime(release.publishedAtUtc.toLocal()),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.updateReleaseNotes,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      release.body.isEmpty ? l10n.noReleaseNotes : release.body,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (!Platform.isAndroid) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.windowsUpdateNotice,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed:
                            updateState.status == AppUpdateStatus.checking
                                ? null
                                : () {
                                    ref
                                        .read(
                                          appUpdateControllerProvider.notifier,
                                        )
                                        .checkForUpdate(userInitiated: true);
                                  },
                        child: Text(
                          updateState.status == AppUpdateStatus.checking
                              ? l10n.checkingForUpdates
                              : l10n.checkForUpdates,
                        ),
                      ),
                      if (updateState.release != null)
                        FilledButton(
                          onPressed: () {
                            if (Platform.isAndroid) {
                              ref
                                  .read(appUpdateControllerProvider.notifier)
                                  .downloadAndInstall();
                              return;
                            }
                            ref
                                .read(appUpdateControllerProvider.notifier)
                                .openReleasePage();
                          },
                          child: Text(
                            Platform.isAndroid
                                ? l10n.updateNow
                                : l10n.openReleasePage,
                          ),
                        ),
                      if (updateState.requiresInstallPermission)
                        OutlinedButton(
                          onPressed: () {
                            ref
                                .read(appUpdateControllerProvider.notifier)
                                .openInstallPermissionSettings();
                          },
                          child: Text(l10n.openInstallPermission),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storage_outlined),
              title: Text(l10n.taskCount),
              subtitle: Text(l10n.taskCountValue(snapshot?.tasks.length ?? 0)),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.translate_outlined),
              title: Text(l10n.language),
              subtitle: Text(_localeLabel(l10n, snapshot?.preferredLocale)),
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<AppLocalePreference>(
                  value: snapshot?.preferredLocale ?? AppLocalePreference.system,
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
                        child: Text(_localeLabel(l10n, item)),
                      ),
                  ],
                ),
              ),
            ),
          ),
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
          Card(
            child: ListTile(
              leading: const Icon(Icons.public_outlined),
              title: Text(l10n.appTimezone),
              subtitle: Text(localizedTimezoneLabel(l10n, timezoneId)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickTimezone(context, ref),
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

  Future<void> _pickTimezone(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(tasksControllerProvider.notifier);
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _TimezonePickerDialog(
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

  String _localeLabel(AppLocalizations l10n, AppLocalePreference? preference) {
    return switch (preference ?? AppLocalePreference.system) {
      AppLocalePreference.system => l10n.localeSystem,
      AppLocalePreference.zh => l10n.localeZh,
      AppLocalePreference.en => l10n.localeEn,
      AppLocalePreference.ja => l10n.localeJa,
    };
  }

  String _updateStatusText(AppLocalizations l10n, AppUpdateState state) {
    return switch (state.status) {
      AppUpdateStatus.idle => l10n.checkForUpdates,
      AppUpdateStatus.checking => l10n.checkingForUpdates,
      AppUpdateStatus.upToDate => l10n.appUpToDate,
      AppUpdateStatus.updateAvailable => l10n.updateAvailableStatus(
        state.release?.version ?? '',
      ),
      AppUpdateStatus.downloading => l10n.updateDownloading,
      AppUpdateStatus.installReady =>
        state.requiresInstallPermission
            ? l10n.updatePermissionRequired
            : l10n.updateInstallReady,
      AppUpdateStatus.error => l10n.updateError(state.errorMessage ?? 'unknown'),
    };
  }

  String _formatDateTime(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:'
        '${value.second.toString().padLeft(2, '0')}';
  }
}

class _TimezonePickerDialog extends StatefulWidget {
  const _TimezonePickerDialog({
    required this.currentTimezoneId,
    required this.timezoneIds,
  });

  final String currentTimezoneId;
  final List<String> timezoneIds;

  @override
  State<_TimezonePickerDialog> createState() => _TimezonePickerDialogState();
}

class _TimezonePickerDialogState extends State<_TimezonePickerDialog> {
  static const _commonTimezoneIds = [
    'Asia/Shanghai',
    'Asia/Hong_Kong',
    'Asia/Taipei',
    'Asia/Tokyo',
    'Asia/Seoul',
    'UTC',
    'Europe/London',
    'America/New_York',
    'America/Los_Angeles',
  ];

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = _filteredTimezoneIds();
    return AlertDialog(
      title: Text(l10n.chooseTimezone),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: l10n.searchTimezone,
                hintText: l10n.searchTimezoneHint,
              ),
              onChanged: (value) {
                setState(() {
                  _query = value.trim().toLowerCase();
                });
              },
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final timezoneId = items[index];
                  final selected = timezoneId == widget.currentTimezoneId;
                  return ListTile(
                    dense: true,
                    leading: selected
                        ? const Icon(Icons.check)
                        : const SizedBox(width: 24),
                    title: Text(localizedTimezoneDisplayName(l10n, timezoneId)),
                    subtitle: Text(timezoneId),
                    onTap: () => Navigator.of(context).pop(timezoneId),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }

  List<String> _filteredTimezoneIds() {
    final l10n = AppLocalizations.of(context)!;
    final known = widget.timezoneIds.toSet();
    final common = [
      for (final timezoneId in _commonTimezoneIds)
        if (known.contains(timezoneId)) timezoneId,
    ];
    final rest = [
      for (final timezoneId in widget.timezoneIds)
        if (!common.contains(timezoneId)) timezoneId,
    ];
    final ordered = [...common, ...rest];
    if (_query.isEmpty) {
      return ordered;
    }
    return [
      for (final timezoneId in ordered)
        if (timezoneId.toLowerCase().contains(_query) ||
            localizedTimezoneDisplayName(l10n, timezoneId)
                .toLowerCase()
                .contains(
              _query,
            ))
          timezoneId,
    ];
  }
}
