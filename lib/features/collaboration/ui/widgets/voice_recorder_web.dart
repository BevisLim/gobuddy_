// This implementation is selected only for Flutter web.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

class VoiceRecorder {
  html.MediaRecorder? _recorder;
  final List<html.Blob> _chunks = [];

  bool get isRecording => _recorder?.state == 'recording';

  Future<void> start() async {
    if (isRecording) return;
    final stream = await html.window.navigator.mediaDevices!.getUserMedia({
      'audio': true,
    });
    final recorder = html.MediaRecorder(stream);
    _chunks.clear();
    recorder.addEventListener('dataavailable', (event) {
      final data = (event as dynamic).data as html.Blob?;
      if (data != null && data.size > 0) _chunks.add(data);
    });
    recorder.start();
    _recorder = recorder;
  }

  Future<Uint8List?> stop() async {
    final recorder = _recorder;
    if (recorder == null || recorder.state != 'recording') return null;
    final completed = Completer<Uint8List?>();
    recorder.addEventListener('stop', (_) {
      final blob = html.Blob(_chunks, 'audio/webm');
      final reader = html.FileReader();
      reader.onLoadEnd.first.then((_) {
        final result = reader.result;
        completed.complete(
          result is ByteBuffer ? Uint8List.view(result) : null,
        );
      });
      reader.readAsArrayBuffer(blob);
    });
    recorder.stop();
    _recorder = null;
    return completed.future;
  }

  void dispose() {
    if (isRecording) _recorder?.stop();
  }
}
