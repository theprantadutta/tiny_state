import 'dart:async';

import 'package:tiny_state/tiny_state.dart';

/// A [TinyStatePersistenceAdapter] for tests that records every call, can be
/// made to fail on demand, and can hold reads open so rehydrate races are
/// reproducible.
class RecordingAdapter extends TinyStatePersistenceAdapter {
  RecordingAdapter([Map<String, Object?>? seed]) : entries = {...?seed};

  /// The backing store. Assert on this to check what was persisted.
  final Map<String, Object?> entries;

  /// Every operation performed, in order, as `'write:key'` / `'remove:key'` /
  /// `'read:key'`.
  final List<String> calls = [];

  /// Every value handed to [write], in the order it actually landed.
  final List<Object?> written = [];

  /// When set, [read] waits on this before completing, so a test can interleave
  /// a write with an in-flight rehydrate.
  Completer<void>? gate;

  /// When set, every operation on this key fails with this error.
  final Map<String, Object> failures = {};

  @override
  Future<T?> read<T>(String key) async {
    calls.add('read:$key');
    final gate = this.gate;
    if (gate != null) await gate.future;
    final failure = failures[key];
    if (failure != null) throw failure;
    return entries[key] as T?;
  }

  @override
  Future<void> write<T>(String key, T value) async {
    calls.add('write:$key');
    final failure = failures[key];
    if (failure != null) throw failure;
    entries[key] = value;
    written.add(value);
  }

  @override
  Future<void> remove(String key) async {
    calls.add('remove:$key');
    final failure = failures[key];
    if (failure != null) throw failure;
    entries.remove(key);
  }
}
