import '../../l10n/app_localizations.dart';
import '../../models/app_snapshot.dart';
import '../../services/app_update_service.dart';
import '../update/app_update_state.dart';

String settingsLocaleLabel(
  AppLocalizations l10n,
  AppLocalePreference? preference,
) {
  return switch (preference ?? AppLocalePreference.system) {
    AppLocalePreference.system => l10n.localeSystem,
    AppLocalePreference.zh => l10n.localeZh,
    AppLocalePreference.en => l10n.localeEn,
    AppLocalePreference.ja => l10n.localeJa,
  };
}

String settingsUpdateStatusText(AppLocalizations l10n, AppUpdateState state) {
  return switch (state.status) {
    AppUpdateStatus.idle => l10n.checkForUpdates,
    AppUpdateStatus.checking => l10n.checkingForUpdates,
    AppUpdateStatus.upToDate => l10n.appUpToDate,
    AppUpdateStatus.updateAvailable => l10n.updateAvailableStatus(
      state.release?.version ?? '',
    ),
    AppUpdateStatus.downloading =>
      state.isUsingCachedInstaller
          ? l10n.updateUsingCachedInstaller(
              state.localInstallerVersion ?? state.release?.version ?? '',
            )
          : l10n.updateDownloading,
    AppUpdateStatus.installReady =>
      state.requiresInstallPermission
          ? l10n.updatePermissionRequired
          : l10n.updateInstallReady,
    AppUpdateStatus.error => settingsUpdateErrorText(l10n, state.error),
  };
}

String settingsDownloadProgressText(
  AppLocalizations l10n,
  AppUpdateState state,
) {
  final percent = state.downloadPercent;
  final speed = state.downloadSpeedBytesPerSecond;
  final percentText = percent == null
      ? l10n.downloadProgressUnknown
      : l10n.downloadPercent(percent);
  final speedText = speed == null || speed <= 0
      ? l10n.downloadSpeedUnknown
      : l10n.downloadSpeed(settingsFormatSpeed(speed));
  return '$percentText · $speedText';
}

String settingsUpdateErrorText(
  AppLocalizations l10n,
  AppUpdateException? error,
) {
  return switch (error?.type ?? AppUpdateErrorType.unknown) {
    AppUpdateErrorType.noPublishedRelease => l10n.updateNoPublishedRelease,
    AppUpdateErrorType.networkUnavailable => l10n.updateErrorNetworkUnavailable,
    AppUpdateErrorType.serviceUnavailable => l10n.updateErrorServiceUnavailable,
    AppUpdateErrorType.missingAndroidAsset =>
      l10n.updateErrorMissingAndroidAsset,
    AppUpdateErrorType.downloadFailed => l10n.updateErrorDownloadFailed,
    AppUpdateErrorType.installerOpenFailed =>
      l10n.updateErrorInstallerOpenFailed,
    AppUpdateErrorType.openReleasePageFailed =>
      l10n.updateErrorOpenReleasePageFailed,
    AppUpdateErrorType.openInstallPermissionFailed =>
      l10n.updateErrorOpenInstallPermissionFailed,
    AppUpdateErrorType.unknown => l10n.updateErrorUnexpected,
  };
}

String settingsFormatDateTime(DateTime value) {
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}:'
      '${value.second.toString().padLeft(2, '0')}';
}

String settingsFormatSpeed(double bytesPerSecond) {
  if (bytesPerSecond >= 1024 * 1024) {
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
  return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
}
