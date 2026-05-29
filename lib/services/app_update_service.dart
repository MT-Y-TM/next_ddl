import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/update_release.dart';
import '../utils/version_utils.dart';

class DownloadProgress {
  const DownloadProgress({
    required this.receivedBytes,
    this.totalBytes,
    required this.speedBytesPerSecond,
  });

  final int receivedBytes;
  final int? totalBytes;
  final double speedBytesPerSecond;

  double? get progress {
    final total = totalBytes;
    if (total == null || total <= 0) {
      return null;
    }
    return (receivedBytes / total).clamp(0, 1).toDouble();
  }

  int? get percent {
    final value = progress;
    if (value == null) {
      return null;
    }
    return (value * 100).round();
  }
}

class CachedUpdateInstaller {
  const CachedUpdateInstaller({
    required this.version,
    required this.filePath,
  });

  final String version;
  final String filePath;
}

enum AppUpdateErrorType {
  noPublishedRelease,
  networkUnavailable,
  serviceUnavailable,
  missingAndroidAsset,
  downloadFailed,
  installerOpenFailed,
  openReleasePageFailed,
  openInstallPermissionFailed,
  unknown,
}

class AppUpdateException implements Exception {
  const AppUpdateException(
    this.type, {
    this.statusCode,
    this.details,
  });

  final AppUpdateErrorType type;
  final int? statusCode;
  final String? details;
}

enum AppUpdateInstallStatus {
  installerOpened,
  permissionRequired,
  openedReleasePage,
}

class AppUpdateInstallResult {
  const AppUpdateInstallResult({
    required this.status,
    this.filePath,
    this.installerVersion,
    this.usedCachedInstaller = false,
  });

  final AppUpdateInstallStatus status;
  final String? filePath;
  final String? installerVersion;
  final bool usedCachedInstaller;
}

abstract class AppUpdateService {
  Future<UpdateRelease?> checkForUpdate({required String currentVersion});

  Future<CachedUpdateInstaller?> findReusableInstaller({
    required UpdateRelease release,
    required String currentVersion,
  });

  Future<AppUpdateInstallResult> downloadAndInstall(
    UpdateRelease release, {
    void Function(DownloadProgress progress)? onProgress,
  });

  Future<void> openReleasePage(UpdateRelease release);

  Future<bool> resumePendingInstall(String filePath);

  Future<void> openInstallPermissionSettings();

  Future<int> clearCachedInstallers();
}

class GithubAppUpdateService implements AppUpdateService {
  GithubAppUpdateService({
    http.Client? client,
    MethodChannel? methodChannel,
  }) : _client = client ?? http.Client(),
       _methodChannel = methodChannel ?? const MethodChannel(_channelName);

  static const _owner = 'MT-Y-TM';
  static const _repo = 'next_ddl';
  static const _channelName = 'next_ddl/app_update';
  static final RegExp _installerPattern = RegExp(r'^app-release-v(.+)\.apk$');

  final http.Client _client;
  final MethodChannel _methodChannel;

  @override
  Future<UpdateRelease?> checkForUpdate({required String currentVersion}) async {
    late final http.Response response;
    try {
      response = await _client.get(
        Uri.https('api.github.com', '/repos/$_owner/$_repo/releases/latest'),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': 'Next-DDL-App',
        },
      );
    } on SocketException catch (error) {
      throw AppUpdateException(
        AppUpdateErrorType.networkUnavailable,
        details: error.message,
      );
    }
    if (response.statusCode == 404) {
      throw const AppUpdateException(
        AppUpdateErrorType.noPublishedRelease,
        statusCode: 404,
      );
    }
    if (response.statusCode != 200) {
      throw AppUpdateException(
        AppUpdateErrorType.serviceUnavailable,
        statusCode: response.statusCode,
      );
    }
    final release = UpdateRelease.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    if (!isNewerSemanticVersion(release.version, currentVersion)) {
      return null;
    }
    return release;
  }

  @override
  Future<CachedUpdateInstaller?> findReusableInstaller({
    required UpdateRelease release,
    required String currentVersion,
  }) async {
    if (!Platform.isAndroid) {
      return null;
    }
    final installers = await _listCachedInstallers();
    final matching = [
      for (final installer in installers)
        if (compareSemanticVersions(installer.version, currentVersion) > 0 &&
            compareSemanticVersions(installer.version, release.version) == 0)
          installer,
    ];
    if (matching.isEmpty) {
      return null;
    }
    matching.sort(
      (left, right) => compareSemanticVersions(right.version, left.version),
    );
    return matching.first;
  }

  @override
  Future<AppUpdateInstallResult> downloadAndInstall(
    UpdateRelease release, {
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    if (!Platform.isAndroid) {
      await openReleasePage(release);
      return const AppUpdateInstallResult(
        status: AppUpdateInstallStatus.openedReleasePage,
      );
    }

    final asset = release.androidApkAsset;
    if (asset == null) {
      throw const AppUpdateException(AppUpdateErrorType.missingAndroidAsset);
    }

    final directory = await getTemporaryDirectory();
    final updatesDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}updates',
    );
    await updatesDirectory.create(recursive: true);
    final apkFile = File(
      '${updatesDirectory.path}${Platform.pathSeparator}app-release-v${release.version}.apk',
    );

    final request = http.Request('GET', Uri.parse(asset.browserDownloadUrl));
    request.headers.addAll(const {
      'Accept': 'application/octet-stream',
      'User-Agent': 'Next-DDL-App',
    });
    late final http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request);
    } on SocketException catch (error) {
      throw AppUpdateException(
        AppUpdateErrorType.networkUnavailable,
        details: error.message,
      );
    }
    if (streamed.statusCode != 200) {
      throw AppUpdateException(
        AppUpdateErrorType.downloadFailed,
        statusCode: streamed.statusCode,
      );
    }
    final sink = apkFile.openWrite();
    var receivedBytes = 0;
    final totalBytes = streamed.contentLength;
    final startedAt = DateTime.now();
    await for (final chunk in streamed.stream) {
      sink.add(chunk);
      receivedBytes += chunk.length;
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      final speed = elapsedMs <= 0
          ? 0.0
          : (receivedBytes / (elapsedMs / 1000.0)).toDouble();
      onProgress?.call(
        DownloadProgress(
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
          speedBytesPerSecond: speed,
        ),
      );
    }
    await sink.flush();
    await sink.close();

    if (!await _canRequestPackageInstalls()) {
      await _openManageUnknownAppSources();
      return AppUpdateInstallResult(
        status: AppUpdateInstallStatus.permissionRequired,
        filePath: apkFile.path,
        installerVersion: release.version,
      );
    }

    await _openInstallerFile(apkFile.path);
    return AppUpdateInstallResult(
      status: AppUpdateInstallStatus.installerOpened,
      filePath: apkFile.path,
      installerVersion: release.version,
    );
  }

  @override
  Future<void> openReleasePage(UpdateRelease release) async {
    final uri = Uri.parse(release.htmlUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw const AppUpdateException(AppUpdateErrorType.openReleasePageFailed);
    }
  }

  @override
  Future<bool> resumePendingInstall(String filePath) async {
    if (!Platform.isAndroid) {
      return false;
    }
    final file = File(filePath);
    if (!await file.exists()) {
      return false;
    }
    if (!await _canRequestPackageInstalls()) {
      return false;
    }
    await _openInstallerFile(filePath);
    return true;
  }

  @override
  Future<void> openInstallPermissionSettings() async {
    await _openManageUnknownAppSources();
  }

  @override
  Future<int> clearCachedInstallers() async {
    if (!Platform.isAndroid) {
      return 0;
    }
    final directory = await _updatesDirectory();
    if (!await directory.exists()) {
      return 0;
    }
    var removed = 0;
    await for (final entity in directory.list()) {
      if (entity is! File) {
        continue;
      }
      if (!_installerPattern.hasMatch(entity.uri.pathSegments.last)) {
        continue;
      }
      await entity.delete();
      removed++;
    }
    return removed;
  }

  Future<bool> _canRequestPackageInstalls() async {
    if (!Platform.isAndroid) {
      return false;
    }
    final result =
        await _methodChannel.invokeMethod<bool>('canRequestPackageInstalls');
    return result ?? false;
  }

  Future<void> _openManageUnknownAppSources() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _methodChannel.invokeMethod('openManageUnknownAppSources');
    } on PlatformException catch (error) {
      throw AppUpdateException(
        AppUpdateErrorType.openInstallPermissionFailed,
        details: error.message,
      );
    }
  }

  Future<void> _openInstallerFile(String path) async {
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      throw AppUpdateException(
        AppUpdateErrorType.installerOpenFailed,
        details: result.message,
      );
    }
  }

  Future<Directory> _updatesDirectory() async {
    final directory = await getTemporaryDirectory();
    return Directory(
      '${directory.path}${Platform.pathSeparator}updates',
    );
  }

  Future<List<CachedUpdateInstaller>> _listCachedInstallers() async {
    final directory = await _updatesDirectory();
    if (!await directory.exists()) {
      return const [];
    }
    final installers = <CachedUpdateInstaller>[];
    await for (final entity in directory.list()) {
      if (entity is! File) {
        continue;
      }
      final name = entity.uri.pathSegments.last;
      final match = _installerPattern.firstMatch(name);
      if (match == null) {
        continue;
      }
      final version = match.group(1);
      if (version == null || version.isEmpty) {
        continue;
      }
      installers.add(
        CachedUpdateInstaller(version: version, filePath: entity.path),
      );
    }
    return installers;
  }
}

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  throw UnimplementedError('appUpdateServiceProvider must be overridden');
});
