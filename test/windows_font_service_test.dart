import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:next_ddl/services/windows_font_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('normalizes and sorts the Windows font list', () async {
    const channel = MethodChannel('test/next_ddl/fonts');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'listFontFamilies');
      return ['Segoe UI', 'Arial', ' ', 'Segoe UI'];
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final fonts = await WindowsFontService(
      channel: channel,
      enabled: true,
    ).listFontFamilies();

    expect(fonts, ['Arial', 'Segoe UI']);
  });

  test('does not call the platform on non-Windows targets', () async {
    final fonts = await WindowsFontService(enabled: false).listFontFamilies();
    expect(fonts, isEmpty);
  });
}
