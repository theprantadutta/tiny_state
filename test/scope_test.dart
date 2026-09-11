import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_state/tiny_state.dart';

void main() {
  setUp(tinyState.clear);

  test('scopes are isolated from each other', () {
    final a = tinyState.scope('a');
    final b = tinyState.scope('b');
    a.watch<int>('counter', 1);
    b.watch<int>('counter', 2);

    a.set<int>('counter', 10);

    expect(a.get<int>('counter'), 10);
    expect(b.get<int>('counter'), 2);
  });

  test('a scoped key cannot collide with a global one', () {
    tinyState.scope('a').watch<int>('b', 1);

    // The only way to produce the key 'a/b' is through the scope, because a
    // literal 'a/b' is rejected outright.
    expect(() => tinyState.watch<int>('a/b', 99), throwsArgumentError);
    expect(tinyState.scope('a').get<int>('b'), 1);
  });

  test('deleting in one scope leaves the other alone', () {
    final a = tinyState.scope('a');
    final b = tinyState.scope('b');
    a.watch<int>('counter', 1);
    b.watch<int>('counter', 2);

    a.delete('counter');

    expect(a.get<int>('counter'), isNull);
    expect(b.get<int>('counter'), 2);
  });

  test('clear only wipes its own scope', () {
    final cart = tinyState.scope('cart');
    final user = tinyState.scope('user');
    cart.watch<int>('items', 3);
    user.watch<String>('name', 'Jane');
    tinyState.watch<int>('global', 7);

    cart.clear();

    expect(cart.get<int>('items'), isNull);
    expect(user.get<String>('name'), 'Jane');
    expect(tinyState.get<int>('global'), 7);
  });

  test('clear also removes scoped computeds and futures', () async {
    final cart = tinyState.scope('cart');
    cart.watch<int>('items', 2);
    cart.computed<int>('doubled', () => cart.get<int>('items')! * 2);
    cart.watchFuture<int>('total', () async => 99);

    cart.clear();

    expect(cart.get<int>('doubled'), isNull);
    // A fresh watchFuture re-runs rather than returning the cached snapshot.
    final snapshot = cart.watchFuture<int>('total', () async => 1);
    expect(snapshot.value.connectionState, ConnectionState.waiting);
  });

  test('scoped computeds track scoped dependencies', () {
    final cart = tinyState.scope('cart');
    cart.watch<int>('items', 1);
    final doubled = cart.computed<int>(
      'doubled',
      () => cart.get<int>('items')! * 2,
    );

    cart.set<int>('items', 5);

    expect(doubled.value, 10);
  });

  test('scoped select is memoized per scope', () {
    final a = tinyState.scope('a');
    final b = tinyState.scope('b');
    a.watch<int>('n', 1);
    b.watch<int>('n', 2);

    final fromA = a.select<int, String>('n', (value) => '$value', id: 'text');
    final fromB = b.select<int, String>('n', (value) => '$value', id: 'text');

    expect(fromA.value, '1');
    expect(fromB.value, '2');
    expect(
      a.select<int, String>('n', (value) => '$value', id: 'text'),
      same(fromA),
    );
  });

  test('rejects an empty or separator-bearing scope name', () {
    expect(() => tinyState.scope(''), throwsArgumentError);
    expect(() => tinyState.scope('a/b'), throwsArgumentError);
  });

  test('rejects the reserved internal scope name', () {
    expect(() => tinyState.scope('future'), throwsArgumentError);
  });

  test('a scoped key is still validated', () {
    final cart = tinyState.scope('cart');

    expect(() => cart.watch<int>('a/b', 0), throwsArgumentError);
  });
}
