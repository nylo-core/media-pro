import 'package:flutter/widgets.dart';
import 'picked_file_info.dart';

/// Visual style for [SingleFilePicker]. Sealed — match exhaustively.
sealed class FilePickerStyle {
  const FilePickerStyle();
}

/// Caller-supplied widget. Receives the upload callback and the picked-file
/// metadata (null until a file is selected) so the rendered widget can show
/// empty state vs filename / size / icon.
class CustomFilePickerStyle extends FilePickerStyle {
  final Widget Function(
    BuildContext context,
    Function upload,
    PickedFileInfo? picked,
  ) builder;
  const CustomFilePickerStyle(this.builder);
}

/// Tappable row with a generic file icon, filename and size.
class SimpleFilePickerStyle extends FilePickerStyle {
  const SimpleFilePickerStyle();
}
