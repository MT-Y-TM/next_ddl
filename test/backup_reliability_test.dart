import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Test-only fault injection into the storage plugin used by the repository.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:next_ddl/models/app_snapshot.dart';
import 'package:next_ddl/models/task_template.dart';
import 'package:next_ddl/services/backup_service.dart';
import 'package:next_ddl/services/file_export_service.dart';
import 'package:next_ddl/services/shared_prefs_deadline_repository.dart';
import 'package:next_ddl/services/task_planning_repository.dart';

Map<String, dynamic> task(String id) => {
  'id': id,
  'title': '中文 English 日本語',
  'note': '',
  'timezoneId': 'UTC',
  'createdAtUtc': '2026-01-01T00:00:00Z',
  'updatedAtUtc': '2026-01-01T00:00:00Z',
  'finalDueAtUtc': '2026-02-01T00:00:00Z',
  'milestones': [
    {'id': 'node', 'title': '', 'dueAtUtc': '2026-01-20T00:00:00Z'},
  ],
  'alarmAudioItemsOverride': [
    {'id': 'shared-audio', 'displayName': 'audio', 'uri': '/media/audio.mp3'},
  ],
};
AppSnapshot snapshot(String id) => validateSnapshotJson(
  jsonEncode({
    'tasks': [task(id)],
  }),
);
Matcher backupFailure(BackupFailure reason) =>
    isA<BackupException>().having((e) => e.reason, 'reason', reason);

class Picker extends FileExportService {
  String? content;
  @override
  Future<String?> importJson({
    AppLocalePreference localePreference = AppLocalePreference.system,
  }) async => content;
  @override
  Future<String?> exportJson({
    required String suggestedName,
    required String content,
    AppLocalePreference localePreference = AppLocalePreference.system,
  }) async => content;
}

class FailingStore extends SharedPreferencesStorePlatform {
  FailingStore(this.data);
  final Map<String, Object> data;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
  @override
  Future<Map<String, Object>> getAll() async => Map.of(data);
  @override
  Future<bool> remove(String key) async => false;
  @override
  Future<bool> clear() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Picker picker;
  late SharedPrefsDeadlineRepository repository;
  late BackupService service;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('next-ddl-backup-test-');
    picker = Picker();
    repository = SharedPrefsDeadlineRepository(fileExportService: picker);
    service = BackupService(
      repository: repository,
      directory: () async => root,
      retentionCount: 2,
    );
  });
  tearDown(() async {
    await root.delete(recursive: true);
    SharedPreferences.setMockInitialValues({});
  });

  test('legacy JSON defaults and multilingual content survive import', () {
    final value = snapshot('old');
    expect(value.schemaVersion, 1);
    expect(value.tasks.single.title, '中文 English 日本語');
    expect(value.tasks.single.completedAtUtc, isNull);
    expect(value.planningData, isEmpty);
  });
  test('shared audio IDs and node IDs across different tasks are valid', () {
    final value = validateSnapshotJson(
      jsonEncode({
        'tasks': [task('one'), task('two')],
      }),
    );
    expect(value.tasks, hasLength(2));
  });
  test('corrupt JSON and unknown schema are distinguished', () {
    expect(
      () => validateSnapshotJson('{'),
      throwsA(backupFailure(BackupFailure.invalidJson)),
    );
    expect(
      () => validateSnapshotJson('{"schemaVersion":2,"tasks":[]}'),
      throwsA(backupFailure(BackupFailure.unsupportedSchema)),
    );
  });
  for (final value in [
    '2026-02-30T10:00:00Z',
    '2026-13-01T10:00:00Z',
    '2026-01-01T25:00:00Z',
    '2026-01-01T10:00:00+25:00',
    'not a date',
  ]) {
    test('rejects invalid date $value', () {
      final raw = task('one')..['finalDueAtUtc'] = value;
      expect(
        () => validateSnapshotJson(
          jsonEncode({
            'tasks': [raw],
          }),
        ),
        throwsA(backupFailure(BackupFailure.invalidFields)),
      );
    });
  }
  test(
    'rejects invalid optional completed date instead of silently dropping it',
    () {
      final raw = task('one')..['completedAtUtc'] = 'invalid';
      expect(
        () => validateSnapshotJson(
          jsonEncode({
            'tasks': [raw],
          }),
        ),
        throwsA(backupFailure(BackupFailure.invalidFields)),
      );
    },
  );
  test('rejects duplicate task and per-task node IDs', () {
    expect(
      () => validateSnapshotJson(
        jsonEncode({
          'tasks': [task('same'), task('same')],
        }),
      ),
      throwsA(backupFailure(BackupFailure.invalidFields)),
    );
    final raw = task('one');
    final nodes = raw['milestones'] as List;
    nodes.add(Map<String, String>.from(nodes.single as Map));
    expect(
      () => validateSnapshotJson(
        jsonEncode({
          'tasks': [raw],
        }),
      ),
      throwsA(backupFailure(BackupFailure.invalidFields)),
    );
  });
  test('invalid types and node ordering rejected', () {
    final raw = task('one')..['title'] = 42;
    expect(
      () => validateSnapshotJson(
        jsonEncode({
          'tasks': [raw],
        }),
      ),
      throwsA(backupFailure(BackupFailure.invalidFields)),
    );
    final lateNode = task('one');
    (lateNode['milestones'] as List).single['dueAtUtc'] =
        '2027-01-01T00:00:00Z';
    expect(
      () => validateSnapshotJson(
        jsonEncode({
          'tasks': [lateNode],
        }),
      ),
      throwsA(backupFailure(BackupFailure.invalidFields)),
    );
  });
  test(
    'planning data is validated and survives replacement backup restore',
    () async {
      final planning = TaskPlanningSnapshot(
        templates: {'t': TaskTemplate(id: 't', title: 'template')},
        issued: {'issued'},
        skipped: {'skipped'},
      ).toJson();
      final original = snapshot('one').copyWith(planningData: planning);
      await repository.saveSnapshot(original);
      await service.replaceWithBackup(snapshot('two'));
      final restored = await service.restoreBackup(
        (await service.listBackups()).single,
      );
      expect(restored.planningData, planning);
      expect((await repository.loadSnapshot()).planningData, planning);
      final invalid = original.toJson()
        ..['planningData'] = {'schemaVersion': 99};
      expect(
        () => validateSnapshotJson(jsonEncode(invalid)),
        throwsA(backupFailure(BackupFailure.invalidFields)),
      );
      final duplicate = original.toJson()
        ..['planningData'] = {
          'templates': [
            TaskTemplate(id: 't', title: 'x').toJson(),
            TaskTemplate(id: 't', title: 'y').toJson(),
          ],
        };
      expect(
        () => validateSnapshotJson(jsonEncode(duplicate)),
        throwsA(backupFailure(BackupFailure.invalidFields)),
      );
    },
  );
  test('preview and cancel never write data or create backups', () async {
    await repository.saveSnapshot(snapshot('original'));
    picker.content = jsonEncode(snapshot('new').toJson());
    expect((await service.previewImport())!.tasks.single.id, 'new');
    expect((await repository.loadSnapshot()).tasks.single.id, 'original');
    expect(await service.listBackups(), isEmpty);
    picker.content = null;
    expect(await service.previewImport(), isNull);
  });
  test('retention and recovery include backup of pre-restore data', () async {
    await repository.saveSnapshot(snapshot('one'));
    await service.replaceWithBackup(snapshot('two'));
    await service.replaceWithBackup(snapshot('three'));
    await service.replaceWithBackup(snapshot('four'));
    final entries = await service.listBackups();
    expect(entries, hasLength(2));
    expect((await service.readBackup(entries.first)).tasks.single.id, 'three');
    await service.restoreBackup(entries.first);
    expect((await repository.loadSnapshot()).tasks.single.id, 'three');
    expect(
      (await service.readBackup(
        (await service.listBackups()).first,
      )).tasks.single.id,
      'four',
    );
  });
  test('backup disk failure leaves persisted data intact', () async {
    await repository.saveSnapshot(snapshot('original'));
    final blocker = File('${root.path}/not-directory');
    await blocker.writeAsString('x');
    final broken = BackupService(
      repository: repository,
      directory: () async => Directory(blocker.path),
    );
    await expectLater(
      broken.replaceWithBackup(snapshot('new')),
      throwsA(backupFailure(BackupFailure.writeFailed)),
    );
    expect((await repository.loadSnapshot()).tasks.single.id, 'original');
  });
  test(
    'failed platform write reloads old preferences cache and preserves backup',
    () async {
      final original = snapshot('original');
      await repository.saveSnapshot(original);
      final previousStore = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = FailingStore({
        'flutter.${SharedPrefsDeadlineRepository.storageKey}': jsonEncode(
          original.toJson(),
        ),
      });
      try {
        await expectLater(
          service.replaceWithBackup(snapshot('new')),
          throwsA(backupFailure(BackupFailure.writeFailed)),
        );
        expect((await repository.loadSnapshot()).tasks.single.id, 'original');
        expect(
          (await service.readBackup(
            (await service.listBackups()).single,
          )).tasks.single.id,
          'original',
        );
      } finally {
        SharedPreferencesStorePlatform.instance = previousStore;
      }
    },
  );
  test('repository serializes backup and ordinary writes', () async {
    await repository.saveSnapshot(snapshot('one'));
    final entered = Completer<void>(), gate = Completer<void>();
    final replacing = repository.replaceSafely(snapshot('two'), (
      current,
    ) async {
      expect(current.tasks.single.id, 'one');
      entered.complete();
      await gate.future;
    });
    await entered.future;
    final save = repository.saveSnapshot(snapshot('three'));
    expect((await repository.loadSnapshot()).tasks.single.id, 'one');
    gate.complete();
    await replacing;
    await save;
    expect((await repository.loadSnapshot()).tasks.single.id, 'three');
  });
  test('damaged backup cannot replace current data', () async {
    await repository.saveSnapshot(snapshot('one'));
    await service.replaceWithBackup(snapshot('two'));
    final entry = (await service.listBackups()).single;
    await entry.file.writeAsString('{broken');
    await expectLater(
      service.restoreBackup(entry),
      throwsA(backupFailure(BackupFailure.invalidJson)),
    );
    expect((await repository.loadSnapshot()).tasks.single.id, 'two');
  });
}
