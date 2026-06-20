import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_ddl/l10n/app_localizations.dart';

import '../../../models/app_alarm_settings.dart';
import '../../../services/alarm_audio_picker_service.dart';
import '../../tasks/tasks_controller.dart';

class AlarmSettingsCard extends ConsumerWidget {
  const AlarmSettingsCard({
    required this.settings,
    required this.enabled,
    super.key,
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
              Platform.isAndroid
                  ? l10n.alarmAndroidHint
                  : l10n.alarmWindowsHint,
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
              subtitle: Text(
                l10n.alarmAudioCount(settings.globalAudioItems.length),
              ),
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
                subtitle: Text(
                  item.uri,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: l10n.delete,
                  onPressed: enabled ? () => _removeAudio(ref, item.id) : null,
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
    final picked = await ref
        .read(alarmAudioPickerServiceProvider)
        .pickAudioItems();
    if (picked.isEmpty) {
      return;
    }
    await ref
        .read(tasksControllerProvider.notifier)
        .setAlarmSettings(
          settings.copyWith(
            globalAudioItems: [...settings.globalAudioItems, ...picked],
          ),
        );
  }

  Future<void> _removeAudio(WidgetRef ref, String id) async {
    await ref
        .read(tasksControllerProvider.notifier)
        .setAlarmSettings(
          settings.copyWith(
            globalAudioItems: settings.globalAudioItems
                .where((item) => item.id != id)
                .toList(),
          ),
        );
  }
}
