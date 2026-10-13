import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:next_ddl/app/feedback.dart';

void main() {
  test('all app feedback uses the shared three-second SnackBar factory', () {
    expect(
      appSnackBar(content: const Text('Saved')).duration,
      const Duration(seconds: 3),
    );
    expect(
      appSnackBar(
        content: const Text('Saved'),
        action: SnackBarAction(label: 'Undo', onPressed: () {}),
      ).duration,
      const Duration(seconds: 3),
    );
    final rawConstructor = RegExp(r'\bSnackBar\s*\(');
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) =>
              file.path.endsWith('.dart') &&
              !file.path.endsWith('feedback.dart'),
        )
        .where((file) => rawConstructor.hasMatch(file.readAsStringSync()));
    expect(offenders.map((file) => file.path).toList(), isEmpty);
  });

  testWidgets('action feedback dismisses after three seconds', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(appSnackBar(content: const Text('Saved'))),
              child: const Text('Save'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      const Duration(seconds: 3),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
  });
}
