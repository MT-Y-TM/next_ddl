import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_ddl/l10n/app_localizations.dart';

import '../features/tasks/task_detail_page.dart';
import '../features/tasks/task_list_page.dart';
import '../features/tasks/tasks_controller.dart';
import '../features/tasks/task_planning_provider.dart';
import '../features/update/update_reliability_panel.dart';
import '../features/update/app_update_controller.dart';
import '../features/update/app_update_state.dart';
import '../models/update_release.dart';
import '../models/app_snapshot.dart';
import '../services/home_widget_service.dart';
import '../services/timezone_service.dart';
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
  final _homeWidget = HomeWidgetService();
  ProviderSubscription<AsyncValue<AppSnapshot>>? _widgetSubscription;
  ProviderSubscription<int>? _widgetTimezoneSubscription;
  bool _refreshingPlans = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _widgetSubscription = ref.listenManual(tasksControllerProvider, (_, next) {
      final snapshot = next.valueOrNull;
      if (snapshot != null) _syncWidget(snapshot);
    });
    _widgetTimezoneSubscription = ref.listenManual(timezoneRevisionProvider, (_, _) {
      final snapshot = ref.read(tasksControllerProvider).valueOrNull;
      if (snapshot != null) _syncWidget(snapshot);
    });
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
      _initializeWidget();
      _refreshPlans();
    });
  }

  Future<void> _refreshPlans() async {
    if (_refreshingPlans) return;
    _refreshingPlans = true;
    try {
      await ref.read(tasksControllerProvider.future);
      if (!mounted) return;
      final service = ref.read(taskPlanningProvider);
      await service.reload();
      if (!mounted) return;
      await service.materialize();
    } catch (error) {
      debugPrint('Task planning refresh failed: ${error.runtimeType}');
    } finally {
      _refreshingPlans = false;
    }
  }

  Future<void> _syncWidget(AppSnapshot snapshot) async {
    try {
      await _homeWidget.sync(snapshot, timezoneId: ref.read(timezoneServiceProvider).currentTimezoneId);
    } catch (error) {
      debugPrint('Home widget sync failed: ${error.runtimeType}');
    }
  }

  Future<void> _initializeWidget() async {
    try {
      final snapshot = await ref.read(tasksControllerProvider.future);
      if (!mounted) return;
      await _syncWidget(snapshot);
      if (!mounted) return;
      await _homeWidget.listenForTaskTaps((id) {
        if (!mounted) return;
        final navigator = _navigatorKey.currentState;
        final exists = ref.read(tasksControllerProvider).valueOrNull?.tasks.any((task) => task.id == id) ?? false;
        if (navigator == null) return;
        if (exists) {
          navigator.push(MaterialPageRoute<void>(builder: (_) => TaskDetailPage(taskId: id)));
        } else {
          navigator.popUntil((route) => route.isFirst);
        }
      });
    } catch (error) {
      debugPrint('Home widget initialization failed: ${error.runtimeType}');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateSubscription?.close();
    _tapSubscription?.cancel();
    _widgetSubscription?.close();
    _widgetTimezoneSubscription?.close();
    _homeWidget.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(appUpdateControllerProvider.notifier).resumePendingInstallIfPossible();
      _refreshPlans();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localePreference = ref.watch(localePreferenceProvider);
    final themeSettings = ref.watch(themeSettingsProvider);
    return MaterialApp(
      navigatorKey: _navigatorKey,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildNextDdlTheme(settings: themeSettings),
      darkTheme: buildNextDdlTheme(
        brightness: Brightness.dark,
        settings: themeSettings,
      ),
      themeMode: ThemeMode.system,
      locale: resolvePreferredLocale(localePreference),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) =>
          NextDdlAppShell(child: child ?? const SizedBox.shrink()),
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
      barrierDismissible: false,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, child) {
          final state = ref.watch(appUpdateControllerProvider);
          final isDownloading = state.status == AppUpdateStatus.downloading;
          if (state.status == AppUpdateStatus.installReady &&
              !state.requiresInstallPermission) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.of(dialogContext).canPop()) {
                Navigator.of(dialogContext).pop();
              }
            });
          }
          return AlertDialog(
            title: Text(l10n.updateDialogTitle),
            content: SingleChildScrollView(child: Column(
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
                if (state.hasReusableLocalInstaller) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.updateUsingCachedInstaller(
                      state.localInstallerVersion ?? release.version,
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (isDownloading) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: state.downloadProgress),
                  const SizedBox(height: 8),
                  Text(
                    _downloadProgressText(l10n, state),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (state.status == AppUpdateStatus.error || state.requiresInstallPermission)
                  UpdateReliabilityPanel(
                    state: state,
                    onRetry: () => ref.read(appUpdateControllerProvider.notifier).downloadAndInstall(),
                    onOpenRelease: () => ref.read(appUpdateControllerProvider.notifier).openReleasePage(),
                  ),
              ],
            )),
            actions: [
              TextButton(
                onPressed: isDownloading
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.later),
              ),
              FilledButton(
                onPressed: isDownloading
                    ? null
                    : () {
                        if (Platform.isAndroid) {
                          ref
                              .read(appUpdateControllerProvider.notifier)
                              .downloadAndInstall();
                          return;
                        }
                        Navigator.of(dialogContext).pop();
                        ref
                            .read(appUpdateControllerProvider.notifier)
                            .openReleasePage();
                      },
                child: Text(
                  Platform.isAndroid ? l10n.updateNow : l10n.openReleasePage,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _downloadProgressText(AppLocalizations l10n, AppUpdateState state) {
    final percent = state.downloadPercent;
    final speed = state.downloadSpeedBytesPerSecond;
    final percentText =
        percent == null ? l10n.downloadProgressUnknown : l10n.downloadPercent(percent);
    final speedText = speed == null || speed <= 0
        ? l10n.downloadSpeedUnknown
        : l10n.downloadSpeed(_formatSpeed(speed));
    return '$percentText · $speedText';
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond >= 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
  }
}
