import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_state/tiny_state.dart';

void main() {
  setUp(tinyState.clear);

  group('watch', () {
    test('initializes with the default value', () {
      expect(tinyState.watch<int>('counter', 0).value, 0);
    });

    test('returns the same notifier and ignores later defaults', () {
      final first = tinyState.watch<int>('counter', 0);
      final second = tinyState.watch<int>('counter', 99);

      expect(second, same(first));
      expect(second.value, 0);
    });

    test('rejects an empty key', () {
      expect(() => tinyState.watch<int>('', 0), throwsArgumentError);
    });

    test('rejects a key containing the scope separator', () {
      expect(() => tinyState.watch<int>('user/name', 0), throwsArgumentError);
    });

    test('refuses a key already taken by a computed', () {
      tinyState.computed<int>('derived', () => 1);

      expect(() => tinyState.watch<int>('derived', 0), throwsStateError);
    });
  });

  group('get', () {
    test('returns the current value', () {
      tinyState.watch<int>('counter', 5);

      expect(tinyState.get<int>('counter'), 5);
    });

    test('returns null for an unknown key', () {
      expect(tinyState.get<int>('nope'), isNull);
    });

    test('reads computed state too', () {
      tinyState.watch<int>('x', 3);
      tinyState.computed<int>('doubled', () => tinyState.get<int>('x')! * 2);

      expect(tinyState.get<int>('doubled'), 6);
    });
  });

  group('set', () {
    test('updates the value and notifies', () {
      final counter = tinyState.watch<int>('counter', 0);
      int? seen;
      counter.addListener(() => seen = counter.value);

      tinyState.set<int>('counter', 10);

      expect(counter.value, 10);
      expect(seen, 10);
    });

    test('does not notify when the value is unchanged', () {
      final counter = tinyState.watch<int>('counter', 5);
      var notified = false;
      counter.addListener(() => notified = true);

      tinyState.set<int>('counter', 5);

      expect(notified, isFalse);
    });

    test('throws on an unknown key instead of dropping the write', () {
      expect(() => tinyState.set<int>('never_watched', 5), throwsStateError);
    });

    test('throws when the key is a read-only computed', () {
      tinyState.computed<int>('derived', () => 1);

      expect(() => tinyState.set<int>('derived', 2), throwsStateError);
    });
  });

  group('update', () {
    test('derives the next value from the current one', () {
      tinyState.watch<int>('counter', 1);

      tinyState.update<int>('counter', (current) => current + 1);

      expect(tinyState.get<int>('counter'), 2);
    });

    test('throws on an unknown key', () {
      expect(
        () => tinyState.update<int>('nope', (current) => current),
        throwsStateError,
      );
    });

    test('does not notify when the updater returns an equal value', () {
      final counter = tinyState.watch<int>('counter', 1);
      var notified = false;
      counter.addListener(() => notified = true);

      tinyState.update<int>('counter', (current) => current);

      expect(notified, isFalse);
    });
  });

  group('reset', () {
    test('restores the original default', () {
      tinyState.watch<int>('counter', 7);
      tinyState.set<int>('counter', 99);

      tinyState.reset('counter');

      expect(tinyState.get<int>('counter'), 7);
    });

    test('throws on an unknown key', () {
      expect(() => tinyState.reset('nope'), throwsStateError);
    });
  });

  group('delete', () {
    test('removes the key', () {
      tinyState.watch<int>('counter', 1);

      tinyState.delete('counter');

      expect(tinyState.get<int>('counter'), isNull);
    });

    test('is idempotent', () {
      expect(() => tinyState.delete('never_existed'), returnsNormally);
    });

    test('re-watching after delete starts from the default again', () {
      tinyState.watch<int>('counter', 0);
      tinyState.set<int>('counter', 9);
      tinyState.delete('counter');

      expect(tinyState.watch<int>('counter', 0).value, 0);
    });
  });

  group('listen', () {
    test('fires on change and stops after cancel', () {
      tinyState.watch<int>('counter', 0);
      final seen = <int>[];
      final cancel = tinyState.listen<int>('counter', seen.add);

      tinyState.set<int>('counter', 1);
      cancel();
      tinyState.set<int>('counter', 2);

      expect(seen, [1]);
    });

    test('fireImmediately delivers the current value', () {
      tinyState.watch<int>('counter', 42);
      final seen = <int>[];

      tinyState.listen<int>('counter', seen.add, fireImmediately: true);

      expect(seen, [42]);
    });

    test('once unsubscribes after the first delivery', () {
      tinyState.watch<int>('counter', 0);
      final seen = <int>[];
      tinyState.listen<int>('counter', seen.add, once: true);

      tinyState.set<int>('counter', 1);
      tinyState.set<int>('counter', 2);

      expect(seen, [1]);
    });

    test('once with fireImmediately delivers exactly once', () {
      tinyState.watch<int>('counter', 7);
      final seen = <int>[];

      tinyState.listen<int>(
        'counter',
        seen.add,
        fireImmediately: true,
        once: true,
      );
      tinyState.set<int>('counter', 8);

      expect(seen, [7]);
    });

    test('works on computed state', () {
      tinyState.watch<int>('x', 1);
      tinyState.computed<int>('doubled', () => tinyState.get<int>('x')! * 2);
      final seen = <int>[];
      tinyState.listen<int>('doubled', seen.add);

      tinyState.set<int>('x', 5);

      expect(seen, [10]);
    });

    test('throws on an unknown key instead of returning a dead callback', () {
      expect(() => tinyState.listen<int>('nope', (int _) {}), throwsStateError);
    });

    test('cancelling twice, or after delete, is safe', () {
      tinyState.watch<int>('counter', 0);
      final cancel = tinyState.listen<int>('counter', (int _) {});

      tinyState.delete('counter');

      expect(cancel, returnsNormally);
      expect(cancel, returnsNormally);
    });
  });

  group('type guard', () {
    test('rejects a mismatched set', () {
      tinyState.watch<int>('counter', 0);

      expect(() => tinyState.set<String>('counter', 'oops'), throwsStateError);
    });

    test('rejects a mismatched get', () {
      tinyState.watch<int>('counter', 0);

      expect(() => tinyState.get<String>('counter'), throwsStateError);
    });

    test('strictTypes: false relaxes value-level checks', () {
      addTearDown(() => tinyState.strictTypes = true);
      tinyState.watch<dynamic>('loose', 0);
      tinyState.strictTypes = false;

      expect(() => tinyState.set<String>('loose', 'fine'), returnsNormally);
      expect(tinyState.get<String>('loose'), 'fine');
    });

    test('a nullable key accepts its non-nullable generic', () {
      tinyState.watch<int?>('maybe', 0);

      expect(() => tinyState.set<int>('maybe', 5), returnsNormally);
      expect(tinyState.get<int>('maybe'), 5);
    });

    test('handing out a mismatched notifier always throws, even when '
        'strictTypes is off', () {
      addTearDown(() => tinyState.strictTypes = true);
      tinyState.watch<int>('counter', 0);
      tinyState.strictTypes = false;

      expect(() => tinyState.watch<String>('counter', ''), throwsStateError);
    });
  });

  group('instances', () {
    test('a standalone instance has its own keyspace', () {
      final isolated = TinyState();
      tinyState.watch<int>('counter', 1);
      isolated.watch<int>('counter', 100);

      isolated.set<int>('counter', 200);

      expect(tinyState.get<int>('counter'), 1);
      expect(isolated.get<int>('counter'), 200);
    });
  });
}
