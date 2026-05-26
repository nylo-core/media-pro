/// Picker behaviour for [SingleVideoPicker]. Distinct from the visual
/// style — these control what the platform picker does, not how the widget
/// renders.
class VideoPickerOptions {
  /// Cap on recording duration when [SingleVideoPicker.videoSource] is
  /// `"camera"`. Null = no cap (platform default).
  final Duration? maxDuration;

  /// Camera quality preset. `image_picker` exposes this as an opaque enum
  /// (low/medium/high) — wrapped here so consumers don't need to import
  /// `image_picker` directly.
  final VideoQualityPreset quality;

  const VideoPickerOptions({
    this.maxDuration,
    this.quality = VideoQualityPreset.medium,
  });
}

enum VideoQualityPreset { low, medium, high }
