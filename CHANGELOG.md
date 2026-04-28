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
