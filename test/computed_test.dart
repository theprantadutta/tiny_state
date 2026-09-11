import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_state/tiny_state.dart';

void main() {
  setUp(tinyState.clear);

  group('dependency tracking', () {
    test('re-evaluates when a dependency changes', () {
      tinyState.watch<String>('firstName', 'Jane');
      tinyState.watch<String>('lastName', 'Doe');
      final fullName = tinyState.computed<String>(
        'fullName',
        () =>
            '${tinyState.get<String>('firstName')} '
            '${tinyState.get<String>('lastName')}',
      );

      expect(fullName.value, 'Jane Doe');

      tinyState.set<String>('firstName', 'John');

      expect(fullName.value, 'John Doe');
    });

    test('only computeds that read a key are re-evaluated', () {
      tinyState.watch<int>('a', 1);
      tinyState.watch<int>('b', 1);
      var aRuns = 0;
      var bRuns = 0;
      final fromA = tinyState.computed<int>('fromA', () {
        aRuns++;
        return tinyState.get<int>('a')!;
      });
      final fromB = tinyState.computed<int>('fromB', () {
        bRuns++;
        return tinyState.get<int>('b')!;
      });
      fromA.addListener(() {});
      fromB.addListener(() {});
      aRuns = 0;
      bRuns = 0;

      tinyState.set<int>('a', 2);

      expect(aRuns, 1);
      expect(bRuns, 0);
    });

    test(
      'a key created after the first evaluation still wakes the computed',
      () {
        final late = tinyState.computed<int>(
          'late',
          () => tinyState.get<int>('notYet') ?? -1,
        );
        expect(late.value, -1);

        tinyState.watch<int>('notYet', 5);

        expect(late.value, 5);
      },
    );

    test('deleting a dependency re-evaluates against its absence', () {
      tinyState.watch<int>('x', 4);
      final doubled = tinyState.computed<int>(
        'doubled',
        () => (tinyState.get<int>('x') ?? 0) * 2,
      );
      expect(doubled.value, 8);

      tinyState.delete('x');

      expect(doubled.value, 0);
    });

    test('dependencies are re-collected, so a branch that stops being read '
        'stops triggering re-evaluation', () {
      tinyState.watch<bool>('useA', true);
      tinyState.watch<int>('a', 1);
      tinyState.watch<int>('b', 100);
      var runs = 0;
      final picked = tinyState.computed<int>('picked', () {
        runs++;
        return tinyState.get<bool>('useA')!
            ? tinyState.get<int>('a')!
            : tinyState.get<int>('b')!;
      });
      picked.addListener(() {});

      tinyState.set<bool>('useA', false);
      expect(picked.value, 100);
      runs = 0;

      // 'a' is no longer read, so it must no longer be a dependency.
      tinyState.set<int>('a', 999);

      expect(runs, 0);
    });
  });

  group('laziness', () {
    test('does not re-run while nothing is listening', () {
      tinyState.watch<int>('x', 0);
      var runs = 0;
      final doubled = tinyState.computed<int>('doubled', () {
        runs++;
        return tinyState.get<int>('x')! * 2;
      });
      expect(runs, 1);

      for (var i = 1; i <= 50; i++) {
        tinyState.set<int>('x', i);
      }

      expect(runs, 1, reason: 'unlistened computeds must not run eagerly');
      expect(doubled.value, 100);
      expect(runs, 2, reason: 'reading settles it exactly once');
    });

    test('re-runs eagerly once a listener is attached', () {
      tinyState.watch<int>('x', 0);
      final doubled = tinyState.computed<int>(
        'doubled',
        () => tinyState.get<int>('x')! * 2,
      );
      var notifications = 0;
      doubled.addListener(() => notifications++);

      tinyState.set<int>('x', 1);

      expect(notifications, 1);
      expect(doubled.value, 2);
    });

    test('does not notify when the derived value is unchanged', () {
      tinyState.watch<int>('n', 0);
      final isEven = tinyState.computed<bool>(
        'isEven',
        () => tinyState.get<int>('n')!.isEven,
      );
      var notifications = 0;
      isEven.addListener(() => notifications++);

      tinyState.set<int>('n', 2);
      tinyState.set<int>('n', 4);

      expect(notifications, 0);
    });
  });

  group('composition', () {
    test('a computed can depend on another computed', () {
      tinyState.watch<int>('x', 1);
      tinyState.computed<int>('doubled', () => tinyState.get<int>('x')! * 2);
      final quadrupled = tinyState.computed<int>(
        'quadrupled',
        () => tinyState.get<int>('doubled')! * 2,
      );

      expect(quadrupled.value, 4);

      tinyState.set<int>('x', 3);

      expect(quadrupled.value, 12);
    });

    test('reading another computed through its listenable also registers a '
        'dependency', () {
      tinyState.watch<int>('x', 1);
      tinyState.watch<int>('y', 10);
      late ValueListenable<int> inner;
      final outer = tinyState.computed<int>('outer', () {
        inner = tinyState.computed<int>(
          'inner',
          () => tinyState.get<int>('y')! + 1,
        );
        return tinyState.get<int>('x')! + inner.value;
      });
      expect(outer.value, 12);

      tinyState.set<int>('y', 20);

      expect(inner.value, 21);
      expect(outer.value, 22, reason: 'the outer computed must not go stale');
    });

    test('a chain of three propagates all the way down', () {
      tinyState.watch<int>('base', 1);
      tinyState.computed<int>('a', () => tinyState.get<int>('base')! + 1);
      tinyState.computed<int>('b', () => tinyState.get<int>('a')! + 1);
      final c = tinyState.computed<int>(
        'c',
        () => tinyState.get<int>('b')! + 1,
      );

      expect(c.value, 4);

      tinyState.set<int>('base', 10);

      expect(c.value, 13);
    });

    test(
      'circular dependencies terminate instead of overflowing the stack',
      () {
        tinyState.watch<int>('x', 1);
        final a = tinyState.computed<int>(
          'a',
          () => tinyState.get<int>('x')! + (tinyState.get<int>('b') ?? 0),
        );
        tinyState.computed<int>('b', () => tinyState.get<int>('a') ?? 0);

        expect(() => tinyState.set<int>('x', 2), returnsNormally);
        expect(() => a.value, returnsNormally);
      },
    );
  });

  group('identity and lifecycle', () {
    test('the first call defines the key', () {
      tinyState.watch<int>('x', 1);
      final first = tinyState.computed<int>(
        'c',
        () => tinyState.get<int>('x')!,
      );
      final second = tinyState.computed<int>('c', () => 999);

      expect(second, same(first));
      expect(second.value, 1);
    });

    test('requesting an existing computed with another type throws', () {
      tinyState.computed<int>('c', () => 1);

      expect(
        () => tinyState.computed<String>('c', () => 'x'),
        throwsStateError,
      );
    });

    test('refuses a key already taken by regular state', () {
      tinyState.watch<int>('x', 1);

      expect(() => tinyState.computed<int>('x', () => 2), throwsStateError);
    });

    test('delete removes it so the key can be redefined', () {
      tinyState.watch<int>('x', 1);
      final first = tinyState.computed<int>(
        'c',
        () => tinyState.get<int>('x')! * 2,
      );
      expect(first.value, 2);

      tinyState.delete('c');
      final second = tinyState.computed<int>(
        'c',
        () => tinyState.get<int>('x')! * 10,
      );

      expect(second, isNot(same(first)));
      expect(second.value, 10);
    });

    test('a deleted computed stops reacting to its old dependencies', () {
      tinyState.watch<int>('x', 1);
      final doubled = tinyState.computed<int>(
        'doubled',
        () => tinyState.get<int>('x')! * 2,
      );
      doubled.addListener(() {});

      tinyState.delete('doubled');

      expect(() => tinyState.set<int>('x', 5), returnsNormally);
    });
  });

  group('errors', () {
    test('a throw during the first evaluation reaches the caller', () {
      expect(
        () => tinyState.computed<int>('boom', () => throw StateError('nope')),
        throwsStateError,
      );
    });

    test('a throw during re-evaluation is reported and the value is kept', () {
      addTearDown(() => tinyState.onError = null);
      tinyState.watch<int>('x', 1);
      final risky = tinyState.computed<int>(
        'risky',
        () => tinyState.get<int>('x')! * 2,
      );
      risky.addListener(() {});
      final contexts = <String>[];
      tinyState.onError = (Object error, StackTrace stack, String context) =>
          contexts.add(context);

      // Deleting the dependency makes the `!` inside the builder throw.
      tinyState.delete('x');

      expect(contexts, ['recomputing computed state "risky"']);
      expect(risky.value, 2, reason: 'the last good value survives');
    });

    test('a computed recovers after a failed re-evaluation', () {
      addTearDown(() => tinyState.onError = null);
      tinyState.onError = (Object error, StackTrace stack, String context) {};
      tinyState.watch<int>('x', 1);
      final risky = tinyState.computed<int>(
        'risky',
        () => tinyState.get<int>('x')! * 2,
      );
      risky.addListener(() {});

      tinyState.delete('x');
      tinyState.watch<int>('x', 21);

      expect(risky.value, 42);
    });
  });
}
