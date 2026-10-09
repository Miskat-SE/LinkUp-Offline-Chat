import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqmesh/core/bootstrap/core_services.dart';
import 'package:resqmesh/core/connection/connection_method.dart';
import 'package:resqmesh/core/connection/connection_providers.dart';
import 'package:resqmesh/core/identity/identity_providers.dart';
import 'package:resqmesh/core/network/discovery/datagram_transport.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/discovery/service_discovery.dart';
import 'package:resqmesh/core/network/network_monitor.dart';
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
          method == ConnectionMethod.hotspot,
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
