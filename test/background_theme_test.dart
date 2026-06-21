import 'package:flutter_test/flutter_test.dart';
import 'package:next_ddl/app/theme.dart';

void main() {
  test(
    'background image provider cache reuses providers for the same path',
    () {
      final cache = BackgroundImageProviderCache();

      final first = cache.providerFor('C:/next_ddl/backgrounds/bg.png');
      final second = cache.providerFor('C:/next_ddl/backgrounds/bg.png');
      final third = cache.providerFor('C:/next_ddl/backgrounds/other.png');

      expect(identical(second, first), isTrue);
      expect(identical(third, first), isFalse);
    },
  );
}
