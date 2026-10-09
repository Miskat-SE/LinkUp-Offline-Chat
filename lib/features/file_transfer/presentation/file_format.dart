import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/features/file_transfer/domain/file_transfer.dart';

/// "820 B", "14.2 KB", "3.1 MB", "1.27 GB".
String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  if (unit == 0) return '$bytes B';
  final digits = value >= 100 ? 0 : (value >= 10 ? 1 : (unit >= 3 ? 2 : 1));
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

/// "2.4 MB/s".
String formatSpeed(double bytesPerSecond) =>
    '${formatBytes(bytesPerSecond.round())}/s';

/// "8 s", "3 min", "1 h 5 min".
String formatTimeLeft(Duration left) {
  if (left.inSeconds < 60) return '${left.inSeconds.clamp(1, 59)} s';
  if (left.inMinutes < 60) return '${(left.inSeconds / 60).ceil()} min';
  final minutes = left.inMinutes % 60;
  return '${left.inHours} h${minutes == 0 ? '' : ' $minutes min'}';
}

IconData kindIcon(FileKind kind) => switch (kind) {
  FileKind.image => Icons.image_rounded,
  FileKind.video => Icons.movie_rounded,
  FileKind.audio => Icons.music_note_rounded,
  FileKind.pdf => Icons.picture_as_pdf_rounded,
  FileKind.document => Icons.description_rounded,
  FileKind.archive => Icons.folder_zip_rounded,
  FileKind.apk => Icons.android_rounded,
  FileKind.other => Icons.insert_drive_file_rounded,
};

String kindLabel(FileKind kind) => switch (kind) {
  FileKind.image => 'Image',
  FileKind.video => 'Video',
  FileKind.audio => 'Audio',
  FileKind.pdf => 'PDF',
  FileKind.document => 'Document',
  FileKind.archive => 'Archive',
  FileKind.apk => 'App (APK)',
  FileKind.other => 'File',
};

/// One line that says where a transfer is, in words a user understands.
String transferStatusText(
  FileTransfer transfer, {
  required String peerName,
  TransferProgress? progress,
}) {
  final out = transfer.isOutgoing;
  final error = transfer.error;
  switch (transfer.status) {
    case TransferStatus.preparing:
      return 'Preparing…';
    case TransferStatus.offered:
      if (!out && error == TransferErrors.checksumMismatch) {
        return 'Damaged on the way · trying again';
      }
      return out ? 'Waiting to send' : 'Waiting for $peerName';
    case TransferStatus.queued:
      if (error == TransferErrors.checksumMismatch) return 'Trying again…';
      return transfer.attempts > 0 ? 'Reconnecting…' : 'Waiting to send';
    case TransferStatus.inProgress:
      final verb = out ? 'Sending' : 'Receiving';
      if (progress == null) return '$verb…';
      final parts = ['$verb ${(progress.fraction * 100).floor()}%'];
      final speed = progress.bytesPerSecond;
      if (speed != null) parts.add(formatSpeed(speed));
      final left = progress.timeLeft;
      if (left != null) parts.add('${formatTimeLeft(left)} left');
      return parts.join(' · ');
    case TransferStatus.paused:
      if (error == TransferErrors.pausedByPeer) return 'Paused by $peerName';
      if (!out) return 'Interrupted · waiting for $peerName';
      return 'Paused';
    case TransferStatus.completed:
      if (transfer.isDeleted) return 'File deleted';
      return out ? 'Sent' : 'Received';
    case TransferStatus.failed:
      return switch (error) {
        TransferErrors.unavailable => 'File no longer available',
        TransferErrors.checksumMismatch => 'Damaged on the way · not saved',
        _ => out ? 'Not sent' : 'Not received',
      };
    case TransferStatus.cancelled:
      return error == TransferErrors.cancelledByPeer
          ? 'Cancelled by $peerName'
          : 'Cancelled';
    case TransferStatus.rejected:
      return switch (error) {
        'noSpace' => out ? "$peerName's phone is full" : 'Not enough space',
        'tooLarge' => out ? 'Too large for $peerName' : 'File too large',
        'declined' => out ? '$peerName declined it' : 'Declined',
        _ => 'Not accepted',
      };
  }
}
