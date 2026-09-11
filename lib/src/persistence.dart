/// The contract `tiny_state` uses to persist and rehydrate state.
///
/// `tiny_state` deliberately ships with **no** storage dependency. Bring your
/// own backend — `shared_preferences`, `hive`, secure storage, a remote KV
/// store — by implementing these three methods and assigning the result to
/// [TinyState.persistenceAdapter].
///
/// A reference `shared_preferences` implementation lives in the README and in
/// `example/lib/src/persistence/shared_preferences_adapter.dart`.
///
/// ### Contract
///
/// * [read] returns `null` when the key is absent. Returning `null` leaves the
///   in-memory default in place.
/// * [write] is called on every change to a key declared with `persist: true`.
///   Writes for a single key are serialized by `TinyState`, so implementations
///   do not need their own locking.
/// * [remove] is called by `reset` and `delete`, so a reset key falls back to
///   the default declared in code on the next launch.
///
/// Throwing from any method is safe: `TinyState` catches the error and reports
/// it through [TinyState.onError] instead of leaking an unhandled async error.
abstract class TinyStatePersistenceAdapter {
  /// Allows `const` subclasses.
  const TinyStatePersistenceAdapter();

  /// Reads the value stored under [key], or `null` if there is none.
  Future<T?> read<T>(String key);

  /// Writes [value] under [key].
  Future<void> write<T>(String key, T value);

  /// Deletes whatever is stored under [key]. A no-op if nothing is stored.
  Future<void> remove(String key);
}

/// An in-memory [TinyStatePersistenceAdapter].
///
/// Nothing survives a restart, which makes this useful for tests, for demos,
/// and as a null-object when persistence is disabled in a build flavour.
///
/// ```dart
/// final adapter = MemoryPersistenceAdapter({'themeMode': 1});
/// tinyState.persistenceAdapter = adapter;
/// ```
class MemoryPersistenceAdapter extends TinyStatePersistenceAdapter {
  /// Creates an adapter, optionally pre-populated with [seed].
  MemoryPersistenceAdapter([Map<String, Object?>? seed])
    : _entries = {...?seed};

  final Map<String, Object?> _entries;

  /// An unmodifiable view of everything currently stored.
  ///
  /// Handy for asserting on persisted output in tests.
  Map<String, Object?> get entries => Map.unmodifiable(_entries);

  @override
  Future<T?> read<T>(String key) async => _entries[key] as T?;

  @override
  Future<void> write<T>(String key, T value) async {
    _entries[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _entries.remove(key);
  }
}
