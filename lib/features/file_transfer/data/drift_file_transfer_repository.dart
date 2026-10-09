import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:resqmesh/core/storage/app_database.dart';
import 'package:resqmesh/features/file_transfer/domain/file_transfer.dart';
import 'package:resqmesh/features/file_transfer/domain/file_transfer_repository.dart';

/// [FileTransferRepository] on SQLite (drift).
final class DriftFileTransferRepository implements FileTransferRepository {
  DriftFileTransferRepository(this._db);

  final AppDatabase _db;

  $FilesTable get _files => _db.files;

  @override
  Future<void> insert(FileTransfer transfer) => _db
      .into(_files)
      .insert(
        FilesCompanion.insert(
          fileId: transfer.fileId,
          messageId: transfer.messageId,
          peerId: transfer.peerId,
          direction: transfer.isOutgoing ? _out : _in,
          name: transfer.name,
          mimeType: transfer.mimeType,
          size: transfer.size,
          bytesTransferred: Value(transfer.bytesTransferred),
          status: _statusCodes[transfer.status]!,
          sha256: Value(transfer.sha256),
          localPath: Value(transfer.localPath),
          error: Value(transfer.error),
          attempts: Value(transfer.attempts),
          createdAt: transfer.createdAt,
          updatedAt: transfer.updatedAt,
        ),
      );

  @override
  Future<FileTransfer?> find(String fileId) async {
    final row = await _byId(fileId).getSingleOrNull();
    return row == null ? null : _toTransfer(row);
  }

  @override
  Stream<FileTransfer?> watch(String fileId) =>
      _byId(fileId)
          .watchSingleOrNull()
          .map((row) => row == null ? null : _toTransfer(row));

  SimpleSelectStatement<$FilesTable, FileRow> _byId(String fileId) =>
      _db.select(_files)..where((f) => f.fileId.equals(fileId));

  @override
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
  }) async {
    await (_db.update(_files)..where((f) => f.fileId.equals(fileId))).write(
      FilesCompanion(
        status: status == null
            ? const Value.absent()
            : Value(_statusCodes[status]!),
        bytesTransferred: Value.absentIfNull(bytesTransferred),
        sha256: Value.absentIfNull(sha256),
        localPath: clearLocalPath
            ? const Value(null)
            : Value.absentIfNull(localPath),
        error: clearError ? const Value(null) : Value.absentIfNull(error),
        attempts: Value.absentIfNull(attempts),
        updatedAt: Value(clock.now()),
      ),
    );
    return find(fileId);
  }

  @override
  Future<List<FileTransfer>> withStatus(
    Set<TransferStatus> statuses, {
    TransferDirection? direction,
  }) async {
    final rows =
        await (_db.select(_files)
              ..where((f) {
                final inStatus = f.status.isIn([
                  for (final s in statuses) _statusCodes[s]!,
                ]);
                return direction == null
                    ? inStatus
                    : inStatus &
                          f.direction.equals(
                            direction == TransferDirection.outgoing
                                ? _out
                                : _in,
                          );
              })
              ..orderBy([
                (f) => OrderingTerm.asc(f.createdAt),
                (f) => OrderingTerm.asc(f.id),
              ]))
            .get();
    return rows.map(_toTransfer).toList();
  }

  @override
  Future<FileTransfer?> findReceivedContent({
    required String peerId,
    required String sha256,
    required int size,
  }) async {
    final row =
        await (_db.select(_files)
              ..where(
                (f) =>
                    f.peerId.equals(peerId) &
                    f.direction.equals(_in) &
                    f.sha256.equals(sha256) &
                    f.size.equals(size) &
                    f.status.equals(_statusCodes[TransferStatus.completed]!) &
                    f.localPath.isNotNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toTransfer(row);
  }

  @override
  Future<int> countUsing(String localPath) async {
    final count = _files.id.count();
    final row =
        await (_db.selectOnly(_files)
              ..addColumns([count])
              ..where(_files.localPath.equals(localPath)))
            .getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Stream<List<FileTransfer>> watchRecent({int limit = 50}) =>
      (_db.select(_files)
            ..orderBy([
              (f) => OrderingTerm.desc(f.updatedAt),
              (f) => OrderingTerm.desc(f.id),
            ])
            ..limit(limit))
          .watch()
          .map((rows) => rows.map(_toTransfer).toList());

  @override
  Future<void> delete(String fileId) =>
      (_db.delete(_files)..where((f) => f.fileId.equals(fileId))).go();

  // ------------------------------------------------------------- mapping

  // Stored codes are part of the schema: never change them without a
  // migration.
  static const _in = 'in';
  static const _out = 'out';

  static const _statusCodes = {
    TransferStatus.preparing: 'preparing',
    TransferStatus.offered: 'offered',
    TransferStatus.queued: 'queued',
    TransferStatus.inProgress: 'inProgress',
    TransferStatus.paused: 'paused',
    TransferStatus.completed: 'completed',
    TransferStatus.failed: 'failed',
    TransferStatus.cancelled: 'cancelled',
    TransferStatus.rejected: 'rejected',
  };

  static final _statusByCode = {
    for (final e in _statusCodes.entries) e.value: e.key,
  };

  static FileTransfer _toTransfer(FileRow row) => FileTransfer(
    fileId: row.fileId,
    messageId: row.messageId,
    peerId: row.peerId,
    direction: row.direction == _out
        ? TransferDirection.outgoing
        : TransferDirection.incoming,
    name: row.name,
    mimeType: row.mimeType,
    size: row.size,
    bytesTransferred: row.bytesTransferred,
    // An unknown code (from a newer version) shows as failed.
    status: _statusByCode[row.status] ?? TransferStatus.failed,
    sha256: row.sha256,
    localPath: row.localPath,
    error: row.error,
    attempts: row.attempts,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}
