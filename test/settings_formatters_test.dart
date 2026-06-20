import 'package:flutter_test/flutter_test.dart';
import 'package:next_ddl/features/settings/settings_formatters.dart';
import 'package:next_ddl/features/update/app_update_state.dart';
import 'package:next_ddl/l10n/app_localizations_en.dart';
import 'package:next_ddl/services/app_update_service.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('download progress text keeps existing percentage and speed format', () {
    const state = AppUpdateState(
      status: AppUpdateStatus.downloading,
      downloadPercent: 50,
      downloadSpeedBytesPerSecond: 1536,
    );

    expect(settingsDownloadProgressText(l10n, state), '50% · 1.5 KB/s');
  });

  test('update status text keeps service error mapping', () {
    const state = AppUpdateState(
      status: AppUpdateStatus.error,
      error: AppUpdateException(AppUpdateErrorType.serviceUnavailable),
    );

    expect(
      settingsUpdateStatusText(l10n, state),
      'The update service is temporarily unavailable. Please try again later.',
    );
  });
}
