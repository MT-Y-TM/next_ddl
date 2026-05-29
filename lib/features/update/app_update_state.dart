import '../../models/update_release.dart';
import '../../services/app_update_service.dart';

enum AppUpdateStatus {
  idle,
  checking,
  upToDate,
  updateAvailable,
  downloading,
  installReady,
  error,
}

class AppUpdateState {
  const AppUpdateState({
    required this.status,
    this.release,
    this.error,
    this.userInitiated = false,
    this.downloadedFilePath,
    this.downloadProgress,
    this.downloadPercent,
    this.downloadSpeedBytesPerSecond,
    this.isUsingCachedInstaller = false,
    this.hasReusableLocalInstaller = false,
    this.localInstallerVersion,
    this.requiresInstallPermission = false,
  });

  const AppUpdateState.idle() : this(status: AppUpdateStatus.idle);

  final AppUpdateStatus status;
  final UpdateRelease? release;
  final AppUpdateException? error;
  final bool userInitiated;
  final String? downloadedFilePath;
  final double? downloadProgress;
  final int? downloadPercent;
  final double? downloadSpeedBytesPerSecond;
  final bool isUsingCachedInstaller;
  final bool hasReusableLocalInstaller;
  final String? localInstallerVersion;
  final bool requiresInstallPermission;

  AppUpdateState copyWith({
    AppUpdateStatus? status,
    UpdateRelease? release,
    bool clearRelease = false,
    AppUpdateException? error,
    bool clearErrorMessage = false,
    bool? userInitiated,
    String? downloadedFilePath,
    bool clearDownloadedFilePath = false,
    double? downloadProgress,
    bool clearDownloadProgress = false,
    int? downloadPercent,
    bool clearDownloadPercent = false,
    double? downloadSpeedBytesPerSecond,
    bool clearDownloadSpeed = false,
    bool? isUsingCachedInstaller,
    bool? hasReusableLocalInstaller,
    String? localInstallerVersion,
    bool clearLocalInstallerVersion = false,
    bool? requiresInstallPermission,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      release: clearRelease ? null : (release ?? this.release),
      error: clearErrorMessage ? null : (error ?? this.error),
      userInitiated: userInitiated ?? this.userInitiated,
      downloadedFilePath:
          clearDownloadedFilePath
              ? null
              : (downloadedFilePath ?? this.downloadedFilePath),
      downloadProgress:
          clearDownloadProgress ? null : (downloadProgress ?? this.downloadProgress),
      downloadPercent:
          clearDownloadPercent ? null : (downloadPercent ?? this.downloadPercent),
      downloadSpeedBytesPerSecond:
          clearDownloadSpeed
              ? null
              : (downloadSpeedBytesPerSecond ?? this.downloadSpeedBytesPerSecond),
      isUsingCachedInstaller:
          isUsingCachedInstaller ?? this.isUsingCachedInstaller,
      hasReusableLocalInstaller:
          hasReusableLocalInstaller ?? this.hasReusableLocalInstaller,
      localInstallerVersion:
          clearLocalInstallerVersion
              ? null
              : (localInstallerVersion ?? this.localInstallerVersion),
      requiresInstallPermission:
          requiresInstallPermission ?? this.requiresInstallPermission,
    );
  }
}
