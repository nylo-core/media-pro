// ignore: unnecessary_library_name
library media_pro;

export '/models/api_request.dart';
export '/widgets/single_image_picker_widget.dart';
export '/widgets/grid_image_picker_widget.dart';

/// MediaPro version
const String _mediaProVersion = '2.0.3';

/// MediaPro class
class MediaPro {
  MediaPro._privateConstructor();

  static final MediaPro instance = MediaPro._privateConstructor();

  /// MediaPro version
  static String get version => _mediaProVersion;

  /// Debug mode
  bool? debugMode = false;

  /// Initialize MediaPro
  init({bool? debugMode}) {
    this.debugMode = debugMode;
  }
}
