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

enum AppUpdateInstallStatus {
  installerOpened,
  permissionRequired,
  openedReleasePage,
}

class AppUpdateInstallResult {
  const AppUpdateInstallResult({
    required this.status,
    this.filePath,
  });

  final AppUpdateInstallStatus status;
  final String? filePath;
}

abstract class AppUpdateService {
  Future<UpdateRelease?> checkForUpdate({required String currentVersion});

  Future<AppUpdateInstallResult> downloadAndInstall(UpdateRelease release);

  Future<void> openReleasePage(UpdateRelease release);

  Future<bool> resumePendingInstall(String filePath);

  Future<void> openInstallPermissionSettings();
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

  final http.Client _client;
  final MethodChannel _methodChannel;

  @override
  Future<UpdateRelease?> checkForUpdate({required String currentVersion}) async {
    final response = await _client.get(
      Uri.https('api.github.com', '/repos/$_owner/$_repo/releases/latest'),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'Next-DDL-App',
      },
    );
    if (response.statusCode != 200) {
      throw HttpException(
        'GitHub API returned ${response.statusCode}',
        uri: Uri.parse('https://api.github.com/repos/$_owner/$_repo/releases/latest'),
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
  Future<AppUpdateInstallResult> downloadAndInstall(UpdateRelease release) async {
    if (!Platform.isAndroid) {
      await openReleasePage(release);
      return const AppUpdateInstallResult(
        status: AppUpdateInstallStatus.openedReleasePage,
      );
    }

    final asset = release.androidApkAsset;
    if (asset == null) {
      throw StateError('Missing app-release.apk asset');
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
    final streamed = await _client.send(request);
    if (streamed.statusCode != 200) {
      throw HttpException(
        'Asset download returned ${streamed.statusCode}',
        uri: Uri.parse(asset.browserDownloadUrl),
      );
    }

    await apkFile.writeAsBytes(await streamed.stream.toBytes());

    if (!await _canRequestPackageInstalls()) {
      await _openManageUnknownAppSources();
      return AppUpdateInstallResult(
        status: AppUpdateInstallStatus.permissionRequired,
        filePath: apkFile.path,
      );
    }

    await _openInstallerFile(apkFile.path);
    return AppUpdateInstallResult(
      status: AppUpdateInstallStatus.installerOpened,
      filePath: apkFile.path,
    );
  }

  @override
  Future<void> openReleasePage(UpdateRelease release) async {
    final uri = Uri.parse(release.htmlUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw StateError('Failed to open release page');
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
    await _methodChannel.invokeMethod('openManageUnknownAppSources');
  }

  Future<void> _openInstallerFile(String path) async {
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      throw StateError(result.message);
    }
  }
}

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  throw UnimplementedError('appUpdateServiceProvider must be overridden');
});
