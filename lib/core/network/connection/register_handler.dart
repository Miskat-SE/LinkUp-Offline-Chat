import 'dart:async';

import 'package:resqmesh/core/identity/username.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/network/connection/peer_links.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/discovery/peer.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';

/// Name registration over TCP (PROTOCOL.md §4.2): tells connected devices
/// about a rename, applies theirs, and answers REGISTER.
final class RegisterHandler {
  RegisterHandler({
    required this._links,
    required this._self,
    required this._onRename,
    required this._logger,
  });

  final PeerLinks _links;
  final SelfInfo Function() _self;

  /// Called with (deviceId, name, claimedAt) when a device renames itself.
  final void Function(String deviceId, String name, DateTime claimedAt)
  _onRename;
  final AppLogger _logger;
  StreamSubscription<PeerPacket>? _subscription;

  void start() {
    _subscription ??= _links.packets.listen(_onPacket);
  }

  Future<void> stop() async => _subscription?.cancel();

  /// Sends REGISTER for this device's current name to every connection.
  void announce() {
    final self = _self();
    if (!self.canAnnounce) return;
    _links.sendToAll(
      (id) => RegisterPacket(
        PacketHeader.create(
          senderId: self.deviceId,
          senderName: self.name!,
          receiverId: id,
        ),
        name: self.name!,
        nameClaimedAt: self.nameClaimedAt!,
      ),
    );
  }

  void _onPacket(PeerPacket incoming) {
    switch (incoming.packet) {
      case RegisterPacket(:final name, :final nameClaimedAt):
        _onRename(incoming.from, name, nameClaimedAt);
        _answer(incoming.from, name, nameClaimedAt);
      case RegisterResponsePacket(result: RegisterResult.nameTaken):
        _logger.warning(LogTag.discovery, 'Name taken on the network', {
          'by': incoming.from.substring(0, 4),
        });
      default:
        break;
    }
  }

  void _answer(String from, String name, DateTime claimedAt) {
    final self = _self();
    final ownName = self.name;
    if (!self.canAnnounce || ownName == null) return;
    final keepsName =
        Username.same(ownName, name) &&
        Peer.winsNameClash(
          claimedAt: self.nameClaimedAt!,
          deviceId: self.deviceId,
          otherClaimedAt: claimedAt,
          otherId: from,
        );
    _links.send(
      from,
      RegisterResponsePacket(
        PacketHeader.create(
          senderId: self.deviceId,
          senderName: ownName,
          receiverId: from,
        ),
        result: keepsName ? RegisterResult.nameTaken : RegisterResult.ok,
        name: name,
        holderId: keepsName ? self.deviceId : null,
        holderClaimedAt: keepsName ? self.nameClaimedAt : null,
      ),
    );
  }
}
