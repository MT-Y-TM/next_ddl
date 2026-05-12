import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/tasks/task_detail_page.dart';
import '../features/tasks/task_list_page.dart';
import '../services/local_notification_scheduler.dart';
import 'theme.dart';

class NextDdlApp extends ConsumerStatefulWidget {
  const NextDdlApp({super.key});

  @override
  ConsumerState<NextDdlApp> createState() => _NextDdlAppState();
}

class _NextDdlAppState extends ConsumerState<NextDdlApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<String>? _tapSubscription;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _tapSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Next DDL',
      debugShowCheckedModeBanner: false,
      theme: buildNextDdlTheme(),
      darkTheme: buildNextDdlTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      home: const TaskListPage(),
    );
  }
}
