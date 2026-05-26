import 'package:flutter/widgets.dart';

/// Visual style for [SingleVideoPicker]. Sealed — match exhaustively.
sealed class VideoPickerStyle {
  const VideoPickerStyle();
}

/// Caller-supplied widget. The builder receives the upload callback so the
/// rendered widget can trigger a pick + upload on tap.
class CustomVideoPickerStyle extends VideoPickerStyle {
  final Widget Function(BuildContext context, Function upload) builder;
  const CustomVideoPickerStyle(this.builder);
}

/// Circular poster with an optional edit badge.
class CompactVideoPickerStyle extends VideoPickerStyle {
  const CompactVideoPickerStyle();
}

/// Centered poster with a label below.
class SimpleVideoPickerStyle extends VideoPickerStyle {
  const SimpleVideoPickerStyle();
}
