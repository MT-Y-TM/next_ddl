import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/app_snapshot.dart';
import 'deadline_repository.dart';
import 'task_planning_repository.dart';

enum BackupFailure {
  invalidJson,
  unsupportedSchema,
  invalidFields,
  writeFailed,
  busy,
}

class BackupException implements Exception {
  const BackupException(this.reason);
  final BackupFailure reason;
}

AppSnapshot validateSnapshotJson(String content) {
  dynamic decoded;
  try {
    decoded = jsonDecode(content);
  } catch (_) {
    throw const BackupException(BackupFailure.invalidJson);
  }
  if (decoded is! Map<String, dynamic>) {
    throw const BackupException(BackupFailure.invalidFields);
  }
  if ((decoded['schemaVersion'] ?? 1) != 1) {
    throw const BackupException(BackupFailure.unsupportedSchema);
  }
  try {
    if (decoded['tasks'] is! List) throw const FormatException();
    void walk(dynamic value, [String? key]) {
      if (value is Map) {
        for (final entry in value.entries) {
          walk(entry.value, entry.key as String);
        }
      } else if (value is List) {
        for (final item in value) {
          walk(item, key);
        }
      } else if (key != null && key.endsWith('AtUtc') && value != null) {
        if (value is! String) throw const FormatException();
        final match = RegExp(
          r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$',
        ).firstMatch(value);
        if (match == null) throw const FormatException();
        final year = int.parse(match[1]!),
            month = int.parse(match[2]!),
            day = int.parse(match[3]!);
        final date = DateTime.utc(year, month, day);
        if (date.year != year ||
            date.month != month ||
            date.day != day ||
            int.parse(match[4]!) > 23 ||
            int.parse(match[5]!) > 59 ||
            int.parse(match[6]!) > 59) {
          throw const FormatException();
        }
        final offset = RegExp(r'[+-](\d{2}):(\d{2})$').firstMatch(value);
        if (offset != null &&
            (int.parse(offset[1]!) > 23 || int.parse(offset[2]!) > 59)) {
          throw const FormatException();
        }
        DateTime.parse(value);
      }
    }

    // Extension fields such as planningData are owned by their model readers.
    walk(decoded['tasks']);
    walk(decoded['exportedAtUtc'], 'exportedAtUtc');
    final snapshot = AppSnapshot.fromJson(decoded);
    TaskPlanningSnapshot.fromJson(snapshot.planningData);
    final taskIds = <String>{};
    for (final task in snapshot.tasks) {
      final nodeIds = <String>{};
      if (task.id.trim().isEmpty ||
          !taskIds.add(task.id) ||
          task.milestones.any(
            (m) => m.id.trim().isEmpty || !nodeIds.add(m.id),
          ) ||
          task.title.trim().isEmpty ||
          task.timezoneId.trim().isEmpty ||
          task.updatedAtUtc.isBefore(task.createdAtUtc) ||
          task.reminderOffsetsSeconds.any((v) => v < 0) ||
          task.milestones.any(
            (m) => !m.dueAtUtc.isBefore(task.finalDueAtUtc),
          )) {
        throw const FormatException();
      }
    }
    return snapshot;
  } catch (_) {
    throw const BackupException(BackupFailure.invalidFields);
  }
}

class BackupEntry {
  const BackupEntry({required this.file, required this.createdAtUtc});
  final File file;
  final DateTime createdAtUtc;
}

class BackupService {
  BackupService({
    required this.repository,
    Future<Directory> Function()? directory,
    this.retentionCount = 5,
  }) : _directory = directory {
    if (retentionCount < 1) throw ArgumentError.value(retentionCount);
  }
  final DeadlineRepository repository;
  final Future<Directory> Function()? _directory;
  final int retentionCount;
  bool _busy = false;
  Future<Directory> _root() async => _directory != null
      ? _directory()
      : Directory(
          '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}backups',
        );

  Future<AppSnapshot?> previewImport() => repository.importSnapshot();

  Future<void> replaceWithBackup(AppSnapshot snapshot) async {
    if (_busy) throw const BackupException(BackupFailure.busy);
    final target = repository;
    if (target is! ProtectedDeadlineRepository) {
      throw const BackupException(BackupFailure.writeFailed);
    }
    final validated = validateSnapshotJson(jsonEncode(snapshot.toJson()));
    _busy = true;
    try {
      await (target as ProtectedDeadlineRepository).replaceSafely(
        validated,
        _createBackup,
      );
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException(BackupFailure.writeFailed);
    } finally {
      // Retention failure must not misreport an already committed import as failed.
      try {
        await pruneBackups();
      } catch (_) {
        /* Retry on the next import. */
      }
      _busy = false;
    }
  }

  Future<void> _createBackup(AppSnapshot current) async {
    final root = await _root();
    await root.create(recursive: true);
    var stamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    while (await File('${root.path}/snapshot-$stamp.json').exists()) {
      stamp++;
    }
    final file = File('${root.path}/snapshot-$stamp.json');
    final part = File('${file.path}.part');
    try {
      final payload = jsonEncode(current.toJson());
      await part.writeAsString(payload, flush: true);
      if (await part.readAsString() != payload) {
        throw const FileSystemException();
      }
      await part.rename(file.path);
    } finally {
      if (await part.exists()) await part.delete();
    }
  }

  Future<List<BackupEntry>> listBackups() async {
    final root = await _root();
    if (!await root.exists()) return [];
    final entries = <BackupEntry>[];
    await for (final file in root.list()) {
      if (file is! File) continue;
      final match = RegExp(
        r'^snapshot-(\d+)\.json$',
      ).firstMatch(file.uri.pathSegments.last);
      final stamp = int.tryParse(match?[1] ?? '');
      if (stamp != null) {
        entries.add(
          BackupEntry(
            file: file,
            createdAtUtc: DateTime.fromMicrosecondsSinceEpoch(
              stamp,
              isUtc: true,
            ),
          ),
        );
      }
    }
    entries.sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
    return entries;
  }

  Future<AppSnapshot> readBackup(BackupEntry entry) async {
    final entries = await listBackups();
    if (!entries.any((e) => e.file.absolute.path == entry.file.absolute.path)) {
      throw const BackupException(BackupFailure.invalidFields);
    }
    return validateSnapshotJson(await entry.file.readAsString());
  }

  Future<AppSnapshot> restoreBackup(BackupEntry entry) async {
    final snapshot = await readBackup(entry);
    await replaceWithBackup(snapshot);
    return snapshot;
  }

  Future<void> pruneBackups() async {
    for (final entry in (await listBackups()).skip(retentionCount)) {
      await entry.file.delete();
    }
  }
}
