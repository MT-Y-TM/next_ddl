import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class BootstrapService {
  static Future<void> configureDesktopWindow() async {
    if (!Platform.isWindows) {
      return;
    }
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1320, 860),
      minimumSize: Size(980, 720),
      title: 'Next DDL',
      center: true,
      backgroundColor: Colors.transparent,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
}
