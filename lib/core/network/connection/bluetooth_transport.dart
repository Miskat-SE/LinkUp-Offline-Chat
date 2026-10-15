import 'dart:async';

import 'package:flutter/services.dart';
import 'package:resqmesh/core/network/connection/byte_link.dart';
import 'package:resqmesh/core/platform/bluetooth.dart';

/// [LinkTransport] over Bluetooth L2CAP channels (P14). Listening opens a
/// server; the "port" is its channel. Several transports (control and
/// file data) share one [Bluetooth]; each takes only its own links.
final class BluetoothTransport implements LinkTransport {
  BluetoothTransport(this._bt) {
    _events = _bt.links.listen(_onEvent);
  }

  final Bluetooth _bt;
  late final StreamSubscription<BtLinkEvent> _events;
  final Map<int, _BtLink> _open = {};

  /// Data for links whose connect() hasn't returned yet.
  final Map<int, List<BtLinkEvent>> _early = {};

  int? _channel;
  void Function(ByteLink link)? _onLink;

  @override
  Future<int?> listen(void Function(ByteLink link) onLink) async {
    await close();
    _onLink = onLink;
    try {
      return _channel = await _bt.openServer();
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> close() async {
    final channel = _channel;
    _channel = null;
    _onLink = null;
    if (channel != null) await _bt.closeServer(channel);
  }

  @override
  Future<ByteLink> connect(String address, int port, Duration timeout) async {
    final int id;
    try {
      id = await _bt.connect(address, port).timeout(timeout);
    } on PlatformException catch (e) {
      throw LinkException(e.message ?? e.code);
    } on TimeoutException {
      throw const LinkException('Bluetooth connect timed out');
    }
    final link = _open[id] = _BtLink(_bt, id, address);
    for (final event in _early.remove(id) ?? const <BtLinkEvent>[]) {
      _deliver(link, event);
    }
    return link;
  }

  /// Stops listening for link events; open links close.
  Future<void> dispose() async {
    await close();
    await _events.cancel();
    for (final link in _open.values.toList()) {
      link.destroy();
    }
    _open.clear();
  }

  void _onEvent(BtLinkEvent event) {
    final link = _open[event.linkId];
    if (link != null) {
      _deliver(link, event);
      if (event is BtLinkClosed) _open.remove(event.linkId);
      return;
    }
    switch (event) {
      case BtLinkOpened(:final channel, :final address)
          when channel == _channel:
        final accepted = _open[event.linkId] = _BtLink(
          _bt,
          event.linkId,
          address,
        );
        _onLink?.call(accepted);
      case BtLinkOpened():
        break; // another transport's server
      case BtLinkClosed():
        _early.remove(event.linkId);
      case BtData():
        // Possibly an outbound link whose connect() reply is still on its
        // way: kept, a little. Otherwise another transport's.
        if (_early.length < 8) {
          final early = _early.putIfAbsent(event.linkId, () => []);
          if (early.length < 8) early.add(event);
        }
    }
  }

  void _deliver(_BtLink link, BtLinkEvent event) {
    switch (event) {
      case BtData(:final bytes):
        link._received(bytes);
      case BtLinkClosed():
        link._closedByPeer();
      case BtLinkOpened():
        break;
    }
  }
}

final class _BtLink implements ByteLink {
  _BtLink(this._bt, this._id, this.address);

  final Bluetooth _bt;
  final int _id;
  final StreamController<Uint8List> _input = StreamController();
  bool _closed = false;

  @override
  final String address;

  @override
  Stream<Uint8List> get input => _input.stream;

  @override
  void add(List<int> bytes) {
    if (_closed) return;
    _bt.send(_id, bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
  }

  @override
  void destroy() {
    if (_closed) return;
    _closed = true;
    _bt.closeLink(_id);
    unawaited(_input.close());
  }

  void _received(Uint8List bytes) {
    if (!_closed) _input.add(bytes);
  }

  void _closedByPeer() {
    if (_closed) return;
    _closed = true;
    unawaited(_input.close());
  }
}
