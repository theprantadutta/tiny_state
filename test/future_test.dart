import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_state/tiny_state.dart';

void main() {
  setUp(tinyState.clear);

  test('resolves to data', () async {
    final snapshot = tinyState.watchFuture<String>(
      'greeting',
      () async => 'hi',
    );
    expect(snapshot.value.connectionState, ConnectionState.waiting);

    await Future<void>.delayed(Duration.zero);

    expect(snapshot.value.connectionState, ConnectionState.done);
    expect(snapshot.value.data, 'hi');
  });

  test('resolves to an error', () async {
    final snapshot = tinyState.watchFuture<String>(
      'greeting',
      () async => throw StateError('boom'),
    );

    await Future<void>.delayed(Duration.zero);

    expect(snapshot.value.hasError, isTrue);
    expect(snapshot.value.error, isStateError);
  });

  test('caches: a second call does not re-run the future', () async {
    var runs = 0;
    tinyState.watchFuture<int>('n', () async {
      runs++;
      return 1;
    });
    await Future<void>.delayed(Duration.zero);

    tinyState.watchFuture<int>('n', () async {
      runs++;
      return 2;
    });
    await Future<void>.delayed(Duration.zero);

    expect(runs, 1);
  });

  test('refresh: true re-runs with the new future', () async {
    tinyState.watchFuture<int>('n', () async => 1);
    await Future<void>.delayed(Duration.zero);

    final snapshot = tinyState.watchFuture<int>(
      'n',
      () async => 2,
      refresh: true,
    );
    expect(snapshot.value.connectionState, ConnectionState.waiting);
    await Future<void>.delayed(Duration.zero);

    expect(snapshot.value.data, 2);
  });

  test('refreshFuture re-runs the originally registered future', () async {
    var runs = 0;
    final snapshot = tinyState.watchFuture<int>('n', () async {
      runs++;
      return runs;
    });
    await Future<void>.delayed(Duration.zero);

    tinyState.refreshFuture('n');
    await Future<void>.delayed(Duration.zero);

    expect(runs, 2);
    expect(snapshot.value.data, 2);
  });

  test('refreshFuture on an unwatched key is a no-op', () {
    expect(() => tinyState.refreshFuture('never'), returnsNormally);
  });

  test('a superseded run cannot overwrite a newer result', () async {
    final slow = Completer<int>();
    final fast = Completer<int>();

    final snapshot = tinyState.watchFuture<int>('n', () => slow.future);
    tinyState.watchFuture<int>('n', () => fast.future, refresh: true);

    fast.complete(2);
    await Future<void>.delayed(Duration.zero);
    expect(snapshot.value.data, 2);

    slow.complete(1);
    await Future<void>.delayed(Duration.zero);

    expect(snapshot.value.data, 2, reason: 'the stale run must be discarded');
  });

  test('future keys live in their own namespace', () async {
    tinyState.watch<int>('n', 42);
    tinyState.watchFuture<int>('n', () async => 7);
    await Future<void>.delayed(Duration.zero);

    expect(tinyState.get<int>('n'), 42);
  });

  test('deleteFuture drops the cache so the next watch re-runs', () async {
    var runs = 0;
    tinyState.watchFuture<int>('n', () async {
      runs++;
      return runs;
    });
    await Future<void>.delayed(Duration.zero);

    tinyState.deleteFuture('n');
    tinyState.watchFuture<int>('n', () async {
      runs++;
      return runs;
    });
    await Future<void>.delayed(Duration.zero);

    expect(runs, 2);
  });

  test('a result arriving after delete is discarded', () async {
    final pending = Completer<int>();
    tinyState.watchFuture<int>('n', () => pending.future);

    tinyState.deleteFuture('n');
    pending.complete(1);

    await expectLater(Future<void>.delayed(Duration.zero), completes);
  });

  test('scoped futures are isolated', () async {
    final a = tinyState.scope('a');
    final b = tinyState.scope('b');

    final fromA = a.watchFuture<int>('n', () async => 1);
    final fromB = b.watchFuture<int>('n', () async => 2);
    await Future<void>.delayed(Duration.zero);

    expect(fromA.value.data, 1);
    expect(fromB.value.data, 2);
  });
}
