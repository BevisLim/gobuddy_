import 'dart:typed_data';

class VoiceRecorder {
  bool get isRecording => false;

  Future<void> start() => throw UnsupportedError(
    'Voice recording is available when you run GoBuddy in Chrome.',
  );

  Future<Uint8List?> stop() async => null;

  void dispose() {}
}
