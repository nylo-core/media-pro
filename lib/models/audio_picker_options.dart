/// Picker behaviour for [SingleAudioPicker]. Distinct from the visual style.
class AudioPickerOptions {
  /// File extensions accepted by the picker dialog, e.g. `["mp3", "wav"]`.
  /// Null = `file_picker`'s default audio file types.
  final List<String>? allowedExtensions;

  /// Optional cap on audio duration. Enforced only when [durationResolver]
  /// is also supplied — `file_picker` doesn't return duration metadata.
  final Duration? maxDuration;

  /// Reads duration for the file at [path]. Plug in a metadata reader
  /// (`audioplayers`, `just_audio`, etc.) — `media_pro` does not depend
  /// on one to keep the package lean.
  ///
  /// Return `null` to skip the [maxDuration] check for that file.
  final Future<Duration?> Function(String path)? durationResolver;

  const AudioPickerOptions({
    this.allowedExtensions,
    this.maxDuration,
    this.durationResolver,
  });
}
