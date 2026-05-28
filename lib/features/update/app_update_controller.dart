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
  AppUpdateService get _service => ref.read(appUpdateServiceProvider);
  AppInfoService get _appInfo => ref.read(appInfoServiceProvider);

  @override
  AppUpdateState build() {
    return const AppUpdateState.idle();
  }

  Future<void> checkForUpdate({bool userInitiated = false}) async {
    state = state.copyWith(
      status: AppUpdateStatus.checking,
      clearErrorMessage: true,
      userInitiated: userInitiated,
    );
    try {
      final currentVersion = await _appInfo.getVersionLabel();
      final release = await _service.checkForUpdate(currentVersion: currentVersion);
      if (release == null) {
        state = state.copyWith(
          status: AppUpdateStatus.upToDate,
          clearRelease: true,
          clearDownloadedFilePath: true,
          requiresInstallPermission: false,
          userInitiated: userInitiated,
        );
        return;
      }
      state = state.copyWith(
        status: AppUpdateStatus.updateAvailable,
        release: release,
        clearDownloadedFilePath: true,
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
    final release = state.release;
    if (release == null) {
      return;
    }
    state = state.copyWith(
      status: AppUpdateStatus.downloading,
      clearErrorMessage: true,
    );
    try {
      final result = await _service.downloadAndInstall(release);
      switch (result.status) {
        case AppUpdateInstallStatus.installerOpened:
          state = state.copyWith(
            status: AppUpdateStatus.installReady,
            downloadedFilePath: result.filePath,
            requiresInstallPermission: false,
          );
        case AppUpdateInstallStatus.permissionRequired:
          state = state.copyWith(
            status: AppUpdateStatus.installReady,
            downloadedFilePath: result.filePath,
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
    if (!Platform.isAndroid) {
      return;
    }
    final path = state.downloadedFilePath;
    if (path == null || !state.requiresInstallPermission) {
      return;
    }
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
    }
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
