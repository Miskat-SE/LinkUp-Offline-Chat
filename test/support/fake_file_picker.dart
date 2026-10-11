import 'package:resqmesh/features/file_transfer/data/file_picker_service.dart';
import 'package:resqmesh/features/file_transfer/data/transfer_service.dart';

/// Returns [next] as if the user picked those files.
final class FakeFilePicker implements FilePickerService {
  List<PickedFile> next = const [];
  int opened = 0;

  @override
  Future<List<PickedFile>> pick({void Function(bool busy)? onBusy}) async {
    opened++;
    return next;
  }

  /// What the camera returns next (null: the user backed out).
  PickedFile? photo;
  int cameraOpened = 0;

  @override
  Future<PickedFile?> takePhoto() async {
    cameraOpened++;
    return photo;
  }
}
