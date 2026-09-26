import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/update_release.dart';
import '../features/update/update_integrity.dart';
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
  const CachedUpdateInstaller({required this.version, required this.filePath});

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
    this.reason,
  });

  final AppUpdateErrorType type;
  final int? statusCode;
  final String? details;
  final UpdateFailureReason? reason;
}

enum UpdateFailureReason {
  missingChecksum,
  integrityMismatch,
  timeout,
  busy,
  invalidCache,
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
    Future<Directory> Function()? cacheDirectory,
    bool? isAndroid,
    Future<void> Function(String)? installerOpener,
    this.networkTimeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client(),
       _cacheDirectory = cacheDirectory,
       _isAndroid = isAndroid ?? Platform.isAndroid,
       _installerOpener = installerOpener,
       _methodChannel = methodChannel ?? const MethodChannel(_channelName);

  static const _owner = 'MT-Y-TM';
  static const _repo = 'next_ddl';
  static const _channelName = 'next_ddl/app_update';
  static final RegExp _installerPattern = RegExp(r'^app-release-v(.+)\.apk$');

  final http.Client _client;
  final MethodChannel _methodChannel;
  final Future<Directory> Function()? _cacheDirectory;
  final bool _isAndroid;
  final Future<void> Function(String)? _installerOpener;
  final Duration networkTimeout;
  final Map<String, UpdateRelease> _verifiedReleases = {};
  bool _busy = false;

  @override
  Future<UpdateRelease?> checkForUpdate({
    required String currentVersion,
  }) async {
    late final http.Response response;
    try {
      response = await _client
          .get(
            Uri.https(
              'api.github.com',
              '/repos/$_owner/$_repo/releases/latest',
            ),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
              'User-Agent': 'Next-DDL-App',
            },
          )
          .timeout(networkTimeout);
    } on TimeoutException {
      throw const AppUpdateException(
        AppUpdateErrorType.networkUnavailable,
        reason: UpdateFailureReason.timeout,
      );
    } on SocketException catch (error) {
      throw AppUpdateException(
        AppUpdateErrorType.networkUnavailable,
        details: error.message,
      );
    } on http.ClientException {
      throw const AppUpdateException(AppUpdateErrorType.networkUnavailable);
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
    late final UpdateRelease release;
    try {
      release = UpdateRelease.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      throw const AppUpdateException(AppUpdateErrorType.serviceUnavailable);
    }
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
    if (!_isAndroid) {
      return null;
    }
    if (_busy || !release.hasChecksumSource) return null;
    release = await _resolveChecksum(release);
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
    for (final installer in matching) {
      if (await _validateCache(File(installer.filePath), release)) {
        _verifiedReleases[installer.filePath] = release;
        return installer;
      }
    }
    return null;
  }

  @override
  Future<AppUpdateInstallResult> downloadAndInstall(
    UpdateRelease release, {
    void Function(DownloadProgress progress)? onProgress,
  }) async {
    if (!_isAndroid) {
      await openReleasePage(release);
      return const AppUpdateInstallResult(
        status: AppUpdateInstallStatus.openedReleasePage,
      );
    }

    if (_busy) {
      throw const AppUpdateException(
        AppUpdateErrorType.downloadFailed,
        reason: UpdateFailureReason.busy,
      );
    }
    _busy = true;
    try {
      return await _downloadAndInstall(release, onProgress: onProgress);
    } on AppUpdateException {
      rethrow;
    } catch (_) {
      throw const AppUpdateException(AppUpdateErrorType.downloadFailed);
    } finally {
      _busy = false;
    }
  }

  Future<AppUpdateInstallResult> _downloadAndInstall(
    UpdateRelease release, {
    void Function(DownloadProgress)? onProgress,
  }) async {
    release = await _resolveChecksum(release);
    final asset = release.androidApkAsset;
    if (asset == null) {
      throw const AppUpdateException(AppUpdateErrorType.missingAndroidAsset);
    }

    if (asset.sha256 == null) {
      throw const AppUpdateException(
        AppUpdateErrorType.downloadFailed,
        reason: UpdateFailureReason.missingChecksum,
      );
    }
    if (!RegExp(r'^[0-9A-Za-z.+_-]+$').hasMatch(release.version) ||
        asset.size <= 0) {
      throw const AppUpdateException(
        AppUpdateErrorType.downloadFailed,
        reason: UpdateFailureReason.integrityMismatch,
      );
    }
    final updatesDirectory = await _updatesDirectory();
    await updatesDirectory.create(recursive: true);
    final apkFile = File(
      '${updatesDirectory.path}${Platform.pathSeparator}app-release-v${release.version}.apk',
    );

    if (await _validateCache(apkFile, release)) {
      _verifiedReleases[apkFile.path] = release;
      return _installVerified(apkFile, release, cached: true);
    }
    final part = File('${apkFile.path}.part');
    final request = http.Request('GET', Uri.parse(asset.browserDownloadUrl));
    request.headers.addAll(const {
      'Accept': 'application/octet-stream',
      'User-Agent': 'Next-DDL-App',
    });
    RandomAccessFile? output;
    try {
      final streamed = await _client.send(request).timeout(networkTimeout);
      if (streamed.statusCode != 200) {
        await streamed.stream.listen((_) {}).cancel();
        throw AppUpdateException(
          AppUpdateErrorType.downloadFailed,
          statusCode: streamed.statusCode,
        );
      }
      output = await part.open(mode: FileMode.write);
      var receivedBytes = 0;
      final totalBytes = asset.size;
      final startedAt = DateTime.now();
      await for (final chunk in streamed.stream.timeout(networkTimeout)) {
        await output.writeFrom(chunk);
        receivedBytes += chunk.length;
        if (receivedBytes > asset.size) {
          throw const AppUpdateException(
            AppUpdateErrorType.downloadFailed,
            reason: UpdateFailureReason.integrityMismatch,
          );
        }
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
      await output.flush();
      await output.close();
      output = null;
      if (receivedBytes != asset.size ||
          (streamed.contentLength != null &&
              receivedBytes != streamed.contentLength) ||
          await sha256File(part) != asset.sha256) {
        throw const AppUpdateException(
          AppUpdateErrorType.downloadFailed,
          reason: UpdateFailureReason.integrityMismatch,
        );
      }
      if (await apkFile.exists()) await apkFile.delete();
      await part.rename(apkFile.path);
      final metadata = File('${apkFile.path}.json');
      final metadataPart = File('${metadata.path}.part');
      await metadataPart.writeAsString(
        jsonEncode(_identity(release)),
        flush: true,
      );
      if (await metadata.exists()) await metadata.delete();
      await metadataPart.rename(metadata.path);
      _verifiedReleases[apkFile.path] = release;
    } on TimeoutException {
      throw const AppUpdateException(
        AppUpdateErrorType.downloadFailed,
        reason: UpdateFailureReason.timeout,
      );
    } on AppUpdateException {
      rethrow;
    } catch (_) {
      throw const AppUpdateException(AppUpdateErrorType.downloadFailed);
    } finally {
      await output?.close();
      if (await part.exists()) await part.delete();
      final metadataPart = File('${apkFile.path}.json.part');
      if (await metadataPart.exists()) await metadataPart.delete();
    }
    return _installVerified(apkFile, release);
  }

  Future<AppUpdateInstallResult> _installVerified(
    File apkFile,
    UpdateRelease release, {
    bool cached = false,
  }) async {
    if (!await _canRequestPackageInstalls()) {
      await _openManageUnknownAppSources();
      return AppUpdateInstallResult(
        status: AppUpdateInstallStatus.permissionRequired,
        filePath: apkFile.path,
        installerVersion: release.version,
        usedCachedInstaller: cached,
      );
    }

    await _openInstallerFile(apkFile.path);
    return AppUpdateInstallResult(
      status: AppUpdateInstallStatus.installerOpened,
      filePath: apkFile.path,
      installerVersion: release.version,
      usedCachedInstaller: cached,
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
    if (!_isAndroid) {
      return false;
    }
    if (_busy) return false;
    _busy = true;
    try {
      final release = _verifiedReleases[filePath];
      if (release == null || !await _validateCache(File(filePath), release)) {
        throw const AppUpdateException(
          AppUpdateErrorType.downloadFailed,
          reason: UpdateFailureReason.invalidCache,
        );
      }
      if (!await _canRequestPackageInstalls()) {
        return false;
      }
      await _openInstallerFile(filePath);
      return true;
    } finally {
      _busy = false;
    }
  }

  @override
  Future<void> openInstallPermissionSettings() async {
    await _openManageUnknownAppSources();
  }

  @override
  Future<int> clearCachedInstallers() async {
    if (!_isAndroid) {
      return 0;
    }
    if (_busy) {
      throw const AppUpdateException(
        AppUpdateErrorType.downloadFailed,
        reason: UpdateFailureReason.busy,
      );
    }
    _busy = true;
    try {
      final directory = await _updatesDirectory();
      if (!await directory.exists()) {
        return 0;
      }
      var removed = 0;
      await for (final entity in directory.list()) {
        if (entity is! File) {
          continue;
        }
        if (!RegExp(
          r'^app-release-v[^/\\]+\.apk(?:\.part|\.json(?:\.part)?)?$',
        ).hasMatch(entity.uri.pathSegments.last)) {
          continue;
        }
        await entity.delete();
        removed++;
      }
      _verifiedReleases.clear();
      return removed;
    } finally {
      _busy = false;
    }
  }

  Future<bool> _canRequestPackageInstalls() async {
    if (!_isAndroid) {
      return false;
    }
    final result = await _methodChannel.invokeMethod<bool>(
      'canRequestPackageInstalls',
    );
    return result ?? false;
  }

  Future<void> _openManageUnknownAppSources() async {
    if (!_isAndroid) {
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
    if (_installerOpener != null) return _installerOpener(path);
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      throw AppUpdateException(
        AppUpdateErrorType.installerOpenFailed,
        details: result.message,
      );
    }
  }

  Future<Directory> _updatesDirectory() async {
    if (_cacheDirectory != null) return _cacheDirectory();
    final directory = await getTemporaryDirectory();
    return Directory('${directory.path}${Platform.pathSeparator}updates');
  }

  Map<String, dynamic> _identity(UpdateRelease release) {
    final asset = release.androidApkAsset!;
    return {
      'version': release.version,
      'tag': release.tagName,
      'assetId': asset.id,
      'url': asset.browserDownloadUrl,
      'name': asset.name,
      'size': asset.size,
      'sha256': asset.sha256,
    };
  }

  Future<UpdateRelease> _resolveChecksum(UpdateRelease release) async {
    if (release.androidApkAsset?.sha256 != null) return release;
    final sidecars = release.assets.where(
      (a) => a.name == 'app-release.apk.sha256',
    );
    if (sidecars.isEmpty) return release;
    try {
      final response = await _client
          .send(
            http.Request('GET', Uri.parse(sidecars.first.browserDownloadUrl)),
          )
          .timeout(networkTimeout);
      if (response.statusCode != 200) {
        await response.stream.listen((_) {}).cancel();
        throw const AppUpdateException(AppUpdateErrorType.downloadFailed);
      }
      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(networkTimeout)) {
        bytes.addAll(chunk);
        if (bytes.length > 8192) throw const FormatException();
      }
      final text = utf8.decode(bytes).trim();
      final match = RegExp(
        r'^([a-fA-F0-9]{64})(?:[ \t]+\*?app-release\.apk)?$',
      ).firstMatch(text);
      if (match == null) throw const FormatException();
      return release.withApkChecksum(match[1]!.toLowerCase());
    } on TimeoutException {
      throw const AppUpdateException(
        AppUpdateErrorType.downloadFailed,
        reason: UpdateFailureReason.timeout,
      );
    } on AppUpdateException {
      rethrow;
    } catch (_) {
      throw const AppUpdateException(
        AppUpdateErrorType.downloadFailed,
        reason: UpdateFailureReason.integrityMismatch,
      );
    }
  }

  Future<bool> _validateCache(File file, UpdateRelease release) async {
    final asset = release.androidApkAsset;
    if (asset?.sha256 == null || asset!.size <= 0) return false;
    try {
      final metadata = jsonDecode(
        await File('${file.path}.json').readAsString(),
      );
      final expected = _identity(release);
      if (metadata is! Map ||
          expected.keys.any((key) => metadata[key] != expected[key])) {
        return false;
      }
      return await file.length() == asset.size &&
          await sha256File(file) == asset.sha256;
    } catch (_) {
      return false;
    }
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
