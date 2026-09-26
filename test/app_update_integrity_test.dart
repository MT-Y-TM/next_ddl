import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:next_ddl/features/update/update_integrity.dart';
import 'package:next_ddl/models/update_release.dart';
import 'package:next_ddl/services/app_update_service.dart';

const channel = MethodChannel('test/update');
final payload = utf8.encode('complete APK fixture');
UpdateRelease release({
  String version = '2.0.0',
  String? digest,
  bool checksum = true,
  bool sidecar = false,
  int id = 1,
  int? size,
}) => UpdateRelease(
  tagName: 'v$version',
  version: version,
  publishedAtUtc: DateTime.utc(2026),
  body: '',
  htmlUrl: 'https://example.test/release',
  assets: [
    UpdateAsset(
      name: 'app-release.apk',
      browserDownloadUrl: 'https://example.test/app-release.apk',
      contentType: 'application/octet-stream',
      size: size ?? payload.length,
      id: id,
      digest: checksum ? 'sha256:${digest ?? sha256.convert(payload)}' : null,
    ),
    if (sidecar)
      const UpdateAsset(
        name: 'app-release.apk.sha256',
        browserDownloadUrl: 'https://example.test/app-release.apk.sha256',
        contentType: 'text/plain',
        size: 100,
      ),
  ],
);

Matcher failure(UpdateFailureReason reason) =>
    isA<AppUpdateException>().having((e) => e.reason, 'reason', reason);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late bool permission;
  late int opened;
  late int permissionPages;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('next-ddl-update-test-');
    permission = true;
    opened = 0;
    permissionPages = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'canRequestPackageInstalls') return permission;
          if (call.method == 'openManageUnknownAppSources') permissionPages++;
          return null;
        });
  });
  tearDown(() async {
    await root.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  GithubAppUpdateService service(
    http.Client client, {
    Duration timeout = const Duration(seconds: 2),
    Future<void> Function(String)? opener,
  }) => GithubAppUpdateService(
    client: client,
    isAndroid: true,
    methodChannel: channel,
    cacheDirectory: () async => root,
    networkTimeout: timeout,
    installerOpener:
        opener ??
        (_) async {
          opened++;
        },
  );

  test('streaming SHA-256 standard vectors', () async {
    expect(
      await sha256Stream(const Stream<List<int>>.empty()),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    expect(
      await sha256Stream(
        Stream.fromIterable([
          [97],
          [98, 99],
        ]),
      ),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });
  test(
    'download commits only verified data and reuses metadata-bound cache',
    () async {
      var requests = 0;
      final s = service(
        MockClient((_) async {
          requests++;
          return http.Response.bytes(payload, 200);
        }),
      );
      final progress = <DownloadProgress>[];
      final first = await s.downloadAndInstall(
        release(),
        onProgress: progress.add,
      );
      expect(await File(first.filePath!).readAsBytes(), payload);
      expect(await File('${first.filePath}.part').exists(), false);
      expect(progress.last.percent, 100);
      expect((await s.downloadAndInstall(release())).usedCachedInstaller, true);
      expect(requests, 1);
      expect(opened, 2);
      expect(
        await s.findReusableInstaller(
          release: release(),
          currentVersion: '1.0.0',
        ),
        isNotNull,
      );
      expect(
        await s.findReusableInstaller(
          release: release(),
          currentVersion: '2.0.0',
        ),
        isNull,
      );
      expect(
        await s.findReusableInstaller(
          release: release(id: 2),
          currentVersion: '1.0.0',
        ),
        isNull,
      );
      expect(
        await s.findReusableInstaller(
          release: release(version: '3.0.0'),
          currentVersion: '1.0.0',
        ),
        isNull,
      );
      await File(first.filePath!).writeAsBytes(List.filled(payload.length, 0));
      expect(
        await s.findReusableInstaller(
          release: release(),
          currentVersion: '1.0.0',
        ),
        isNull,
      );
      await expectLater(
        s.resumePendingInstall(first.filePath!),
        throwsA(failure(UpdateFailureReason.invalidCache)),
      );
      expect(
        (await s.downloadAndInstall(release())).usedCachedInstaller,
        false,
      );
      expect(requests, 2);
    },
  );
  test('legacy filename without metadata is not reused', () async {
    await File('${root.path}/app-release-v2.0.0.apk').writeAsBytes(payload);
    final s = service(
      MockClient((_) async => http.Response.bytes(payload, 200)),
    );
    expect(
      await s.findReusableInstaller(
        release: release(),
        currentVersion: '1.0.0',
      ),
      isNull,
    );
  });
  test('missing checksum is explicit and sends no request', () async {
    final s = service(
      MockClient((_) async => throw StateError('must not download')),
    );
    await expectLater(
      s.downloadAndInstall(release(checksum: false)),
      throwsA(failure(UpdateFailureReason.missingChecksum)),
    );
    expect(opened, 0);
  });
  test('sidecar standard sha256sum output is accepted', () async {
    final s = service(
      MockClient(
        (r) async => r.url.path.endsWith('.sha256')
            ? http.Response(
                '${sha256.convert(payload)}  app-release.apk\n',
                200,
              )
            : http.Response.bytes(payload, 200),
      ),
    );
    expect(
      (await s.downloadAndInstall(
        release(checksum: false, sidecar: true),
      )).status,
      AppUpdateInstallStatus.installerOpened,
    );
  });
  test('GitHub digest takes priority over sidecar', () async {
    final s = service(
      MockClient((r) async {
        expect(r.url.path.endsWith('.sha256'), false);
        return http.Response.bytes(payload, 200);
      }),
    );
    await s.downloadAndInstall(release(sidecar: true));
  });
  test('malformed or wrong-filename sidecar is rejected', () async {
    final s = service(
      MockClient(
        (_) async =>
            http.Response('${sha256.convert(payload)}  other.apk', 200),
      ),
    );
    await expectLater(
      s.downloadAndInstall(release(checksum: false, sidecar: true)),
      throwsA(failure(UpdateFailureReason.integrityMismatch)),
    );
    expect(opened, 0);
  });
  for (final scenario in [
    'truncated',
    'wrong hash',
    'oversized',
    'broken stream',
  ]) {
    test('$scenario is never installed and part is removed', () async {
      final s = service(
        MockClient.streaming(
          (_, _) async => http.StreamedResponse(
            scenario == 'broken stream'
                ? Stream<List<int>>.error(const SocketException('offline'))
                : Stream.value(
                    scenario == 'truncated'
                        ? payload.sublist(1)
                        : scenario == 'oversized'
                        ? [...payload, 0]
                        : List.filled(payload.length, 0),
                  ),
            200,
          ),
        ),
      );
      await expectLater(
        s.downloadAndInstall(release()),
        throwsA(isA<AppUpdateException>()),
      );
      expect(await root.list().toList(), isEmpty);
      expect(opened, 0);
    });
  }
  test('header length mismatch blocks install', () async {
    final s = service(
      MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          Stream.value(payload),
          200,
          contentLength: payload.length + 1,
        ),
      ),
    );
    await expectLater(
      s.downloadAndInstall(release()),
      throwsA(failure(UpdateFailureReason.integrityMismatch)),
    );
  });
  test('missing content length still validates release size', () async {
    final s = service(
      MockClient.streaming(
        (_, _) async => http.StreamedResponse(Stream.value(payload), 200),
      ),
    );
    expect(
      (await s.downloadAndInstall(release())).status,
      AppUpdateInstallStatus.installerOpened,
    );
  });
  test('stream inactivity timeout cleans up and retry works', () async {
    final stream = StreamController<List<int>>();
    var first = true;
    final s = service(
      MockClient.streaming((_, _) async {
        if (first) {
          first = false;
          return http.StreamedResponse(stream.stream, 200);
        }
        return http.StreamedResponse(Stream.value(payload), 200);
      }),
      timeout: const Duration(milliseconds: 20),
    );
    await expectLater(
      s.downloadAndInstall(release()),
      throwsA(failure(UpdateFailureReason.timeout)),
    );
    await stream.close();
    expect(await root.list().toList(), isEmpty);
    expect(
      (await s.downloadAndInstall(release())).status,
      AppUpdateInstallStatus.installerOpened,
    );
  });
  test('request timeout and check timeout use safe reason', () async {
    final pending = Completer<http.Response>();
    final s = service(
      MockClient((_) => pending.future),
      timeout: const Duration(milliseconds: 20),
    );
    await expectLater(
      s.downloadAndInstall(release()),
      throwsA(failure(UpdateFailureReason.timeout)),
    );
    await expectLater(
      s.checkForUpdate(currentVersion: '1.0.0'),
      throwsA(failure(UpdateFailureReason.timeout)),
    );
    pending.complete(http.Response('', 503));
  });
  test('permission denial and return revalidate bytes', () async {
    permission = false;
    final s = service(
      MockClient((_) async => http.Response.bytes(payload, 200)),
    );
    final result = await s.downloadAndInstall(release());
    expect(result.status, AppUpdateInstallStatus.permissionRequired);
    expect(permissionPages, 1);
    expect(opened, 0);
    expect(await s.resumePendingInstall(result.filePath!), false);
    permission = true;
    expect(await s.resumePendingInstall(result.filePath!), true);
    expect(opened, 1);
  });
  test(
    'duplicate download and cleanup cannot race an active operation',
    () async {
      final gate = Completer<http.Response>();
      final s = service(MockClient((_) => gate.future));
      final first = s.downloadAndInstall(release());
      await expectLater(
        s.downloadAndInstall(release()),
        throwsA(failure(UpdateFailureReason.busy)),
      );
      await expectLater(
        s.clearCachedInstallers(),
        throwsA(failure(UpdateFailureReason.busy)),
      );
      gate.complete(http.Response.bytes(payload, 200));
      await first;
      expect(opened, 1);
    },
  );
  test('duplicate resume does not open a second installer', () async {
    permission = false;
    final gate = Completer<void>();
    final s = service(
      MockClient((_) async => http.Response.bytes(payload, 200)),
      opener: (_) async {
        opened++;
        await gate.future;
      },
    );
    final result = await s.downloadAndInstall(release());
    permission = true;
    final first = s.resumePendingInstall(result.filePath!);
    expect(await s.resumePendingInstall(result.filePath!), false);
    gate.complete();
    await first;
    expect(opened, 1);
  });
  test(
    'cleanup removes partials and sidecars but preserves unrelated files',
    () async {
      for (final name in [
        'app-release-v1.apk',
        'app-release-v1.apk.part',
        'app-release-v1.apk.json',
        'app-release-v1.apk.json.part',
        'keep.txt',
      ]) {
        await File('${root.path}/$name').writeAsString('x');
      }
      final s = service(MockClient((_) async => http.Response('', 200)));
      expect(await s.clearCachedInstallers(), 4);
      expect((await root.list().toList()).single.path, endsWith('keep.txt'));
    },
  );
  test('disk path failure never launches installer', () async {
    final blocked = File('${root.path}/blocked');
    await blocked.writeAsString('x');
    final s = GithubAppUpdateService(
      client: MockClient((_) async => http.Response.bytes(payload, 200)),
      isAndroid: true,
      cacheDirectory: () async => Directory(blocked.path),
      installerOpener: (_) async {
        opened++;
      },
    );
    await expectLater(
      s.downloadAndInstall(release()),
      throwsA(isA<AppUpdateException>()),
    );
    expect(opened, 0);
  });
}
