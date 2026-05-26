import 'package:flutter/widgets.dart';

/// Visual style for [SingleAudioPicker]. Sealed — match exhaustively.
///
/// Audio doesn't have a meaningful "compact circle" representation, so the
/// hierarchy ships with custom + simple only. A waveform variant could be
/// added later without breaking existing call sites.
sealed class AudioPickerStyle {
  const AudioPickerStyle();
}

/// Caller-supplied widget. The builder receives the upload callback so the
/// rendered widget can trigger a pick + upload on tap.
class CustomAudioPickerStyle extends AudioPickerStyle {
  final Widget Function(BuildContext context, Function upload) builder;
  const CustomAudioPickerStyle(this.builder);
}

/// Tappable row with a music icon, filename and label.
class SimpleAudioPickerStyle extends AudioPickerStyle {
  const SimpleAudioPickerStyle();
}
