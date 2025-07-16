import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// An abstract class that defines the interface for a persistence adapter.
abstract class TinyStatePersistenceAdapter {
  /// Reads a value from the persistence layer.
  Future<T?> read<T>(String key);

  /// Writes a value to the persistence layer.
  Future<void> write<T>(String key, T value);
}

/// A persistence adapter that uses the `shared_preferences` package.
class SharedPreferencesAdapter extends TinyStatePersistenceAdapter {
  final SharedPreferences _prefs;

  SharedPreferencesAdapter(this._prefs);

  @override
  Future<T?> read<T>(String key) async {
    final value = _prefs.get(key);
    if (value == null) {
      return null;
    }
    if (T == bool) {
      return value as T;
    }
    if (T == int) {
      return value as T;
    }
    if (T == double) {
      return value as T;
    }
    if (T == String) {
      return value as T;
    }
    if (T == List<String>) {
      return (value as List).cast<String>() as T;
    }
    // For complex types, we assume they are stored as JSON strings.
    try {
      return jsonDecode(value as String) as T;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> write<T>(String key, T value) async {
    if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is double) {
      await _prefs.setDouble(key, value);
    } else if (value is String) {
      await _prefs.setString(key, value);
    } else if (value is List<String>) {
      await _prefs.setStringList(key, value);
    } else {
      // For complex types, we store them as JSON strings.
      await _prefs.setString(key, jsonEncode(value));
    }
  }
}
