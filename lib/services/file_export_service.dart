import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_snapshot.dart';
import '../utils/locale_utils.dart';

abstract class FileExportService {
  Future<String?> exportJson({
    required String suggestedName,
    required String content,
    AppLocalePreference localePreference = AppLocalePreference.system,
  });

  Future<String?> importJson({
    AppLocalePreference localePreference = AppLocalePreference.system,
  });
}

class PlatformFileExportService implements FileExportService {
  @override
  Future<String?> exportJson({
    required String suggestedName,
    required String content,
    AppLocalePreference localePreference = AppLocalePreference.system,
  }) async {
    final l10n = resolveAppLocalizations(localePreference);
    String? path;
    try {
      path = await FilePicker.platform.saveFile(
        dialogTitle: l10n.fileExportDialogTitle,
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
    } catch (_) {
      path = null;
    }
    path ??= await _fallbackPath(suggestedName);
    if (path == null) {
      return null;
    }
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsString(content);
    return file.path;
  }

  @override
  Future<String?> importJson({
    AppLocalePreference localePreference = AppLocalePreference.system,
  }) async {
    final l10n = resolveAppLocalizations(localePreference);
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: l10n.fileImportDialogTitle,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final file = result.files.single;
    if (file.path case final path?) {
      return File(path).readAsString();
    }
    final bytes = file.bytes;
    if (bytes == null) {
      return null;
    }
    return String.fromCharCodes(bytes);
  }

  Future<String?> _fallbackPath(String suggestedName) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}${Platform.pathSeparator}$suggestedName';
  }
}

final fileExportServiceProvider = Provider<FileExportService>((ref) {
  throw UnimplementedError('fileExportServiceProvider must be overridden');
});
