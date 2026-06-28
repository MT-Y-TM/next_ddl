import 'package:flutter/material.dart';
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

  testWidgets('app shell keeps background layer stable while child changes', (
    tester,
  ) async {
    var initCount = 0;
    var buildCount = 0;
    final background = _ProbeBackground(
      onInit: () => initCount++,
      onBuild: () => buildCount++,
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: NextDdlAppShell(
          background: background,
          child: const Text('first page'),
        ),
      ),
    );

    expect(initCount, 1);
    expect(buildCount, 1);
    expect(find.text('first page'), findsOneWidget);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: NextDdlAppShell(
          background: background,
          child: const Text('second page'),
        ),
      ),
    );

    expect(initCount, 1);
    expect(buildCount, 1);
    expect(find.text('first page'), findsNothing);
    expect(find.text('second page'), findsOneWidget);
  });
}

class _ProbeBackground extends StatefulWidget {
  const _ProbeBackground({required this.onInit, required this.onBuild});

  final VoidCallback onInit;
  final VoidCallback onBuild;

  @override
  State<_ProbeBackground> createState() => _ProbeBackgroundState();
}

class _ProbeBackgroundState extends State<_ProbeBackground> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    return const SizedBox.expand();
  }
}
