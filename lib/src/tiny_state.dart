import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'persistence.dart';

/// Separator used to build scoped keys.
///
/// User-supplied keys and scope names may not contain it, which is what makes
/// scoped keys collision-proof against global ones.
const String _sep = '/';

/// Reserved prefix for keys created by [TinyState.watchFuture].
const String _futurePrefix = 'future$_sep';

/// Scope names that would collide with an internal prefix.
const Set<String> _reservedScopeNames = {'future'};

/// Signature for [TinyState.onError].
///
/// [context] is a short human-readable description of what `tiny_state` was
/// doing, e.g. `'recomputing computed state "fullName"'`.
typedef TinyStateErrorHandler =
    void Function(Object error, StackTrace stackTrace, String context);

/// Internal record for one piece of state.
class _State<T> {
  _State(this.notifier, this.defaultValue, {required this.persist});

  final ValueNotifier<T> notifier;
  final T defaultValue;

  /// Declared once, at the `watch` call that created the key.
  final bool persist;

  /// Whether the notifier can safely be handed out as a `ValueNotifier<U>`.
  ///
  /// Generic types are covariant in Dart, so this is exactly the condition
  /// under which `notifier as ValueNotifier<U>` succeeds.
  bool isReadableAs<U>() => <T>[] is List<U>;

  /// Whether [U] and [T] overlap in either direction.
  ///
  /// Used for value-level reads and writes, which pass through `dynamic` and
  /// are checked by the runtime anyway. The looser check is what lets
  /// `set<int>` work against a key watched as `int?`.
  bool accepts<U>() => <T>[] is List<U> || <U>[] is List<T>;

  String get typeLabel => T.toString();
}

/// A tiny, global, reactive state manager.
///
/// Use the global [tinyState] singleton for app state; construct your own
/// instance when you want an isolated store (tests, or a feature module that
/// should not share a keyspace with the rest of the app).
///
/// ```dart
/// final counter = tinyState.watch<int>('counter', 0);
/// tinyState.update<int>('counter', (n) => n + 1);
/// ```
class TinyState {
  /// Creates an independent state manager.
  ///
  /// Most apps want the global [tinyState] singleton instead.
  TinyState();

  /// The single, global instance backing [tinyState].
  static final TinyState instance = TinyState();

  // --- stores -------------------------------------------------------------

  final Map<String, _State<dynamic>> _store = {};
  final Map<String, _ComputedValueNotifier<dynamic>> _computedStore = {};

  /// Reverse index: source key -> computed keys that read it.
  final Map<String, Set<String>> _dependencyIndex = {};

  /// Memoized selectors, keyed by slot (see [_selectSlot]).
  final Map<String, _SelectValueNotifier<dynamic, dynamic>> _selects = {};

  /// Source key -> slots derived from it, so `delete` can tear them down.
  final Map<String, Set<String>> _selectSlotsBySource = {};

  /// Keys of computeds currently evaluating, innermost last.
  final List<String> _computingStack = [];

  /// Dependency collector for each in-flight computed evaluation.
  final Map<String, Set<String>> _trackingFrames = {};

  final Map<String, void Function()> _futureRefreshers = {};
  final Map<String, int> _futureGenerations = {};

  /// In-flight persistence reads and writes, for [flushPersistence].
  final Map<String, Future<void>> _pendingLoads = {};
  final Map<String, Future<void>> _pendingWrites = {};

  /// Keys the caller has written to while a rehydrate was still in flight.
  /// The load result is discarded for these, so it cannot clobber the write.
  final Set<String> _loadSuperseded = {};

  bool _tearingDown = false;

  // --- configuration ------------------------------------------------------

  /// Where persisted state is read from and written to.
  ///
  /// `null` (the default) means persistence is unavailable; watching a key with
  /// `persist: true` while this is unset reports an error through [onError]
  /// rather than failing silently.
  TinyStatePersistenceAdapter? persistenceAdapter;

  /// Whether value-level generic mismatches throw instead of being coerced.
  ///
  /// When `true` (the default), `get`/`set`/`update` throw a [StateError] if
  /// the generic does not overlap the type the key was watched with.
  ///
  /// This only relaxes *value-level* checks. Handing out a typed notifier
  /// ([watch], [select], [listen]) is always checked, because the cast would
  /// fail with a far worse message otherwise.
  bool strictTypes = true;

  /// Called when `tiny_state` catches an error it cannot surface to a caller:
  /// a failed persistence read or write, or a `computed` builder that threw
  /// during a recompute.
  ///
  /// When `null`, errors go to [FlutterError.reportError].
  TinyStateErrorHandler? onError;

  // --- key validation -----------------------------------------------------

  static void _validateKey(String key, String label) {
    if (key.isEmpty) {
      throw ArgumentError.value(key, label, 'must not be empty');
    }
    if (key.contains(_sep)) {
      throw ArgumentError.value(
        key,
        label,
        'must not contain "$_sep" — that character is reserved for scopes. '
        'Use tinyState.scope(...) to namespace keys instead',
      );
    }
  }

  void _report(Object error, StackTrace stackTrace, String context) {
    final handler = onError;
    if (handler != null) {
      handler(error, stackTrace, context);
      return;
    }
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'tiny_state',
        context: ErrorDescription(context),
      ),
    );
  }

  // --- core API -----------------------------------------------------------

  /// Returns the [ValueNotifier] for [key], creating it with [defaultValue]
  /// the first time it is seen.
  ///
  /// Calling `watch` again with the same key returns the same notifier; the
  /// [defaultValue] and [persist] flag of later calls are ignored, so the first
  /// call is the one that defines the key.
  ///
  /// Set [persist] to `true` to save every change through [persistenceAdapter]
  /// and rehydrate the value on startup. Persistence is a property of the key,
  /// so `set`, `update`, `reset` and `delete` all honour it without repeating
  /// the flag.
  ///
  /// Throws an [ArgumentError] if [key] is empty or contains `'/'`, and a
  /// [StateError] if [key] is already a [computed].
  ValueNotifier<T> watch<T>(
    String key,
    T defaultValue, {
    bool persist = false,
  }) {
    _validateKey(key, 'key');
    return _watch<T>(key, defaultValue, persist: persist);
  }

  ValueNotifier<T> _watch<T>(
    String key,
    T defaultValue, {
    required bool persist,
  }) {
    final existing = _store[key];
    if (existing != null) {
      _assertReadableAs<T>(key, existing);
      return existing.notifier as ValueNotifier<T>;
    }
    if (_computedStore.containsKey(key)) {
      throw StateError(
        'Cannot watch "$key": it is already registered as a computed state. '
        'Computed states are read-only; give the writable state its own key.',
      );
    }

    final notifier = ValueNotifier<T>(defaultValue);
    _store[key] = _State<T>(notifier, defaultValue, persist: persist);
    if (persist) _rehydrate<T>(key, notifier);

    // A computed may have read this key before it existed, in which case it is
    // holding the `null` fallback and needs to re-run.
    _notifyComputedDependents(key);
    return notifier;
  }

  /// Reads the current value of [key] without subscribing to it.
  ///
  /// Returns `null` when the key does not exist. Works for both regular state
  /// and [computed] state.
  ///
  /// Calls made from inside a [computed] builder are recorded as dependencies
  /// of that computed — this is how automatic dependency tracking works.
  ///
  /// Throws a [StateError] if [T] does not overlap the type the key holds and
  /// [strictTypes] is `true`.
  T? get<T>(String key) {
    _validateKey(key, 'key');
    return _get<T>(key);
  }

  T? _get<T>(String key) {
    _trackDependency(key);

    final state = _store[key];
    if (state != null) {
      _assertAccepts<T>(key, state);
      return state.notifier.value as T?;
    }

    final computed = _computedStore[key];
    if (computed != null) {
      _assertComputedAccepts<T>(key, computed);
      return computed.value as T?;
    }

    return null;
  }

  /// Sets [key] to [value] and notifies listeners.
  ///
  /// Does nothing if the value is unchanged (`==`). If the key was watched with
  /// `persist: true`, the new value is written through [persistenceAdapter].
  ///
  /// Throws a [StateError] if [key] has not been created with [watch] — a
  /// dropped write is a much harder bug to find than a thrown one.
  void set<T>(String key, T value) {
    _validateKey(key, 'key');
    _set<T>(key, value);
  }

  void _set<T>(String key, T value) {
    final state = _requireState(key, 'set');
    _assertAccepts<T>(key, state);
    _loadSuperseded.add(key);

    if (state.notifier.value == value) return;
    state.notifier.value = value;
    if (state.persist) _enqueueWrite<T>(key, value);
    _notifyComputedDependents(key);
  }

  /// Replaces the value of [key] with `updater(currentValue)`.
  ///
  /// Reading and writing in one step avoids the lost-update race you get from
  /// `set(key, get(key)! + 1)`.
  ///
  /// > [updater] must return a *new* value. Mutating the current value in place
  /// > and returning it will not notify, because the equality check sees the
  /// > same object. Copy the list/map/model instead.
  ///
  /// Throws a [StateError] if [key] has not been created with [watch].
  void update<T>(String key, T Function(T current) updater) {
    _validateKey(key, 'key');
    _update<T>(key, updater);
  }

  void _update<T>(String key, T Function(T current) updater) {
    final state = _requireState(key, 'update');
    _assertAccepts<T>(key, state);
    _loadSuperseded.add(key);

    final current = state.notifier.value as T;
    final next = updater(current);
    if (current == next) return;
    state.notifier.value = next;
    if (state.persist) _enqueueWrite<T>(key, next);
    _notifyComputedDependents(key);
  }

  /// Restores [key] to the default value it was watched with.
  ///
  /// For a persisted key this also deletes the stored entry, so the value comes
  /// from the default declared in code on the next launch — not from whatever
  /// was on disk before the reset.
  ///
  /// Throws a [StateError] if [key] has not been created with [watch].
  void reset(String key) {
    _validateKey(key, 'key');
    _reset(key);
  }

  void _reset(String key) {
    final state = _requireState(key, 'reset');
    _loadSuperseded.add(key);
    if (state.persist) _enqueueRemove(key);

    if (state.notifier.value == state.defaultValue) return;
    state.notifier.value = state.defaultValue;
    _notifyComputedDependents(key);
  }

  /// Removes [key] and disposes everything derived from it.
  ///
  /// Works on both regular state and [computed] state. Deleting a key that does
  /// not exist is a no-op, so this is safe to call unconditionally.
  ///
  /// For a persisted key the stored entry is deleted too.
  ///
  /// > The notifier is disposed. Any widget still listening to a notifier from
  /// > a previous `watch` of this key will throw "used after dispose" on the
  /// > next change — re-`watch` after deleting.
  void delete(String key) {
    _validateKey(key, 'key');
    _delete(key);
  }

  void _delete(String key) {
    final computed = _computedStore.remove(key);
    if (computed != null) {
      computed.unindex();
      computed.dispose();
      return;
    }

    final state = _store.remove(key);
    if (state == null) return;

    // Selectors must be torn down while their source is still alive.
    for (final slot in _selectSlotsBySource.remove(key) ?? const <String>{}) {
      _selects.remove(slot)?.dispose();
    }

    state.notifier.dispose();
    _loadSuperseded.remove(key);
    _futureRefreshers.remove(key);
    _futureGenerations.remove(key);
    if (state.persist) _enqueueRemove(key);

    // Dependents re-run and see `null`; their index entries stay in place so
    // they wake up again if the key is re-created.
    _notifyComputedDependents(key);
  }

  /// Derives a value from [key] that only notifies when the *derived* value
  /// changes.
  ///
  /// ```dart
  /// final isEven = tinyState.select<int, bool>(
  ///   'counter',
  ///   (n) => n.isEven,
  ///   id: 'isEven',
  /// );
  /// ```
  ///
  /// The result is memoized on `(key, id)`, so calling `select` from inside
  /// `build` returns the same listenable every time instead of leaking a new
  /// one per rebuild. [id] is required for exactly that reason: two different
  /// projections of the same key need two different ids.
  ///
  /// The returned listenable is owned by `TinyState` — do not dispose it. It is
  /// torn down automatically when [key] is deleted or the store is cleared.
  ///
  /// Throws a [StateError] if [key] does not exist, or if the same `(key, id)`
  /// was already created with different type arguments.
  ValueListenable<R> select<T, R>(
    String key,
    R Function(T value) selector, {
    required String id,
  }) {
    _validateKey(key, 'key');
    _validateKey(id, 'id');
    return _select<T, R>(key, selector, id);
  }

  ValueListenable<R> _select<T, R>(
    String key,
    R Function(T value) selector,
    String id,
  ) {
    final slot = _selectSlot(key, id);
    final existing = _selects[slot];
    if (existing != null) {
      if (existing is! _SelectValueNotifier<T, R>) {
        throw StateError(
          'select("$key", id: "$id") already exists with different type '
          'arguments (${existing.typeLabel}, requested <$T, $R>). '
          'Use a different id for a different projection.',
        );
      }
      return existing;
    }

    final state = _requireState(key, 'select from');
    _assertReadableAs<T>(key, state);

    final notifier = _SelectValueNotifier<T, R>(
      state.notifier as ValueNotifier<T>,
      selector,
    );
    _selects[slot] = notifier;
    _selectSlotsBySource.putIfAbsent(key, () => <String>{}).add(slot);
    return notifier;
  }

  /// Length-prefixed so no `(key, id)` pair can collide with another.
  static String _selectSlot(String key, String id) => '${key.length}:$key:$id';

  /// Registers a value derived from other state, re-evaluated automatically
  /// when anything it read changes.
  ///
  /// Dependencies are discovered by recording the [get] calls the builder
  /// makes, including `get` of another computed — derived state composes.
  ///
  /// ```dart
  /// final fullName = tinyState.computed<String>('fullName', () {
  ///   final first = tinyState.get<String>('firstName') ?? '';
  ///   final last = tinyState.get<String>('lastName') ?? '';
  ///   return '$first $last';
  /// });
  /// ```
  ///
  /// Like [watch], the first call defines the key: later calls return the
  /// existing listenable and ignore the builder passed to them.
  ///
  /// Evaluation is lazy while nothing is listening — the builder re-runs on the
  /// next read instead of on every dependency change. Once a listener is
  /// attached it re-runs eagerly, because that is the only way to know whether
  /// to notify.
  ///
  /// If the builder throws during a re-evaluation the error is reported through
  /// [onError] and the previous value is kept; a throw during the *first*
  /// evaluation propagates to the caller.
  ///
  /// Throws a [StateError] if [key] is already a regular state key.
  ValueListenable<T> computed<T>(String key, T Function() builder) {
    _validateKey(key, 'key');
    return _computed<T>(key, builder);
  }

  ValueListenable<T> _computed<T>(String key, T Function() builder) {
    final existing = _computedStore[key];
    if (existing != null) {
      if (existing is! _ComputedValueNotifier<T>) {
        throw StateError(
          'computed("$key") already exists as ${existing.typeLabel} but was '
          'requested as $T.',
        );
      }
      return existing;
    }
    if (_store.containsKey(key)) {
      throw StateError(
        'Cannot create computed "$key": it is already a regular state key. '
        'Computed states need a key of their own.',
      );
    }
    if (_computingStack.contains(key)) {
      throw StateError(
        'Circular dependency: computed "$key" is referenced while it is still '
        'being created.',
      );
    }

    final collected = <String>{};
    _trackingFrames[key] = collected;
    _computingStack.add(key);
    final T initialValue;
    try {
      initialValue = builder();
    } finally {
      _computingStack.removeLast();
      _trackingFrames.remove(key);
    }

    final notifier = _ComputedValueNotifier<T>(
      key,
      builder,
      this,
      initialValue,
    );
    _computedStore[key] = notifier;
    notifier.applyDependencies(collected);
    return notifier;
  }

  /// Calls [listener] whenever [key] changes. Returns a cancel callback.
  ///
  /// Works for regular state and [computed] state.
  ///
  /// * [fireImmediately] invokes [listener] once with the current value.
  /// * [once] removes the subscription after the first invocation.
  ///
  /// Cancelling twice, or cancelling after [key] was deleted, is safe.
  ///
  /// Throws a [StateError] if [key] does not exist.
  VoidCallback listen<T>(
    String key,
    void Function(T value) listener, {
    bool fireImmediately = false,
    bool once = false,
  }) {
    _validateKey(key, 'key');
    return _listen<T>(
      key,
      listener,
      fireImmediately: fireImmediately,
      once: once,
    );
  }

  VoidCallback _listen<T>(
    String key,
    void Function(T value) listener, {
    required bool fireImmediately,
    required bool once,
  }) {
    final ValueListenable<T> listenable;
    final state = _store[key];
    if (state != null) {
      _assertReadableAs<T>(key, state);
      listenable = state.notifier as ValueListenable<T>;
    } else {
      final computed = _computedStore[key];
      if (computed == null) {
        throw StateError(
          'Cannot listen to "$key": no such state. '
          'Call watch("$key", <default>) first.',
        );
      }
      if (computed is! _ComputedValueNotifier<T>) {
        throw StateError(
          'Cannot listen to computed "$key" as $T: it is '
          '${computed.typeLabel}.',
        );
      }
      listenable = computed;
    }

    var cancelled = false;

    void wrapper() {
      if (cancelled) return;
      // Unsubscribe before invoking, so a listener that mutates state cannot
      // re-enter a `once` subscription.
      if (once) {
        cancelled = true;
        listenable.removeListener(wrapper);
      }
      listener(listenable.value);
    }

    listenable.addListener(wrapper);
    if (fireImmediately) wrapper();

    return () {
      if (cancelled) return;
      cancelled = true;
      listenable.removeListener(wrapper);
    };
  }

  /// Returns a view of this store whose keys are prefixed with [name].
  ///
  /// Scopes are the supported way to namespace keys — `'/'` is rejected inside
  /// keys precisely so that `scope('cart').watch('count')` can never collide
  /// with a global key.
  ///
  /// Throws an [ArgumentError] if [name] is empty, contains `'/'`, or is
  /// reserved for internal use.
  TinyStateScope scope(String name) {
    _validateKey(name, 'name');
    if (_reservedScopeNames.contains(name)) {
      throw ArgumentError.value(
        name,
        'name',
        'is reserved for internal use by tiny_state',
      );
    }
    return TinyStateScope(name, this);
  }

  // --- async --------------------------------------------------------------

  /// Runs [future] once and exposes its progress as an [AsyncSnapshot].
  ///
  /// The first call for [key] starts the future; later calls return the cached
  /// notifier without re-running it, unless [refresh] is `true`.
  ///
  /// Results from a superseded run are discarded, so a slow first request
  /// cannot overwrite the result of a newer one.
  ///
  /// Future keys live in their own namespace and cannot collide with regular
  /// state keys.
  ValueNotifier<AsyncSnapshot<T>> watchFuture<T>(
    String key,
    Future<T> Function() future, {
    bool refresh = false,
  }) {
    _validateKey(key, 'key');
    return _watchFuture<T>('$_futurePrefix$key', future, refresh: refresh);
  }

  ValueNotifier<AsyncSnapshot<T>> _watchFuture<T>(
    String storeKey,
    Future<T> Function() future, {
    required bool refresh,
  }) {
    final existing = _store[storeKey];
    final ValueNotifier<AsyncSnapshot<T>> notifier;

    if (existing != null) {
      _assertReadableAs<AsyncSnapshot<T>>(storeKey, existing);
      notifier = existing.notifier as ValueNotifier<AsyncSnapshot<T>>;
      if (!refresh) return notifier;
    } else {
      notifier = ValueNotifier<AsyncSnapshot<T>>(const AsyncSnapshot.waiting());
      _store[storeKey] = _State<AsyncSnapshot<T>>(
        notifier,
        const AsyncSnapshot.nothing(),
        persist: false,
      );
    }

    void run() {
      final generation = (_futureGenerations[storeKey] ?? 0) + 1;
      _futureGenerations[storeKey] = generation;
      notifier.value = const AsyncSnapshot.waiting();

      bool isCurrent() =>
          identical(_store[storeKey]?.notifier, notifier) &&
          _futureGenerations[storeKey] == generation;

      future().then(
        (data) {
          if (!isCurrent()) return;
          notifier.value = AsyncSnapshot.withData(ConnectionState.done, data);
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!isCurrent()) return;
          notifier.value = AsyncSnapshot.withError(
            ConnectionState.done,
            error,
            stackTrace,
          );
        },
      );
    }

    _futureRefreshers[storeKey] = run;
    run();
    return notifier;
  }

  /// Re-runs the future registered for [key] by [watchFuture].
  ///
  /// The snapshot returns to [AsyncSnapshot.waiting] until the new run settles.
  /// A no-op if [key] was never watched.
  void refreshFuture(String key) {
    _validateKey(key, 'key');
    _futureRefreshers['$_futurePrefix$key']?.call();
  }

  /// Discards the cached future for [key], so the next [watchFuture] starts a
  /// fresh run. A no-op if [key] was never watched.
  void deleteFuture(String key) {
    _validateKey(key, 'key');
    _delete('$_futurePrefix$key');
  }

  // --- persistence --------------------------------------------------------

  void _rehydrate<T>(String key, ValueNotifier<T> notifier) {
    final adapter = persistenceAdapter;
    if (adapter == null) {
      _report(
        StateError(
          'State "$key" was watched with persist: true but no '
          'persistenceAdapter is configured.',
        ),
        StackTrace.current,
        'rehydrating "$key"',
      );
      return;
    }

    final load = adapter
        .read<T>(key)
        .then((value) {
          // A write that happened while the read was in flight wins.
          if (_loadSuperseded.contains(key)) return;
          if (value == null) return;
          if (!identical(_store[key]?.notifier, notifier)) return;
          notifier.value = value;
          _notifyComputedDependents(key);
        })
        .catchError((Object error, StackTrace stackTrace) {
          _report(error, stackTrace, 'reading persisted state "$key"');
        })
        .whenComplete(() {
          _pendingLoads.remove(key);
          _loadSuperseded.remove(key);
        });

    _pendingLoads[key] = load;
  }

  void _enqueueWrite<T>(String key, T value) {
    _enqueue(key, (adapter) => adapter.write<T>(key, value), 'writing');
  }

  void _enqueueRemove(String key) {
    _enqueue(key, (adapter) => adapter.remove(key), 'removing');
  }

  void _enqueue(
    String key,
    Future<void> Function(TinyStatePersistenceAdapter adapter) operation,
    String verb,
  ) {
    final adapter = persistenceAdapter;
    if (adapter == null) {
      _report(
        StateError(
          'State "$key" is persisted but no persistenceAdapter is configured.',
        ),
        StackTrace.current,
        '$verb persisted state "$key"',
      );
      return;
    }

    // Serialize per key so two writes cannot land out of order.
    final previous = _pendingWrites[key] ?? Future<void>.value();
    late final Future<void> next;
    next = previous
        .then((_) => operation(adapter))
        .catchError((Object error, StackTrace stackTrace) {
          _report(error, stackTrace, '$verb persisted state "$key"');
        })
        .whenComplete(() {
          if (identical(_pendingWrites[key], next)) _pendingWrites.remove(key);
        });
    _pendingWrites[key] = next;
  }

  /// Completes when every pending persistence read and write has settled.
  ///
  /// Persistence is fire-and-forget by design, so this exists for the two cases
  /// where you need to wait: asserting on stored values in a test, and flushing
  /// before the app is torn down.
  Future<void> flushPersistence() async {
    while (_pendingLoads.isNotEmpty || _pendingWrites.isNotEmpty) {
      await Future.wait<void>([
        ..._pendingLoads.values,
        ..._pendingWrites.values,
      ]);
    }
  }

  // --- teardown -----------------------------------------------------------

  /// Removes all state, computeds, selectors and futures from this store.
  ///
  /// Configuration ([persistenceAdapter], [strictTypes], [onError]) is left
  /// alone, and persisted data on disk is untouched — `clear` is a lifecycle
  /// operation on the container, not a semantic one on the values. This is the
  /// call you want in a test `setUp`.
  void clear() {
    _tearingDown = true;
    try {
      for (final computed in _computedStore.values) {
        computed.dispose();
      }
      _computedStore.clear();

      for (final select in _selects.values) {
        select.dispose();
      }
      _selects.clear();
      _selectSlotsBySource.clear();

      for (final state in _store.values) {
        state.notifier.dispose();
      }
      _store.clear();

      _dependencyIndex.clear();
      _trackingFrames.clear();
      _computingStack.clear();
      _loadSuperseded.clear();
      _futureRefreshers.clear();
      _futureGenerations.clear();
    } finally {
      _tearingDown = false;
    }
  }

  /// [clear]s the store and resets configuration to defaults.
  ///
  /// Use this when you are done with an instance entirely. To reset state while
  /// keeping the adapter you just configured, use [clear].
  void dispose() {
    clear();
    persistenceAdapter = null;
    onError = null;
    strictTypes = true;
  }

  // --- internals ----------------------------------------------------------

  _State<dynamic> _requireState(String key, String operation) {
    final state = _store[key];
    if (state != null) return state;
    if (_computedStore.containsKey(key)) {
      throw StateError(
        'Cannot $operation "$key": it is a computed state, which is read-only.',
      );
    }
    throw StateError(
      'Cannot $operation "$key": no such state. '
      'Call watch("$key", <default>) first.',
    );
  }

  void _assertReadableAs<T>(String key, _State<dynamic> state) {
    if (T == dynamic || state.isReadableAs<T>()) return;
    throw StateError(
      'Type mismatch for state "$key": it holds ${state.typeLabel}, which '
      'cannot be handed out as $T.',
    );
  }

  void _assertAccepts<T>(String key, _State<dynamic> state) {
    if (!strictTypes) return;
    if (T == dynamic || T == Object || state.accepts<T>()) return;
    throw StateError(
      'Type mismatch for state "$key": it holds ${state.typeLabel} but was '
      'accessed as $T. Set strictTypes = false to disable this check.',
    );
  }

  void _assertComputedAccepts<T>(
    String key,
    _ComputedValueNotifier<dynamic> computed,
  ) {
    if (!strictTypes) return;
    if (T == dynamic || T == Object || computed.accepts<T>()) return;
    throw StateError(
      'Type mismatch for computed "$key": it holds ${computed.typeLabel} but '
      'was accessed as $T. Set strictTypes = false to disable this check.',
    );
  }

  /// Records [key] as a dependency of the computed currently evaluating.
  void _trackDependency(String key) {
    if (_computingStack.isEmpty) return;
    final current = _computingStack.last;
    if (current == key) return; // never depend on yourself
    _trackingFrames[current]?.add(key);
  }

  void _notifyComputedDependents(String key) {
    if (_tearingDown) return;
    final dependents = _dependencyIndex[key];
    if (dependents == null || dependents.isEmpty) return;
    for (final computedKey in dependents.toList(growable: false)) {
      _computedStore[computedKey]?.markDirty();
    }
  }
}

/// The global [TinyState] instance.
final TinyState tinyState = TinyState.instance;

/// A [ValueNotifier] that projects a source notifier through a selector and
/// only notifies when the projection changes.
///
/// Owned by [TinyState]; never constructed or disposed by user code.
class _SelectValueNotifier<T, R> extends ValueNotifier<R> {
  _SelectValueNotifier(this._source, this._selector)
    : super(_selector(_source.value)) {
    _source.addListener(_update);
  }

  final ValueNotifier<T> _source;
  final R Function(T value) _selector;
  bool _disposed = false;

  String get typeLabel => '<$T, $R>';

  void _update() {
    final next = _selector(_source.value);
    if (value != next) value = next;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _source.removeListener(_update);
    super.dispose();
  }
}

/// A [ValueNotifier] whose value is derived from other state.
///
/// Recomputation is lazy while nothing is listening: a dependency change marks
/// the value dirty and the builder re-runs on the next read. With listeners
/// attached it recomputes immediately, since notification requires knowing the
/// new value.
class _ComputedValueNotifier<T> extends ValueNotifier<T> {
  _ComputedValueNotifier(this.key, this._builder, this._root, super.value);

  final String key;
  final T Function() _builder;
  final TinyState _root;

  /// Keys this computed read during its last successful evaluation.
  final Set<String> dependencies = <String>{};

  bool _dirty = false;
  bool _disposed = false;

  String get typeLabel => T.toString();

  bool accepts<U>() => <T>[] is List<U> || <U>[] is List<T>;

  @override
  T get value {
    _root._trackDependency(key);
    if (_dirty && !_disposed) _recompute();
    return super.value;
  }

  /// Called when something this computed depends on has changed.
  void markDirty() {
    if (_disposed) return;
    if (hasListeners) {
      _recompute();
      return;
    }
    if (_dirty) return;
    _dirty = true;
    // Downstream computeds must learn about this even though we have not
    // re-evaluated yet, or they would keep serving a stale value.
    _root._notifyComputedDependents(key);
  }

  void _recompute() {
    _dirty = false;
    if (_root._computingStack.contains(key)) {
      _root._report(
        StateError('Circular dependency detected while recomputing "$key".'),
        StackTrace.current,
        'recomputing computed state "$key"',
      );
      return;
    }

    final collected = <String>{};
    _root._trackingFrames[key] = collected;
    _root._computingStack.add(key);
    final T next;
    try {
      next = _builder();
    } catch (error, stackTrace) {
      // Keep the previous value and the previous dependency set, so the
      // computed can recover on the next change instead of going inert.
      _root._report(error, stackTrace, 'recomputing computed state "$key"');
      return;
    } finally {
      _root._computingStack.removeLast();
      _root._trackingFrames.remove(key);
    }

    applyDependencies(collected);
    if (super.value == next) return;
    super.value = next;
    _root._notifyComputedDependents(key);
  }

  /// Swaps the reverse index over to [collected].
  void applyDependencies(Set<String> collected) {
    for (final dependency in dependencies) {
      if (collected.contains(dependency)) continue;
      final dependents = _root._dependencyIndex[dependency];
      if (dependents == null) continue;
      dependents.remove(key);
      if (dependents.isEmpty) _root._dependencyIndex.remove(dependency);
    }
    for (final dependency in collected) {
      _root._dependencyIndex.putIfAbsent(dependency, () => <String>{}).add(key);
    }
    dependencies
      ..clear()
      ..addAll(collected);
  }

  /// Drops this computed from the reverse index.
  void unindex() {
    applyDependencies(<String>{});
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}

/// A view of a [TinyState] store whose keys are prefixed with a scope name.
///
/// Obtain one with [TinyState.scope]. Every method mirrors the root API and
/// forwards to it with the key namespaced, so `cart.watch('count', 0)` is
/// stored as `'cart/count'` and cannot collide with anything global.
class TinyStateScope {
  /// Creates a scope. Prefer [TinyState.scope], which validates [name].
  TinyStateScope(this.name, this._root);

  /// The prefix applied to every key in this scope.
  final String name;

  final TinyState _root;

  String _scoped(String key) => '$name$_sep$key';

  /// See [TinyState.watch].
  ValueNotifier<T> watch<T>(
    String key,
    T defaultValue, {
    bool persist = false,
  }) {
    TinyState._validateKey(key, 'key');
    return _root._watch<T>(_scoped(key), defaultValue, persist: persist);
  }

  /// See [TinyState.get].
  T? get<T>(String key) {
    TinyState._validateKey(key, 'key');
    return _root._get<T>(_scoped(key));
  }

  /// See [TinyState.set].
  void set<T>(String key, T value) {
    TinyState._validateKey(key, 'key');
    _root._set<T>(_scoped(key), value);
  }

  /// See [TinyState.update].
  void update<T>(String key, T Function(T current) updater) {
    TinyState._validateKey(key, 'key');
    _root._update<T>(_scoped(key), updater);
  }

  /// See [TinyState.reset].
  void reset(String key) {
    TinyState._validateKey(key, 'key');
    _root._reset(_scoped(key));
  }

  /// See [TinyState.delete].
  void delete(String key) {
    TinyState._validateKey(key, 'key');
    _root._delete(_scoped(key));
  }

  /// See [TinyState.select].
  ValueListenable<R> select<T, R>(
    String key,
    R Function(T value) selector, {
    required String id,
  }) {
    TinyState._validateKey(key, 'key');
    TinyState._validateKey(id, 'id');
    return _root._select<T, R>(_scoped(key), selector, id);
  }

  /// See [TinyState.computed].
  ValueListenable<T> computed<T>(String key, T Function() builder) {
    TinyState._validateKey(key, 'key');
    return _root._computed<T>(_scoped(key), builder);
  }

  /// See [TinyState.listen].
  VoidCallback listen<T>(
    String key,
    void Function(T value) listener, {
    bool fireImmediately = false,
    bool once = false,
  }) {
    TinyState._validateKey(key, 'key');
    return _root._listen<T>(
      _scoped(key),
      listener,
      fireImmediately: fireImmediately,
      once: once,
    );
  }

  /// See [TinyState.watchFuture].
  ValueNotifier<AsyncSnapshot<T>> watchFuture<T>(
    String key,
    Future<T> Function() future, {
    bool refresh = false,
  }) {
    TinyState._validateKey(key, 'key');
    return _root._watchFuture<T>(
      '$_futurePrefix${_scoped(key)}',
      future,
      refresh: refresh,
    );
  }

  /// See [TinyState.refreshFuture].
  void refreshFuture(String key) {
    TinyState._validateKey(key, 'key');
    _root._futureRefreshers['$_futurePrefix${_scoped(key)}']?.call();
  }

  /// See [TinyState.deleteFuture].
  void deleteFuture(String key) {
    TinyState._validateKey(key, 'key');
    _root._delete('$_futurePrefix${_scoped(key)}');
  }

  /// Removes every state, computed, selector and future belonging to this
  /// scope, leaving the rest of the store untouched.
  void clear() {
    final prefix = '$name$_sep';
    final futurePrefix = '$_futurePrefix$prefix';

    final keys = <String>[
      ..._root._store.keys.where(
        (key) => key.startsWith(prefix) || key.startsWith(futurePrefix),
      ),
      ..._root._computedStore.keys.where((key) => key.startsWith(prefix)),
    ];
    for (final key in keys) {
      _root._delete(key);
    }
  }
}
