import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'src/persistence.dart';
export 'src/persistence.dart';

/// A private class to hold the notifier and its default value.
class _State<T> {
  final ValueNotifier<T> notifier;
  final T defaultValue;
  final Type type;

  _State(this.notifier, this.defaultValue, this.type);
}

/// A tiny, global, reactive state manager.
class TinyState {
  /// The internal store for all state notifiers.
  final _store = <String, _State<dynamic>>{};
  final _computedStore = <String, _ComputedValueNotifier<dynamic>>{};

  /// Reverse index: source key -> set of computed keys that depend on it.
  /// Lets `set`/`update`/`delete` find dependents in O(1) instead of scanning.
  final _dependencyIndex = <String, Set<String>>{};

  /// Active select notifiers per source key. Disposed when the source is deleted.
  final _selectNotifiers = <String, List<_SelectValueNotifier<dynamic, dynamic>>>{};

  /// Keys whose persisted value is still loading. If the user calls `set`/`update`
  /// before the load completes, the load is suppressed to avoid clobbering them.
  final _persistLoadPending = <String>{};

  /// Stack of computed keys currently evaluating. Used to nest computed() correctly.
  final _computingStack = <String>[];

  /// Per-frame dependency collector for the currently-evaluating computed.
  /// Keyed by computed key so nested computeds each get their own collector.
  final _trackingFrames = <String, Set<String>>{};

  /// Stored future-runner callbacks per future key, used by `refreshFuture`.
  final _futureRefreshers = <String, void Function()>{};

  /// Generation counter per future key. Lets us ignore stale future completions
  /// after a refresh has been triggered.
  final _futureGenerations = <String, int>{};

  /// The persistence adapter for saving and loading state.
  TinyStatePersistenceAdapter? persistenceAdapter;

  /// When true, `set`/`update`/`get` throw a clear [StateError] if the generic
  /// type does not match the type the key was originally watched with.
  bool strictTypes = true;

  /// Private constructor for the singleton instance.
  TinyState._();

  /// The single, global instance of [TinyState].
  static final TinyState instance = TinyState._();

  /// Watches a state value, returning a [ValueNotifier] that can be listened to.
  ///
  /// If the [key] does not exist, it will be initialized with the [defaultValue].
  ///
  /// - [key]: The unique identifier for the state.
  /// - [defaultValue]: The value to use if the state is not yet initialized.
  /// - [persist]: If `true`, the state will be saved to and loaded from the persistence adapter.
  ValueNotifier<T> watch<T>(
    String key,
    T defaultValue, {
    bool persist = false,
  }) {
    if (_store.containsKey(key)) {
      _checkType<T>(key);
      return _store[key]!.notifier as ValueNotifier<T>;
    }

    final notifier = ValueNotifier<T>(defaultValue);
    _store[key] = _State<T>(notifier, defaultValue, T);

    if (persist && persistenceAdapter != null) {
      _persistLoadPending.add(key);
      persistenceAdapter!.read<T>(key).then((value) {
        // Only apply the loaded value if the user hasn't taken over via set/update,
        // and the key still exists in the store.
        if (_persistLoadPending.remove(key) &&
            value != null &&
            _store.containsKey(key)) {
          notifier.value = value;
          _notifyComputedDependents(key);
        }
      });
    }

    return notifier;
  }

  /// Gets the current value of a state.
  ///
  /// Returns `null` if the key does not exist or if the type is incorrect.
  ///
  /// - [key]: The unique identifier for the state.
  T? get<T>(String key) {
    // If a computed value is being evaluated, register this key as one of its
    // dependencies via the per-frame collector for the top of the stack.
    if (_computingStack.isNotEmpty) {
      _trackingFrames[_computingStack.last]?.add(key);
    }

    if (_store.containsKey(key)) {
      _checkType<T>(key);
      return _store[key]!.notifier.value as T?;
    }
    return null;
  }

  /// Sets the value of a state and notifies listeners.
  ///
  /// The [key] must already exist in the store (e.g., initialized via `watch`).
  /// The type [T] must match the type of the existing notifier.
  ///
  /// - [key]: The unique identifier for the state.
  /// - [value]: The new value to set.
  /// - [persist]: If `true`, the state will be saved to the persistence adapter.
  void set<T>(String key, T value, {bool persist = false}) {
    if (!_store.containsKey(key)) return;
    _checkType<T>(key);
    // User has explicitly written: cancel any pending persist load.
    _persistLoadPending.remove(key);
    final state = _store[key]!;
    if (state.notifier.value != value) {
      state.notifier.value = value;
      if (persist && persistenceAdapter != null) {
        persistenceAdapter!.write<T>(key, value);
      }
      _notifyComputedDependents(key);
    }
  }

  /// Updates a state using a callback function and notifies listeners.
  ///
  /// The [updater] function receives the current value and should return the new value.
  /// The [key] must already exist in the store (e.g., initialized via `watch`).
  /// The type [T] must match the type of the existing notifier.
  ///
  /// - [key]: The unique identifier for the state.
  /// - [updater]: A function that takes the current value and returns the new value.
  /// - [persist]: If `true`, the state will be saved to the persistence adapter.
  void update<T>(String key, T Function(T) updater, {bool persist = false}) {
    if (!_store.containsKey(key)) return;
    _checkType<T>(key);
    _persistLoadPending.remove(key);
    final state = _store[key]!;
    final currentValue = state.notifier.value as T;
    final newValue = updater(currentValue);
    if (currentValue != newValue) {
      state.notifier.value = newValue;
      if (persist && persistenceAdapter != null) {
        persistenceAdapter!.write<T>(key, newValue);
      }
      _notifyComputedDependents(key);
    }
  }

  /// Resets a state to its original default value.
  ///
  /// - [key]: The unique identifier for the state to reset.
  void reset(String key) {
    if (_store.containsKey(key)) {
      final state = _store[key]!;
      state.notifier.value = state.defaultValue;
      _notifyComputedDependents(key);
    }
  }

  /// Deletes a state from the store.
  ///
  /// This removes the key and its associated [ValueNotifier], and disposes of it.
  ///
  /// - [key]: The unique identifier for the state to delete.
  void delete(String key) {
    if (!_store.containsKey(key)) return;

    // Dispose any select notifiers tied to this source first, while the source
    // is still alive so removeListener works.
    final selects = _selectNotifiers.remove(key);
    if (selects != null) {
      for (final s in selects) {
        s.dispose();
      }
    }

    final state = _store.remove(key);
    state?.notifier.dispose();
    _persistLoadPending.remove(key);

    // Also clean future-related state for `future/...` keys.
    _futureRefreshers.remove(key);
    _futureGenerations.remove(key);

    // Trigger re-evaluation of any computed states that depend on this key.
    _notifyComputedDependents(key);
    _dependencyIndex.remove(key);
  }

  /// Selects a transformed value from a state, returning a [ValueListenable].
  ///
  /// The returned listener will only notify when the selected value changes.
  /// Throws an exception if the [key] does not exist.
  ///
  /// - [key]: The unique identifier for the source state.
  /// - [selector]: A function that transforms the state value.
  ValueListenable<R> select<T, R>(String key, R Function(T) selector) {
    if (!_store.containsKey(key)) {
      throw Exception(
        'Cannot select from a non-existent key: "$key". Call watch() first to initialize it.',
      );
    }

    final sourceNotifier = _store[key]!.notifier as ValueNotifier<T>;
    late _SelectValueNotifier<T, R> selectNotifier;
    selectNotifier = _SelectValueNotifier<T, R>(
      sourceNotifier,
      selector,
      onDispose: () {
        _selectNotifiers[key]?.remove(selectNotifier);
        if (_selectNotifiers[key]?.isEmpty ?? false) {
          _selectNotifiers.remove(key);
        }
      },
    );
    _selectNotifiers.putIfAbsent(key, () => []).add(selectNotifier);
    return selectNotifier;
  }

  /// Creates a computed state that derives its value from other states.
  ///
  /// The [computer] function is run once to determine the initial value and
  /// its dependencies. It will be automatically re-run whenever a dependency changes.
  ///
  /// - [key]: The unique identifier for the computed state.
  /// - [computer]: The function that calculates the value.
  ValueListenable<T> computed<T>(String key, T Function() computer) {
    if (_computedStore.containsKey(key)) {
      return _computedStore[key]! as ValueListenable<T>;
    }

    // Run the computer with dependency tracking active. The collected deps
    // are then attached to the new notifier.
    final collected = <String>{};
    _trackingFrames[key] = collected;
    _computingStack.add(key);
    late T initialValue;
    try {
      initialValue = computer();
    } finally {
      _computingStack.removeLast();
      _trackingFrames.remove(key);
    }

    final notifier = _ComputedValueNotifier<T>(key, computer, this, initialValue);
    notifier.dependencies.addAll(collected);
    for (final dep in collected) {
      _dependencyIndex.putIfAbsent(dep, () => <String>{}).add(key);
    }
    _computedStore[key] = notifier;
    return notifier;
  }

  /// Listens to a state and calls the [listener] function when it changes.
  ///
  /// - [key]: The unique identifier for the state to listen to.
  /// - [listener]: The function to call with the new value.
  /// - [fireImmediately]: If `true`, the [listener] is called immediately with the current value.
  /// - [once]: If `true`, the [listener] is automatically removed after the first call.
  ///
  /// Returns a `VoidCallback` function that can be called to cancel the subscription.
  VoidCallback listen<T>(
    String key,
    void Function(T) listener, {
    bool fireImmediately = false,
    bool once = false,
  }) {
    if (!_store.containsKey(key)) {
      return () {};
    }

    final notifier = _store[key]!.notifier as ValueNotifier<T>;

    void listenerWrapper() {
      listener(notifier.value);
      if (once) {
        notifier.removeListener(listenerWrapper);
      }
    }

    notifier.addListener(listenerWrapper);

    if (fireImmediately) {
      listenerWrapper();
    }

    return () => notifier.removeListener(listenerWrapper);
  }

  /// Creates a new scope for state management.
  ///
  /// Scopes provide a way to organize state and prevent key collisions.
  /// All keys used within the scope will be prefixed with the [name].
  TinyStateScope scope(String name) {
    return TinyStateScope(name, this);
  }

  /// Clears all states and listeners from the store. The singleton remains
  /// usable; subsequent `watch` calls re-create notifiers from scratch.
  void clear() {
    final keys = _store.keys.toList();
    for (final key in keys) {
      delete(key);
    }
    // Computed notifiers live outside _store; tear them down too.
    for (final c in _computedStore.values) {
      c.dispose();
    }
    _computedStore.clear();
    _dependencyIndex.clear();
    _trackingFrames.clear();
    _computingStack.clear();
  }

  /// Tears down the entire state manager: clears all states, computed notifiers,
  /// select notifiers, and drops the persistence adapter. After calling this,
  /// the singleton is in a fresh state and ready to be reused.
  void dispose() {
    clear();
    _futureRefreshers.clear();
    _futureGenerations.clear();
    _persistLoadPending.clear();
    persistenceAdapter = null;
    strictTypes = true;
  }

  /// Watches a [Future] and returns a [ValueNotifier] of [AsyncSnapshot].
  ///
  /// On first call for [key], the [future] function is invoked. Subsequent calls
  /// return the cached notifier without re-running the future, unless [refresh]
  /// is true (in which case the notifier is reset to waiting and the future
  /// is re-run).
  ///
  /// - [key]: The unique identifier for the future state.
  /// - [future]: A function that returns the future to execute.
  /// - [refresh]: If true and the key already exists, re-runs the future.
  ValueNotifier<AsyncSnapshot<T>> watchFuture<T>(
    String key,
    Future<T> Function() future, {
    bool refresh = false,
  }) {
    final scopedKey = 'future/$key';
    final alreadyExists = _store.containsKey(scopedKey);

    if (alreadyExists && !refresh) {
      return _store[scopedKey]!.notifier as ValueNotifier<AsyncSnapshot<T>>;
    }

    late ValueNotifier<AsyncSnapshot<T>> notifier;
    if (alreadyExists) {
      notifier = _store[scopedKey]!.notifier as ValueNotifier<AsyncSnapshot<T>>;
    } else {
      notifier = ValueNotifier<AsyncSnapshot<T>>(const AsyncSnapshot.waiting());
      _store[scopedKey] = _State<AsyncSnapshot<T>>(
        notifier,
        const AsyncSnapshot.nothing(),
        AsyncSnapshot,
      );
    }

    void runFuture() {
      final gen = (_futureGenerations[scopedKey] ?? 0) + 1;
      _futureGenerations[scopedKey] = gen;
      notifier.value = const AsyncSnapshot.waiting();
      future().then(
        (data) {
          if (_store.containsKey(scopedKey) &&
              _futureGenerations[scopedKey] == gen) {
            notifier.value = AsyncSnapshot.withData(ConnectionState.done, data);
          }
        },
        onError: (error, stackTrace) {
          if (_store.containsKey(scopedKey) &&
              _futureGenerations[scopedKey] == gen) {
            notifier.value = AsyncSnapshot.withError(
              ConnectionState.done,
              error,
              stackTrace,
            );
          }
        },
      );
    }

    _futureRefreshers[scopedKey] = runFuture;
    runFuture();
    return notifier;
  }

  /// Re-runs the future previously registered for [key] via [watchFuture].
  /// The notifier is reset to [AsyncSnapshot.waiting] until the new future settles.
  /// No-op if [key] was never watched.
  void refreshFuture(String key) {
    final scopedKey = 'future/$key';
    _futureRefreshers[scopedKey]?.call();
  }

  /// Notify computeds whose dependency set contains [key].
  void _notifyComputedDependents(String key) {
    final dependents = _dependencyIndex[key];
    if (dependents == null || dependents.isEmpty) return;
    // Snapshot to avoid concurrent modification while a recompute may rewrite deps.
    final toRecompute = dependents.toList();
    for (final computedKey in toRecompute) {
      _computedStore[computedKey]?.recompute();
    }
  }

  /// Throws if [T] does not match the type the key was originally registered with.
  /// Skipped when [strictTypes] is false or when the caller used `dynamic`/`Object`.
  void _checkType<T>(String key) {
    if (!strictTypes) return;
    if (T == dynamic || T == Object) return;
    final stored = _store[key]?.type;
    if (stored == null || stored == dynamic || stored == T) return;
    throw StateError(
      'Type mismatch for key "$key": expected $stored but got $T. '
      'Set tinyState.strictTypes = false to disable this check.',
    );
  }
}

/// A convenient global accessor for the [TinyState] instance.
final tinyState = TinyState.instance;

/// A private [ValueNotifier] that listens to a source notifier and transforms its value.
///
/// It only notifies its own listeners if the transformed value has changed.
class _SelectValueNotifier<T, R> extends ValueNotifier<R> {
  final ValueNotifier<T> _source;
  final R Function(T) _selector;
  final void Function()? _onDispose;
  bool _disposed = false;

  _SelectValueNotifier(
    this._source,
    this._selector, {
    void Function()? onDispose,
  })  : _onDispose = onDispose,
        super(_selector(_source.value)) {
    _source.addListener(_updateValue);
  }

  void _updateValue() {
    final newValue = _selector(_source.value);
    if (value != newValue) {
      value = newValue;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // Source may have been disposed already (e.g., by `delete()` calling us).
    // Guard against post-dispose listener removal.
    try {
      _source.removeListener(_updateValue);
    } catch (_) {
      // Source was disposed first; listener is already gone.
    }
    _onDispose?.call();
    super.dispose();
  }
}

/// A private [ValueNotifier] that computes its value based on other states.
class _ComputedValueNotifier<T> extends ValueNotifier<T> {
  final String key;
  final T Function() _computer;
  final TinyState _root;
  final Set<String> dependencies = {};

  _ComputedValueNotifier(this.key, this._computer, this._root, T initialValue)
      : super(initialValue);

  void recompute() {
    // Strip old dependencies from the reverse index.
    for (final dep in dependencies) {
      _root._dependencyIndex[dep]?.remove(key);
      if (_root._dependencyIndex[dep]?.isEmpty ?? false) {
        _root._dependencyIndex.remove(dep);
      }
    }
    dependencies.clear();

    final collected = <String>{};
    _root._trackingFrames[key] = collected;
    _root._computingStack.add(key);
    late T newValue;
    try {
      newValue = _computer();
    } finally {
      _root._computingStack.removeLast();
      _root._trackingFrames.remove(key);
    }

    dependencies.addAll(collected);
    for (final dep in collected) {
      _root._dependencyIndex.putIfAbsent(dep, () => <String>{}).add(key);
    }

    if (value != newValue) {
      value = newValue;
    }
  }
}

/// Represents a scoped instance of [TinyState].
///
/// All method calls are forwarded to the root [TinyState] instance
/// with the keys automatically prefixed by the scope name.
class TinyStateScope {
  final String _name;
  final TinyState _root;

  TinyStateScope(this._name, this._root);

  String _scopedKey(String key) => '$_name/$key';

  ValueNotifier<T> watch<T>(
    String key,
    T defaultValue, {
    bool persist = false,
  }) {
    return _root.watch<T>(_scopedKey(key), defaultValue, persist: persist);
  }

  T? get<T>(String key) {
    return _root.get<T>(_scopedKey(key));
  }

  void set<T>(String key, T value, {bool persist = false}) {
    _root.set<T>(_scopedKey(key), value, persist: persist);
  }

  void update<T>(String key, T Function(T) updater, {bool persist = false}) {
    _root.update<T>(_scopedKey(key), updater, persist: persist);
  }

  void reset(String key) {
    _root.reset(_scopedKey(key));
  }

  void delete(String key) {
    _root.delete(_scopedKey(key));
  }

  ValueListenable<R> select<T, R>(String key, R Function(T) selector) {
    return _root.select<T, R>(_scopedKey(key), selector);
  }

  ValueListenable<T> computed<T>(String key, T Function() computer) {
    return _root.computed<T>(_scopedKey(key), computer);
  }

  VoidCallback listen<T>(
    String key,
    void Function(T) listener, {
    bool fireImmediately = false,
    bool once = false,
  }) {
    return _root.listen<T>(
      _scopedKey(key),
      listener,
      fireImmediately: fireImmediately,
      once: once,
    );
  }

  /// Clears all states and listeners within this scope.
  void clear() {
    final keysInScope = _root._store.keys
        .where((key) => key.startsWith('$_name/'))
        .toList();
    for (final key in keysInScope) {
      _root.delete(key);
    }
  }

  ValueNotifier<AsyncSnapshot<T>> watchFuture<T>(
    String key,
    Future<T> Function() future, {
    bool refresh = false,
  }) {
    return _root.watchFuture<T>(_scopedKey(key), future, refresh: refresh);
  }

  void refreshFuture(String key) {
    _root.refreshFuture(_scopedKey(key));
  }
}
