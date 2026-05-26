import 'package:flutter/widgets.dart';

/// Visual style for [SingleImagePicker]. Sealed — match exhaustively.
sealed class ImagePickerStyle {
  const ImagePickerStyle();
}

/// Caller-supplied widget. The builder receives the upload callback so the
/// rendered widget can trigger a pick + upload on tap.
class CustomImagePickerStyle extends ImagePickerStyle {
  final Widget Function(BuildContext context, Function upload) builder;
  const CustomImagePickerStyle(this.builder);
}

/// Circular thumbnail with an optional edit badge.
class CompactImagePickerStyle extends ImagePickerStyle {
  const CompactImagePickerStyle();
}

/// Centered thumbnail with a label below.
class SimpleImagePickerStyle extends ImagePickerStyle {
  const SimpleImagePickerStyle();
}
