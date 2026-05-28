import '../../models/update_release.dart';

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
    this.errorMessage,
    this.userInitiated = false,
    this.downloadedFilePath,
    this.requiresInstallPermission = false,
  });

  const AppUpdateState.idle() : this(status: AppUpdateStatus.idle);

  final AppUpdateStatus status;
  final UpdateRelease? release;
  final String? errorMessage;
  final bool userInitiated;
  final String? downloadedFilePath;
  final bool requiresInstallPermission;

  AppUpdateState copyWith({
    AppUpdateStatus? status,
    UpdateRelease? release,
    bool clearRelease = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? userInitiated,
    String? downloadedFilePath,
    bool clearDownloadedFilePath = false,
    bool? requiresInstallPermission,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      release: clearRelease ? null : (release ?? this.release),
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      userInitiated: userInitiated ?? this.userInitiated,
      downloadedFilePath:
          clearDownloadedFilePath
              ? null
              : (downloadedFilePath ?? this.downloadedFilePath),
      requiresInstallPermission:
          requiresInstallPermission ?? this.requiresInstallPermission,
    );
  }
}
