import 'package:flutter/widgets.dart';

/// Pluggable backend for video playback. Implement against your preferred
/// player package (`video_player`, `chewie`, `media_kit`, etc.) so
/// `media_pro` itself stays free of video-engine dependencies.
///
/// One adapter instance corresponds to one video. Created via
/// [NetworkVideo.adapterFactory] and disposed when the widget unmounts.
abstract class VideoPlayerAdapter {
  /// Load and prepare the video at [source]. Resolves once playback can
  /// start. After this completes, [aspectRatio] should be available.
  Future<void> initialize(String source);

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> dispose();

  /// Returns the rendered video surface. Called every frame, so cache
  /// internally — don't rebuild the underlying player widget here.
  Widget buildView();

  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<bool> get playingStream;

  /// Emits `true` once [initialize] has completed successfully.
  Stream<bool> get initializedStream;

  /// Aspect ratio derived from the video's intrinsic size. Null until
  /// initialized.
  double? get aspectRatio;
}
