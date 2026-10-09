import 'package:resqmesh/core/identity/username.dart';

/// Labels for people in a list. Until a name clash is resolved, devices that
/// share a name (with each other or with this device) get their short device
/// ID added: "Yusuf · 3f2a" (PROJECT_PLAN.md §6.4).
Map<String, String> displayNames(
  Iterable<({String deviceId, String name})> people, {
  String? selfName,
}) {
  final counts = <String, int>{};
  for (final person in people) {
    final key = Username.key(person.name);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return {
    for (final person in people)
      person.deviceId:
          (counts[Username.key(person.name)]! > 1 ||
              (selfName != null && Username.same(person.name, selfName)))
          ? '${person.name} · ${person.deviceId.substring(0, 4)}'
          : person.name,
  };
}
