# Changelog

## 2.0.0

A full audit pass. Every finding below was reproduced with a test before it was
fixed, and each now has a regression test.

`tiny_state` is now a **zero-dependency** package, and the API is stricter
about the things that used to fail silently.

### Breaking changes

* **`shared_preferences` is no longer a dependency, and `SharedPreferencesAdapter`
  has been removed.** The package now depends on nothing but Flutter itself.
  `TinyStatePersistenceAdapter` remains, and a ready-to-copy
  `SharedPreferencesAdapter` — with key namespacing and codec support — lives in
  the README and in `example/lib/src/persistence/shared_preferences_adapter.dart`.
* **`TinyStatePersistenceAdapter` requires a `remove(String key)` method.**
  Without it, `reset` and `delete` could not clear stored values.
* **`persist` is now a property of the key.** Declare it once at
  `watch(persist: true)`; the `persist:` parameter is gone from `set` and
  `update`, which now honour the key's own setting. This removes the "I called
  `set` but nothing was saved" failure mode entirely.
* **`select` requires a `String id`.** Results are memoized on `(key, id)`, so
  calling `select` from `build` is now safe.
* **Unknown keys throw instead of failing silently.** `set`, `update`, `reset`
  and `listen` throw a `StateError` naming the key and pointing at `watch`.
  `delete` stays idempotent.
* **Keys and scope names may not contain `/` or be empty**, and `future` is
  reserved as a scope name. This is what makes scoped keys collision-proof.
  Use `tinyState.scope('user').watch('name', ...)` instead of
  `watch('user/name', ...)`.
* **Computed and regular state share one namespace.** A key cannot be both;
  `delete` and `listen` now work uniformly on either.
* **`clear()` no longer resets configuration.** It clears state and keeps your
  adapter, `strictTypes` and `onError` — which is what you want in a test
  `setUp`. `dispose()` still resets everything.
* **`reset` and `delete` now delete persisted entries** for persisted keys.
  `clear` and `dispose` deliberately do not: semantic operations touch storage,
  lifecycle operations do not.

### Fixed

* **`select` leaked a listener on every call.** It was the only API not
  memoized by key, so calling it from `build` — as the 1.x example app and
  README both did — added a new notifier and a new subscription on the source
  on every rebuild, retained forever. Now memoized on `(key, id)`.
* **`reset` and `delete` left persisted values on disk**, so the old value came
  back on the next launch.
* **`clear()` could throw out of user code.** Deleting a key re-evaluated its
  dependent computeds against the now-missing state, so any builder using `!`
  crashed mid-teardown. Teardown no longer re-evaluates, and a builder that
  throws during a normal re-evaluation is reported through `onError` with the
  previous value kept, instead of propagating out of `set`/`delete`.
* **A computed could not depend on another computed.** `get` only looked at
  regular state, so reading a computed key silently returned `null`. Derived
  state now composes to any depth.
* **A nested computed left the outer one permanently stale.** Reading another
  computed's `.value` was not tracked; both `get('other')` and a direct
  `.value` read now register a dependency.
* **`computed` was eager, not lazy as documented.** A computed with no
  listeners re-ran on every dependency change. It is now genuinely lazy while
  unlistened and eager once a listener attaches.
* **A computed that read a not-yet-created key never woke up.** `watch` now
  notifies dependents when it creates a key.
* **There was no way to remove a computed.** `delete('key')` ignored computeds,
  so re-registering a key silently returned the old builder. `delete` now
  handles both kinds of key.
* **`computed` and `select` bypassed the type guard**, failing with a raw
  `_TypeError` instead of a useful message.
* **Nullable generics tripped the type guard.** `watch<int?>` followed by
  `set<int>` threw. Value-level checks now allow types that overlap in either
  direction; handing out a typed notifier is still checked exactly.
* **Scoped keys could collide with global ones.** `scope('a').watch('b')` and
  `watch('a/b')` resolved to the same entry, as did `watchFuture('x')` and
  `scope('future').watch('x')`.
* **Persistence errors vanished.** Reads and writes were fire-and-forget with no
  error path, so a throwing adapter produced an unhandled async error. All
  adapter calls are now caught and reported through `onError`.
* **Concurrent writes to one key could land out of order.** Writes are now
  serialized per key.
* **`get`'s documentation was wrong.** It said a type mismatch returns `null`;
  it throws.
* **`listen(once: true)` invoked the listener before unsubscribing**, so a
  listener that changed state could re-enter. It now unsubscribes first.
* **`dispose()` silently reset `strictTypes`** as a side effect.

### Added

* **`TinyBuilder`** — the terse widget form:
  `TinyBuilder<int>('counter', 0, (context, count) => Text('$count'))`, plus
  `TinyBuilder.listen(...)` for a `select` or `computed` result.
* **`TinyState.onError`** — one hook for persistence failures and computed
  builders that throw. Defaults to `FlutterError.reportError`.
* **`TinyState.flushPersistence()`** — completes when pending reads and writes
  have settled. For tests, and for flushing before teardown.
* **`MemoryPersistenceAdapter`** — an in-memory adapter for tests and demos.
* **A public `TinyState()` constructor**, for an isolated store. `tinyState`
  remains the global singleton.
* **`TinyState.deleteFuture(key)`** — drops a cached `watchFuture` result.
* **`TinyStateScope`** gained `watchFuture`, `refreshFuture` and `deleteFuture`,
  and its `clear()` now removes scoped computeds and futures too.

### Changed

* Split into `src/tiny_state.dart`, `src/persistence.dart` and
  `src/builder.dart` behind the same `package:tiny_state/tiny_state.dart`
  import.
* The analyzer runs with `strict-casts`, `strict-inference`, `strict-raw-types`,
  `public_member_api_docs` and `unawaited_futures`.
* The test suite went from 39 tests in one file to 117 across eight.
* CI now checks formatting, `analyze --fatal-infos`, the example app, version
  consistency and `pub publish --dry-run`, and a tag-driven OIDC publish
  workflow was added. See `RELEASING.md`.
* `environment.flutter` is `>=3.32.0`, replacing a `>=1.17.0` constraint that
  could never have been satisfied alongside Dart 3.8.

### Migrating from 1.x

```dart
// Persistence: declare it once, at the watch that creates the key.
- tinyState.watch<int>('count', 0, persist: true);
- tinyState.set<int>('count', 1, persist: true);
+ tinyState.watch<int>('count', 0, persist: true);
+ tinyState.set<int>('count', 1);

// select: give each projection an id.
- tinyState.select<int, bool>('count', (n) => n.isEven);
+ tinyState.select<int, bool>('count', (n) => n.isEven, id: 'isEven');

// Keys with slashes become scopes.
- tinyState.watch<String>('user/name', '');
+ tinyState.scope('user').watch<String>('name', '');

// set/update/listen/reset now require the key to exist.
+ tinyState.watch<int>('count', 0);   // call this first
  tinyState.set<int>('count', 1);

// Test setUp: clear() keeps your adapter, dispose() drops it.
- setUp(() => tinyState.dispose());
+ setUp(tinyState.clear);
```

Custom adapters need a `remove` method:

```dart
class MyAdapter extends TinyStatePersistenceAdapter {
  @override Future<T?> read<T>(String key) async { /* ... */ }
  @override Future<void> write<T>(String key, T value) async { /* ... */ }
+ @override Future<void> remove(String key) async { /* ... */ }
}
```

If you used `SharedPreferencesAdapter`, copy
`example/lib/src/persistence/shared_preferences_adapter.dart` into your project
— it also fixes complex-type round-tripping, which the 1.x built-in could not
do for model classes.

## 1.1.0

* **New**: `TinyState.dispose()` for full teardown (clears all states, computeds, adapter — singleton remains reusable).
* **New**: `watchFuture(refresh: true)` and `tinyState.refreshFuture(key)` to re-run a previously registered future. Stale completions from earlier generations are ignored.
* **New**: `tinyState.strictTypes` (default `true`) — throws a clear `StateError` on `set`/`update`/`get` with a generic that doesn't match the type the key was originally watched with.
* **New**: `SharedPreferencesAdapter` accepts an optional `onError(key, error)` callback for surfacing deserialization failures instead of swallowing them.
* **Improved**: Computed dependency lookup is now O(1) via a reverse index, instead of an O(n_computed) scan on every `set`/`update`/`delete`.
* **Fixed**: `computed()` now correctly tracks dependencies on initial construction. In v1.0.0 the dependency set was always empty, so computed states never recomputed when their inputs changed.
* **Fixed**: Nested `computed()` calls now use a stack-based tracker so each level registers its own dependencies independently.
* **Fixed**: `watch(persist: true)` no longer overwrites a value the user `set` before the async load completed — the load is suppressed once the user has taken over.
* **Fixed**: `select()` notifiers are now disposed automatically when their source key is `delete`d, preventing orphaned listeners on a disposed source.
* **Docs**: Full README rewrite covering every public API, with an Installation section, Quick Start, Persistence walkthrough, and Type Safety note.
* **Example**: New "Persist" tab in the example app demonstrating a persisted note and a persisted counter side-by-side with an in-memory counter.

## 1.0.0

* Initial release of `tiny_state`, a minimalistic and powerful state management library for Flutter.
* Core features include `watch`, `set`, `get`, `update`, `reset`, and `delete`.
* Advanced features include `select`, `computed`, `listen`, `scope`, `watchFuture`, and state persistence.
* Added a comprehensive `README.md` with detailed documentation and examples.
* Included a full example application to demonstrate all features.
