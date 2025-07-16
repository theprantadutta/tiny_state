import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_state/tiny_state.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Reset the tinyState instance before each test to ensure isolation.
  setUp(() {
    tinyState.clear();
  });

  group('TinyState MVP Tests', () {
    test('watch() should initialize with a default value', () {
      final counter = tinyState.watch<int>('counter', 0);
      expect(counter.value, 0);
    });

    test('watch() should return the existing notifier if key exists', () {
      final counter1 = tinyState.watch<int>('counter', 0);
      final counter2 = tinyState.watch<int>(
        'counter',
        99,
      ); // Default value ignored

      expect(counter1, same(counter2));
      expect(counter2.value, 0);
    });

    test('get() should return the current value', () {
      tinyState.watch<int>('counter', 5);
      final value = tinyState.get<int>('counter');
      expect(value, 5);
    });

    test('get() should return null for a non-existent key', () {
      final value = tinyState.get<int>('non_existent_key');
      expect(value, isNull);
    });

    test('set() should update the value and notify listeners', () {
      final counter = tinyState.watch<int>('counter', 0);
      int? notifiedValue;

      counter.addListener(() {
        notifiedValue = counter.value;
      });

      tinyState.set<int>('counter', 10);
      expect(counter.value, 10);
      expect(notifiedValue, 10);
    });

    test('set() should not notify listeners if the value is the same', () {
      final counter = tinyState.watch<int>('counter', 5);
      bool wasNotified = false;

      counter.addListener(() {
        wasNotified = true;
      });

      tinyState.set<int>('counter', 5); // Set the same value
      expect(wasNotified, isFalse);
    });

    test('delete() should remove the key and dispose the notifier', () {
      final counter = tinyState.watch<int>('counter', 0);
      tinyState.delete('counter');

      // The key should no longer exist
      expect(tinyState.get<int>('counter'), isNull);

      // The notifier should be disposed, so listening throws an error
      expect(() => counter.addListener(() {}), throwsA(isA<Object>()));
    });
  });

  group('TinyState Selector Tests', () {
    setUp(() {
      tinyState.clear();
    });
    test('select() should return the transformed value', () {
      tinyState.watch<int>('counter', 5);
      final isEven = tinyState.select<int, bool>(
        'counter',
        (count) => count.isEven,
      );
      expect(isEven.value, isFalse);
    });

    test('select() should update when the source state changes', () {
      tinyState.watch<int>('counter', 5);
      final isEven = tinyState.select<int, bool>(
        'counter',
        (count) => count.isEven,
      );

      bool? notifiedValue;
      isEven.addListener(() {
        notifiedValue = isEven.value;
      });

      tinyState.set<int>('counter', 10);
      expect(isEven.value, isTrue);
      expect(notifiedValue, isTrue);
    });

    test('select() should not notify if the selected value is the same', () {
      tinyState.watch<int>('counter', 2);
      final isEven = tinyState.select<int, bool>(
        'counter',
        (count) => count.isEven,
      );
      expect(isEven.value, isTrue);

      bool wasNotified = false;
      isEven.addListener(() {
        wasNotified = true;
      });

      // Set to another even number, so the selected value shouldn't change
      tinyState.set<int>('counter', 4);
      expect(isEven.value, isTrue);
      expect(wasNotified, isFalse);
    });

    test('select() should throw an exception for a non-existent key', () {
      expect(
        () => tinyState.select<int, bool>('non_existent', (val) => val.isEven),
        throwsA(isA<Exception>()),
      );
    });

    test('deleting the source key should dispose the selector notifier', () {
      tinyState.watch<int>('counter', 0);
      final isEven = tinyState.select<int, bool>(
        'counter',
        (count) => count.isEven,
      );
      tinyState.delete('counter');

      // The notifier should be disposed, so listening throws an error
      expect(() => isEven.addListener(() {}), throwsA(isA<Object>()));
    });
  });

  group('TinyState Computed Tests', () {
    setUp(() {
      tinyState.clear();
    });
    test('computed() should return the correct initial value', () {
      tinyState.watch<int>('a', 10);
      tinyState.watch<int>('b', 20);
      final sum = tinyState.computed<int>('sum', () {
        return (tinyState.get<int>('a') ?? 0) + (tinyState.get<int>('b') ?? 0);
      });
      expect(sum.value, 30);
    });

    test('computed() should update when a dependency changes', () {
      tinyState.watch<int>('a', 10);
      tinyState.watch<int>('b', 20);
      final sum = tinyState.computed<int>('sum', () {
        return (tinyState.get<int>('a') ?? 0) + (tinyState.get<int>('b') ?? 0);
      });

      int? notifiedValue;
      sum.addListener(() {
        notifiedValue = sum.value;
      });

      tinyState.set<int>('a', 15);
      expect(sum.value, 35);
      expect(notifiedValue, 35);
    });

    test('computed() should not update if the value is the same', () {
      tinyState.watch<int>('a', 10);
      final a = tinyState.computed<int>('a_doubled', () {
        return (tinyState.get<int>('a') ?? 0) * 2;
      });

      bool wasNotified = false;
      a.addListener(() {
        wasNotified = true;
      });

      tinyState.set<int>('a', 10);
      expect(wasNotified, isFalse);
    });

    test('deleting a dependency should be handled', () {
      tinyState.watch<int>('a', 10);
      tinyState.watch<int>('b', 20);
      final sum = tinyState.computed<int>('sum', () {
        return (tinyState.get<int>('a') ?? 0) + (tinyState.get<int>('b') ?? 0);
      });

      tinyState.delete('a');
      // The computed value should re-evaluate, now using the default 0 for 'a'.
      expect(sum.value, 20);
    });
  });

  group('TinyState Listener Tests', () {
    setUp(() {
      tinyState.clear();
    });
    test('listen() should be called when the state changes', () {
      tinyState.watch<int>('counter', 0);
      int? receivedValue;
      tinyState.listen<int>('counter', (value) {
        receivedValue = value;
      });
      tinyState.set<int>('counter', 5);
      expect(receivedValue, 5);
    });

    test('listen() with fireImmediately should be called instantly', () {
      tinyState.watch<int>('counter', 10);
      int? receivedValue;
      tinyState.listen<int>('counter', (value) {
        receivedValue = value;
      }, fireImmediately: true);
      expect(receivedValue, 10);
    });

    test('listen() with once should only be called once', () {
      tinyState.watch<int>('counter', 0);
      int callCount = 0;
      tinyState.listen<int>('counter', (value) {
        callCount++;
      }, once: true);
      tinyState.set<int>('counter', 1);
      tinyState.set<int>('counter', 2);
      expect(callCount, 1);
    });

    test('cancelling a listener should stop it from being called', () {
      tinyState.watch<int>('counter', 0);
      int? receivedValue;
      final cancel = tinyState.listen<int>('counter', (value) {
        receivedValue = value;
      });

      cancel();
      tinyState.set<int>('counter', 5);
      expect(receivedValue, isNull);
    });
  });

  group('TinyState Scoped State Tests', () {
    setUp(() {
      tinyState.clear();
    });
    test('scoped states should be isolated', () {
      final scopeA = tinyState.scope('scopeA');
      final scopeB = tinyState.scope('scopeB');

      scopeA.watch<int>('counter', 1);
      scopeB.watch<int>('counter', 2);

      expect(scopeA.get<int>('counter'), 1);
      expect(scopeB.get<int>('counter'), 2);
    });

    test('setting a scoped state should not affect other scopes', () {
      final scopeA = tinyState.scope('scopeA');
      final scopeB = tinyState.scope('scopeB');

      scopeA.watch<int>('counter', 1);
      scopeB.watch<int>('counter', 2);

      scopeA.set<int>('counter', 10);

      expect(scopeA.get<int>('counter'), 10);
      expect(scopeB.get<int>('counter'), 2);
    });

    test('deleting a scoped state should not affect other scopes', () {
      final scopeA = tinyState.scope('scopeA');
      final scopeB = tinyState.scope('scopeB');

      scopeA.watch<int>('counter', 1);
      scopeB.watch<int>('counter', 2);

      scopeA.delete('counter');

      expect(scopeA.get<int>('counter'), isNull);
      expect(scopeB.get<int>('counter'), 2);
    });

    test('global state should not conflict with scoped state', () {
      final profileScope = tinyState.scope('profile');

      tinyState.watch<String>('name', 'Global');
      profileScope.watch<String>('name', 'Profile');

      expect(tinyState.get<String>('name'), 'Global');
      expect(profileScope.get<String>('name'), 'Profile');
    });
  });

  group('TinyState Clear/Reset Tests', () {
    setUp(() {
      tinyState.clear();
    });
    test('clear() should remove all states', () {
      tinyState.watch<int>('a', 1);
      tinyState.watch<String>('b', 'test');
      tinyState.clear();
      expect(tinyState.get<int>('a'), isNull);
      expect(tinyState.get<String>('b'), isNull);
    });

    test('scoped clear() should only clear states within that scope', () {
      final scopeA = tinyState.scope('scopeA');
      final scopeB = tinyState.scope('scopeB');

      scopeA.watch<int>('val', 1);
      scopeB.watch<int>('val', 2);
      tinyState.watch<int>('global', 3);

      scopeA.clear();

      expect(scopeA.get<int>('val'), isNull);
      expect(scopeB.get<int>('val'), 2);
      expect(tinyState.get<int>('global'), 3);
    });
  });

  group('TinyState Async Tests', () {
    setUp(() {
      tinyState.clear();
    });
    test('watchFuture should correctly handle a successful future', () async {
      final future = Future.delayed(
        const Duration(milliseconds: 10),
        () => 'Success',
      );
      final snapshot = tinyState.watchFuture<String>('myFuture', () => future);

      expect(snapshot.value.connectionState, ConnectionState.waiting);

      await Future.delayed(const Duration(milliseconds: 20));

      expect(snapshot.value.connectionState, ConnectionState.done);
      expect(snapshot.value.hasData, isTrue);
      expect(snapshot.value.data, 'Success');
      expect(snapshot.value.hasError, isFalse);
    });

    test(
      'watchFuture should correctly handle a future with an error',
      () async {
        final future = Future<String>.delayed(
          const Duration(milliseconds: 10),
          () => throw Exception('Failure'),
        );
        final snapshot = tinyState.watchFuture<String>(
          'myFuture',
          () => future,
        );

        expect(snapshot.value.connectionState, ConnectionState.waiting);

        await Future.delayed(const Duration(milliseconds: 20));

        expect(snapshot.value.connectionState, ConnectionState.done);
        expect(snapshot.value.hasData, isFalse);
        expect(snapshot.value.hasError, isTrue);
        expect(snapshot.value.error, isA<Exception>());
      },
    );
  });

  group('TinyState Persistence Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      tinyState.persistenceAdapter = SharedPreferencesAdapter(prefs);
    });

    test('persisted state should be saved and loaded', () async {
      tinyState.watch<int>('counter', 0, persist: true);
      tinyState.set<int>('counter', 10, persist: true);

      // Create a new instance to simulate an app restart
      final newTinyState = TinyState.instance;
      final prefs = await SharedPreferences.getInstance();
      newTinyState.persistenceAdapter = SharedPreferencesAdapter(prefs);

      final counter = newTinyState.watch<int>('counter', 0, persist: true);
      expect(counter.value, 10);
    });
  });
}
