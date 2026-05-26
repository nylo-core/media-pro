/// Pluggable backend for audio playback. Implement against your preferred
/// player package (`just_audio`, `audioplayers`, `flutter_sound`, etc.) so
/// `media_pro` itself stays free of audio-engine dependencies.
///
/// One adapter instance corresponds to one underlying player. Coordinate
/// "only one playing at a time" through [AudioMessageController], which
/// owns the adapter and pauses on source changes.
abstract class AudioPlayerAdapter {
  /// Load a new source (URL or local path). Resets position to zero.
  Future<void> load(String source);

  /// Resume / start playback of the currently loaded source.
  Future<void> play();

  /// Pause playback. Position is preserved.
  Future<void> pause();

  /// Seek the currently loaded source to [position].
  Future<void> seek(Duration position);

  /// Release native resources. Called by [AudioMessageController.dispose].
  Future<void> dispose();

  /// Emits the playhead position for the loaded source.
  Stream<Duration> get positionStream;

  /// Emits duration once the source has been parsed by the player. Null
  /// while loading.
  Stream<Duration?> get durationStream;

  /// Emits `true` when actively playing, `false` when paused / stopped.
  Stream<bool> get playingStream;
}
