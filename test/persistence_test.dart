import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_state/tiny_state.dart';

import 'support/recording_adapter.dart';

void main() {
  late RecordingAdapter adapter;

  setUp(() {
    tinyState.clear();
    adapter = RecordingAdapter();
    tinyState.persistenceAdapter = adapter;
  });

  tearDown(() {
    tinyState.persistenceAdapter = null;
    tinyState.onError = null;
  });

  group('round trip', () {
    test('rehydrates a stored value on watch', () async {
      adapter.entries['theme'] = 1;

      final theme = tinyState.watch<int>('theme', 0, persist: true);
      await tinyState.flushPersistence();

      expect(theme.value, 1);
    });

    test('leaves the default in place when nothing is stored', () async {
      final theme = tinyState.watch<int>('theme', 3, persist: true);
      await tinyState.flushPersistence();

      expect(theme.value, 3);
    });

    test(
      'persistence is a property of the key, so set writes without a flag',
      () async {
        tinyState.watch<String>('note', '', persist: true);

        tinyState.set<String>('note', 'hello');
        await tinyState.flushPersistence();

        expect(adapter.entries['note'], 'hello');
      },
    );

    test('update writes too', () async {
      tinyState.watch<int>('count', 0, persist: true);

      tinyState.update<int>('count', (current) => current + 1);
      await tinyState.flushPersistence();

      expect(adapter.entries['count'], 1);
    });

    test('a non-persisted key is never written', () async {
      tinyState.watch<int>('ephemeral', 0);

      tinyState.set<int>('ephemeral', 5);
      await tinyState.flushPersistence();

      expect(adapter.calls, isEmpty);
    });
  });

  group('reset and delete', () {
    test(
      'reset deletes the stored entry so the code default wins next launch',
      () async {
        tinyState.watch<int>('count', 0, persist: true);
        tinyState.set<int>('count', 42);
        await tinyState.flushPersistence();
        expect(adapter.entries['count'], 42);

        tinyState.reset('count');
        await tinyState.flushPersistence();

        expect(tinyState.get<int>('count'), 0);
        expect(adapter.entries.containsKey('count'), isFalse);
      },
    );

    test('delete removes the stored entry', () async {
      tinyState.watch<int>('token', 0, persist: true);
      tinyState.set<int>('token', 7);
      await tinyState.flushPersistence();

      tinyState.delete('token');
      await tinyState.flushPersistence();

      expect(adapter.entries.containsKey('token'), isFalse);
    });

    test('clear is a lifecycle operation and leaves storage alone', () async {
      tinyState.watch<int>('count', 0, persist: true);
      tinyState.set<int>('count', 5);
      await tinyState.flushPersistence();

      tinyState.clear();
      await tinyState.flushPersistence();

      expect(adapter.entries['count'], 5);
    });
  });

  group('ordering and races', () {
    test('writes to one key are applied in order', () async {
      tinyState.watch<int>('count', 0, persist: true);

      for (var i = 1; i <= 5; i++) {
        tinyState.set<int>('count', i);
      }
      await tinyState.flushPersistence();

      expect(adapter.written, [
        1,
        2,
        3,
        4,
        5,
      ], reason: 'writes must land in the order they were issued');
      expect(adapter.entries['count'], 5);
    });

    test('a write during an in-flight rehydrate is not clobbered', () async {
      adapter
        ..entries['note'] = 'from disk'
        ..gate = Completer<void>();

      final note = tinyState.watch<String>('note', '', persist: true);
      tinyState.set<String>('note', 'from user');
      adapter.gate!.complete();
      await tinyState.flushPersistence();

      expect(note.value, 'from user');
    });

    test('a rehydrate for a key deleted mid-flight is discarded', () async {
      adapter
        ..entries['note'] = 'from disk'
        ..gate = Completer<void>();

      tinyState.watch<String>('note', '', persist: true);
      tinyState.delete('note');
      adapter.gate!.complete();
      await tinyState.flushPersistence();

      expect(tinyState.get<String>('note'), isNull);
    });
  });

  group('errors', () {
    test('a failing read is reported, not thrown into the zone', () async {
      final contexts = <String>[];
      tinyState.onError = (Object error, StackTrace stack, String context) =>
          contexts.add(context);
      adapter.failures['note'] = StateError('disk on fire');

      final note = tinyState.watch<String>('note', 'default', persist: true);
      await tinyState.flushPersistence();

      expect(contexts, ['reading persisted state "note"']);
      expect(note.value, 'default');
    });

    test('a failing write is reported, not thrown into the zone', () async {
      final contexts = <String>[];
      tinyState.onError = (Object error, StackTrace stack, String context) =>
          contexts.add(context);
      tinyState.watch<String>('note', '', persist: true);
      adapter.failures['note'] = StateError('disk full');

      tinyState.set<String>('note', 'hi');
      await tinyState.flushPersistence();

      expect(contexts, ['writing persisted state "note"']);
    });

    test('a later write still goes through after one fails', () async {
      tinyState.onError = (Object error, StackTrace stack, String context) {};
      tinyState.watch<String>('note', '', persist: true);
      adapter.failures['note'] = StateError('transient');

      tinyState.set<String>('note', 'first');
      await tinyState.flushPersistence();
      adapter.failures.remove('note');
      tinyState.set<String>('note', 'second');
      await tinyState.flushPersistence();

      expect(adapter.entries['note'], 'second');
    });

    test(
      'persist: true without an adapter is reported instead of silent',
      () async {
        tinyState.persistenceAdapter = null;
        final contexts = <String>[];
        tinyState.onError = (Object error, StackTrace stack, String context) =>
            contexts.add(context);

        tinyState.watch<int>('count', 0, persist: true);

        expect(contexts, ['rehydrating "count"']);
      },
    );
  });

  group('MemoryPersistenceAdapter', () {
    test('round-trips through the public API', () async {
      final memory = MemoryPersistenceAdapter({'count': 9});
      tinyState
        ..clear()
        ..persistenceAdapter = memory;

      final count = tinyState.watch<int>('count', 0, persist: true);
      await tinyState.flushPersistence();
      expect(count.value, 9);

      tinyState.set<int>('count', 10);
      await tinyState.flushPersistence();

      expect(memory.entries['count'], 10);
    });

    test('exposes an unmodifiable view', () {
      final memory = MemoryPersistenceAdapter({'a': 1});

      expect(() => memory.entries['b'] = 2, throwsUnsupportedError);
    });
  });

  test('scoped keys persist under their scoped name', () async {
    final cart = tinyState.scope('cart');
    cart.watch<int>('items', 0, persist: true);

    cart.set<int>('items', 3);
    await tinyState.flushPersistence();

    expect(adapter.entries['cart/items'], 3);
  });
}
