import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'tiny_state.dart';

/// Builder signature used by [TinyBuilder].
typedef TinyWidgetBuilder<T> = Widget Function(BuildContext context, T value);

/// Rebuilds when a piece of `tiny_state` state changes.
///
/// This is the terse form of `ValueListenableBuilder` wired to a key:
///
/// ```dart
/// TinyBuilder<int>('counter', 0, (context, count) => Text('$count'))
/// ```
///
/// which is equivalent to, but shorter than:
///
/// ```dart
/// ValueListenableBuilder<int>(
///   valueListenable: tinyState.watch<int>('counter', 0),
///   builder: (context, count, _) => Text('$count'),
/// )
/// ```
///
/// Pass [scope] to read from a scope instead of the global store, and [persist]
/// to declare the key persisted (only meaningful on the call that creates it).
///
/// Use [TinyBuilder.listen] for a [select] or [computed] result, which is
/// already a [ValueListenable]:
///
/// ```dart
/// TinyBuilder<bool>.listen(isEven, (context, even) => Text('$even'))
/// ```
class TinyBuilder<T> extends StatelessWidget {
  /// Watches [stateKey], creating it with [defaultValue] if it does not exist.
  const TinyBuilder(
    String this.stateKey,
    T this.defaultValue,
    this.builder, {
    super.key,
    this.scope,
    this.persist = false,
  }) : listenable = null;

  /// Rebuilds from an existing [ValueListenable], such as the result of
  /// [TinyState.select] or [TinyState.computed].
  const TinyBuilder.listen(
    ValueListenable<T> this.listenable,
    this.builder, {
    super.key,
  }) : stateKey = null,
       defaultValue = null,
       scope = null,
       persist = false;

  /// The state key to watch, when built with the default constructor.
  final String? stateKey;

  /// The default used if [stateKey] does not exist yet.
  final T? defaultValue;

  /// The listenable to follow, when built with [TinyBuilder.listen].
  final ValueListenable<T>? listenable;

  /// Called with the current value on every change.
  final TinyWidgetBuilder<T> builder;

  /// The scope owning [stateKey]. Defaults to the global store.
  final TinyStateScope? scope;

  /// Whether [stateKey] should be persisted. See [TinyState.watch].
  final bool persist;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<T>(
      valueListenable: listenable ?? _watch(),
      builder: (context, value, _) => builder(context, value),
    );
  }

  ValueNotifier<T> _watch() {
    final key = stateKey!;
    final value = defaultValue as T;
    final target = scope;
    return target == null
        ? tinyState.watch<T>(key, value, persist: persist)
        : target.watch<T>(key, value, persist: persist);
  }
}
