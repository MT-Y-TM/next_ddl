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
  LocalThemeAssetService({
    Future<Directory> Function()? supportDirectory,
    Future<String?> Function()? imagePicker,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _imagePicker = imagePicker ?? _pickImage;

  final Future<Directory> Function() _supportDirectory;
  final Future<String?> Function() _imagePicker;
  static const _folderName = 'theme_backgrounds';

  static Future<String?> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    return result?.files.single.path;
  }

  @override
  Future<String?> pickAndCopyBackgroundImage({String? oldPath}) async {
    final sourcePath = await _imagePicker();
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
    return target.path;
  }

  @override
  Future<void> deleteBackgroundImage(String? path) async {
    if (path == null || path.isEmpty) {
      return;
    }
    // Only drafts copied into our private folder may be removed. Imported JSON
    // can contain paths outside that folder.
    final directory = await _backgroundDirectory();
    if (!p.equals(p.dirname(p.absolute(path)), p.absolute(directory.path))) {
      return;
    }
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> _backgroundDirectory() async {
    final base = await _supportDirectory();
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
