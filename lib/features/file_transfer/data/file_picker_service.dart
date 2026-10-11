import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqmesh/core/platform/platform_api.g.dart';
import 'package:resqmesh/features/file_transfer/data/transfer_service.dart';

/// Lets the user pick files to send. Tests replace it.
abstract interface class FilePickerService {
  /// Files the user picked (empty if they backed out). [onBusy] is told
  /// while Android copies large picks into the app's cache.
  Future<List<PickedFile>> pick({void Function(bool busy)? onBusy});

  /// A photo from the phone's camera app, or null if the user backed out
  /// (P15.6).
  Future<PickedFile?> takePhoto();
}

final class SystemFilePicker implements FilePickerService {
  const SystemFilePicker();

  @override
  Future<PickedFile?> takePhoto() async {
    final path = await FileHostApi().takePhoto();
    if (path == null) return null;
    final file = File(path);
    return PickedFile(
      path: path,
      name: file.uri.pathSegments.last,
      size: file.lengthSync(),
      mimeType: 'image/jpeg',
    );
  }

  @override
  Future<List<PickedFile>> pick({void Function(bool busy)? onBusy}) async {
    final picked = await FilePicker.pickFiles(
      onFileLoading: (status) =>
          onBusy?.call(status == FilePickerStatus.picking),
    );
    onBusy?.call(false);
    return [
      for (final file in picked)
        if (file.path case final path?)
          PickedFile(path: path, name: file.name, size: await file.length()),
    ];
  }
}

final filePickerProvider = Provider<FilePickerService>(
  (ref) => const SystemFilePicker(),
);
