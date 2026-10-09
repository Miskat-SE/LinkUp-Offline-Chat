import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:resqmesh/core/constants/protocol_constants.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/network/protocol/packet_codec.dart';

/// A device found through NSD/mDNS. Only a hint: the engine confirms it by
/// asking the address directly over UDP.
final class ServiceCandidate {
  const ServiceCandidate({required this.deviceId, required this.address});

  final String deviceId;
  final String address;
}

/// Advertises this device and browses for others with NSD/mDNS (ADR-0004).
abstract interface class ServiceDiscovery {
  Stream<ServiceCandidate> get candidates;

  Future<void> startBrowsing();

  Future<void> advertise({required String deviceId, required int port});

  Future<void> stopAdvertising();

  Future<void> stop();
}

/// [ServiceDiscovery] over Android `NsdManager`, through `bonsoir`. Errors
/// are logged and swallowed: UDP discovery keeps working without NSD.
final class NsdServiceDiscovery implements ServiceDiscovery {
  NsdServiceDiscovery(this._logger);

  final AppLogger _logger;
  final StreamController<ServiceCandidate> _candidates =
      StreamController<ServiceCandidate>.broadcast();
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _events;
  BonsoirBroadcast? _broadcast;
  String? _advertisedId;

  @override
  Stream<ServiceCandidate> get candidates => _candidates.stream;

  @override
  Future<void> startBrowsing() async {
    if (_discovery != null) return;
    try {
      final discovery = BonsoirDiscovery(type: ProtocolConstants.serviceType);
      _discovery = discovery;
      await discovery.initialize();
      _events = discovery.eventStream?.listen((event) {
        switch (event) {
          case BonsoirDiscoveryServiceFoundEvent(:final service):
            unawaited(service.resolve(discovery.serviceResolver));
          case BonsoirDiscoveryServiceResolvedEvent(:final service):
          case BonsoirDiscoveryServiceUpdatedEvent(:final service):
            _emit(service);
          default:
            break;
        }
      });
      await discovery.start();
      _logger.info(LogTag.discovery, 'NSD browsing started');
    } on Exception catch (e) {
      _logger.warning(LogTag.discovery, 'NSD browsing unavailable', {
        'error': e.runtimeType,
      });
      await _stopBrowsing();
    }
  }

  @override
  Future<void> advertise({required String deviceId, required int port}) async {
    if (_advertisedId == deviceId && _broadcast != null) return;
    await stopAdvertising();
    try {
      final broadcast = BonsoirBroadcast(
        service: BonsoirService(
          name: deviceId,
          type: ProtocolConstants.serviceType,
          port: port,
          attributes: {'id': deviceId, 'v': '${ProtocolConstants.version}'},
        ),
      );
      _broadcast = broadcast;
      _advertisedId = deviceId;
      await broadcast.initialize();
      await broadcast.start();
      _logger.info(LogTag.discovery, 'NSD advertising started');
    } on Exception catch (e) {
      _logger.warning(LogTag.discovery, 'NSD advertising unavailable', {
        'error': e.runtimeType,
      });
      await stopAdvertising();
    }
  }

  @override
  Future<void> stopAdvertising() async {
    final broadcast = _broadcast;
    _broadcast = null;
    _advertisedId = null;
    if (broadcast == null) return;
    try {
      await broadcast.stop();
    } on Exception {
      // Already stopped by the system.
    }
  }

  @override
  Future<void> stop() async {
    await stopAdvertising();
    await _stopBrowsing();
  }

  Future<void> _stopBrowsing() async {
    await _events?.cancel();
    _events = null;
    final discovery = _discovery;
    _discovery = null;
    if (discovery == null) return;
    try {
      await discovery.stop();
    } on Exception {
      // Already stopped by the system.
    }
  }

  void _emit(BonsoirService service) {
    final deviceId = service.attributes['id'] ?? service.name;
    if (!PacketCodec.isId(deviceId)) return;
    for (final address in service.hostAddresses) {
      // IPv4 only, like the rest of the protocol.
      if (!address.contains('.') || address.contains(':')) continue;
      _candidates.add(ServiceCandidate(deviceId: deviceId, address: address));
    }
  }
}
