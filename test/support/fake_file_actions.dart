import 'package:resqmesh/core/platform/file_actions.dart';

/// Records Open, Share and Save instead of calling Android.
final class FakeFileActions implements FileActions {
  FakeFileActions({this.free = 64 << 30});

  int? free;
  final List<String> opened = [];
  final List<String> shared = [];
  final List<String> saved = [];
  bool canOpen = true;

  @override
  Future<int?> freeBytes() async => free;

  @override
  Future<bool> open(
    String path, {
    required String name,
    required String mimeType,
  }) async {
    opened.add(name);
    return canOpen;
  }

  @override
  Future<void> share(
    String path, {
    required String name,
    required String mimeType,
  }) async => shared.add(name);

  @override
  Future<String?> saveToDownloads(
    String path, {
    required String name,
    required String mimeType,
  }) async {
    saved.add(name);
    return name;
  }

  @override
  Future<bool> videoThumbnail(String path, String outPath) async => false;
}
