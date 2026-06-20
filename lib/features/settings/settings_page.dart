import 'dart:io';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_ddl/l10n/app_localizations.dart';

import '../update/app_update_controller.dart';
import '../update/app_update_state.dart';
import '../../models/app_snapshot.dart';
import '../../models/app_theme_settings.dart';
import '../../models/app_alarm_settings.dart';
import '../../services/alarm_audio_picker_service.dart';
import '../../services/theme_asset_service.dart';
import '../../services/timezone_service.dart';
import '../../services/app_update_service.dart';
import '../../utils/timezone_labels.dart';
import '../tasks/tasks_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(tasksControllerProvider).valueOrNull;
    final themeSettings = snapshot?.themeSettings ?? AppThemeSettings.defaults();
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
                  if (updateState.hasReusableLocalInstaller &&
                      updateState.status != AppUpdateStatus.downloading) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.updateUsingCachedInstaller(
                        updateState.localInstallerVersion ??
                            updateState.release?.version ??
                            '',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (updateState.status == AppUpdateStatus.downloading) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: updateState.downloadProgress),
                    const SizedBox(height: 8),
                    Text(
                      _downloadProgressText(l10n, updateState),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
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
                          onPressed:
                              updateState.status == AppUpdateStatus.downloading
                                  ? null
                                  : () {
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
                      OutlinedButton(
                        onPressed: () async {
                          final removed = await ref
                              .read(appUpdateControllerProvider.notifier)
                              .clearCachedInstallers();
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                removed == 0
                                    ? l10n.noCachedInstallers
                                    : l10n.cachedInstallersCleared(removed),
                              ),
                            ),
                          );
                        },
                        child: Text(l10n.clearCachedInstallers),
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
          _ThemeSettingsCard(
            settings: themeSettings,
            enabled: snapshot != null,
          ),
          _AlarmSettingsCard(
            settings: snapshot?.alarmSettings ?? AppAlarmSettings.defaults(),
            enabled: snapshot != null,
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
      AppUpdateStatus.downloading => state.isUsingCachedInstaller
          ? l10n.updateUsingCachedInstaller(
              state.localInstallerVersion ?? state.release?.version ?? '',
            )
          : l10n.updateDownloading,
      AppUpdateStatus.installReady =>
        state.requiresInstallPermission
            ? l10n.updatePermissionRequired
            : l10n.updateInstallReady,
      AppUpdateStatus.error => _updateErrorText(l10n, state.error),
    };
  }

  String _downloadProgressText(AppLocalizations l10n, AppUpdateState state) {
    final percent = state.downloadPercent;
    final speed = state.downloadSpeedBytesPerSecond;
    final percentText =
        percent == null ? l10n.downloadProgressUnknown : l10n.downloadPercent(percent);
    final speedText = speed == null || speed <= 0
        ? l10n.downloadSpeedUnknown
        : l10n.downloadSpeed(_formatSpeed(speed));
    return '$percentText · $speedText';
  }

  String _updateErrorText(
    AppLocalizations l10n,
    AppUpdateException? error,
  ) {
    return switch (error?.type ?? AppUpdateErrorType.unknown) {
      AppUpdateErrorType.noPublishedRelease => l10n.updateNoPublishedRelease,
      AppUpdateErrorType.networkUnavailable => l10n.updateErrorNetworkUnavailable,
      AppUpdateErrorType.serviceUnavailable => l10n.updateErrorServiceUnavailable,
      AppUpdateErrorType.missingAndroidAsset => l10n.updateErrorMissingAndroidAsset,
      AppUpdateErrorType.downloadFailed => l10n.updateErrorDownloadFailed,
      AppUpdateErrorType.installerOpenFailed => l10n.updateErrorInstallerOpenFailed,
      AppUpdateErrorType.openReleasePageFailed => l10n.updateErrorOpenReleasePageFailed,
      AppUpdateErrorType.openInstallPermissionFailed =>
        l10n.updateErrorOpenInstallPermissionFailed,
      AppUpdateErrorType.unknown => l10n.updateErrorUnexpected,
    };
  }

  String _formatDateTime(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:'
        '${value.second.toString().padLeft(2, '0')}';
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond >= 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
  }
}

class _AlarmSettingsCard extends ConsumerWidget {
  const _AlarmSettingsCard({
    required this.settings,
    required this.enabled,
  });

  final AppAlarmSettings settings;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.alarm_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.alarmSettings,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              Platform.isAndroid ? l10n.alarmAndroidHint : l10n.alarmWindowsHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.enabled,
              onChanged: enabled
                  ? (value) => ref
                      .read(tasksControllerProvider.notifier)
                      .setAlarmSettings(settings.copyWith(enabled: value))
                  : null,
              title: Text(l10n.enableAlarmFeature),
              subtitle: Text(l10n.enableAlarmFeatureHint),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.library_music_outlined),
              title: Text(l10n.globalAlarmPlaylist),
              subtitle: Text(l10n.alarmAudioCount(settings.globalAudioItems.length)),
              trailing: FilledButton.tonalIcon(
                onPressed: enabled ? () => _pickGlobalAudio(ref) : null,
                icon: const Icon(Icons.add),
                label: Text(l10n.addAlarmAudio),
              ),
            ),
            for (final item in settings.globalAudioItems)
              ListTile(
                dense: true,
                title: Text(item.displayName),
                subtitle: Text(item.uri, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  tooltip: l10n.delete,
                  onPressed: enabled
                      ? () => _removeAudio(ref, item.id)
                      : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            if (Platform.isAndroid) ...[
              const SizedBox(height: 8),
              FutureBuilder<bool>(
                future: ref
                    .read(tasksControllerProvider.notifier)
                    .canScheduleExactAlarms(),
                builder: (context, snapshot) {
                  final allowed = snapshot.data;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      allowed == true
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_outlined,
                    ),
                    title: Text(l10n.exactAlarmPermission),
                    subtitle: Text(
                      allowed == true
                          ? l10n.exactAlarmPermissionGranted
                          : l10n.exactAlarmPermissionMissing,
                    ),
                    trailing: OutlinedButton(
                      onPressed: () => ref
                          .read(tasksControllerProvider.notifier)
                          .openExactAlarmSettings(),
                      child: Text(l10n.openAlarmPermission),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickGlobalAudio(WidgetRef ref) async {
    final picked = await ref.read(alarmAudioPickerServiceProvider).pickAudioItems();
    if (picked.isEmpty) {
      return;
    }
    await ref.read(tasksControllerProvider.notifier).setAlarmSettings(
          settings.copyWith(
            globalAudioItems: [...settings.globalAudioItems, ...picked],
          ),
        );
  }

  Future<void> _removeAudio(WidgetRef ref, String id) async {
    await ref.read(tasksControllerProvider.notifier).setAlarmSettings(
          settings.copyWith(
            globalAudioItems:
                settings.globalAudioItems.where((item) => item.id != id).toList(),
          ),
        );
  }
}

class _ThemeSettingsCard extends ConsumerWidget {
  const _ThemeSettingsCard({
    required this.settings,
    required this.enabled,
  });

  final AppThemeSettings settings;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.palette_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.themeSettings,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: enabled
                      ? () => _pickColor(
                            context,
                            ref,
                            l10n.themePrimaryColor,
                            Color(settings.seedColorValue),
                            (color) => settings.copyWith(
                              seedColorValue: color.toARGB32(),
                            ),
                          )
                      : null,
                  icon: _ColorSwatch(color: Color(settings.seedColorValue)),
                  label: Text(l10n.themePrimaryColor),
                ),
                OutlinedButton.icon(
                  onPressed: enabled
                      ? () => _pickColor(
                            context,
                            ref,
                            l10n.themeSolidBackground,
                            Color(settings.solidBackgroundColorValue),
                            (color) => settings.copyWith(
                              backgroundMode: ThemeBackgroundMode.solid,
                              solidBackgroundColorValue: color.toARGB32(),
                            ),
                          )
                      : null,
                  icon: _ColorSwatch(
                    color: Color(settings.solidBackgroundColorValue),
                  ),
                  label: Text(l10n.themeSolidBackground),
                ),
                OutlinedButton.icon(
                  onPressed: enabled ? () => _editBackgroundImage(context, ref) : null,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(l10n.themeBackgroundImage),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.themeCornerRadius(settings.cornerRadius.round())),
            Slider(
              value: settings.cornerRadius,
              min: 0,
              max: 32,
              divisions: 32,
              onChanged: enabled
                  ? (value) => ref
                      .read(tasksControllerProvider.notifier)
                      .setThemeSettings(settings.copyWith(cornerRadius: value))
                  : null,
            ),
            const SizedBox(height: 8),
            SegmentedButton<ThemeBackgroundMode>(
              segments: [
                ButtonSegment(
                  value: ThemeBackgroundMode.solid,
                  label: Text(l10n.themeBackgroundSolid),
                  icon: const Icon(Icons.format_color_fill_outlined),
                ),
                ButtonSegment(
                  value: ThemeBackgroundMode.gradient,
                  label: Text(l10n.themeBackgroundGradient),
                  icon: const Icon(Icons.gradient_outlined),
                ),
                ButtonSegment(
                  value: ThemeBackgroundMode.image,
                  label: Text(l10n.themeBackgroundImage),
                  icon: const Icon(Icons.image_outlined),
                ),
              ],
              selected: {settings.backgroundMode},
              onSelectionChanged: enabled
                  ? (values) => ref
                      .read(tasksControllerProvider.notifier)
                      .setThemeSettings(
                        settings.copyWith(backgroundMode: values.single),
                      )
                  : null,
            ),
            if (settings.backgroundMode == ThemeBackgroundMode.gradient) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: enabled
                        ? () => _pickColor(
                              context,
                              ref,
                              l10n.themeGradientStart,
                              Color(settings.gradientStartColorValue),
                              (color) => settings.copyWith(
                                gradientStartColorValue: color.toARGB32(),
                              ),
                            )
                        : null,
                    icon: _ColorSwatch(
                      color: Color(settings.gradientStartColorValue),
                    ),
                    label: Text(l10n.themeGradientStart),
                  ),
                  OutlinedButton.icon(
                    onPressed: enabled
                        ? () => _pickColor(
                              context,
                              ref,
                              l10n.themeGradientEnd,
                              Color(settings.gradientEndColorValue),
                              (color) => settings.copyWith(
                                gradientEndColorValue: color.toARGB32(),
                              ),
                            )
                        : null,
                    icon: _ColorSwatch(
                      color: Color(settings.gradientEndColorValue),
                    ),
                    label: Text(l10n.themeGradientEnd),
                  ),
                ],
              ),
            ],
            if (settings.backgroundMode == ThemeBackgroundMode.image) ...[
              const SizedBox(height: 12),
              Text(
                settings.backgroundImagePath == null
                    ? l10n.themeNoBackgroundImage
                    : l10n.themeBackgroundImageReady,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickColor(
    BuildContext context,
    WidgetRef ref,
    String title,
    Color initial,
    AppThemeSettings Function(Color color) builder,
  ) async {
    Color selected = initial;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: ColorPicker(
            color: selected,
            onColorChanged: (color) => selected = color,
            pickersEnabled: const {
              ColorPickerType.primary: true,
              ColorPickerType.accent: true,
              ColorPickerType.wheel: true,
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(AppLocalizations.of(context)!.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(tasksControllerProvider.notifier).setThemeSettings(
            builder(selected),
          );
    }
  }

  Future<void> _editBackgroundImage(BuildContext context, WidgetRef ref) async {
    final service = ref.read(themeAssetServiceProvider);
    final copiedPath = await service.pickAndCopyBackgroundImage(
      oldPath: settings.backgroundImagePath,
    );
    if (copiedPath == null || !context.mounted) {
      return;
    }
    final edited = await showDialog<AppThemeSettings>(
      context: context,
      builder: (dialogContext) => _BackgroundImageEditorDialog(
        initial: settings.copyWith(
          backgroundMode: ThemeBackgroundMode.image,
          backgroundImagePath: copiedPath,
          imageScale: 1,
          imageOffsetX: 0,
          imageOffsetY: 0,
          imageRotationQuarterTurns: 0,
        ),
      ),
    );
    if (edited == null) {
      await service.deleteBackgroundImage(copiedPath);
      return;
    }
    await ref.read(tasksControllerProvider.notifier).setThemeSettings(edited);
  }
}

class _BackgroundImageEditorDialog extends StatefulWidget {
  const _BackgroundImageEditorDialog({required this.initial});

  final AppThemeSettings initial;

  @override
  State<_BackgroundImageEditorDialog> createState() =>
      _BackgroundImageEditorDialogState();
}

class _BackgroundImageEditorDialogState
    extends State<_BackgroundImageEditorDialog> {
  late AppThemeSettings _settings = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.themeEditBackgroundImage),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: Theme.of(context).colorScheme.surface),
                      if (_settings.backgroundImagePath case final path?)
                        Transform.translate(
                          offset: Offset(
                            _settings.imageOffsetX * 120,
                            _settings.imageOffsetY * 70,
                          ),
                          child: Transform.scale(
                            scale: _settings.imageScale,
                            child: RotatedBox(
                              quarterTurns: _settings.imageRotationQuarterTurns,
                              child: Image.file(File(path), fit: BoxFit.cover),
                            ),
                          ),
                        ),
                      ColoredBox(
                        color: Colors.black.withValues(
                          alpha: _settings.imageOverlayOpacity,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SliderRow(
                label: l10n.themeImageScale,
                value: _settings.imageScale,
                min: 0.5,
                max: 3,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(imageScale: value);
                  });
                },
              ),
              _SliderRow(
                label: l10n.themeImageOffsetX,
                value: _settings.imageOffsetX,
                min: -1,
                max: 1,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(imageOffsetX: value);
                  });
                },
              ),
              _SliderRow(
                label: l10n.themeImageOffsetY,
                value: _settings.imageOffsetY,
                min: -1,
                max: 1,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(imageOffsetY: value);
                  });
                },
              ),
              _SliderRow(
                label: l10n.themeImageOverlay,
                value: _settings.imageOverlayOpacity,
                min: 0,
                max: 0.85,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(imageOverlayOpacity: value);
                  });
                },
              ),
              _SliderRow(
                label: l10n.themeImageBlur,
                value: _settings.imageBlurSigma,
                min: 0,
                max: 20,
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(imageBlurSigma: value);
                  });
                },
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _settings = _settings.copyWith(
                        imageRotationQuarterTurns:
                            _settings.imageRotationQuarterTurns + 1,
                      );
                    });
                  },
                  icon: const Icon(Icons.rotate_90_degrees_ccw_outlined),
                  label: Text(l10n.themeRotateImage),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_settings),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(2)}'),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
    );
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
