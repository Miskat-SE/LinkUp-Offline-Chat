import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqmesh/app/router.dart';
import 'package:resqmesh/core/network/lan_providers.dart';
import 'package:resqmesh/core/platform/background.dart';
import 'package:resqmesh/core/platform/platform_api.g.dart';
import 'package:resqmesh/core/settings/stay_reachable.dart';
import 'package:resqmesh/features/chat/data/chat_providers.dart';
import 'package:resqmesh/features/file_transfer/data/file_transfer_providers.dart';
import 'package:resqmesh/features/file_transfer/data/transfer_service.dart';
import 'package:resqmesh/features/file_transfer/domain/file_transfer.dart';
import 'package:resqmesh/features/file_transfer/presentation/file_format.dart';

/// Keeps the background service in step with the app (PROJECT_PLAN.md §5.6,
/// P8.2–P8.3): running with a progress notification while files move, a
/// quiet "reachable" one while idle with *Stay reachable* on, and stopped
/// otherwise. The notification changes at most once a second.
final class BackgroundCoordinator {
  BackgroundCoordinator({
    required this._transfers,
    required this._service,
    required this._stayReachable,
    this.interval = const Duration(seconds: 1),
  });

  final TransferService _transfers;
  final BackgroundService _service;
  final bool Function() _stayReachable;
  final Duration interval;

  StreamSubscription<void>? _changes;
  Timer? _pending;
  DateTime? _lastSent;
  String? _lastKey;

  void start() {
    _changes ??= _transfers.changes.listen((_) => schedule());
    unawaited(refresh());
  }

  Future<void> stop() async {
    _pending?.cancel();
    await _changes?.cancel();
    _changes = null;
  }

  /// Refreshes now if the last update was at least [interval] ago,
  /// otherwise once that time has passed.
  void schedule() {
    if (_pending != null) return;
    final last = _lastSent;
    final wait = last == null
        ? Duration.zero
        : interval - clock.now().difference(last);
    if (wait <= Duration.zero) {
      unawaited(refresh());
      return;
    }
    _pending = Timer(wait, () {
      _pending = null;
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    final state = describe(
      await _transfers.activeTransfers(),
      stayReachable: _stayReachable(),
    );
    final key = [
      state.transferring,
      state.stayReachable,
      state.title,
      state.text,
      state.progress,
      state.route,
    ].join('|');
    if (key == _lastKey) return;
    _lastKey = key;
    _lastSent = clock.now();
    await _service.update(state);
  }

  /// What the notification says for these transfers.
  static BackgroundState describe(
    List<(FileTransfer, TransferProgress?)> active, {
    required bool stayReachable,
  }) {
    if (active.isEmpty) {
      return BackgroundState(
        transferring: false,
        stayReachable: stayReachable,
        title: 'LinkUp is reachable',
        text: 'Reachable on this Wi-Fi. People nearby can message you.',
        route: Routes.home,
      );
    }
    var done = 0;
    var total = 0;
    for (final (transfer, progress) in active) {
      done += progress?.bytes ?? transfer.bytesTransferred;
      total += transfer.size;
    }
    final percent = total == 0 ? 0 : (done * 100 / total).floor();
    if (active.length == 1) {
      final (transfer, progress) = active.single;
      final verb = transfer.status == TransferStatus.preparing
          ? 'Preparing'
          : transfer.isOutgoing
          ? 'Sending'
          : 'Receiving';
      final speed = progress?.bytesPerSecond;
      final left = progress?.timeLeft;
      return BackgroundState(
        transferring: true,
        stayReachable: stayReachable,
        title: '$verb ${transfer.name} — $percent%',
        text: [
          '${formatBytes(done)} of ${formatBytes(total)}',
          if (speed != null) formatSpeed(speed),
          if (left != null) '${formatTimeLeft(left)} left',
        ].join(' · '),
        progress: transfer.status == TransferStatus.preparing ? null : percent,
        route: Routes.fileDetails(transfer.fileId),
      );
    }
    final sending = active.where((a) => a.$1.isOutgoing).length;
    final receiving = active.length - sending;
    String files(int n) => '$n ${n == 1 ? 'file' : 'files'}';
    return BackgroundState(
      transferring: true,
      stayReachable: stayReachable,
      title: [
        if (sending > 0) 'Sending ${files(sending)}',
        if (receiving > 0)
          sending > 0
              ? 'receiving $receiving'
              : 'Receiving ${files(receiving)}',
      ].join(' · '),
      text: '$percent% · ${formatBytes(done)} of ${formatBytes(total)}',
      progress: percent,
      route: Routes.activity,
    );
  }
}

final backgroundCoordinatorProvider = Provider<void>((ref) {
  final coordinator = BackgroundCoordinator(
    transfers: ref.watch(transferServiceProvider),
    service: ref.watch(backgroundServiceProvider),
    stayReachable: () => ref.read(stayReachableProvider),
  )..start();
  final engine = ref.watch(discoveryEngineProvider);
  ref
    ..listen(stayReachableProvider, (_, _) => unawaited(coordinator.refresh()))
    // Announce less often while the screen is closed (§6.2).
    ..listen(
      appInForegroundProvider,
      (_, foreground) => engine.setBackground(background: !foreground),
    )
    ..onDispose(() => unawaited(coordinator.stop()));
});
