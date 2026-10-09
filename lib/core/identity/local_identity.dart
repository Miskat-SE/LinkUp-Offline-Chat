/// This device's identity on the LAN (PROJECT_PLAN.md §6.1).
final class LocalIdentity {
  const LocalIdentity({
    required this.deviceId,
    this.username,
    this.nameClaimedAt,
  });

  /// Random UUID created on first launch. Never derived from the name.
  final String deviceId;

  /// Normalised name, or null before onboarding is finished.
  final String? username;

  /// When the current name was claimed; decides name clashes (§6.4).
  final DateTime? nameClaimedAt;

  bool get hasName => username != null;

  /// First four characters of the device ID, used to tell devices apart.
  String get shortId => deviceId.substring(0, 4);

  @override
  bool operator ==(Object other) =>
      other is LocalIdentity &&
      other.deviceId == deviceId &&
      other.username == username &&
      other.nameClaimedAt == nameClaimedAt;

  @override
  int get hashCode => Object.hash(deviceId, username, nameClaimedAt);
}
