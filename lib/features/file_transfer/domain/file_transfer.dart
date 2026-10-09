/// Whether this phone sends or receives the file.
enum TransferDirection { incoming, outgoing }

/// Where a file transfer is (PROJECT_PLAN.md §7.5).
///
/// Outgoing: preparing → offered → queued → inProgress → completed, with
/// paused, failed, cancelled or rejected on the way. Incoming: offered →
/// inProgress → completed, or paused (waiting for the sender to resume),
/// cancelled, rejected or failed.
enum TransferStatus {
  /// Sender only: copying and hashing before the file can be offered.
  preparing,

  /// Sender: the file message is out, waiting for it to be confirmed.
  /// Receiver: announced, waiting for the data.
  offered,

  /// Sender only: ready to send as soon as the person is connected and a
  /// slot is free.
  queued,
  inProgress,

  /// Stopped part-way; the partial file is kept.
  paused,
  completed,
  failed,
  cancelled,
  rejected;

  /// Bytes may still move without the user doing anything.
  bool get isActive =>
      this == preparing ||
      this == offered ||
      this == queued ||
      this == inProgress;

  bool get isFinished =>
      this == completed || this == cancelled || this == rejected;
}

/// Fixed codes stored with a transfer to explain its state.
abstract final class TransferErrors {
  static const noSpace = 'noSpace';
  static const tooLarge = 'tooLarge';
  static const declined = 'declined';
  static const invalid = 'invalid';
  static const checksumMismatch = 'checksumMismatch';
  static const unavailable = 'unavailable';
  static const connectionLost = 'connectionLost';
  static const timedOut = 'timedOut';
  static const storage = 'storage';
  static const protocol = 'protocol';
  static const cancelledByPeer = 'cancelledByPeer';
  static const pausedByPeer = 'pausedByPeer';
}

/// What a file is, for icons, labels and previews.
enum FileKind {
  image,
  video,
  audio,
  pdf,
  document,
  archive,
  apk,
  other;

  static FileKind of(String mimeType, String name) {
    final mime = mimeType.isEmpty ? _guess(name) : mimeType.toLowerCase();
    final extension = name.contains('.')
        ? name.substring(name.lastIndexOf('.') + 1).toLowerCase()
        : '';
    if (mime == 'application/vnd.android.package-archive' ||
        extension == 'apk') {
      return apk;
    }
    if (mime.startsWith('image/')) return image;
    if (mime.startsWith('video/')) return video;
    if (mime.startsWith('audio/')) return audio;
    if (mime == 'application/pdf') return pdf;
    if (const {
          'zip',
          'rar',
          '7z',
          'tar',
          'gz',
          'tgz',
          'bz2',
          'xz',
        }.contains(extension) ||
        mime.contains('zip') ||
        mime.contains('compressed')) {
      return archive;
    }
    if (mime.startsWith('text/') ||
        mime.contains('word') ||
        mime.contains('document') ||
        mime.contains('sheet') ||
        mime.contains('excel') ||
        mime.contains('presentation') ||
        mime.contains('powerpoint') ||
        const {
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'odt',
          'txt',
          'csv',
        }.contains(extension)) {
      return document;
    }
    return other;
  }

  /// Picked files have no MIME type yet; enough to choose an icon.
  static String _guess(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return '';
    return switch (name.substring(dot + 1).toLowerCase()) {
      'jpg' ||
      'jpeg' ||
      'png' ||
      'gif' ||
      'webp' ||
      'heic' ||
      'bmp' => 'image/',
      'mp4' || 'mkv' || 'mov' || 'webm' || '3gp' || 'avi' => 'video/',
      'mp3' || 'm4a' || 'aac' || 'wav' || 'ogg' || 'flac' || 'opus' => 'audio/',
      'pdf' => 'application/pdf',
      _ => '',
    };
  }
}

/// One shared file and its transfer state. Pure data.
final class FileTransfer {
  const FileTransfer({
    required this.fileId,
    required this.messageId,
    required this.peerId,
    required this.direction,
    required this.name,
    required this.mimeType,
    required this.size,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.bytesTransferred = 0,
    this.sha256,
    this.localPath,
    this.error,
    this.attempts = 0,
  });

  final String fileId;
  final String messageId;
  final String peerId;
  final TransferDirection direction;

  /// Sanitised display name.
  final String name;
  final String mimeType;
  final int size;
  final int bytesTransferred;
  final TransferStatus status;
  final String? sha256;

  /// Relative to the files directory; null if there is no copy here.
  final String? localPath;

  /// A [TransferErrors] code.
  final String? error;
  final int attempts;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOutgoing => direction == TransferDirection.outgoing;

  FileKind get kind => FileKind.of(mimeType, name);

  /// A completed incoming file whose copy was deleted in Storage.
  bool get isDeleted =>
      !isOutgoing && status == TransferStatus.completed && localPath == null;

  double get fraction => size == 0
      ? (status == TransferStatus.completed ? 1 : 0)
      : bytesTransferred / size;
}

/// Live numbers for a running transfer (PROJECT_PLAN.md §7.5).
final class TransferProgress {
  const TransferProgress({
    required this.bytes,
    required this.total,
    this.bytesPerSecond,
  });

  final int bytes;
  final int total;

  /// Moving average over the last 2 s; null until there is enough data.
  final double? bytesPerSecond;

  double get fraction => total == 0 ? 1 : bytes / total;

  Duration? get timeLeft {
    final speed = bytesPerSecond;
    if (speed == null || speed <= 0) return null;
    return Duration(seconds: ((total - bytes) / speed).ceil());
  }
}
