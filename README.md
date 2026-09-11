# Tiny State

[![Build and Test](https://github.com/theprantadutta/tiny_state/actions/workflows/build.yml/badge.svg)](https://github.com/theprantadutta/tiny_state/actions/workflows/build.yml)
[![pub package](https://img.shields.io/pub/v/tiny_state.svg)](https://pub.dev/packages/tiny_state)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Global, reactive state for Flutter with **zero dependencies**. It feels like a
`ValueNotifier`, because it is one — just global, keyed, and with computed state
and persistence built on top.

```dart
final counter = tinyState.watch<int>('counter', 0);   // a real ValueNotifier
tinyState.update<int>('counter', (n) => n + 1);
```

## Philosophy

`tiny_state` is the snack bar of state management, not the buffet. It exists for
the state that does not deserve a `Provider`, a `Notifier` subclass, or a BLoC:
theme mode, a session flag, a cart count, a filter, a draft.

- **Use it** for small and medium apps, prototypes, and simple global state.
- **Use something else** — Riverpod, BLoC — once you have complex dependency
  graphs, code generation, or elaborate async state machines. This is not
  trying to replace them.

Its one hard rule is in the name: the package depends on **nothing but Flutter**.
Persistence is an interface you implement, not a dependency you inherit.

## Features

- **Zero dependencies** — nothing but the Flutter SDK.
- **No `BuildContext`** — reachable from services, repositories, anywhere.
- **Real `ValueNotifier`s** — everything interops with `ValueListenableBuilder`.
- **Computed state** with automatic dependency tracking, composable to any
  depth, and lazy while nothing is listening.
- **Selectors** that only notify when the derived value actually changes.
- **Scopes** for namespacing, with collisions made structurally impossible.
- **Persistence** through a three-method adapter you control.
- **Async** via `watchFuture` / `refreshFuture` as `AsyncSnapshot`s.
- **Loud about mistakes** — typos and type mismatches throw with a message that
  names the key, instead of silently doing nothing.

> Upgrading from 1.x? See the [migration guide](CHANGELOG.md#migrating-from-1x).
> 2.0 removes the `shared_preferences` dependency and tightens several APIs.

## Installation

```bash
flutter pub add tiny_state
```

```dart
import 'package:tiny_state/tiny_state.dart';
```

The global `tinyState` singleton is ready to use. There is nothing to wrap your
app in.

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:tiny_state/tiny_state.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: TinyBuilder<int>(
            'counter',
            0,
            (context, count) => Text('$count', style: const TextStyle(fontSize: 48)),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => tinyState.update<int>('counter', (n) => n + 1),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
```

## Core API

### `watch`

Creates the key on first use and returns its `ValueNotifier`. Calling it again
returns the same notifier and ignores the later default — the first call defines
the key.

```dart
final counter = tinyState.watch<int>('counter', 0);
```

### `get`

Reads the current value without subscribing. Returns `null` for an unknown key,
and works on computed state too.

```dart
final value = tinyState.get<int>('counter');
```

### `set` and `update`

```dart
tinyState.set<int>('counter', 10);
tinyState.update<int>('counter', (n) => n + 1);   // no lost-update race
```

Both require the key to exist — a typo throws a `StateError` naming the key
rather than dropping the write.

> **`update` must return a new value.** Mutating a list or model in place and
> returning it will not notify, because the equality check sees the same object:
>
> ```dart
> // Wrong — same object, no notification.
> tinyState.update<List<int>>('items', (items) => items..add(1));
>
> // Right.
> tinyState.update<List<int>>('items', (items) => [...items, 1]);
> ```

### `reset` and `delete`

```dart
tinyState.reset('counter');    // back to the default it was watched with
tinyState.delete('counter');   // remove the key entirely
```

For a persisted key, both clear the stored value, so the default declared in
code wins on the next launch.

> `delete` disposes the notifier. Any widget still holding one from an earlier
> `watch` will throw "used after dispose" — re-`watch` after deleting.

### `select`

A projection of one key that only notifies when the *projection* changes.

```dart
final isEven = tinyState.select<int, bool>(
  'counter',
  (n) => n.isEven,
  id: 'isEven',
);
```

The result is memoized on `(key, id)`, so calling this inside `build` is safe —
it returns the same listenable every time. That is what `id` is for: two
different projections of one key need two different ids. Never dispose the
result; `tiny_state` owns it.

### `computed`

Derived state. Dependencies are discovered by watching which `get` calls the
builder makes — nothing is registered by hand.

```dart
tinyState.watch<String>('firstName', 'Jane');
tinyState.watch<String>('lastName', 'Doe');

final fullName = tinyState.computed<String>('fullName', () {
  return '${tinyState.get<String>('firstName')} ${tinyState.get<String>('lastName')}';
});
```

Computed state **composes** — a computed can read another computed:

```dart
final initials = tinyState.computed<String>('initials', () {
  return tinyState.get<String>('fullName')!
      .split(' ')
      .map((part) => part[0])
      .join();
});
```

It is **lazy while nothing is listening**: the builder re-runs on the next read
rather than on every dependency change. Once a listener attaches it re-evaluates
eagerly, because notifying requires knowing the new value.

If the builder throws during a re-evaluation, the error goes to
[`onError`](#error-handling) and the previous value is kept. A throw during the
*first* evaluation propagates to the caller.

### `listen`

```dart
final cancel = tinyState.listen<int>(
  'counter',
  (value) => print('now $value'),
  fireImmediately: true,
  once: false,
);

cancel();   // safe to call twice, and after the key is deleted
```

Works on computed state too. Always cancel from the `dispose` of whatever owns
the subscription.

### `scope`

Namespacing, without collisions being possible:

```dart
final cart = tinyState.scope('cart');
cart.watch<int>('count', 0);          // stored as 'cart/count'
cart.update<int>('count', (n) => n + 1);
cart.clear();                          // wipes this scope only
```

`/` is rejected inside keys and scope names, which is precisely what guarantees
`scope('cart').watch('count')` can never collide with a global key.

### `watchFuture` and `refreshFuture`

```dart
final snapshot = tinyState.watchFuture<User>('me', () => api.fetchUser());

TinyBuilder<AsyncSnapshot<User>>.listen(snapshot, (context, snap) {
  if (snap.connectionState == ConnectionState.waiting) {
    return const CircularProgressIndicator();
  }
  if (snap.hasError) return Text('Error: ${snap.error}');
  return Text('Hi, ${snap.data!.name}');
});

tinyState.refreshFuture('me');
tinyState.deleteFuture('me');   // drop the cached result
```

The future runs once per key. Results from a superseded run are discarded, so a
slow first request cannot overwrite a newer one.

### `clear` and `dispose`

```dart
tinyState.clear();     // drop all state; keeps your adapter and settings
tinyState.dispose();   // drop all state AND reset configuration
```

`clear()` is what you want in a test `setUp`. Neither touches persisted data —
storage is only changed by `reset` and `delete`, which are operations on a
value rather than on the container.

## Widgets

`TinyBuilder` is a thin wrapper over `ValueListenableBuilder`:

```dart
// Watch a key directly.
TinyBuilder<int>('counter', 0, (context, count) => Text('$count'))

// Or follow a select / computed result.
TinyBuilder<String>.listen(fullName, (context, name) => Text(name))

// Scoped.
TinyBuilder<int>('count', 0, (context, n) => Text('$n'), scope: cart)
```

Everything is a plain `ValueListenable`, so `ValueListenableBuilder`,
`AnimatedBuilder` and `ListenableBuilder` all work unchanged.

## Persistence

`tiny_state` ships no storage dependency. You implement three methods:

```dart
abstract class TinyStatePersistenceAdapter {
  Future<T?> read<T>(String key);
  Future<void> write<T>(String key, T value);
  Future<void> remove(String key);
}
```

Assign one at startup, then declare persisted keys with `persist: true`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tinyState.persistenceAdapter = MyAdapter();

  // Persistence is a property of the key: declare it once, here.
  tinyState.watch<int>('themeMode', ThemeMode.dark.index, persist: true);

  runApp(const MyApp());
}

// Every write is saved. No flag to remember, nowhere to forget it.
tinyState.set<int>('themeMode', ThemeMode.light.index);
```

`MemoryPersistenceAdapter` is included for tests and demos, and
`flushPersistence()` completes when pending reads and writes have settled:

```dart
tinyState.persistenceAdapter = MemoryPersistenceAdapter();
tinyState.set<int>('themeMode', 1);
await tinyState.flushPersistence();
```

### A `shared_preferences` adapter

Copy this into your app — it is the whole integration. A fuller version, with
key namespacing and codecs for model classes, is in
[`example/lib/src/persistence/shared_preferences_adapter.dart`](example/lib/src/persistence/shared_preferences_adapter.dart).

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_state/tiny_state.dart';

class SharedPreferencesAdapter extends TinyStatePersistenceAdapter {
  SharedPreferencesAdapter(this._prefs, {this.namespace = 'tiny_state.'});

  final SharedPreferences _prefs;
  final String namespace;

  String _key(String key) => '$namespace$key';

  @override
  Future<T?> read<T>(String key) async {
    final stored = _prefs.get(_key(key));
    if (stored == null) return null;
    if (stored is T) return stored as T;
    if (T == List<String>) return (stored as List).cast<String>() as T;
    return jsonDecode(stored as String) as T;
  }

  @override
  Future<void> write<T>(String key, T value) async {
    final k = _key(key);
    switch (value) {
      case final bool v: await _prefs.setBool(k, v);
      case final int v: await _prefs.setInt(k, v);
      case final double v: await _prefs.setDouble(k, v);
      case final String v: await _prefs.setString(k, v);
      case final List<String> v: await _prefs.setStringList(k, v);
      default: await _prefs.setString(k, jsonEncode(value));
    }
  }

  @override
  Future<void> remove(String key) async => _prefs.remove(_key(key));
}
```

> **Model classes need a codec.** `jsonDecode` produces a `Map<String, dynamic>`,
> which will not cast back to your model. The example adapter shows how to
> register a per-key `PersistedCodec` so a `List<Todo>` round-trips properly.

## Error handling

One hook covers persistence failures and computed builders that throw. Without
it, these go to `FlutterError.reportError`.

```dart
tinyState.onError = (error, stack, context) {
  debugPrint('[tiny_state] $context: $error');
};
```

Adapter calls are never fire-and-forget: a throwing adapter is reported here
rather than surfacing as an unhandled async error.

## Type safety

Watch a key as one type and use it as another and you get a `StateError` naming
the key, not a confusing cast failure three frames away:

```dart
tinyState.watch<int>('counter', 0);
tinyState.set<String>('counter', 'oops');
// StateError: Type mismatch for state "counter": it holds int but was
// accessed as String.
```

Nullable generics are handled — `watch<int?>` accepts `set<int>`. To relax the
value-level checks:

```dart
tinyState.strictTypes = false;
```

Handing out a typed notifier (`watch`, `select`, `listen`) is always checked,
because the cast would fail anyway with a far worse message.

## Testing

```dart
setUp(tinyState.clear);   // keeps your adapter; dispose() would drop it

test('the counter increments', () {
  tinyState.watch<int>('counter', 0);
  tinyState.update<int>('counter', (n) => n + 1);
  expect(tinyState.get<int>('counter'), 1);
});
```

For full isolation, build your own store — `tinyState` is just a singleton
instance of a normal class:

```dart
final store = TinyState();
store.watch<int>('counter', 0);
```

## Example app

The `example/` directory is a five-tab app covering every feature.

| | |
| --- | --- |
| **Basics** | `watch`, `get`, `set`, `update`, `reset`, `select`, `listen` |
| **Profile** | composed `computed` state and a persisted theme |
| **Todos** | a list of models, a derived count, and a codec so it survives a restart |
| **Scopes** | two counters sharing a key name, kept apart by scopes |
| **Persist** | a persisted note and counter beside an in-memory one |

![Basics](screenshots/basics_screen.jpg)
![Todos](screenshots/todos_screen.jpg)
![Profile](screenshots/profile_screen.jpg)
![Scopes](screenshots/scopes_screen.jpg)

## Contributing

Releases are tag-driven and documented in [RELEASING.md](RELEASING.md). Before
opening a PR:

```bash
dart format .
flutter analyze --fatal-infos
flutter test
```

## License

MIT — see [LICENSE](LICENSE).
