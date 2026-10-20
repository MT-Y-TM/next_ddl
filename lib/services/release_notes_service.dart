import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/update_release.dart';
import 'app_info_service.dart';

String localizedReleaseNotes(String body, String languageCode) {
  final sections = <String, List<String>>{'zh': [], 'en': []};
  String? language;
  var multilingual = false;
  for (final line in body.split('\n')) {
    final heading = RegExp(r'^\s{0,3}#{1,6}\s+(.+?)\s*#*\s*$').firstMatch(line);
    final title = heading?.group(1)?.trim().toLowerCase();
    if (title != null &&
        RegExp(r'^(中文|简体中文|chinese|zh)(\s.*)?$').hasMatch(title)) {
      language = 'zh';
      multilingual = true;
      continue;
    }
    if (title != null && RegExp(r'^(english|英文|en)(\s.*)?$').hasMatch(title)) {
      language = 'en';
      multilingual = true;
      continue;
    }
    if (language != null) sections[language]!.add(line);
  }
  final text = !multilingual
      ? body
      : languageCode == 'zh'
      ? (sections['zh']!.join('\n').trim().isNotEmpty
            ? sections['zh']!.join('\n')
            : sections['en']!.join('\n'))
      : sections['en']!.join('\n');
  return text
      .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '')
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m[1]!)
      .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true), '')
      .replaceAll('`', '')
      .trim();
}

class VersionReleaseNotes {
  const VersionReleaseNotes({required this.version, required this.body});
  final String version;
  final String body;
  String textFor(String languageCode) =>
      localizedReleaseNotes(body, languageCode);
}

/// Device-local metadata, deliberately outside exported task snapshots.
class ReleaseNotesService {
  ReleaseNotesService({
    http.Client? client,
    Future<SharedPreferences> Function()? preferences,
    Future<String> Function()? bundledNotes,
  }) : _client = client ?? http.Client(),
       _preferences = preferences ?? SharedPreferences.getInstance,
       _bundledNotes =
           bundledNotes ??
           (() => rootBundle.loadString('asset/release_notes.json'));

  static const cacheKey = 'version_release_notes_v1';
  static Future<void> _writes = Future<void>.value();
  final http.Client _client;
  final Future<SharedPreferences> Function() _preferences;
  final Future<String> Function() _bundledNotes;

  Future<VersionReleaseNotes?> load(String version) async {
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) return null;
    try {
      final prefs = await _preferences();
      final cached = _decodeCache(prefs.getString(cacheKey))[version];
      if (cached is String && cached.trim().isNotEmpty) {
        return VersionReleaseNotes(version: version, body: cached);
      }
    } catch (_) {
      /* Notes remain available from the bundle if storage fails. */
    }
    try {
      final data = jsonDecode(await _bundledNotes()) as Map<String, dynamic>;
      if (data['version'] == version) {
        final body = '## 中文\n${data['zh']}\n\n## English\n${data['en']}';
        await remember(version, body);
        return VersionReleaseNotes(version: version, body: body);
      }
    } catch (_) {
      /* A version-matched GitHub release is the remaining source. */
    }
    try {
      final response = await _client
          .get(
            Uri.https(
              'api.github.com',
              '/repos/MT-Y-TM/next_ddl/releases/tags/v$version',
            ),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'Next-DDL-App',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final release = UpdateRelease.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      if (release.version != version || release.body.isEmpty) return null;
      await remember(release.version, release.body);
      return VersionReleaseNotes(version: version, body: release.body);
    } catch (_) {
      return null;
    }
  }

  Future<void> remember(String version, String body) async {
    if (body.trim().isEmpty) return;
    final write = _writes.then((_) async {
      final prefs = await _preferences();
      final cache = _decodeCache(prefs.getString(cacheKey))..remove(version);
      cache[version] = body;
      while (cache.length > 10) {
        cache.remove(cache.keys.first);
      }
      await prefs.setString(cacheKey, jsonEncode(cache));
    });
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    try {
      await write;
    } catch (_) {
      /* Metadata must never block updates. */
    }
  }

  Map<String, dynamic> _decodeCache(String? raw) {
    try {
      return jsonDecode(raw ?? '{}') as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  void dispose() => _client.close();
}

final releaseNotesServiceProvider = Provider<ReleaseNotesService>((ref) {
  final service = ReleaseNotesService();
  ref.onDispose(service.dispose);
  return service;
});

final currentVersionNotesProvider = FutureProvider<VersionReleaseNotes?>((
  ref,
) async {
  final service = ref.watch(releaseNotesServiceProvider);
  final version = await ref.watch(appInfoServiceProvider).getVersionLabel();
  return service.load(version);
});
