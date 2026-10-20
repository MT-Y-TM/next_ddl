import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:next_ddl/services/release_notes_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('bundled bilingual notes match the application version', () {
    final notes =
        jsonDecode(File('asset/release_notes.json').readAsStringSync()) as Map;
    final version = RegExp(
      r'^version: (\d+\.\d+\.\d+)\+',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
    expect(notes['version'], version);
    expect(notes['zh'], isNotEmpty);
    expect(notes['en'], isNotEmpty);
  });

  test(
    'Chinese gets Chinese; English, Japanese and other locales get English',
    () {
      const body = '## 中文\n- 中文内容\n\n## English\n- English `notes`';
      expect(localizedReleaseNotes(body, 'zh'), '- 中文内容');
      for (final locale in ['en', 'ja', 'fr']) {
        expect(localizedReleaseNotes(body, locale), '- English notes');
      }
      expect(localizedReleaseNotes('## English\nFallback', 'zh'), 'Fallback');
      expect(localizedReleaseNotes('## 中文\n仅中文', 'ja'), isEmpty);
      expect(
        localizedReleaseNotes('Legacy plain text', 'en'),
        'Legacy plain text',
      );
    },
  );

  test(
    'matching bundle is cached and survives service recreation offline',
    () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        throw Exception('offline');
      });
      final service = ReleaseNotesService(
        client: client,
        bundledNotes: () async =>
            jsonEncode({'version': '1.2.10', 'zh': '中文', 'en': 'English'}),
      );
      final notes = await service.load('1.2.10');
      expect(notes!.textFor('ja'), 'English');
      final offline = ReleaseNotesService(
        client: client,
        bundledNotes: () async => throw Exception('missing bundle'),
      );
      expect((await offline.load('1.2.10'))!.textFor('zh'), '中文');
      expect(requests, 0);
      service.dispose();
      offline.dispose();
    },
  );

  test('fetches the installed version tag, not the latest release', () async {
    final service = ReleaseNotesService(
      bundledNotes: () async => '{}',
      client: MockClient((request) async {
        expect(
          request.url.path,
          '/repos/MT-Y-TM/next_ddl/releases/tags/v1.2.9',
        );
        return http.Response(
          jsonEncode({
            'tag_name': 'v1.2.9',
            'body': '## 中文\n旧版\n## English\nPrevious',
            'published_at': '2026-10-20T00:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(service.dispose);
    await service.remember('1.3.0', '## English\nFuture version');
    expect((await service.load('1.2.9'))!.textFor('en'), 'Previous');
  });

  test(
    'cache is bounded and corrupt storage or missing releases are harmless',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ReleaseNotesService.cacheKey, 'broken');
      final service = ReleaseNotesService(
        bundledNotes: () async => '{}',
        client: MockClient((_) async => http.Response('{}', 404)),
      );
      addTearDown(service.dispose);
      expect(await service.load('1.2.8'), isNull);
      for (var i = 0; i < 12; i++) {
        await service.remember('1.2.$i', 'Notes $i');
      }
      final cache =
          jsonDecode(prefs.getString(ReleaseNotesService.cacheKey)!) as Map;
      expect(cache.length, 10);
      expect(cache.containsKey('1.2.0'), isFalse);
      expect((await service.load('1.2.11'))!.body, 'Notes 11');
    },
  );
}
