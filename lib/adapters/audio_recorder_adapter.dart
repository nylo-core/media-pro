/// Pluggable backend for audio recording. Implement against your preferred
/// recording package (`record`, `flutter_sound`, etc.) so `media_pro` itself
/// stays free of recording-engine dependencies.
abstract class AudioRecorderAdapter {
  /// Has the user already granted microphone permission?
  Future<bool> hasPermission();

  /// Request microphone permission. Returns `true` if granted.
  Future<bool> requestPermission();

  /// Start recording. If [path] is null, the adapter generates a temp path
  /// and returns it. The returned path is where the final recording will
  /// be written.
  Future<String> start({String? path});

  /// Stop recording and finalize the file. Returns the path on success,
  /// null if nothing was recorded.
  Future<String?> stop();

  /// Cancel the active recording and discard the file.
  Future<void> cancel();

  /// Release native resources.
  Future<void> dispose();

  /// Emits amplitude values normalised to `0.0`–`1.0`. Adapter-determined
  /// emission rate (typically 10–20 Hz).
  Stream<double> get amplitudeStream;

  /// Emits the elapsed recording duration.
  Stream<Duration> get durationStream;

  /// Emits state transitions.
  Stream<RecorderState> get stateStream;
}

enum RecorderState { idle, recording, stopping, stopped }
