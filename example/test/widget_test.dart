import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_state/tiny_state.dart';

import 'package:example/src/screens/basics_screen.dart';

void main() {
  setUp(tinyState.clear);

  testWidgets('the basics screen counts up and down', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BasicsScreen())),
    );

    expect(find.text('0'), findsOneWidget);
    expect(find.text('Even'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('Odd'), findsOneWidget);

    await tester.tap(find.text('Reset counter'));
    await tester.pump();

    expect(find.text('0'), findsOneWidget);
  });
}
