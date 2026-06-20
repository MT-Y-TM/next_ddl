import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_ddl/l10n/app_localizations.dart';

import '../../update/app_update_controller.dart';
import '../../update/app_update_state.dart';
import '../settings_formatters.dart';

class UpdateSettingsCard extends ConsumerWidget {
  const UpdateSettingsCard({required this.state, super.key});

  final AppUpdateState state;

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
              settingsUpdateStatusText(l10n, state),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (state.hasReusableLocalInstaller &&
                state.status != AppUpdateStatus.downloading) ...[
              const SizedBox(height: 8),
              Text(
                l10n.updateUsingCachedInstaller(
                  state.localInstallerVersion ?? state.release?.version ?? '',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (state.status == AppUpdateStatus.downloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: state.downloadProgress),
              const SizedBox(height: 8),
              Text(
                settingsDownloadProgressText(l10n, state),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (state.release case final release?) ...[
              const SizedBox(height: 8),
              Text(
                l10n.publishedAtLabel(
                  settingsFormatDateTime(release.publishedAtUtc.toLocal()),
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
                  onPressed: state.status == AppUpdateStatus.checking
                      ? null
                      : () {
                          ref
                              .read(appUpdateControllerProvider.notifier)
                              .checkForUpdate(userInitiated: true);
                        },
                  child: Text(
                    state.status == AppUpdateStatus.checking
                        ? l10n.checkingForUpdates
                        : l10n.checkForUpdates,
                  ),
                ),
                if (state.release != null)
                  FilledButton(
                    onPressed: state.status == AppUpdateStatus.downloading
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
                if (state.requiresInstallPermission)
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
    );
  }
}
