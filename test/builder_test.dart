import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_state/tiny_state.dart';

Widget _wrap(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

void main() {
  setUp(tinyState.clear);

  testWidgets('renders the current value and rebuilds on change', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TinyBuilder<int>(
          'counter',
          0,
          (BuildContext context, int value) => Text('$value'),
        ),
      ),
    );
    expect(find.text('0'), findsOneWidget);

    tinyState.set<int>('counter', 1);
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('creates the key with the given default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TinyBuilder<String>(
          'name',
          'Jane',
          (BuildContext context, String value) => Text(value),
        ),
      ),
    );

    expect(find.text('Jane'), findsOneWidget);
    expect(tinyState.get<String>('name'), 'Jane');
  });

  testWidgets('reads from a scope when one is given', (
    WidgetTester tester,
  ) async {
    final cart = tinyState.scope('cart');
    tinyState.watch<int>('items', 99);

    await tester.pumpWidget(
      _wrap(
        TinyBuilder<int>(
          'items',
          1,
          (BuildContext context, int value) => Text('$value'),
          scope: cart,
        ),
      ),
    );

    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('TinyBuilder.listen follows a computed', (
    WidgetTester tester,
  ) async {
    tinyState.watch<int>('x', 1);
    final doubled = tinyState.computed<int>(
      'doubled',
      () => tinyState.get<int>('x')! * 2,
    );

    await tester.pumpWidget(
      _wrap(
        TinyBuilder<int>.listen(
          doubled,
          (BuildContext context, int value) => Text('$value'),
        ),
      ),
    );
    expect(find.text('2'), findsOneWidget);

    tinyState.set<int>('x', 5);
    await tester.pump();

    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('TinyBuilder.listen follows a selector', (
    WidgetTester tester,
  ) async {
    tinyState.watch<int>('counter', 0);
    final isEven = tinyState.select<int, bool>(
      'counter',
      (value) => value.isEven,
      id: 'isEven',
    );

    await tester.pumpWidget(
      _wrap(
        TinyBuilder<bool>.listen(
          isEven,
          (BuildContext context, bool value) => Text(value ? 'even' : 'odd'),
        ),
      ),
    );
    expect(find.text('even'), findsOneWidget);

    tinyState.set<int>('counter', 1);
    await tester.pump();

    expect(find.text('odd'), findsOneWidget);
  });

  testWidgets('rebuilding the widget does not accumulate subscriptions', (
    WidgetTester tester,
  ) async {
    tinyState.watch<int>('counter', 0);
    var selectorCalls = 0;

    Widget build() => _wrap(
      Builder(
        builder: (BuildContext context) {
          final isEven = tinyState.select<int, bool>('counter', (int value) {
            selectorCalls++;
            return value.isEven;
          }, id: 'isEven');
          return TinyBuilder<bool>.listen(
            isEven,
            (BuildContext context, bool value) => Text('$value'),
          );
        },
      ),
    );

    for (var i = 0; i < 10; i++) {
      await tester.pumpWidget(build());
      // Force a genuinely new element tree each time.
      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
    }
    selectorCalls = 0;

    tinyState.set<int>('counter', 1);

    expect(selectorCalls, 1);
  });
}
