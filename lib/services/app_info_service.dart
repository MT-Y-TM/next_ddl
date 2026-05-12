import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

abstract class AppInfoService {
  Future<String> getVersionLabel();
}

class PackageInfoAppInfoService implements AppInfoService {
  @override
  Future<String> getVersionLabel() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }
}

final appInfoServiceProvider = Provider<AppInfoService>((ref) {
  throw UnimplementedError('appInfoServiceProvider must be overridden');
});
