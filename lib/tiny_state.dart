/// A tiny, global, reactive state manager for Flutter.
///
/// `tiny_state` is a keyed store of [ValueNotifier]s with dependency-tracked
/// derived state on top. It has no dependencies beyond Flutter itself.
///
/// ```dart
/// import 'package:tiny_state/tiny_state.dart';
///
/// final counter = tinyState.watch<int>('counter', 0);
/// tinyState.update<int>('counter', (n) => n + 1);
/// ```
///
/// See [TinyState] for the full API, [TinyBuilder] for the widget, and
/// [TinyStatePersistenceAdapter] for persistence.
library;

export 'src/builder.dart';
export 'src/persistence.dart';
export 'src/tiny_state.dart';
