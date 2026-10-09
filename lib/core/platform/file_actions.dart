import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqmesh/core/platform/platform_api.g.dart';

/// Getting a shared file out of the app, and facts only Android knows.
/// Tests replace it.
abstract interface class FileActions {
  /// Free bytes for the app's files, or null if unknown.
  Future<int?> freeBytes();

  /// False if no installed app can open the file.
  Future<bool> open(
    String path, {
    required String name,
    required String mimeType,
  });

  Future<void> share(
    String path, {
    required String name,
    required String mimeType,
  });

  /// The name it was saved under in Downloads, or null if it failed.
  Future<String?> saveToDownloads(
    String path, {
    required String name,
    required String mimeType,
  });

  Future<bool> videoThumbnail(String path, String outPath);
}

final class PlatformFileActions implements FileActions {
  PlatformFileActions([FileHostApi? api]) : _api = api ?? FileHostApi();

  final FileHostApi _api;

  @override
  Future<int?> freeBytes() async {
    try {
      return await _api.freeBytes();
    } on Exception {
      return null;
    }
  }

  @override
  Future<bool> open(
    String path, {
    required String name,
    required String mimeType,
  }) => _api.openFile(path, name, mimeType);

  @override
  Future<void> share(
    String path, {
    required String name,
    required String mimeType,
  }) => _api.shareFile(path, name, mimeType);

  @override
  Future<String?> saveToDownloads(
    String path, {
    required String name,
    required String mimeType,
  }) => _api.saveToDownloads(path, name, mimeType);

  @override
  Future<bool> videoThumbnail(String path, String outPath) =>
      _api.videoThumbnail(path, outPath);
}

final fileActionsProvider = Provider<FileActions>(
  (ref) => PlatformFileActions(),
);
