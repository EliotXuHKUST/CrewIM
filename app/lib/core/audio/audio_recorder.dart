import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

class AppAudioRecorder {
  AppAudioRecorder._();
  static final instance = AppAudioRecorder._();

  final _recorder = AudioRecorder();
  String? _currentPath;
  bool _recording = false;

  bool get isRecording => _recording;

  Future<bool> start() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      debugPrint('Microphone permission denied');
      return false;
    }

    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentPath = '${dir.path}/voice_$timestamp.m4a';

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 64000,
        ),
        path: _currentPath!,
      );
      _recording = true;
      return true;
    } catch (e) {
      debugPrint('Recording start failed: $e');
      _currentPath = null;
      return false;
    }
  }

  /// Stops recording and returns the file path, or null if not recording.
  Future<String?> stop() async {
    if (!_recording) return null;
    try {
      final path = await _recorder.stop();
      _recording = false;
      _currentPath = null;
      return path;
    } catch (e) {
      debugPrint('Recording stop failed: $e');
      _recording = false;
      _currentPath = null;
      return null;
    }
  }

  /// Stops recording and deletes the temp file.
  Future<void> cancel() async {
    if (!_recording) return;
    try {
      await _recorder.stop();
    } catch (_) {}
    _recording = false;
    if (_currentPath != null) {
      try {
        await File(_currentPath!).delete();
      } catch (_) {}
      _currentPath = null;
    }
  }

  Future<void> dispose() async {
    await cancel();
    _recorder.dispose();
  }
}
