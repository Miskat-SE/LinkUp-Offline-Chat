import 'dart:async';
import 'dart:io';

import 'package:resqmesh/core/platform/voice.dart';

/// A [Voice] the test drives: recordings are small real files, playback
/// is reported at once.
final class FakeVoice implements Voice {
  bool permitted = true;
  bool grantOnRequest = true;

  /// What the next stopRecording returns (0: too short).
  int nextLength = 3000;
  final List<String> calls = [];
  final StreamController<VoiceState> _playback = StreamController.broadcast();

  @override
  Stream<VoiceState> get playback => _playback.stream;

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<bool> requestPermission() async {
    calls.add('request');
    if (grantOnRequest) permitted = true;
    return permitted;
  }

  @override
  Future<String> startRecording() async {
    calls.add('start');
    final dir = Directory.systemTemp.createTempSync('resqmesh_voice');
    final file = File('${dir.path}/VOICE_1.m4a')
      ..writeAsBytesSync(List.filled(2048, 7));
    return file.path;
  }

  @override
  Future<int> stopRecording() async {
    calls.add('stop');
    return nextLength;
  }

  @override
  Future<void> cancelRecording() async => calls.add('cancel');

  @override
  Future<int> level() async => 0;

  @override
  Future<void> play(String path) async {
    calls.add('play');
    _playback.add(
      VoiceState(
        path: path,
        positionMs: 1000,
        durationMs: nextLength,
        playing: true,
      ),
    );
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> stopPlayback() async => calls.add('stopPlayback');
}
