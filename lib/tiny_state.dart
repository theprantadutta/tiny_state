import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'src/persistence.dart';
export 'src/persistence.dart';

/// A private class to hold the notifier and its default value.
class _State<T> {
  final ValueNotifier<T> notifier;
  final T defaultValue;

  _State(this.notifier, this.defaultValue);
}

/// A tiny, global, reactive state manager.
class TinyState {
  /// The internal store for all state notifiers.
  final _store = <String, _State<dynamic>>{};
  final _computedStore = <String, _ComputedValueNotifier<dynamic>>{};

  /// The persistence adapter for saving and loading state.
  TinyStatePersistenceAdapter? persistenceAdapter;

  /// Tracks the key of the computed notifier that is currently being evaluated.
  /// This allows `get()` to know which computed state to register as a dependency.
  String? _currentlyComputingKey;

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
      return _store[key]!.notifier as ValueNotifier<T>;
    }

    // Create the notifier with the default value first.
    final notifier = ValueNotifier<T>(defaultValue);
    _store[key] = _State(notifier, defaultValue);

    // If persistence is enabled, asynchronously load the value and update the notifier.
    if (persist && persistenceAdapter != null) {
      persistenceAdapter!.read<T>(key).then((value) {
        if (value != null) {
          notifier.value = value;
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
    // If a computed value is being evaluated, register this key as a dependency.
    if (_currentlyComputingKey != null &&
        _computedStore.containsKey(_currentlyComputingKey)) {
      _computedStore[_currentlyComputingKey]!.addDependency(key);
    }

    if (_store.containsKey(key)) {
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
    if (_store.containsKey(key)) {
      final state = _store[key]!;
      if (state.notifier.value != value) {
        state.notifier.value = value;
        if (persist && persistenceAdapter != null) {
          persistenceAdapter!.write<T>(key, value);
        }
        // Trigger re-evaluation of any computed states that depend on this key.
        _computedStore.values
            .where((c) => c.dependencies.contains(key))
            .forEach((c) => c.recompute());
      }
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
    if (_store.containsKey(key)) {
      final state = _store[key]!;
      final currentValue = state.notifier.value as T;
      final newValue = updater(currentValue);
      if (currentValue != newValue) {
        state.notifier.value = newValue;
        if (persist && persistenceAdapter != null) {
          persistenceAdapter!.write<T>(key, newValue);
        }
        // Trigger re-evaluation of any computed states that depend on this key.
        _computedStore.values
            .where((c) => c.dependencies.contains(key))
            .forEach((c) => c.recompute());
      }
    }
  }

  /// Resets a state to its original default value.
  ///
  /// - [key]: The unique identifier for the state to reset.
  void reset(String key) {
    if (_store.containsKey(key)) {
      final state = _store[key]!;
      state.notifier.value = state.defaultValue;
    }
  }

  /// Deletes a state from the store.
  ///
  /// This removes the key and its associated [ValueNotifier], and disposes of it.
  ///
  /// - [key]: The unique identifier for the state to delete.
  void delete(String key) {
    if (_store.containsKey(key)) {
      final state = _store.remove(key);
      state?.notifier.dispose();

      // Also remove this key from any computed dependencies and trigger re-computation.
      _computedStore.values
          .where((c) => c.dependencies.contains(key))
          .forEach((c) => c.recompute());
    }
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
    return _SelectValueNotifier(sourceNotifier, selector);
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

    _currentlyComputingKey = key;
    final computedNotifier = _ComputedValueNotifier<T>(key, computer);
    _computedStore[key] = computedNotifier;
    _currentlyComputingKey = null;

    return computedNotifier;
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
    // If the key doesn't exist, we can't listen to it. Return an empty callback.
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

  /// Clears all states and listeners from the store.
  ///
  /// This is useful for resetting the state of the application, for example,
  /// when a user logs out.
  void clear() {
    // Create a copy of the keys to avoid concurrent modification issues.
    final keys = _store.keys.toList();
    for (final key in keys) {
      delete(key);
    }
  }

  /// Watches a [Future] and returns a [ValueNotifier<AsyncSnapshot<T>>].
  ///
  /// This allows you to easily track the state of a future (loading, data, error)
  /// in a reactive way. The future is only executed if the key is being watched
  /// for the first time.
  ///
  /// - [key]: The unique identifier for the future state.
  /// - [future]: A function that returns the future to execute.
  ValueNotifier<AsyncSnapshot<T>> watchFuture<T>(
    String key,
    Future<T> Function() future,
  ) {
    final scopedKey = 'future/$key';
    if (_store.containsKey(scopedKey)) {
      return _store[scopedKey]!.notifier as ValueNotifier<AsyncSnapshot<T>>;
    }

    final notifier = ValueNotifier<AsyncSnapshot<T>>(
      const AsyncSnapshot.waiting(),
    );
    _store[scopedKey] = _State(notifier, const AsyncSnapshot.nothing());

    future().then(
      (data) {
        notifier.value = AsyncSnapshot.withData(ConnectionState.done, data);
      },
      onError: (error, stackTrace) {
        notifier.value = AsyncSnapshot.withError(
          ConnectionState.done,
          error,
          stackTrace,
        );
      },
    );

    return notifier;
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

  _SelectValueNotifier(this._source, this._selector)
    : super(_selector(_source.value)) {
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
    _source.removeListener(_updateValue);
    super.dispose();
  }
}

/// A private [ValueNotifier] that computes its value based on other states.
class _ComputedValueNotifier<T> extends ValueNotifier<T> {
  final String key;
  final T Function() _computer;
  final Set<String> dependencies = {};

  _ComputedValueNotifier(this.key, this._computer) : super(_computer());

  void addDependency(String depKey) {
    dependencies.add(depKey);
  }

  void removeDependency(String depKey) {
    dependencies.remove(depKey);
  }

  void recompute() {
    // Clear old dependencies before re-computing so they can be re-tracked.
    dependencies.clear();
    tinyState._currentlyComputingKey = key;
    final newValue = _computer();
    tinyState._currentlyComputingKey = null;

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
    Future<T> Function() future,
  ) {
    return _root.watchFuture<T>(_scopedKey(key), future);
  }
}
