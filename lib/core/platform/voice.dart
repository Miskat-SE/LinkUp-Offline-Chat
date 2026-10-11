import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqmesh/core/platform/platform_api.g.dart';

/// Where playback of one voice message is.
final class VoiceState {
  const VoiceState({
    required this.path,
    required this.positionMs,
    required this.durationMs,
    required this.playing,
  });

  final String path;
  final int positionMs;
  final int durationMs;
  final bool playing;
}

/// Records and plays voice messages (P15.7), behind an interface for tests.
abstract interface class Voice {
  /// Playback changes; one message plays at a time.
  Stream<VoiceState> get playback;

  Future<bool> hasPermission();
  Future<bool> requestPermission();

  /// Starts recording; the file's path.
  Future<String> startRecording();

  /// Stops; the length in ms, or 0 if too short to keep.
  Future<int> stopRecording();
  Future<void> cancelRecording();

  /// Loudest level since the last call, 0–32767.
  Future<int> level();

  Future<void> play(String path);
  Future<void> pause();
  Future<void> stopPlayback();
}

/// [Voice] backed by the Kotlin bridge (`VoiceBridge.kt`).
final class PlatformVoice implements Voice, VoiceFlutterApi {
  PlatformVoice({VoiceHostApi? host}) : _host = host ?? VoiceHostApi() {
    VoiceFlutterApi.setUp(this);
  }

  final VoiceHostApi _host;
  final StreamController<VoiceState> _playback = StreamController.broadcast();

  @override
  Stream<VoiceState> get playback => _playback.stream;

  @override
  Future<bool> hasPermission() => _host.hasPermission();

  @override
  Future<bool> requestPermission() => _host.requestPermission();

  @override
  Future<String> startRecording() => _host.startRecording();

  @override
  Future<int> stopRecording() => _host.stopRecording();

  @override
  Future<void> cancelRecording() => _host.cancelRecording();

  @override
  Future<int> level() => _host.level();

  @override
  Future<void> play(String path) => _host.play(path);

  @override
  Future<void> pause() => _host.pause();

  @override
  Future<void> stopPlayback() => _host.stopPlayback();

  @override
  void onPlayback(VoicePlayback state) => _playback.add(
    VoiceState(
      path: state.path,
      positionMs: state.positionMs,
      durationMs: state.durationMs,
      playing: state.playing,
    ),
  );
}

final voiceProvider = Provider<Voice>((ref) => PlatformVoice());

/// The latest playback state, for the voice message cards.
final voicePlaybackProvider = StreamProvider<VoiceState>(
  (ref) => ref.watch(voiceProvider).playback,
);
