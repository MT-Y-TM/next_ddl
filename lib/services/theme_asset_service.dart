import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract class ThemeAssetService {
  Future<String?> pickAndCopyBackgroundImage({String? oldPath});

  Future<void> deleteBackgroundImage(String? path);
}

class LocalThemeAssetService implements ThemeAssetService {
  static const _folderName = 'theme_backgrounds';

  @override
  Future<String?> pickAndCopyBackgroundImage({String? oldPath}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final sourcePath = result?.files.single.path;
    if (sourcePath == null || sourcePath.isEmpty) {
      return null;
    }

    final directory = await _backgroundDirectory();
    final extension = p.extension(sourcePath).isEmpty
        ? '.image'
        : p.extension(sourcePath);
    final target = File(
      p.join(
        directory.path,
        'background_${DateTime.now().microsecondsSinceEpoch}$extension',
      ),
    );
    await File(sourcePath).copy(target.path);
    if (oldPath != null && oldPath != target.path) {
      await deleteBackgroundImage(oldPath);
    }
    return target.path;
  }

  @override
  Future<void> deleteBackgroundImage(String? path) async {
    if (path == null || path.isEmpty) {
      return;
    }
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> _backgroundDirectory() async {
    final base = await getApplicationSupportDirectory();
    final directory = Directory(p.join(base.path, _folderName));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}

final themeAssetServiceProvider = Provider<ThemeAssetService>((ref) {
  throw UnimplementedError('themeAssetServiceProvider must be overridden');
});
