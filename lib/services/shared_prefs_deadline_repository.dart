import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_snapshot.dart';
import 'deadline_repository.dart';
import 'file_export_service.dart';
import 'backup_service.dart';

class SharedPrefsDeadlineRepository
    implements DeadlineRepository, ProtectedDeadlineRepository {
  SharedPrefsDeadlineRepository({required FileExportService fileExportService})
    : _fileExportService = fileExportService;

  static const storageKey = 'app_snapshot_v1';

  final FileExportService _fileExportService;
  Future<void> _pending = Future.value();
  Future<void> _serialize(Future<void> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  @override
  Future<void> replaceSafely(
    AppSnapshot snapshot,
    Future<void> Function(AppSnapshot) backup,
  ) => _serialize(() async {
    validateSnapshotJson(jsonEncode(snapshot.toJson()));
    final current = await loadSnapshot();
    await backup(current);
    await _save(snapshot);
  });

  @override
  Future<String?> exportSnapshot(AppSnapshot snapshot) async {
    final payload = jsonEncode(
      snapshot.copyWith(exportedAtUtc: DateTime.now().toUtc()).toJson(),
    );
    return _fileExportService.exportJson(
      suggestedName: 'next_ddl_snapshot_v1.json',
      content: payload,
      localePreference: snapshot.preferredLocale,
    );
  }

  @override
  Future<AppSnapshot?> importSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    final existingSnapshot = raw == null || raw.isEmpty
        ? AppSnapshot.empty()
        : AppSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    final content = await _fileExportService.importJson(
      localePreference: existingSnapshot.preferredLocale,
    );
    if (content == null) {
      return null;
    }
    return validateSnapshotJson(content);
  }

  @override
  Future<AppSnapshot> loadSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return AppSnapshot.empty();
    }
    return AppSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> saveSnapshot(AppSnapshot snapshot) =>
      _serialize(() => _save(snapshot));
  Future<void> _save(AppSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final nextSnapshot = snapshot.copyWith(
      exportedAtUtc: DateTime.now().toUtc(),
    );
    try {
      final saved = await prefs.setString(
        storageKey,
        jsonEncode(nextSnapshot.toJson()),
      );
      if (!saved) throw const BackupException(BackupFailure.writeFailed);
    } catch (_) {
      // The plugin changes its memory cache before platform persistence succeeds.
      await prefs.reload();
      rethrow;
    }
  }
}
