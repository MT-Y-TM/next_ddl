import 'dart:io';

import 'package:flutter/services.dart';

class WindowsFontService {
  WindowsFontService({MethodChannel? channel, bool? enabled})
    : _channel = channel ?? const MethodChannel('next_ddl/fonts'),
      _enabled = enabled ?? Platform.isWindows;

  final MethodChannel _channel;
  final bool _enabled;
  Future<List<String>>? _fonts;

  Future<List<String>> listFontFamilies() {
    if (!_enabled) return Future.value(const []);
    return _fonts ??= _loadFonts();
  }

  Future<List<String>> _loadFonts() async {
    try {
      final values = await _channel.invokeListMethod<String>('listFontFamilies');
      final names = {
        for (final value in values ?? const <String>[])
          if (value.trim().isNotEmpty) value.trim(),
      };
      final result = names.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return List.unmodifiable(result);
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }
}
