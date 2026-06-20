import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Windows build suppresses deprecated experimental coroutine failure',
    () {
      final cmake = File('windows/CMakeLists.txt').readAsStringSync();

      expect(
        cmake,
        contains('_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS'),
      );
    },
  );
}
