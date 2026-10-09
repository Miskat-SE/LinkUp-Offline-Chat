import 'package:resqmesh/core/storage/key_value_store.dart';

/// In-memory [KeyValueStore] for tests.
final class MemoryKeyValueStore implements KeyValueStore {
  MemoryKeyValueStore([Map<String, String>? values]) : values = {...?values};

  final Map<String, String> values;

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}
