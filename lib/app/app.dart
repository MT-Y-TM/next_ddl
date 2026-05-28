import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_ddl/l10n/app_localizations.dart';

import '../features/tasks/task_detail_page.dart';
import '../features/tasks/task_list_page.dart';
import '../features/tasks/tasks_controller.dart';
import '../features/update/app_update_controller.dart';
import '../features/update/app_update_state.dart';
import '../models/update_release.dart';
import '../services/local_notification_scheduler.dart';
import '../utils/locale_utils.dart';
import 'theme.dart';

class NextDdlApp extends ConsumerStatefulWidget {
  const NextDdlApp({super.key});

  @override
  ConsumerState<NextDdlApp> createState() => _NextDdlAppState();
}

class _NextDdlAppState extends ConsumerState<NextDdlApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<String>? _tapSubscription;
  ProviderSubscription<AppUpdateState>? _updateSubscription;
  String? _shownReleaseTag;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tapSubscription = LocalNotificationScheduler.notificationTapStream.listen((
      taskId,
    ) {
      final navigator = _navigatorKey.currentState;
      if (navigator == null) {
        return;
      }
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => TaskDetailPage(taskId: taskId)),
      );
    });
    _updateSubscription = ref.listenManual<AppUpdateState>(
      appUpdateControllerProvider,
      (previous, next) {
        if (next.status != AppUpdateStatus.updateAvailable ||
            next.release == null ||
            next.userInitiated ||
            _shownReleaseTag == next.release!.tagName) {
          return;
        }
        _shownReleaseTag = next.release!.tagName;
        _showUpdateDialog(next.release!);
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appUpdateControllerProvider.notifier).checkForUpdate();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateSubscription?.close();
    _tapSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(appUpdateControllerProvider.notifier).resumePendingInstallIfPossible();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localePreference = ref.watch(localePreferenceProvider);
    return MaterialApp(
      navigatorKey: _navigatorKey,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildNextDdlTheme(),
      darkTheme: buildNextDdlTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      locale: resolvePreferredLocale(localePreference),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const TaskListPage(),
    );
  }

  Future<void> _showUpdateDialog(UpdateRelease release) async {
    final navigator = _navigatorKey.currentState;
    final context = navigator?.context;
    if (context == null || !mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.updateDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.updateDialogMessage(release.version)),
            const SizedBox(height: 8),
            Text(
              l10n.publishedAtLabel(
                '${release.publishedAtUtc.toLocal().year}-${release.publishedAtUtc.toLocal().month.toString().padLeft(2, '0')}-${release.publishedAtUtc.toLocal().day.toString().padLeft(2, '0')}',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              release.body.isEmpty ? l10n.noReleaseNotes : release.body,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.later),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (Platform.isAndroid) {
                ref.read(appUpdateControllerProvider.notifier).downloadAndInstall();
                return;
              }
              ref.read(appUpdateControllerProvider.notifier).openReleasePage();
            },
            child: Text(
              Platform.isAndroid ? l10n.updateNow : l10n.openReleasePage,
            ),
          ),
        ],
      ),
    );
  }
}
