import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:next_ddl/app/smooth_scroll.dart';

void main() {
  testWidgets('Windows pointer scrolling animates toward its target', (
    tester,
  ) async {
    final controller = SmoothScrollController(
      duration: const Duration(milliseconds: 180),
      smoothWheel: true,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 160,
          child: SmoothListViewBuilder(
            controller: controller,
            itemCount: 50,
            itemBuilder: (_, index) => SizedBox(
              height: 40,
              child: Text('Item $index'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    controller.position.pointerScroll(160);
    expect(controller.offset, lessThan(160));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 89));
    expect(controller.offset, greaterThan(0));
    await tester.pumpAndSettle();
    expect(controller.offset, 160);
  });
}
