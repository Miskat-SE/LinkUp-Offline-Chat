import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/core/platform/file_actions.dart';
import 'package:resqmesh/core/storage/database_providers.dart';
import 'package:resqmesh/core/storage/file_store.dart';
import 'package:resqmesh/features/file_transfer/data/file_transfer_providers.dart';
import 'package:resqmesh/features/file_transfer/domain/file_transfer.dart';

/// A stored image, decoded at [width] pixels so large photos don't use a
/// lot of memory in chat.
ImageProvider storedImage(String absolutePath, {int? width}) {
  final image = FileImage(File(absolutePath));
  return width == null ? image : ResizeImage(image, width: width);
}

/// The absolute path of a transfer's copy on this phone, if there is one.
final storedPathProvider = Provider.family<String?, String>((ref, fileId) {
  final transfer = ref.watch(fileTransferProvider(fileId)).value;
  final path = transfer?.localPath;
  if (path == null ||
      transfer!.status != TransferStatus.completed && !transfer.isOutgoing) {
    return null;
  }
  return ref.watch(fileStoreProvider).absolute(path);
});

/// A video's thumbnail, made by Android the first time it is shown and
/// kept in `thumbs/`.
final videoThumbnailProvider = FutureProvider.family<String?, String>((
  ref,
  fileId,
) async {
  final video = ref.watch(storedPathProvider(fileId));
  if (video == null) return null;
  final store = ref.watch(fileStoreProvider);
  final thumb = store.absolute(FileStore.thumbPath(fileId));
  if (File(thumb).existsSync()) return thumb;
  final made = await ref.read(fileActionsProvider).videoThumbnail(video, thumb);
  return made ? thumb : null;
});
