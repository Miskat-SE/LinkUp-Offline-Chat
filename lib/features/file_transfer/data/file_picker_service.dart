import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqmesh/features/file_transfer/data/transfer_service.dart';

/// Lets the user pick files to send. Tests replace it.
abstract interface class FilePickerService {
  /// Files the user picked (empty if they backed out). [onBusy] is told
  /// while Android copies large picks into the app's cache.
  Future<List<PickedFile>> pick({void Function(bool busy)? onBusy});
}

final class SystemFilePicker implements FilePickerService {
  const SystemFilePicker();

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
