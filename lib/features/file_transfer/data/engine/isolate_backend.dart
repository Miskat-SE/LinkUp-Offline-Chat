import 'dart:async';
import 'dart:isolate';

import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/features/file_transfer/data/engine/transfer_backend.dart';
import 'package:resqmesh/features/file_transfer/data/engine/transfer_engine.dart';

/// Runs a [TransferEngine] in its own long-lived isolate (ADR-0010), so
/// file reads, writes, hashing and data sockets never run on the UI
/// isolate. Commands go in and events come out as plain Dart objects.
final class IsolateTransferBackend implements TransferBackend {
  IsolateTransferBackend._(this._isolate, this._commands, this._replies);

  static Future<IsolateTransferBackend> spawn() async {
    final replies = ReceivePort();
    final isolate = await Isolate.spawn(
      _workerMain,
      replies.sendPort,
      debugName: 'transfer-worker',
    );
    final messages = replies.asBroadcastStream();
    final commands = await messages.first as SendPort;
    final backend = IsolateTransferBackend._(isolate, commands, replies);
    backend._subscription = messages.listen(backend._onMessage);
    return backend;
  }

  final Isolate _isolate;
  final SendPort _commands;
  final ReceivePort _replies;
  late final StreamSubscription<Object?> _subscription;
  final StreamController<TransferEvent> _events =
      StreamController<TransferEvent>.broadcast();
  final Map<int, Completer<Object?>> _pending = {};
  int _nextRequest = 0;

  @override
  Stream<TransferEvent> get events => _events.stream;

  @override
  Future<int?> start(TransferIdentity self) async =>
      await _request(_Start(self)) as int?;

  @override
  Future<int?> reset() async => await _request(const _Reset()) as int?;

  @override
  void updateIdentity(TransferIdentity self) =>
      _commands.send(_UpdateIdentity(self));

  @override
  void upload(UploadRequest request) => _commands.send(_Upload(request));

  @override
  void answer(String fileId, OfferAnswer answer) =>
      _commands.send(_Answer(fileId, answer));

  @override
  void stop(String fileId, FileCancelReason reason) =>
      _commands.send(_Stop(fileId, reason));

  @override
  Future<String> hashFile(String path) async =>
      await _request(_Hash(path)) as String;

  @override
  Future<void> dispose() async {
    try {
      await _request(const _Dispose()).timeout(const Duration(seconds: 2));
    } on Object {
      // Kill it anyway.
    }
    await _subscription.cancel();
    _replies.close();
    _isolate.kill();
    await _events.close();
  }

  Future<Object?> _request(_Command command) {
    final id = _nextRequest++;
    final completer = _pending[id] = Completer<Object?>();
    _commands.send(_Request(id, command));
    return completer.future;
  }

  void _onMessage(Object? message) {
    switch (message) {
      case TransferEvent():
        if (!_events.isClosed) _events.add(message);
      case _Reply(:final id, :final value, :final error):
        final completer = _pending.remove(id);
        if (completer == null) return;
        if (error != null) {
          completer.completeError(StateError(error));
        } else {
          completer.complete(value);
        }
    }
  }
}

Future<void> _workerMain(SendPort replies) async {
  final commands = ReceivePort();
  replies.send(commands.sendPort);
  final engine = TransferEngine();
  final events = engine.events.listen(replies.send);
  await for (final message in commands) {
    switch (message) {
      case _Request(:final id, :final command):
        try {
          final value = switch (command) {
            _Start(:final self) => await engine.start(self),
            _Reset() => await engine.reset(),
            _Hash(:final path) => await engine.hashFile(path),
            _Dispose() => null,
            _ => null,
          };
          replies.send(_Reply(id, value, null));
        } on Object catch (e) {
          replies.send(_Reply(id, null, e.toString()));
        }
        if (command is _Dispose) {
          await events.cancel();
          await engine.dispose();
          commands.close();
        }
      case _UpdateIdentity(:final self):
        engine.updateIdentity(self);
      case _Upload(:final request):
        engine.upload(request);
      case _Answer(:final fileId, :final answer):
        engine.answer(fileId, answer);
      case _Stop(:final fileId, :final reason):
        engine.stop(fileId, reason);
    }
  }
}

sealed class _Command {
  const _Command();
}

final class _Request extends _Command {
  const _Request(this.id, this.command);

  final int id;
  final _Command command;
}

final class _Reply {
  const _Reply(this.id, this.value, this.error);

  final int id;
  final Object? value;
  final String? error;
}

final class _Start extends _Command {
  const _Start(this.self);

  final TransferIdentity self;
}

final class _Reset extends _Command {
  const _Reset();
}

final class _Hash extends _Command {
  const _Hash(this.path);

  final String path;
}

final class _Dispose extends _Command {
  const _Dispose();
}

final class _UpdateIdentity extends _Command {
  const _UpdateIdentity(this.self);

  final TransferIdentity self;
}

final class _Upload extends _Command {
  const _Upload(this.request);

  final UploadRequest request;
}

final class _Answer extends _Command {
  const _Answer(this.fileId, this.answer);

  final String fileId;
  final OfferAnswer answer;
}

final class _Stop extends _Command {
  const _Stop(this.fileId, this.reason);

  final String fileId;
  final FileCancelReason reason;
}
