import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqmesh/core/bootstrap/core_services.dart';
import 'package:resqmesh/core/connection/bluetooth_controller.dart';
import 'package:resqmesh/core/connection/bluetooth_providers.dart';
import 'package:resqmesh/core/connection/connection_method.dart';
import 'package:resqmesh/core/connection/connection_providers.dart';
import 'package:resqmesh/core/identity/identity_providers.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/network/connection/bluetooth_transport.dart';
import 'package:resqmesh/core/network/connection/byte_link.dart';
import 'package:resqmesh/core/network/connection/connection_manager.dart';
import 'package:resqmesh/core/network/connection/peer_connection.dart';
import 'package:resqmesh/core/network/connection/peer_links.dart';
import 'package:resqmesh/core/network/connection/register_handler.dart';
import 'package:resqmesh/core/network/discovery/datagram_transport.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/discovery/service_discovery.dart';
import 'package:resqmesh/core/network/nearby.dart';
import 'package:resqmesh/core/network/network_monitor.dart';
import 'package:resqmesh/core/network/network_snapshot.dart';
import 'package:resqmesh/core/platform/app_info_provider.dart';

final networkMonitorProvider = Provider<NetworkMonitor>(
  (ref) => PlatformNetworkMonitor(),
);

final datagramBinderProvider = Provider<DatagramBinder>((ref) => bindUdp);

final serviceDiscoveryProvider = Provider<ServiceDiscovery?>(
  (ref) => NsdServiceDiscovery(ref.watch(appLoggerProvider)),
);

/// The single discovery engine. Created on first use after start-up and
/// kept for the life of the app. Only valid after start-up has finished.
final discoveryEngineProvider = Provider<DiscoveryEngine>((ref) {
  SelfInfo selfInfo() {
    final identity = ref.read(identityProvider);
    final method = ref.read(connectionMethodProvider);
    return SelfInfo(
      deviceId: identity.deviceId,
      name: identity.username,
      nameClaimedAt: identity.nameClaimedAt,
      announce:
          method == ConnectionMethod.wifiRouter ||
          method == ConnectionMethod.hotspot ||
          method == ConnectionMethod.wifiDirect ||
          method == ConnectionMethod.bluetooth,
      appVersion: ref.read(appInfoProvider).value?.wireVersion ?? '',
    );
  }

  final engine = DiscoveryEngine(
    network: ref.watch(networkMonitorProvider),
    bindUdp: ref.watch(datagramBinderProvider),
    serviceDiscovery: ref.watch(serviceDiscoveryProvider),
    logger: ref.watch(appLoggerProvider),
    self: selfInfo(),
  );
  void update() => engine.updateSelf(selfInfo());
  ref
    ..listen(identityProvider, (_, _) => update())
    ..listen(connectionMethodProvider, (_, _) => update())
    ..listen(appInfoProvider, (_, _) => update())
    ..onDispose(() => unawaited(engine.dispose()));
  unawaited(engine.start());
  return engine;
});

/// Live discovery state for the UI.
final discoveryProvider = StreamProvider<DiscoverySnapshot>((ref) async* {
  final engine = ref.watch(discoveryEngineProvider);
  yield engine.current;
  yield* engine.snapshots;
});

/// Creates the TCP side; tests replace it.
typedef PeerLinksFactory = PeerLinks Function(
  SelfInfo Function() self,
  AppLogger logger, {
  LinkTransport? transport,
});

final peerLinksFactoryProvider = Provider<PeerLinksFactory>(
  (ref) =>
      (self, logger, {transport}) => ConnectionManager(
        self: self,
        logger: logger,
        transport: transport,
        timing: transport == null
            ? const ConnectionTiming()
            : ConnectionTiming.bluetooth,
      ),
);

/// Control connections to every discovered device (P3), kept in step with
/// discovery: dials who is online, resets on network changes, and handles
/// name registration.
final peerLinksProvider = Provider<PeerLinks>((ref) {
  final engine = ref.watch(discoveryEngineProvider);
  final logger = ref.watch(appLoggerProvider);
  // Bluetooth (P14): the same connections over L2CAP channels, to the
  // phones Bluetooth LE finds; Wi-Fi discovery doesn't feed them.
  final bluetooth = ref.watch(bluetoothControllerProvider);
  final transport = bluetooth == null
      ? null
      : BluetoothTransport(ref.read(bluetoothProvider));
  final links = ref.watch(peerLinksFactoryProvider)(
    () => engine.self,
    logger,
    transport: transport,
  );
  final register = RegisterHandler(
    links: links,
    self: () => engine.self,
    onRename: engine.applyRename,
    logger: logger,
  )..start();

  void announcePort(int? port) {
    if (bluetooth != null) {
      bluetooth.setChannel(port);
    } else if (port != null) {
      engine.setTcpPort(port);
    }
  }

  NetworkSnapshot? lastNetwork;
  final btEndpoints = bluetooth?.endpoints.listen(links.updateEndpoints);
  // The Bluetooth server can only open once permission is given and
  // Bluetooth is on, often after the first try, and turning Bluetooth off
  // closes it: open it again then.
  var lost = false;
  var reopening = false;
  final btReady = bluetooth?.watch().listen((status) {
    if (status.phase == BluetoothPhase.off) lost = true;
    if (!bluetooth.ready || reopening) return;
    if (!lost && bluetooth.channel != null) return;
    lost = false;
    reopening = true;
    unawaited(
      links
          .resetNetwork()
          .then(announcePort)
          .whenComplete(() => reopening = false),
    );
  });
  final subscription = engine.snapshots.listen((snapshot) {
    if (bluetooth != null) return;
    if (lastNetwork != null && lastNetwork != snapshot.network) {
      unawaited(links.resetNetwork().then(announcePort));
    }
    lastNetwork = snapshot.network;
    links.updateEndpoints([
      for (final peer in snapshot.peers)
        if (peer.online)
          PeerEndpoint(
            deviceId: peer.deviceId,
            address: peer.address,
            port: peer.tcpPort,
          ),
    ]);
  });

  ref
    ..listen(identityProvider, (previous, next) {
      if (previous?.username != next.username) register.announce();
    })
    ..onDispose(() {
      unawaited(subscription.cancel());
      unawaited(btEndpoints?.cancel());
      unawaited(btReady?.cancel());
      unawaited(register.stop());
      unawaited(links.stop().then((_) => transport?.dispose()));
    });
  unawaited(links.start().then(announcePort));
  return links;
});

final linksProvider = StreamProvider<LinksSnapshot>((ref) async* {
  final links = ref.watch(peerLinksProvider);
  yield links.current;
  yield* links.snapshots;
});

/// People nearby for the UI: discovery and connections combined.
final nearbyProvider = Provider<NearbySnapshot>(
  (ref) => NearbySnapshot.combine(
    ref.watch(discoveryProvider).value ?? DiscoverySnapshot.initial,
    ref.watch(linksProvider).value ?? LinksSnapshot.initial,
    overBluetooth: ref.watch(usesBluetoothProvider),
  ),
);
