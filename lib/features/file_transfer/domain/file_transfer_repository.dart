import 'package:resqmesh/features/file_transfer/domain/file_transfer.dart';

/// Where file transfer records live (SQLite in the app).
abstract interface class FileTransferRepository {
  Future<void> insert(FileTransfer transfer);

  Future<FileTransfer?> find(String fileId);

  Stream<FileTransfer?> watch(String fileId);

  /// Changes the given fields; [clearError] removes the stored error and
  /// [clearLocalPath] marks the copy as gone.
  Future<FileTransfer?> update(
    String fileId, {
    TransferStatus? status,
    int? bytesTransferred,
    String? sha256,
    String? localPath,
    String? error,
    int? attempts,
    bool clearError = false,
    bool clearLocalPath = false,
  });

  /// Transfers in any of [statuses], oldest first.
  Future<List<FileTransfer>> withStatus(
    Set<TransferStatus> statuses, {
    TransferDirection? direction,
  });

  /// A completed incoming file from [peerId] with this content that still
  /// has a copy here (duplicate detection).
  Future<FileTransfer?> findReceivedContent({
    required String peerId,
    required String sha256,
    required int size,
  });

  /// How many transfers use the stored copy at [localPath].
  Future<int> countUsing(String localPath);

  Future<void> delete(String fileId);

  /// The most recently changed transfers, newest first (Activity screen).
  Stream<List<FileTransfer>> watchRecent({int limit = 50});
}
