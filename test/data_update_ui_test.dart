import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:next_ddl/features/backup/backup_localizations.dart';
import 'package:next_ddl/features/backup/backup_page.dart';
import 'package:next_ddl/features/update/app_update_controller.dart';
import 'package:next_ddl/features/update/app_update_state.dart';
import 'package:next_ddl/features/update/update_reliability_panel.dart';
import 'package:next_ddl/models/app_snapshot.dart';
import 'package:next_ddl/models/update_release.dart';
import 'package:next_ddl/services/app_info_service.dart';
import 'package:next_ddl/services/app_update_service.dart';
import 'package:next_ddl/services/backup_service.dart';
import 'package:next_ddl/services/deadline_repository.dart';

class MemoryRepository extends DeadlineRepository {
  @override
  Future<AppSnapshot> loadSnapshot() async => AppSnapshot.empty();
  @override
  Future<void> saveSnapshot(AppSnapshot snapshot) async {}
  @override
  Future<AppSnapshot?> importSnapshot() async => null;
  @override
  Future<String?> exportSnapshot(AppSnapshot snapshot) async => null;
}

class FakeBackupService extends BackupService {
  FakeBackupService() : super(repository: MemoryRepository());
  int replacements = 0;
  @override
  Future<List<BackupEntry>> listBackups() async => [
    BackupEntry(file: File('unused.json'), createdAtUtc: DateTime.utc(2026)),
  ];
  @override
  Future<AppSnapshot> readBackup(BackupEntry entry) async =>
      AppSnapshot.empty();
  @override
  Future<void> replaceWithBackup(AppSnapshot snapshot) async {
    replacements++;
  }
}

final oldRelease = UpdateRelease(
  tagName: 'v2.0.0',
  version: '2.0.0',
  publishedAtUtc: DateTime.utc(2026),
  body: '',
  htmlUrl: 'https://example.test',
  assets: const [
    UpdateAsset(
      name: 'app-release.apk',
      browserDownloadUrl: 'https://example.test/app.apk',
      contentType: '',
      size: 3,
    ),
  ],
);

class FakeInfo extends AppInfoService {
  @override
  Future<String> getVersionLabel() async => '1.0.0';
}

class FakeUpdateService extends AppUpdateService {
  final gate = Completer<AppUpdateInstallResult>();
  void Function(DownloadProgress)? progress;
  int downloads = 0;
  @override
  Future<UpdateRelease?> checkForUpdate({
    required String currentVersion,
  }) async => oldRelease;
  @override
  Future<CachedUpdateInstaller?> findReusableInstaller({
    required UpdateRelease release,
    required String currentVersion,
  }) async => null;
  @override
  Future<AppUpdateInstallResult> downloadAndInstall(
    UpdateRelease release, {
    void Function(DownloadProgress)? onProgress,
  }) {
    downloads++;
    progress = onProgress;
    return gate.future;
  }

  @override
  Future<void> openReleasePage(UpdateRelease release) async {}
  @override
  Future<bool> resumePendingInstall(String filePath) async => false;
  @override
  Future<void> openInstallPermissionSettings() async {}
  @override
  Future<int> clearCachedInstallers() async => 0;
}

Widget app(String language, Widget home) => MaterialApp(
  locale: Locale(language),
  supportedLocales: const [Locale('zh'), Locale('en'), Locale('ja')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: home,
);

void main() {
  for (final language in ['zh', 'en', 'ja']) {
    testWidgets('$language confirmation and cancel keep existing data', (
      tester,
    ) async {
      final service = FakeBackupService(), l = BackupLocalizations(language);
      await tester.pumpWidget(
        app(language, BackupPage(service: service, onRestored: (_) async {})),
      );
      await tester.pumpAndSettle();
      expect(find.text(l.title), findsOneWidget);
      expect(find.text(l.retention(5)), findsOneWidget);
      await tester.tap(find.text(l.restore));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text(l.replacement(0)), findsOneWidget);
      await tester.tap(find.text(l.cancel));
      await tester.pumpAndSettle();
      expect(service.replacements, 0);
    });
    testWidgets('$language missing checksum explanation and release fallback', (
      tester,
    ) async {
      final l = UpdateReliabilityLocalizations(language);
      var opened = 0;
      await tester.pumpWidget(
        app(
          language,
          Scaffold(
            body: UpdateReliabilityPanel(
              state: AppUpdateState(
                status: AppUpdateStatus.updateAvailable,
                release: oldRelease,
              ),
              onRetry: () {},
              onOpenRelease: () {
                opened++;
              },
            ),
          ),
        ),
      );
      expect(
        find.text(l.failure(UpdateFailureReason.missingChecksum)),
        findsOneWidget,
      );
      expect(find.text(l.retry), findsNothing);
      await tester.tap(find.text(l.releasePage));
      expect(opened, 1);
    });
  }
  testWidgets('post-save scheduling failure retries synchronization only', (
    tester,
  ) async {
    final service = FakeBackupService(), l = BackupLocalizations('en');
    var syncs = 0;
    await tester.pumpWidget(
      app(
        'en',
        BackupPage(
          service: service,
          onRestored: (_) async {
            syncs++;
            if (syncs == 1) throw StateError('private platform detail');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.restore));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.widgetWithText(FilledButton, l.confirm));
    await tester.pumpAndSettle();
    expect(service.replacements, 1);
    expect(find.text(l.scheduleFailed), findsOneWidget);
    expect(find.textContaining('private platform detail'), findsNothing);
    await tester.tap(find.text(l.retry));
    await tester.pumpAndSettle();
    expect(service.replacements, 1);
    expect(syncs, 2);
    expect(find.text(l.scheduleFailed), findsNothing);
  });
  test(
    'controller ignores repeated clicks and unknown progress clears stale percent',
    () async {
      final service = FakeUpdateService();
      final container = ProviderContainer(
        overrides: [
          appUpdateServiceProvider.overrideWithValue(service),
          appInfoServiceProvider.overrideWithValue(FakeInfo()),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(appUpdateControllerProvider.notifier);
      await controller.checkForUpdate();
      final first = controller.downloadAndInstall();
      await controller.downloadAndInstall();
      expect(service.downloads, 1);
      service.progress!(
        const DownloadProgress(
          receivedBytes: 3,
          totalBytes: 10,
          speedBytesPerSecond: 1,
        ),
      );
      expect(container.read(appUpdateControllerProvider).downloadPercent, 30);
      service.progress!(
        const DownloadProgress(receivedBytes: 5, speedBytesPerSecond: 1),
      );
      expect(
        container.read(appUpdateControllerProvider).downloadPercent,
        isNull,
      );
      expect(
        container.read(appUpdateControllerProvider).downloadProgress,
        isNull,
      );
      service.gate.complete(
        const AppUpdateInstallResult(
          status: AppUpdateInstallStatus.permissionRequired,
          filePath: '/verified.apk',
        ),
      );
      await first;
      expect(
        container.read(appUpdateControllerProvider).requiresInstallPermission,
        true,
      );
    },
  );
}
