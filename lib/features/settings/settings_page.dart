import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_ddl/l10n/app_localizations.dart';

import '../../models/app_alarm_settings.dart';
import '../../models/app_snapshot.dart';
import '../../models/app_theme_settings.dart';
import '../../models/app_prediction_settings.dart';
import '../../services/timezone_service.dart';
import '../../services/deadline_repository.dart';
import '../../services/backup_service.dart';
import '../backup/backup_page.dart';
import '../backup/backup_localizations.dart';
import '../tasks/task_planning_page.dart';
import '../tasks/task_planning_provider.dart';
import '../tasks/task_planning_strings.dart';
import '../../utils/timezone_labels.dart';
import '../tasks/tasks_controller.dart';
import '../update/app_update_controller.dart';
import 'settings_formatters.dart';
import 'widgets/alarm_settings_card.dart';
import 'widgets/reminder_health_card.dart';
import 'widgets/theme_settings_card.dart';
import 'widgets/timezone_picker_dialog.dart';
import 'widgets/update_settings_card.dart';
import 'prediction_ui_strings.dart';
import '../../services/ai_secret_store.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(tasksControllerProvider).valueOrNull;
    final versionAsync = ref.watch(appVersionProvider);
    ref.watch(timezoneRevisionProvider);
    final timezoneId = ref.watch(timezoneServiceProvider).currentTimezoneId;
    final l10n = AppLocalizations.of(context)!;
    final prediction =
        snapshot?.predictionSettings ?? const AppPredictionSettings();
    final predictionStrings = PredictionUiStrings(context);

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
          _SettingsEntryCard(
            icon: Icons.auto_awesome_outlined,
            title: predictionStrings.title,
            subtitle: predictionStrings.entrySubtitle(
              localEnabled: prediction.enabled,
              aiEnabled: prediction.aiEnabled,
            ),
            onTap: () => _push(context, const _PredictionSettingsPage()),
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
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _ImportDataPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restore),
              title: Text(BackupLocalizations.of(context).title),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BackupPage(
                    service: BackupService(
                      repository: ref.read(deadlineRepositoryProvider),
                    ),
                    onRestored: (_) async {
                      await ref
                          .read(tasksControllerProvider.notifier)
                          .reloadPersistedSnapshot();
                      await ref.read(taskPlanningProvider).reload();
                    },
                  ),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.repeat),
              title: Text(
                TaskPlanningStrings(
                  Localizations.localeOf(context),
                ).text('title'),
              ),
              onTap: () async {
                final service = ref.read(taskPlanningProvider);
                await service.reload();
                if (!context.mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TaskPlanningPage(
                      service: service,
                      sourceTasks:
                          ref
                              .read(tasksControllerProvider)
                              .valueOrNull
                              ?.tasks ??
                          const [],
                      timezoneId: ref
                          .read(timezoneServiceProvider)
                          .currentTimezoneId,
                    ),
                  ),
                );
              },
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
          ReminderHealthCard(
            tasks: snapshot?.tasks ?? const [],
            settings: snapshot?.alarmSettings ?? AppAlarmSettings.defaults(),
            enabled: snapshot != null,
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

class _PredictionSettingsPage extends ConsumerStatefulWidget {
  const _PredictionSettingsPage();

  @override
  ConsumerState<_PredictionSettingsPage> createState() =>
      _PredictionSettingsPageState();
}

class _PredictionSettingsPageState
    extends ConsumerState<_PredictionSettingsPage> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _modelController;
  late final TextEditingController _promptController;
  late AppPredictionSettings _settings;
  final _apiKeyController = TextEditingController();
  bool _apiKeySaved = false;
  bool _saving = false;

  PredictionUiStrings get strings => PredictionUiStrings(context);

  @override
  void initState() {
    super.initState();
    _settings = ref.read(predictionSettingsProvider);
    _baseUrlController = TextEditingController(text: _settings.baseUrl);
    _modelController = TextEditingController(text: _settings.model);
    _promptController = TextEditingController(text: _settings.customPrompt);
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final value = await ref.read(aiSecretStoreProvider).readApiKey();
    if (mounted) setState(() => _apiKeySaved = value?.isNotEmpty == true);
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _modelController.dispose();
    _promptController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final next = _settings.copyWith(
      enabled: _settings.enabled,
      aiEnabled: _settings.aiEnabled,
      aiProtocol: _settings.aiProtocol,
      stepByStep: _settings.stepByStep,
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
      customPrompt: _promptController.text,
    );
    await ref
        .read(tasksControllerProvider.notifier)
        .setPredictionSettings(next);
    if (_apiKeyController.text.trim().isNotEmpty) {
      await ref.read(aiSecretStoreProvider).writeApiKey(_apiKeyController.text);
      _apiKeyController.clear();
      _apiKeySaved = true;
    }
    if (mounted) {
      setState(() {
        _settings = next;
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.save)));
    }
  }

  String _protocolLabel(AiProtocol value) => switch (value) {
    AiProtocol.chatCompletions => 'Chat Completions',
    AiProtocol.responses => 'Responses',
    AiProtocol.anthropicMessages => 'Anthropic Messages',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(strings.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(strings.enabled),
                  subtitle: Text(strings.enabledHint),
                  value: _settings.enabled,
                  onChanged: (value) => setState(
                    () => _settings = _settings.copyWith(enabled: value),
                  ),
                ),
                SwitchListTile(
                  title: Text(strings.aiEnabled),
                  subtitle: Text(strings.aiHint),
                  value: _settings.aiEnabled,
                  onChanged: (value) => setState(
                    () => _settings = _settings.copyWith(aiEnabled: value),
                  ),
                ),
                SwitchListTile(
                  title: Text(strings.stepByStep),
                  subtitle: Text(strings.stepByStepHint),
                  value: _settings.stepByStep,
                  onChanged: _settings.aiEnabled
                      ? (value) => setState(
                          () =>
                              _settings = _settings.copyWith(stepByStep: value),
                        )
                      : null,
                ),
              ],
            ),
          ),
          if (_settings.aiEnabled) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<AiProtocol>(
                      initialValue: _settings.aiProtocol,
                      decoration: InputDecoration(labelText: strings.protocol),
                      items: [
                        for (final item in AiProtocol.values)
                          DropdownMenuItem(
                            value: item,
                            child: Text(_protocolLabel(item)),
                          ),
                      ],
                      onChanged: (value) => setState(
                        () => _settings = _settings.copyWith(aiProtocol: value),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _baseUrlController,
                      decoration: InputDecoration(labelText: strings.baseUrl),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _modelController,
                      decoration: InputDecoration(labelText: strings.model),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _apiKeyController,
                      keyboardType: TextInputType.text,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: strings.apiKey,
                        helperText: _apiKeySaved ? strings.apiKeySaved : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _promptController,
                      minLines: 3,
                      maxLines: 8,
                      decoration: InputDecoration(
                        labelText: strings.prompt,
                        hintText: strings.promptHint,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      strings.privacy,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(strings.save),
          ),
        ],
      ),
    );
  }
}

class _ImportDataPage extends ConsumerStatefulWidget {
  const _ImportDataPage();
  @override
  ConsumerState<_ImportDataPage> createState() => _ImportDataPageState();
}

class _ImportDataPageState extends ConsumerState<_ImportDataPage> {
  bool _busy = false;
  bool _pendingSync = false;
  String? _message;

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    final strings = BackupLocalizations.of(context);
    try {
      final imported = await ref
          .read(deadlineRepositoryProvider)
          .importSnapshot();
      if (imported == null || !mounted) return;
      if (!await confirmSnapshotReplacement(context, imported) || !mounted) {
        return;
      }
      final controller = ref.read(tasksControllerProvider.notifier);
      try {
        await controller.replaceWithBackup(imported);
      } catch (error) {
        // State is published only after the protected replacement commits.
        if (identical(
          ref.read(tasksControllerProvider).valueOrNull,
          imported,
        )) {
          _pendingSync = true;
        } else {
          rethrow;
        }
      }
      await ref.read(taskPlanningProvider).reload();
      if (mounted) {
        setState(
          () => _message = _pendingSync
              ? strings.scheduleFailed
              : AppLocalizations.of(
                  context,
                )!.importSuccess(imported.tasks.length),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _message = strings.error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retry() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(tasksControllerProvider.notifier)
          .reloadPersistedSnapshot();
      if (mounted) {
        setState(() {
          _pendingSync = false;
          _message = BackupLocalizations.of(context).saved;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = BackupLocalizations.of(context).scheduleFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.importJson)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.importJsonHint),
            const SizedBox(height: 16),
            if (_busy) const LinearProgressIndicator(),
            if (_message != null) Text(_message!),
            FilledButton(
              onPressed: _busy
                  ? null
                  : _pendingSync
                  ? _retry
                  : _import,
              child: Text(
                _pendingSync
                    ? BackupLocalizations.of(context).retry
                    : l10n.importJson,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
