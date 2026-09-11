import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_state/tiny_state.dart';

void main() {
  setUp(tinyState.clear);

  tearDown(() {
    tinyState.persistenceAdapter = null;
    tinyState.onError = null;
    tinyState.strictTypes = true;
  });

  group('clear', () {
    test('removes every state, computed, selector and future', () async {
      tinyState.watch<int>('counter', 1);
      tinyState.computed<int>('doubled', () => tinyState.get<int>('counter')!);
      tinyState.select<int, bool>(
        'counter',
        (value) => value.isEven,
        id: 'isEven',
      );
      tinyState.watchFuture<int>('n', () async => 1);

      tinyState.clear();

      expect(tinyState.get<int>('counter'), isNull);
      expect(tinyState.get<int>('doubled'), isNull);
    });

    test('does not throw when a computed cannot survive its dependency going '
        'away', () {
      tinyState.watch<int>('x', 1);
      // A null-check in the builder is exactly what blew up in 1.1.0.
      final doubled = tinyState.computed<int>(
        'doubled',
        () => tinyState.get<int>('x')! * 2,
      );
      doubled.addListener(() {});

      expect(tinyState.clear, returnsNormally);
    });

    test('keeps configuration, so a test setUp does not lose the adapter', () {
      final adapter = MemoryPersistenceAdapter();
      tinyState
        ..persistenceAdapter = adapter
        ..strictTypes = false;

      tinyState.clear();

      expect(tinyState.persistenceAdapter, same(adapter));
      expect(tinyState.strictTypes, isFalse);
    });

    test('the instance is reusable afterwards', () {
      tinyState.watch<int>('counter', 1);
      tinyState.clear();

      final revived = tinyState.watch<int>('counter', 5);

      expect(revived.value, 5);
    });
  });

  group('dispose', () {
    test('clears state and resets configuration', () {
      tinyState
        ..persistenceAdapter = MemoryPersistenceAdapter()
        ..strictTypes = false
        ..onError = (Object error, StackTrace stack, String context) {};
      tinyState.watch<int>('counter', 1);

      tinyState.dispose();

      expect(tinyState.get<int>('counter'), isNull);
      expect(tinyState.persistenceAdapter, isNull);
      expect(tinyState.strictTypes, isTrue);
      expect(tinyState.onError, isNull);
    });

    test('the instance is reusable afterwards', () {
      tinyState.dispose();

      expect(tinyState.watch<int>('counter', 2).value, 2);
    });
  });

  group('references held across a teardown', () {
    test('a notifier from before clear() is disposed', () {
      final counter = tinyState.watch<int>('counter', 0);

      tinyState.clear();

      expect(() => counter.addListener(() {}), throwsFlutterError);
    });

    test('a computed from before clear() is disposed', () {
      tinyState.watch<int>('x', 1);
      final doubled = tinyState.computed<int>(
        'doubled',
        () => tinyState.get<int>('x')! * 2,
      );

      tinyState.clear();

      expect(() => doubled.addListener(() {}), throwsFlutterError);
    });
  });
}
