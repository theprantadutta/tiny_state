import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_state/tiny_state.dart';

/// Tells the adapter how to turn one key's value into something storable and
/// back again.
///
/// `tiny_state` has no opinion about serialization — that is the adapter's job,
/// which is why models round-trip here instead of silently decoding to a
/// `Map<String, dynamic>` and failing the cast.
class PersistedCodec<T> {
  const PersistedCodec({required this.encode, required this.decode});

  /// Converts a value into JSON-encodable data.
  final Object? Function(T value) encode;

  /// Rebuilds a value from the data [encode] produced.
  final T Function(Object? stored) decode;

  Object? _encodeDynamic(Object? value) => encode(value as T);

  Object? _decodeDynamic(Object? stored) => decode(stored);
}

/// A reference [TinyStatePersistenceAdapter] backed by `shared_preferences`.
///
/// `tiny_state` ships no storage dependency, so this lives in the example app.
/// Copy it into your project and adjust it — it is deliberately small.
///
/// ```dart
/// final prefs = await SharedPreferences.getInstance();
/// tinyState.persistenceAdapter = SharedPreferencesAdapter(
///   prefs,
///   codecs: {
///     'todos': PersistedCodec<List<Todo>>(
///       encode: (todos) => todos.map((t) => t.toJson()).toList(),
///       decode: (stored) => (stored! as List)
///           .map((e) => Todo.fromJson(e as Map<String, dynamic>))
///           .toList(),
///     ),
///   },
/// );
/// ```
class SharedPreferencesAdapter extends TinyStatePersistenceAdapter {
  SharedPreferencesAdapter(
    this._prefs, {
    this.namespace = 'tiny_state.',
    Map<String, PersistedCodec<dynamic>> codecs = const {},
  }) : _codecs = codecs;

  final SharedPreferences _prefs;

  /// Prefix applied to every key, so `tiny_state` cannot collide with the
  /// preferences your app already stores.
  final String namespace;

  final Map<String, PersistedCodec<dynamic>> _codecs;

  String _storageKey(String key) => '$namespace$key';

  @override
  Future<T?> read<T>(String key) async {
    final stored = _prefs.get(_storageKey(key));
    if (stored == null) return null;

    final codec = _codecs[key];
    if (codec != null) {
      return codec._decodeDynamic(jsonDecode(stored as String)) as T?;
    }

    // Primitives are stored natively.
    if (stored is T) return stored as T;
    if (T == List<String>) return (stored as List).cast<String>() as T;

    // Anything else was JSON-encoded. Without a codec this only works for
    // plain maps and lists — register a PersistedCodec for your own models.
    return jsonDecode(stored as String) as T;
  }

  @override
  Future<void> write<T>(String key, T value) async {
    final storageKey = _storageKey(key);

    final codec = _codecs[key];
    if (codec != null) {
      await _prefs.setString(
        storageKey,
        jsonEncode(codec._encodeDynamic(value)),
      );
      return;
    }

    switch (value) {
      case final bool v:
        await _prefs.setBool(storageKey, v);
      case final int v:
        await _prefs.setInt(storageKey, v);
      case final double v:
        await _prefs.setDouble(storageKey, v);
      case final String v:
        await _prefs.setString(storageKey, v);
      case final List<String> v:
        await _prefs.setStringList(storageKey, v);
      default:
        await _prefs.setString(storageKey, jsonEncode(value));
    }
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(_storageKey(key));
  }
}
