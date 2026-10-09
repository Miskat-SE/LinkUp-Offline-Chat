import 'package:resqmesh/core/network/protocol/packet.dart';

/// Who this device is on data connections (the HELLO it sends).
final class TransferIdentity {
  const TransferIdentity({
    required this.deviceId,
    required this.name,
    required this.nameClaimedAt,
    required this.appVersion,
  });

  final String deviceId;
  final String name;
  final DateTime nameClaimedAt;
  final String appVersion;
}

/// Send one file to another device (PROTOCOL.md §4.4).
final class UploadRequest {
  const UploadRequest({
    required this.fileId,
    required this.chatMessageId,
    required this.peerId,
    required this.address,
    required this.port,
    required this.path,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.sha256,
  });

  final String fileId;
  final String chatMessageId;
  final String peerId;

  /// The receiver's address and file port.
  final String address;
  final int port;

  /// Absolute path of the stable copy to read.
  final String path;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final String sha256;
}

/// How the app answers a FILE_OFFER.
sealed class OfferAnswer {
  const OfferAnswer();
}

/// Receive into [partPath], continuing from its current size, then move it
/// to [finalPath] once verified.
final class AcceptOffer extends OfferAnswer {
  const AcceptOffer({required this.partPath, required this.finalPath});

  final String partPath;
  final String finalPath;
}

final class RejectOffer extends OfferAnswer {
  const RejectOffer(this.reason);

  final FileRejectReason reason;
}

/// This device already has the file: answer FILE_COMPLETE straight away.
final class AlreadyHaveFile extends OfferAnswer {
  const AlreadyHaveFile();
}

/// Why a transfer failed (not stopped on purpose by either side).
enum TransferFailure {
  /// The connection couldn't be opened or dropped.
  connectionLost,

  /// The other side stopped answering.
  timedOut,

  /// The file to send is missing or changed.
  unavailable,

  /// The other side broke the protocol.
  protocol,

  /// Reading or writing the file failed on this phone.
  storage,

  /// The received bytes didn't match the sender's SHA-256.
  checksumMismatch,
}

/// How a transfer ended.
sealed class TransferOutcome {
  const TransferOutcome();
}

final class TransferCompleted extends TransferOutcome {
  const TransferCompleted();
}

final class TransferRejected extends TransferOutcome {
  const TransferRejected(this.reason);

  final FileRejectReason reason;
}

/// This device paused or cancelled it.
final class StoppedHere extends TransferOutcome {
  const StoppedHere(this.reason);

  final FileCancelReason reason;
}

/// The other device sent FILE_CANCEL.
final class StoppedByPeer extends TransferOutcome {
  const StoppedByPeer(this.reason);

  final FileCancelReason reason;
}

final class TransferFailed extends TransferOutcome {
  const TransferFailed(this.failure, [this.detail]);

  final TransferFailure failure;
  final String? detail;
}

/// What the transfer engine reports to the app.
sealed class TransferEvent {
  const TransferEvent(this.fileId);

  final String fileId;
}

/// Another device wants to send a file; answer with
/// [TransferBackend.answer].
final class OfferReceived extends TransferEvent {
  OfferReceived(this.offer, {required this.peerId}) : super(offer.fileId);

  final FileOfferPacket offer;
  final String peerId;
}

/// Bytes started flowing; [offset] bytes were already there.
final class TransferStarted extends TransferEvent {
  const TransferStarted(super.fileId, {required this.offset});

  final int offset;
}

/// Bytes sent or written so far, including the offset. At most 10 a
/// second per transfer.
final class TransferProgressed extends TransferEvent {
  const TransferProgressed(super.fileId, {required this.bytes});

  final int bytes;
}

final class TransferEnded extends TransferEvent {
  const TransferEnded(super.fileId, this.outcome, {this.bytes});

  final TransferOutcome outcome;

  /// Bytes done when it ended, if known.
  final int? bytes;
}

/// Moves file bytes (ADR-0010). `TransferEngine` does the work; the app
/// runs it in a worker isolate through `IsolateTransferBackend`.
abstract interface class TransferBackend {
  Stream<TransferEvent> get events;

  /// Starts accepting data connections; returns the file port, or null if
  /// nothing could be bound.
  Future<int?> start(TransferIdentity self);

  /// The network changed: ends every transfer and listens again.
  Future<int?> reset();

  void updateIdentity(TransferIdentity self);

  void upload(UploadRequest request);

  void answer(String fileId, OfferAnswer answer);

  /// Pauses or cancels a running transfer in either direction.
  void stop(String fileId, FileCancelReason reason);

  /// SHA-256 of a file as lowercase hex, read in chunks.
  Future<String> hashFile(String path);

  Future<void> dispose();
}
