import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_snapshot.dart';
import 'deadline_repository.dart';
import 'file_export_service.dart';

class SharedPrefsDeadlineRepository implements DeadlineRepository {
  SharedPrefsDeadlineRepository({
    required FileExportService fileExportService,
  }) : _fileExportService = fileExportService;

  static const storageKey = 'app_snapshot_v1';

  final FileExportService _fileExportService;

  @override
  Future<String?> exportSnapshot(AppSnapshot snapshot) async {
    final payload = jsonEncode(
      snapshot.copyWith(exportedAtUtc: DateTime.now().toUtc()).toJson(),
    );
    return _fileExportService.exportJson(
      suggestedName: 'next_ddl_snapshot_v1.json',
      content: payload,
    );
  }

  @override
  Future<AppSnapshot?> importSnapshot() async {
    final content = await _fileExportService.importJson();
    if (content == null) {
      return null;
    }
    return AppSnapshot.fromJson(
      jsonDecode(content) as Map<String, dynamic>,
    );
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
  Future<void> saveSnapshot(AppSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final nextSnapshot = snapshot.copyWith(
      exportedAtUtc: DateTime.now().toUtc(),
    );
    await prefs.setString(storageKey, jsonEncode(nextSnapshot.toJson()));
  }
}
