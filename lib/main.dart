import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'services/app_info_service.dart';
import 'services/bootstrap_service.dart';
import 'services/deadline_repository.dart';
import 'services/file_export_service.dart';
import 'services/local_notification_scheduler.dart';
import 'services/notification_scheduler.dart';
import 'services/shared_prefs_deadline_repository.dart';
import 'services/timezone_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final timezoneService = DeviceTimezoneService();
  await timezoneService.initialize();

  final fileExportService = PlatformFileExportService();
  final repository = SharedPrefsDeadlineRepository(
    fileExportService: fileExportService,
  );
  final notificationScheduler = LocalNotificationScheduler(
    timezoneService: timezoneService,
  );

  await notificationScheduler.initialize();
  await BootstrapService.configureDesktopWindow();

  runApp(
    ProviderScope(
      overrides: [
        deadlineRepositoryProvider.overrideWithValue(repository),
        notificationSchedulerProvider.overrideWithValue(notificationScheduler),
        timezoneServiceProvider.overrideWithValue(timezoneService),
        fileExportServiceProvider.overrideWithValue(fileExportService),
        appInfoServiceProvider.overrideWithValue(PackageInfoAppInfoService()),
      ],
      child: const NextDdlApp(),
    ),
  );
}
