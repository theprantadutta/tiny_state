import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_state/tiny_state.dart';

void main() {
  setUp(tinyState.clear);

  test('projects the source value', () {
    tinyState.watch<int>('counter', 2);

    final isEven = tinyState.select<int, bool>(
      'counter',
      (value) => value.isEven,
      id: 'isEven',
    );

    expect(isEven.value, isTrue);
  });

  test('only notifies when the projection changes', () {
    tinyState.watch<int>('counter', 0);
    final isEven = tinyState.select<int, bool>(
      'counter',
      (value) => value.isEven,
      id: 'isEven',
    );
    var notifications = 0;
    isEven.addListener(() => notifications++);

    tinyState.set<int>('counter', 2);
    tinyState.set<int>('counter', 4);
    expect(notifications, 0);

    tinyState.set<int>('counter', 5);
    expect(notifications, 1);
  });

  test('is memoized on (key, id), so calling it in build cannot leak', () {
    tinyState.watch<int>('counter', 0);
    var selectorCalls = 0;

    // Simulates 50 widget rebuilds, each calling select() again.
    for (var i = 0; i < 50; i++) {
      tinyState.select<int, bool>('counter', (value) {
        selectorCalls++;
        return value.isEven;
      }, id: 'isEven');
    }
    selectorCalls = 0;

    tinyState.set<int>('counter', 1);

    expect(
      selectorCalls,
      1,
      reason: '50 select() calls must leave exactly one live subscription',
    );
  });

  test('returns the identical listenable for the same (key, id)', () {
    tinyState.watch<int>('counter', 0);

    final first = tinyState.select<int, bool>(
      'counter',
      (value) => value.isEven,
      id: 'isEven',
    );
    final second = tinyState.select<int, bool>(
      'counter',
      (value) => value.isEven,
      id: 'isEven',
    );

    expect(second, same(first));
  });

  test('different ids give independent projections', () {
    tinyState.watch<int>('counter', 3);

    final isEven = tinyState.select<int, bool>(
      'counter',
      (value) => value.isEven,
      id: 'isEven',
    );
    final asText = tinyState.select<int, String>(
      'counter',
      (value) => '$value',
      id: 'asText',
    );

    expect(isEven.value, isFalse);
    expect(asText.value, '3');
  });

  test('reusing an id with different types throws', () {
    tinyState.watch<int>('counter', 0);
    tinyState.select<int, bool>('counter', (value) => value.isEven, id: 'x');

    expect(
      () => tinyState.select<int, String>(
        'counter',
        (value) => '$value',
        id: 'x',
      ),
      throwsStateError,
    );
  });

  test('throws on an unknown key', () {
    expect(
      () => tinyState.select<int, bool>(
        'nope',
        (value) => value.isEven,
        id: 'isEven',
      ),
      throwsStateError,
    );
  });

  test('throws on a source type mismatch', () {
    tinyState.watch<int>('counter', 0);

    expect(
      () => tinyState.select<String, int>(
        'counter',
        (value) => value.length,
        id: 'len',
      ),
      throwsStateError,
    );
  });

  test('is torn down when the source key is deleted', () {
    tinyState.watch<int>('counter', 0);
    final isEven = tinyState.select<int, bool>(
      'counter',
      (value) => value.isEven,
      id: 'isEven',
    );

    tinyState.delete('counter');

    expect(() => isEven.addListener(() {}), throwsFlutterError);
  });

  test('a re-created key gets a fresh selector rather than a dead one', () {
    tinyState.watch<int>('counter', 0);
    tinyState.select<int, bool>(
      'counter',
      (value) => value.isEven,
      id: 'isEven',
    );
    tinyState.delete('counter');

    tinyState.watch<int>('counter', 1);
    final revived = tinyState.select<int, bool>(
      'counter',
      (value) => value.isEven,
      id: 'isEven',
    );

    expect(revived.value, isFalse);
    expect(() => revived.addListener(() {}), returnsNormally);
  });

  test('rejects an empty id', () {
    tinyState.watch<int>('counter', 0);

    expect(
      () => tinyState.select<int, bool>(
        'counter',
        (value) => value.isEven,
        id: '',
      ),
      throwsArgumentError,
    );
  });
}
