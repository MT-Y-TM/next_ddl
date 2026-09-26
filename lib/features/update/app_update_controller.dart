import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/app_info_service.dart';
import '../../services/app_update_service.dart';
import 'app_update_state.dart';

final appUpdateControllerProvider =
    NotifierProvider<AppUpdateController, AppUpdateState>(
      AppUpdateController.new,
    );

class AppUpdateController extends Notifier<AppUpdateState> {
  bool _installBusy = false;
  AppUpdateService get _service => ref.read(appUpdateServiceProvider);
  AppInfoService get _appInfo => ref.read(appInfoServiceProvider);

  @override
  AppUpdateState build() {
    return const AppUpdateState.idle();
  }

  Future<void> checkForUpdate({bool userInitiated = false}) async {
    if (_installBusy || state.status == AppUpdateStatus.checking) return;
    state = state.copyWith(
      status: AppUpdateStatus.checking,
      clearErrorMessage: true,
      userInitiated: userInitiated,
    );
    try {
      final currentVersion = await _appInfo.getVersionLabel();
      final release = await _service.checkForUpdate(
        currentVersion: currentVersion,
      );
      if (release == null) {
        state = state.copyWith(
          status: AppUpdateStatus.upToDate,
          clearRelease: true,
          clearDownloadedFilePath: true,
          clearDownloadProgress: true,
          clearDownloadPercent: true,
          clearDownloadSpeed: true,
          hasReusableLocalInstaller: false,
          isUsingCachedInstaller: false,
          clearLocalInstallerVersion: true,
          requiresInstallPermission: false,
          userInitiated: userInitiated,
        );
        return;
      }
      final cachedInstaller = await _service.findReusableInstaller(
        release: release,
        currentVersion: currentVersion,
      );
      state = state.copyWith(
        status: AppUpdateStatus.updateAvailable,
        release: release,
        downloadedFilePath: cachedInstaller?.filePath,
        clearDownloadedFilePath: cachedInstaller == null,
        clearDownloadProgress: true,
        clearDownloadPercent: true,
        clearDownloadSpeed: true,
        hasReusableLocalInstaller: cachedInstaller != null,
        isUsingCachedInstaller: false,
        localInstallerVersion: cachedInstaller?.version,
        clearLocalInstallerVersion: cachedInstaller == null,
        requiresInstallPermission: false,
        userInitiated: userInitiated,
      );
    } catch (error) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        error: _normalizeError(error),
        userInitiated: userInitiated,
      );
    }
  }

  Future<void> downloadAndInstall() async {
    if (_installBusy || state.status == AppUpdateStatus.checking) return;
    _installBusy = true;
    try {
      await _downloadAndInstall();
    } finally {
      _installBusy = false;
    }
  }

  Future<void> _downloadAndInstall() async {
    final release = state.release;
    if (release == null) {
      return;
    }
    state = state.copyWith(
      status: AppUpdateStatus.downloading,
      clearErrorMessage: true,
      downloadProgress: 0,
      downloadPercent: 0,
      downloadSpeedBytesPerSecond: 0,
      isUsingCachedInstaller: false,
    );
    try {
      final result = await _service.downloadAndInstall(
        release,
        onProgress: (progress) {
          state = state.copyWith(
            status: AppUpdateStatus.downloading,
            downloadProgress: progress.progress,
            clearDownloadProgress: progress.progress == null,
            downloadPercent: progress.percent,
            clearDownloadPercent: progress.percent == null,
            downloadSpeedBytesPerSecond: progress.speedBytesPerSecond,
          );
        },
      );
      switch (result.status) {
        case AppUpdateInstallStatus.installerOpened:
          state = state.copyWith(
            status: AppUpdateStatus.installReady,
            downloadedFilePath: result.filePath,
            localInstallerVersion: result.installerVersion,
            hasReusableLocalInstaller: result.filePath != null,
            isUsingCachedInstaller: result.usedCachedInstaller,
            requiresInstallPermission: false,
          );
        case AppUpdateInstallStatus.permissionRequired:
          state = state.copyWith(
            status: AppUpdateStatus.installReady,
            downloadedFilePath: result.filePath,
            localInstallerVersion: result.installerVersion,
            hasReusableLocalInstaller: result.filePath != null,
            isUsingCachedInstaller: result.usedCachedInstaller,
            requiresInstallPermission: true,
          );
        case AppUpdateInstallStatus.openedReleasePage:
          state = state.copyWith(
            status: AppUpdateStatus.updateAvailable,
            requiresInstallPermission: false,
          );
      }
    } catch (error) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        error: _normalizeError(error),
      );
    }
  }

  Future<void> openReleasePage() async {
    final release = state.release;
    if (release == null) {
      return;
    }
    try {
      await _service.openReleasePage(release);
    } catch (error) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        error: _normalizeError(error),
      );
    }
  }

  Future<void> openInstallPermissionSettings() async {
    try {
      await _service.openInstallPermissionSettings();
    } catch (error) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        error: _normalizeError(error),
      );
    }
  }

  Future<void> resumePendingInstallIfPossible() async {
    if (_installBusy) return;
    if (!Platform.isAndroid) {
      return;
    }
    final path = state.downloadedFilePath;
    if (path == null || !state.requiresInstallPermission) {
      return;
    }
    _installBusy = true;
    try {
      final resumed = await _service.resumePendingInstall(path);
      if (resumed) {
        state = state.copyWith(
          status: AppUpdateStatus.installReady,
          requiresInstallPermission: false,
        );
      }
    } catch (error) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        error: _normalizeError(error),
      );
    } finally {
      _installBusy = false;
    }
  }

  Future<int> clearCachedInstallers() async {
    if (_installBusy || state.status == AppUpdateStatus.checking) return 0;
    final removed = await _service.clearCachedInstallers();
    final downloadedFilePath = state.downloadedFilePath;
    final shouldClearPath = downloadedFilePath != null;
    state = state.copyWith(
      hasReusableLocalInstaller: false,
      isUsingCachedInstaller: false,
      clearDownloadedFilePath: shouldClearPath,
      clearLocalInstallerVersion: true,
      requiresInstallPermission: false,
    );
    return removed;
  }

  AppUpdateException _normalizeError(Object error) {
    if (error is AppUpdateException) {
      return error;
    }
    if (error is SocketException) {
      return AppUpdateException(
        AppUpdateErrorType.networkUnavailable,
        details: error.message,
      );
    }
    return AppUpdateException(
      AppUpdateErrorType.unknown,
      details: error.toString(),
    );
  }
}
